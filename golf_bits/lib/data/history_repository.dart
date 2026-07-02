import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';
import '../models/history_round.dart';
import '../models/round_bit_event_draft.dart';
import '../models/round_game_config.dart';
import '../models/round_session_args.dart';
import '../models/stroke_tracking.dart';
import '../models/wolf_round_state.dart';
import 'round_session_store.dart';
import 'sync_status_notifier.dart';

class HistoryRepository {
  HistoryRepository._();

  static SupabaseClient get _client => Supabase.instance.client;

  static String? get _uid => _client.auth.currentUser?.id;

  static Set<String>? _roundColumns;

  /// Filters insert/update payloads to columns known to exist (from schema probe).
  static void configureRoundColumns(Set<String>? columns) {
    _roundColumns = columns == null || columns.isEmpty ? null : Set<String>.from(columns);
  }

  static Map<String, dynamic> _filterRoundPayload(Map<String, dynamic> payload) {
    final cols = _roundColumns;
    if (cols == null || cols.isEmpty) return payload;
    return {
      for (final entry in payload.entries)
        if (cols.contains(entry.key)) entry.key: entry.value,
    };
  }

  static String? _missingColumn(Object error) {
    if (error is! PostgrestException) return null;
    final m = error.message;
    final pgrst = RegExp(r"Could not find the '([^']+)' column").firstMatch(m);
    if (pgrst != null) return pgrst.group(1);
    final pg = RegExp(r'column\s+rounds\.([a-zA-Z0-9_]+)\s+does not exist').firstMatch(m);
    if (pg != null) return pg.group(1);
    return null;
  }

  static bool _isRlsViolation(Object error) {
    if (error is! PostgrestException) return false;
    if (error.code == '42501') return true;
    return error.message.toLowerCase().contains('row-level security');
  }

  static StateError _rlsError() {
    return StateError(
      'Database policies are blocking round sync. Run the rounds RLS compatibility migration, then retry.',
    );
  }

  static Future<Map<String, dynamic>> _insertRoundWithFallback(
    Map<String, dynamic> payload, {
    String select = 'id',
  }) async {
    final filtered = _filterRoundPayload(payload);
    try {
      final res = await _client.from('rounds').insert(filtered).select(select).single();
      SyncStatusNotifier.instance.recordSuccess();
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      if (_isRlsViolation(e)) throw _rlsError();
      // Legacy fallback if schema probe was unavailable.
      final working = Map<String, dynamic>.from(payload);
      for (var i = 0; i < 12; i++) {
        try {
          final res = await _client.from('rounds').insert(working).select(select).single();
          SyncStatusNotifier.instance.recordSuccess();
          return Map<String, dynamic>.from(res as Map);
        } catch (err) {
          if (_isRlsViolation(err)) throw _rlsError();
          final col = _missingColumn(err);
          if (col == null || !working.containsKey(col)) rethrow;
          working.remove(col);
        }
      }
      SyncStatusNotifier.instance.recordFailure();
      rethrow;
    }
  }

  static Future<void> _updateRoundWithFallback({
    required String roundId,
    required Map<String, dynamic> payload,
  }) async {
    final filtered = _filterRoundPayload(payload);
    try {
      if (filtered.isNotEmpty) {
        await _client.from('rounds').update(filtered).eq('id', roundId);
      }
      SyncStatusNotifier.instance.recordSuccess();
      return;
    } catch (e) {
      if (_isRlsViolation(e)) throw _rlsError();
      final working = Map<String, dynamic>.from(payload);
      for (var i = 0; i < 12; i++) {
        if (working.isEmpty) return;
        try {
          await _client.from('rounds').update(working).eq('id', roundId);
          SyncStatusNotifier.instance.recordSuccess();
          return;
        } catch (err) {
          if (_isRlsViolation(err)) throw _rlsError();
          final col = _missingColumn(err);
          if (col == null || !working.containsKey(col)) rethrow;
          working.remove(col);
        }
      }
      SyncStatusNotifier.instance.recordFailure();
      rethrow;
    }
  }

  /// One round row by id (must belong to current user). Null if missing or RLS denies.
  static Future<HistoryRound?> fetchRoundById(String id) async {
    if (!SupabaseEnv.isConfigured) return null;
    final uid = _uid;
    if (uid == null) return null;

    final rows = await _client
        .from('rounds')
        .select()
        .eq('id', id)
        .eq('created_by', uid)
        .limit(1);

    final list = rows as List<dynamic>;
    if (list.isEmpty) return null;
    return HistoryRound.fromSupabase(Map<String, dynamic>.from(list.first as Map));
  }

  /// Past rounds created by the signed-in user (newest first).
  static Future<List<HistoryRound>> fetchMyRounds() async {
    if (!SupabaseEnv.isConfigured) return [];
    final uid = _uid;
    if (uid == null) return [];

    final rows = await _client
        .from('rounds')
        .select()
        .eq('created_by', uid)
        .order('ended_at', ascending: false)
        .limit(500);

    final maps = _roundMaps(rows);
    _sortRoundMapsByTimestampDesc(maps);
    return maps.map(HistoryRound.fromSupabase).toList();
  }

  static List<Map<String, dynamic>> _roundMaps(dynamic rows) {
    return (rows as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static void _sortRoundMapsByTimestampDesc(List<Map<String, dynamic>> maps) {
    maps.sort(
      (a, b) => HistoryRound.timestampUtcFromRow(b).compareTo(HistoryRound.timestampUtcFromRow(a)),
    );
  }

  /// Latest completed + latest in-progress for the home dashboard (single round-trip).
  ///
  /// Does not filter on `rounds.completed` in SQL — some databases only have `completed_at`.
  static Future<({HistoryRound? active, HistoryRound? previous})> fetchHomeDashboardRounds() async {
    if (!SupabaseEnv.isConfigured) {
      return (active: null, previous: null);
    }
    final uid = _uid;
    if (uid == null) {
      return (active: null, previous: null);
    }

    final rows = await _client
        .from('rounds')
        .select()
        .eq('created_by', uid)
        .order('ended_at', ascending: false)
        .limit(80);

    final maps = _roundMaps(rows);
    _sortRoundMapsByTimestampDesc(maps);
    HistoryRound? previous;
    HistoryRound? active;
    for (final map in maps) {
      final r = HistoryRound.fromSupabase(map);
      if (previous == null && r.completed) previous = r;
      if (active == null && !r.completed) active = r;
    }
    return (active: active, previous: previous);
  }

  /// Latest completed round for the signed-in user (e.g. home “previous session”), or null.
  static Future<HistoryRound?> fetchLatestCompletedRound() async {
    final r = await fetchHomeDashboardRounds();
    return r.previous;
  }

  /// Latest in-progress round, or null.
  static Future<HistoryRound?> fetchLatestIncompleteRound() async {
    final r = await fetchHomeDashboardRounds();
    return r.active;
  }

  /// Persists a completed round row; returns new row `id` for bit-event inserts.
  static Future<String> saveCompletedRound(Map<String, dynamic> row) async {
    if (!SupabaseEnv.isConfigured) {
      throw StateError('Supabase is not configured');
    }
    final uid = _uid;
    if (uid == null) {
      throw StateError('Must be signed in to save a round');
    }

    final res = await _insertRoundWithFallback({
      ...row,
      'status': 'completed',
      'created_by': uid,
      // Legacy schema compatibility: some projects still require these owner columns.
      'user_id': uid,
      'owner_id': uid,
    });

    return res['id'] as String;
  }

  /// Creates an in-progress round row and returns new `id`.
  static Future<String> createInProgressRound({
    required String courseName,
    required String courseShortTitle,
    required int holeCount,
    required List<String> players,
    required List<RoundParticipant> participants,
    required int currentHole,
    int startHole = 1,
    String? courseCatalogId,
    String? courseCoverageLevel,
    Map<String, int>? holePars,
    Map<String, int>? holeYardages,
    Map<String, int>? holeStrokeIndexes,
    StrokeTrackingMode strokeTrackingMode = StrokeTrackingMode.off,
    RoundGameConfig? gameConfig,
  }) async {
    if (!SupabaseEnv.isConfigured) {
      throw StateError('Supabase is not configured');
    }
    final uid = _uid;
    if (uid == null) {
      throw StateError('Must be signed in to start a synced round');
    }
    final config = gameConfig ?? const RoundGameConfig();
    final res = await _insertRoundWithFallback({
      'created_by': uid,
      // Legacy schema compatibility: some projects still require these owner columns.
      'user_id': uid,
      'owner_id': uid,
      'course_name': courseName,
      'course_short_title': courseShortTitle,
      'holes': holeCount,
      'hole_count': holeCount,
      'start_hole': startHole,
      'status': 'in_progress',
      'completed': false,
      'completed_at': null,
      'winner_name': 'TBD',
      'winner_bits': 0,
      'players': players,
      'participants': participants.map((p) => p.toJson()).toList(),
      'standings': const <Map<String, dynamic>>[],
      'left_early': const <Map<String, dynamic>>[],
      'current_hole': currentHole,
      'score_by_player': <String, int>{for (final p in participants) p.key: 0},
      'round_formats': roundFormatsToDb(config.formats),
      'game_config': config.toJson(),
      'wolf_points_by_player': <String, int>{for (final p in participants) p.key: 0},
      'wolf_hole_results': <String, dynamic>{},
      'wolf_hole_phase': WolfInRoundPhase.call.toDb(),
      if (courseCatalogId != null) 'course_catalog_id': courseCatalogId,
      if (courseCoverageLevel != null) 'course_coverage_level': courseCoverageLevel,
      if (holePars != null) 'hole_pars': holePars,
      if (holeYardages != null) 'hole_yardages': holeYardages,
      if (holeStrokeIndexes != null) 'hole_stroke_indexes': holeStrokeIndexes,
      'stroke_tracking_mode': strokeTrackingMode.toDb(),
      'stroke_by_hole': <String, dynamic>{},
      'gross_by_player': <String, int>{},
    });
    return res['id'] as String;
  }

  /// Persists current round progress for resume on next launch.
  static Future<void> updateRoundProgress({
    required String roundId,
    required int currentHole,
    required Map<String, int> scoreByPlayer,
    Map<String, Map<int, int>>? strokeByHole,
    Map<String, int>? grossByPlayer,
    Map<String, int>? wolfPointsByPlayer,
    Map<int, WolfHoleResult>? wolfHoleResults,
    WolfInRoundPhase? wolfHolePhase,
    Map<String, dynamic>? gameConfig,
  }) async {
    if (!SupabaseEnv.isConfigured) return;
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      if (_roundColumns == null || _roundColumns!.contains('status')) 'status': 'in_progress',
      'current_hole': currentHole,
      'score_by_player': scoreByPlayer,
      if (_roundColumns == null || _roundColumns!.contains('last_activity_at'))
        'last_activity_at': now,
    };
    if (strokeByHole != null) {
      payload['stroke_by_hole'] = strokeByHoleToJson(strokeByHole);
    }
    if (grossByPlayer != null) {
      payload['gross_by_player'] = grossByPlayer;
    }
    if (wolfPointsByPlayer != null) {
      payload['wolf_points_by_player'] = wolfPointsByPlayer;
    }
    if (wolfHoleResults != null) {
      payload['wolf_hole_results'] = wolfHoleResultsToJson(wolfHoleResults);
    }
    if (wolfHolePhase != null) {
      payload['wolf_hole_phase'] = wolfHolePhase.toDb();
    }
    if (gameConfig != null) {
      payload['game_config'] = gameConfig;
    }
    await _updateRoundWithFallback(roundId: roundId, payload: payload);
  }

  static Future<void> replayPendingBitEvents(String roundId) async {
    if (!SupabaseEnv.isConfigured || roundId.isEmpty) return;
    final pending = await RoundSessionStore.loadPendingBitEvents();
    if (pending.isEmpty) return;
    final remaining = <Map<String, dynamic>>[];
    for (final event in pending) {
      if ((event['round_id'] as String?) != roundId) {
        remaining.add(event);
        continue;
      }
      try {
        final action = event['action'] as String? ?? 'save';
        if (action == 'delete') {
          await deleteLatestBitEventForRound(
            roundId: roundId,
            participantKey: event['participant_key'] as String?,
            playerName: event['player_name'] as String?,
            hole: (event['hole'] as num).toInt(),
            eventLabel: event['event_label'] as String,
            delta: (event['delta'] as num).toInt(),
          );
        } else {
          await saveBitEventsForRound(
            roundId,
            [
              RoundBitEventDraft(
                participantKey: event['participant_key'] as String?,
                playerName: event['player_name'] as String? ?? '',
                hole: (event['hole'] as num).toInt(),
                eventLabel: event['event_label'] as String,
                delta: (event['delta'] as num).toInt(),
                iconKey: event['icon_key'] as String?,
              ),
            ],
          );
        }
      } catch (_) {
        remaining.add(event);
      }
    }
    await RoundSessionStore.savePendingBitEvents(remaining);
  }

  /// Writes round handicaps back to linked player profiles.
  static Future<void> syncHandicapsToProfiles({
    required List<RoundParticipant> participants,
    required Map<String, int> handicaps,
  }) async {
    if (!SupabaseEnv.isConfigured) return;
    for (final p in participants) {
      final userId = p.userId;
      final hc = handicaps[p.key];
      if (userId == null || userId.isEmpty || hc == null) continue;
      try {
        await _client.from('profiles').update({'handicap': hc}).eq('id', userId);
      } catch (_) {
        // Column may not exist until migration applied.
      }
    }
  }

  /// Fetch handicaps for profile pre-fill at setup.
  static Future<Map<String, int>> fetchHandicapsForUserIds(Iterable<String?> userIds) async {
    if (!SupabaseEnv.isConfigured) return {};
    final ids = userIds.whereType<String>().where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return {};
    try {
      final rows = await _client.from('profiles').select('id, handicap').inFilter('id', ids);
      final out = <String, int>{};
      for (final row in rows as List<dynamic>) {
        final m = Map<String, dynamic>.from(row as Map);
        final id = m['id'] as String?;
        final hc = (m['handicap'] as num?)?.toInt();
        if (id != null && hc != null) out[id] = hc;
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  /// All bit events for a round (resume hydration).
  static Future<List<Map<String, dynamic>>> fetchBitEventsForRound(String roundId) async {
    if (!SupabaseEnv.isConfigured || roundId.isEmpty) return [];
    final rows = await _client.from('round_bit_events').select().eq('round_id', roundId);
    final list = (rows as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList()
      ..sort((a, b) {
        final ha = (a['hole'] as num).toInt();
        final hb = (b['hole'] as num).toInt();
        if (ha != hb) return ha.compareTo(hb);
        return (a['created_at'] as String).compareTo(b['created_at'] as String);
      });
    return list;
  }

  /// Marks an in-progress round as completed and writes final summary.
  static Future<void> completeRound({
    required String roundId,
    required Map<String, dynamic> row,
  }) async {
    if (!SupabaseEnv.isConfigured) return;
    await _updateRoundWithFallback(roundId: roundId, payload: row);
  }

  /// Deletes an in-progress round and any related bit events.
  ///
  /// Used for "dismiss/discard" UX where the user explicitly abandons a round
  /// before completion.
  static Future<void> deleteRound(String roundId) async {
    if (!SupabaseEnv.isConfigured) return;
    final uid = _uid;
    if (roundId.isEmpty) return;

    // Best-effort cleanup of bit events; ignore failures so we can still try to
    // remove the parent round row.
    try {
      await _client.from('round_bit_events').delete().eq('round_id', roundId);
    } catch (_) {
      // Non-fatal.
    }

    if (uid == null) {
      await _client.from('rounds').delete().eq('id', roundId);
      return;
    }

    try {
      await _client.from('rounds').delete().eq('id', roundId).eq('created_by', uid);
    } catch (e) {
      if (_isRlsViolation(e)) throw _rlsError();
      final col = _missingColumn(e);
      if (col == 'created_by') {
        await _client.from('rounds').delete().eq('id', roundId);
        return;
      }
      rethrow;
    }
  }

  /// Inserts bit events after the parent round row exists.
  static Future<void> saveBitEventsForRound(String roundId, List<RoundBitEventDraft> events) async {
    if (!SupabaseEnv.isConfigured || events.isEmpty) return;

    final rows = events.map((e) => e.toRow(roundId)).toList();
    await Supabase.instance.client.from('round_bit_events').insert(rows);
  }

  /// Removes one matching event (latest first) for tap-to-toggle behavior.
  static Future<void> deleteLatestBitEventForRound({
    required String roundId,
    String? participantKey,
    String? playerName,
    required int hole,
    required String eventLabel,
    required int delta,
  }) async {
    if (!SupabaseEnv.isConfigured) return;
    dynamic rows;
    if (participantKey != null && participantKey.isNotEmpty) {
      rows = await Supabase.instance.client
          .from('round_bit_events')
          .select('id')
          .eq('round_id', roundId)
          .eq('participant_key', participantKey)
          .eq('hole', hole)
          .eq('event_label', eventLabel)
          .eq('delta', delta)
          .order('created_at', ascending: false)
          .limit(1);
    } else if (playerName != null && playerName.isNotEmpty) {
      rows = await Supabase.instance.client
          .from('round_bit_events')
          .select('id')
          .eq('round_id', roundId)
          .eq('player_name', playerName)
          .eq('hole', hole)
          .eq('event_label', eventLabel)
          .eq('delta', delta)
          .order('created_at', ascending: false)
          .limit(1);
    } else {
      return;
    }
    final list = rows as List<dynamic>;
    if (list.isEmpty) return;
    final id = (list.first as Map)['id'];
    if (id == null) return;
    await Supabase.instance.client.from('round_bit_events').delete().eq('id', id);
  }

  /// Bit timeline for one player in a saved round.
  static Future<List<Map<String, dynamic>>> fetchBitEventsForPlayer({
    required String roundId,
    required String playerName,
    String? participantKey,
  }) async {
    if (!SupabaseEnv.isConfigured) return [];

    dynamic rows;
    try {
      if (participantKey != null && participantKey.isNotEmpty) {
        rows = await Supabase.instance.client
            .from('round_bit_events')
            .select()
            .eq('round_id', roundId)
            .eq('participant_key', participantKey);
      } else {
        rows = await Supabase.instance.client
            .from('round_bit_events')
            .select()
            .eq('round_id', roundId)
            .eq('player_name', playerName);
      }
    } catch (e) {
      final missing = _missingColumn(e);
      if (missing != 'participant_key') rethrow;
      rows = await Supabase.instance.client
          .from('round_bit_events')
          .select()
          .eq('round_id', roundId)
          .eq('player_name', playerName);
    }

    final list = (rows as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList()
      ..sort((a, b) {
        final ha = (a['hole'] as num).toInt();
        final hb = (b['hole'] as num).toInt();
        if (ha != hb) return ha.compareTo(hb);
        return (a['created_at'] as String).compareTo(b['created_at'] as String);
      });
    return list;
  }

  /// Match a player by email to an existing account/profile.
  static Future<RoundParticipant?> lookupPlayerByEmail(String email) async {
    if (!SupabaseEnv.isConfigured) return null;
    final e = email.trim().toLowerCase();
    if (e.isEmpty) return null;
    final rows = await _client.rpc('lookup_player_by_email', params: {'input_email': e}) as List<dynamic>;
    if (rows.isEmpty) return null;
    final row = Map<String, dynamic>.from(rows.first as Map);
    final userId = row['user_id'] as String?;
    final displayName = (row['display_name'] as String?)?.trim();
    if (userId == null || displayName == null || displayName.isEmpty) return null;
    return RoundParticipant(
      key: 'u_$userId',
      displayName: displayName,
      email: e,
      userId: userId,
    );
  }

  /// Sets `participants[].user_id` on rounds where your profile email matches an entry (post-signup link).
  static Future<int> claimParticipantIdentityForCurrentUser() async {
    if (!SupabaseEnv.isConfigured || _uid == null) return 0;
    try {
      final n = await _client.rpc('claim_participant_identity_for_current_user');
      if (n is int) return n;
      if (n is num) return n.toInt();
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// Sends round invite emails (best-effort) for participant emails not yet linked to a user.
  static Future<void> sendRoundInvites({
    required String roundId,
    required String courseName,
    required List<RoundParticipant> participants,
  }) async {
    if (!SupabaseEnv.isConfigured || _uid == null) return;
    final invites = [
      for (final p in participants)
        if ((p.userId == null || p.userId!.isEmpty) && (p.email?.trim().isNotEmpty ?? false))
          {
            'email': p.email!.trim().toLowerCase(),
            'displayName': p.displayName,
          },
    ];
    if (invites.isEmpty) return;
    try {
      await _client.functions.invoke(
        'send-round-invite',
        body: {
          'roundId': roundId,
          'courseName': courseName,
          'invites': invites,
        },
      );
    } catch (_) {
      // Non-fatal: round creation should still succeed even when email provider is down.
    }
  }

  /// Accepts invite token for signed-in user and links participant identity where possible.
  static Future<bool> acceptRoundInviteForCurrentUser(String token) async {
    if (!SupabaseEnv.isConfigured || _uid == null) return false;
    try {
      final v = await _client.rpc(
        'accept_round_invite_for_current_user',
        params: {'invite_token': token},
      );
      if (v is bool) return v;
      return false;
    } catch (_) {
      return false;
    }
  }
}

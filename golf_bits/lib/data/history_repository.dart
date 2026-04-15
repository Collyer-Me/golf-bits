import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';
import '../models/history_round.dart';
import '../models/round_bit_event_draft.dart';
import '../models/round_session_args.dart';

class HistoryRepository {
  HistoryRepository._();

  static SupabaseClient get _client => Supabase.instance.client;

  static String? get _uid => _client.auth.currentUser?.id;

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
    final working = Map<String, dynamic>.from(payload);
    for (var i = 0; i < 12; i++) {
      try {
        final res = await _client.from('rounds').insert(working).select(select).single();
        return Map<String, dynamic>.from(res as Map);
      } catch (e) {
        if (_isRlsViolation(e)) throw _rlsError();
        final col = _missingColumn(e);
        if (col == null || !working.containsKey(col)) rethrow;
        working.remove(col);
      }
    }
    throw StateError('Could not insert round after schema fallback attempts');
  }

  static Future<void> _updateRoundWithFallback({
    required String roundId,
    required Map<String, dynamic> payload,
  }) async {
    final working = Map<String, dynamic>.from(payload);
    for (var i = 0; i < 12; i++) {
      if (working.isEmpty) return;
      try {
        await _client.from('rounds').update(working).eq('id', roundId);
        return;
      } catch (e) {
        if (_isRlsViolation(e)) throw _rlsError();
        final col = _missingColumn(e);
        if (col == null || !working.containsKey(col)) rethrow;
        working.remove(col);
      }
    }
    throw StateError('Could not update round after schema fallback attempts');
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
  }) async {
    if (!SupabaseEnv.isConfigured) {
      throw StateError('Supabase is not configured');
    }
    final uid = _uid;
    if (uid == null) {
      throw StateError('Must be signed in to start a synced round');
    }
    final res = await _insertRoundWithFallback({
      'created_by': uid,
      // Legacy schema compatibility: some projects still require these owner columns.
      'user_id': uid,
      'owner_id': uid,
      'course_name': courseName,
      'course_short_title': courseShortTitle,
      'hole_count': holeCount,
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
    });
    return res['id'] as String;
  }

  /// Persists current round progress for resume on next launch.
  static Future<void> updateRoundProgress({
    required String roundId,
    required int currentHole,
    required Map<String, int> scoreByPlayer,
  }) async {
    if (!SupabaseEnv.isConfigured) return;
    await _updateRoundWithFallback(
      roundId: roundId,
      payload: {
        'status': 'in_progress',
        'current_hole': currentHole,
        'score_by_player': scoreByPlayer,
        'ended_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  /// Marks an in-progress round as completed and writes final summary.
  static Future<void> completeRound({
    required String roundId,
    required Map<String, dynamic> row,
  }) async {
    if (!SupabaseEnv.isConfigured) return;
    await _updateRoundWithFallback(roundId: roundId, payload: row);
  }

  /// Inserts bit events after the parent round row exists.
  static Future<void> saveBitEventsForRound(String roundId, List<RoundBitEventDraft> events) async {
    if (!SupabaseEnv.isConfigured || events.isEmpty) return;

    final rows = events.map((e) => e.toRow(roundId)).toList();
    await Supabase.instance.client.from('round_bit_events').insert(rows);
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
    final resolvedEmail = (row['email'] as String?)?.trim();
    if (userId == null || displayName == null || displayName.isEmpty) return null;
    return RoundParticipant(
      key: 'u_$userId',
      displayName: displayName,
      email: resolvedEmail ?? e,
      userId: userId,
    );
  }
}

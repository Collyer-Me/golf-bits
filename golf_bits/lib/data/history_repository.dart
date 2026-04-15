import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';
import '../models/history_round.dart';
import '../models/round_bit_event_draft.dart';

class HistoryRepository {
  HistoryRepository._();

  static SupabaseClient get _client => Supabase.instance.client;

  static String? get _uid => _client.auth.currentUser?.id;

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

    final res = await _client
        .from('rounds')
        .insert({
          ...row,
          'created_by': uid,
        })
        .select('id')
        .single();

    return res['id'] as String;
  }

  /// Creates an in-progress round row and returns new `id`.
  static Future<String> createInProgressRound({
    required String courseName,
    required String courseShortTitle,
    required int holeCount,
    required List<String> players,
    required int currentHole,
  }) async {
    if (!SupabaseEnv.isConfigured) {
      throw StateError('Supabase is not configured');
    }
    final uid = _uid;
    if (uid == null) {
      throw StateError('Must be signed in to start a synced round');
    }
    final res = await _client
        .from('rounds')
        .insert({
          'created_by': uid,
          'course_name': courseName,
          'course_short_title': courseShortTitle,
          'hole_count': holeCount,
          'completed': false,
          'completed_at': null,
          'winner_name': 'TBD',
          'winner_bits': 0,
          'players': players,
          'standings': const <Map<String, dynamic>>[],
          'left_early': const <Map<String, dynamic>>[],
          'current_hole': currentHole,
          'score_by_player': <String, int>{for (final p in players) p: 0},
        })
        .select('id')
        .single();
    return res['id'] as String;
  }

  /// Persists current round progress for resume on next launch.
  static Future<void> updateRoundProgress({
    required String roundId,
    required int currentHole,
    required Map<String, int> scoreByPlayer,
  }) async {
    if (!SupabaseEnv.isConfigured) return;
    await _client
        .from('rounds')
        .update({
          'current_hole': currentHole,
          'score_by_player': scoreByPlayer,
          'ended_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', roundId);
  }

  /// Marks an in-progress round as completed and writes final summary.
  static Future<void> completeRound({
    required String roundId,
    required Map<String, dynamic> row,
  }) async {
    if (!SupabaseEnv.isConfigured) return;
    await _client.from('rounds').update(row).eq('id', roundId);
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
  }) async {
    if (!SupabaseEnv.isConfigured) return [];

    final rows = await Supabase.instance.client
        .from('round_bit_events')
        .select()
        .eq('round_id', roundId)
        .eq('player_name', playerName);

    final list = (rows as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList()
      ..sort((a, b) {
        final ha = (a['hole'] as num).toInt();
        final hb = (b['hole'] as num).toInt();
        if (ha != hb) return ha.compareTo(hb);
        return (a['created_at'] as String).compareTo(b['created_at'] as String);
      });
    return list;
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';
import '../models/history_round.dart';
import '../models/round_bit_event_draft.dart';

class HistoryRepository {
  HistoryRepository._();

  /// Past rounds created by the signed-in user (newest first).
  static Future<List<HistoryRound>> fetchMyRounds() async {
    if (!SupabaseEnv.isConfigured) return [];
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return [];

    final rows = await Supabase.instance.client
        .from('rounds')
        .select()
        .eq('created_by', uid)
        .order('ended_at', ascending: false);

    return (rows as List<dynamic>)
        .map((e) => HistoryRound.fromSupabase(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static List<Map<String, dynamic>> _roundMaps(dynamic rows) {
    return (rows as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static void _sortByEndedAtDesc(List<Map<String, dynamic>> maps) {
    maps.sort(
      (a, b) => DateTime.parse(b['ended_at'] as String).compareTo(DateTime.parse(a['ended_at'] as String)),
    );
  }

  /// Latest completed + latest in-progress for the home dashboard (single round-trip).
  ///
  /// Does not filter on `rounds.completed` in SQL — some databases only have `completed_at`.
  static Future<({HistoryRound? active, HistoryRound? previous})> fetchHomeDashboardRounds() async {
    if (!SupabaseEnv.isConfigured) {
      return (active: null, previous: null);
    }
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      return (active: null, previous: null);
    }

    final rows = await Supabase.instance.client
        .from('rounds')
        .select()
        .eq('created_by', uid)
        .order('ended_at', ascending: false)
        .limit(80);

    final maps = _roundMaps(rows);
    _sortByEndedAtDesc(maps);
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
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Must be signed in to save a round');
    }

    final res = await Supabase.instance.client
        .from('rounds')
        .insert({
          ...row,
          'created_by': uid,
        })
        .select('id')
        .single();

    return res['id'] as String;
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

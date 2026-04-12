import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';
import '../models/history_round.dart';

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

  /// Persists a completed round row (server sets `created_by` via RLS + client passes uid).
  static Future<void> saveCompletedRound(Map<String, dynamic> row) async {
    if (!SupabaseEnv.isConfigured) {
      throw StateError('Supabase is not configured');
    }
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Must be signed in to save a round');
    }

    await Supabase.instance.client.from('rounds').insert({
      ...row,
      'created_by': uid,
    });
  }
}

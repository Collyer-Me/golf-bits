import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';
import '../models/friend_models.dart';
import 'round_coplayers.dart';

abstract final class FriendsRepository {
  static SupabaseClient get _client => Supabase.instance.client;

  static String? get _uid => _client.auth.currentUser?.id;

  static Future<List<FriendConnection>> fetchOverview() async {
    if (!SupabaseEnv.isConfigured || _uid == null) return const [];
    final rows = await _client.rpc('friend_overview') as List<dynamic>;
    return rows
        .map((row) => FriendConnection.fromRpc(Map<String, dynamic>.from(row as Map)))
        .where((item) => item.friendshipId.isNotEmpty && item.otherUserId.isNotEmpty)
        .toList();
  }

  /// Co-players from your rounds who are not already covered by a non-declined friendship row.
  static List<CoplayerSummary> coplayerSummariesExcludingFriendships(
    List<FriendConnection> connections,
    Map<String, int> nameCounts,
  ) {
    final reserved = <String>{
      for (final c in connections)
        if (c.status != 'declined') c.otherDisplayName.trim().toLowerCase(),
    };
    final out = <CoplayerSummary>[];
    for (final e in nameCounts.entries) {
      final key = e.key.trim().toLowerCase();
      if (key.isEmpty || reserved.contains(key)) continue;
      out.add(CoplayerSummary(displayName: e.key, roundsPlayed: e.value));
    }
    out.sort((a, b) {
      final byCount = b.roundsPlayed.compareTo(a.roundsPlayed);
      if (byCount != 0) return byCount;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return out;
  }

  static Future<List<CoplayerSummary>> fetchCoplayerSummaries(
    List<FriendConnection> connections,
  ) async {
    final counts = await RoundCoplayers.fetchCoPlayerCountsForCurrentUser();
    return coplayerSummariesExcludingFriendships(connections, counts);
  }

  static Future<List<FriendCandidate>> searchCandidates(String query) async {
    if (!SupabaseEnv.isConfigured || _uid == null) return const [];
    final q = query.trim();
    if (q.length < 2) return const [];
    final rows = await _client.rpc(
      'search_friend_candidates',
      params: {'input_query': q, 'input_limit': 20},
    ) as List<dynamic>;
    return rows
        .map((row) => FriendCandidate.fromRpc(Map<String, dynamic>.from(row as Map)))
        .where((item) => item.userId.isNotEmpty)
        .toList();
  }

  static Future<void> sendFriendRequest(String otherUserId) async {
    final uid = _uid;
    if (!SupabaseEnv.isConfigured || uid == null) return;
    if (otherUserId.isEmpty || otherUserId == uid) return;

    final existing = await _client
        .from('friendships')
        .select('id,status,requester_user_id,addressee_user_id')
        .or('and(requester_user_id.eq.$uid,addressee_user_id.eq.$otherUserId),and(requester_user_id.eq.$otherUserId,addressee_user_id.eq.$uid)')
        .limit(1);
    final existingList = existing as List<dynamic>;
    if (existingList.isEmpty) {
      await _client.from('friendships').insert({
        'requester_user_id': uid,
        'addressee_user_id': otherUserId,
        'status': 'pending',
      });
      return;
    }
    final row = Map<String, dynamic>.from(existingList.first as Map);
    final status = (row['status'] as String?) ?? 'pending';
    final requester = (row['requester_user_id'] as String?) ?? '';
    final id = (row['id'] as String?) ?? '';
    if (status == 'pending' && requester == otherUserId && id.isNotEmpty) {
      await _client
          .from('friendships')
          .update({'status': 'accepted', 'acted_by': uid, 'responded_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id);
    }
  }

  static Future<void> acceptRequest(String friendshipId) async {
    final uid = _uid;
    if (!SupabaseEnv.isConfigured || uid == null) return;
    await _client
        .from('friendships')
        .update({'status': 'accepted', 'acted_by': uid, 'responded_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', friendshipId)
        .eq('addressee_user_id', uid)
        .eq('status', 'pending');
  }

  static Future<void> declineRequest(String friendshipId) async {
    final uid = _uid;
    if (!SupabaseEnv.isConfigured || uid == null) return;
    await _client
        .from('friendships')
        .update({'status': 'declined', 'acted_by': uid, 'responded_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', friendshipId)
        .eq('addressee_user_id', uid)
        .eq('status', 'pending');
  }

  static Future<void> removeFriend(String friendshipId) async {
    if (!SupabaseEnv.isConfigured || _uid == null) return;
    await _client.from('friendships').delete().eq('id', friendshipId);
  }
}

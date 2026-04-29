import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';

/// Reads co-player display names from `rounds.players` / `rounds.participants` with
/// tolerant decoding so one bad row does not wipe the whole list.
abstract final class RoundCoplayers {
  static List<Map<String, dynamic>> _roundMaps(dynamic rows) {
    return (rows as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static const _roundSelectColumns = 'players,participants,ended_at,completed_at,created_at';

  static String? _readString(Map<String, dynamic> m, List<String> keys) {
    for (final key in keys) {
      final v = m[key];
      if (v is String) {
        final t = v.trim();
        if (t.isNotEmpty) return t;
      }
    }
    return null;
  }

  static bool _readBool(Map<String, dynamic> m, List<String> keys) {
    for (final key in keys) {
      final v = m[key];
      if (v is bool) return v;
      if (v is String) {
        final t = v.trim().toLowerCase();
        if (t == 'true') return true;
        if (t == 'false') return false;
      }
    }
    return false;
  }

  static DateTime _rowTimestampUtc(Map<String, dynamic> row) {
    for (final key in ['ended_at', 'completed_at', 'created_at']) {
      final v = row[key];
      if (v is String && v.isNotEmpty) {
        try {
          return DateTime.parse(v).toUtc();
        } catch (_) {}
      }
      if (v is DateTime) return v.toUtc();
    }
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  static void _sortRowsNewestFirst(List<Map<String, dynamic>> rows) {
    rows.sort((a, b) => _rowTimestampUtc(b).compareTo(_rowTimestampUtc(a)));
  }

  static Future<List<Map<String, dynamic>>> _fetchRowsByOwnerColumn(
    SupabaseClient client,
    String userId,
    String ownerColumn,
  ) async {
    try {
      final rows = await client.from('rounds').select(_roundSelectColumns).eq(ownerColumn, userId).limit(200);
      return _roundMaps(rows);
    } catch (_) {
      try {
        // Legacy schema may not have `participants` yet.
        final rows = await client.from('rounds').select('players,ended_at,completed_at,created_at').eq(ownerColumn, userId).limit(200);
        return _roundMaps(rows);
      } catch (_) {
        return const [];
      }
    }
  }

  static List<Map<String, dynamic>> _mergeDistinctRowsByContent(List<List<Map<String, dynamic>>> groups) {
    final merged = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final group in groups) {
      for (final row in group) {
        final sig = '${row['players']}|${row['participants']}';
        if (seen.add(sig)) merged.add(row);
      }
    }
    return merged;
  }

  static Future<List<Map<String, dynamic>>> _fetchRowsUnfiltered(SupabaseClient client) async {
    try {
      final rows = await client.from('rounds').select(_roundSelectColumns).limit(200);
      return _roundMaps(rows);
    } catch (_) {
      try {
        final rows = await client.from('rounds').select('players,ended_at,completed_at,created_at').limit(200);
        return _roundMaps(rows);
      } catch (_) {
        return const [];
      }
    }
  }

  /// Decodes legacy `players` arrays that may be strings or small maps.
  static List<String> namesFromPlayersArrayOnly(List<dynamic> raw) {
    return [
      for (final p in raw)
        if (_nameFromPlayerCell(p) case final n?) n,
    ];
  }

  static String? _nameFromPlayerCell(dynamic p) {
    if (p == null) return null;
    if (p is String) {
      final t = p.trim();
      return t.isEmpty ? null : t;
    }
    if (p is Map) {
      final m = Map<String, dynamic>.from(p);
      final n = _readString(m, ['display_name', 'displayName', 'name']);
      if (n != null) return n;
    }
    final asString = p.toString().trim();
    return asString.isEmpty ? null : asString;
  }

  /// One round row: prefer `participants` (skips `is_you`), else `players` cells.
  static List<String> namesForRoundRow(Map<String, dynamic> row, {String? currentUserId}) {
    final participants = row['participants'] as List<dynamic>? ?? const [];
    if (participants.isNotEmpty) {
      final out = <String>[];
      for (final e in participants) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final isYou = _readBool(m, ['is_you', 'isYou']);
        final userId = _readString(m, ['user_id', 'userId']);
        if (isYou) continue;
        if (currentUserId != null && currentUserId.isNotEmpty && userId == currentUserId) continue;
        final name = _readString(m, ['display_name', 'displayName', 'name']);
        if (name != null) out.add(name);
      }
      if (out.isNotEmpty) return out;
    }
    final players = row['players'] as List<dynamic>? ?? const [];
    final fromPlayers = <String>[];
    for (final p in players) {
      final n = _nameFromPlayerCell(p);
      if (n != null) fromPlayers.add(n);
    }
    return fromPlayers;
  }

  /// Counts how often each co-player name appears across [rows] (excluding [myDisplayName], case-insensitive).
  static Map<String, int> mergeCountsFromRoundRows(
    List<Map<String, dynamic>> rows,
    String myDisplayName,
    String? myUserId,
  ) {
    final me = myDisplayName.trim().toLowerCase();
    final counts = <String, int>{};
    final canonicalByLower = <String, String>{};
    for (final row in rows) {
      try {
        for (final name in namesForRoundRow(row, currentUserId: myUserId)) {
          final t = name.trim();
          if (t.isEmpty) continue;
          final lowered = t.toLowerCase();
          if (lowered == me) continue;
          final canonical = canonicalByLower.putIfAbsent(lowered, () => t);
          counts[canonical] = (counts[canonical] ?? 0) + 1;
        }
      } catch (_) {
        // Skip malformed rows; keep counts from others.
      }
    }
    return counts;
  }

  static List<String> recentUniqueNamesFromRoundRows(
    List<Map<String, dynamic>> rows,
    String myDisplayName, {
    String? myUserId,
    int limit = 8,
  }) {
    if (limit <= 0) return const [];
    final me = myDisplayName.trim().toLowerCase();
    final out = <String>[];
    final seen = <String>{};
    final sorted = [...rows];
    _sortRowsNewestFirst(sorted);
    for (final row in sorted) {
      for (final name in namesForRoundRow(row, currentUserId: myUserId)) {
        final t = name.trim();
        if (t.isEmpty) continue;
        final lowered = t.toLowerCase();
        if (lowered == me) continue;
        if (seen.add(lowered)) out.add(t);
        if (out.length >= limit) return out;
      }
    }
    return out;
  }

  /// Fetches `players` + `participants` for the signed-in user's rounds and returns co-player name counts.
  /// Uses owner-column fallbacks (`created_by`, `user_id`, `owner_id`) for legacy schemas.
  static Future<Map<String, int>> fetchCoPlayerCountsForCurrentUser({String? knownDisplayName}) async {
    if (!SupabaseEnv.isConfigured) return {};
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return {};

    var displayName = knownDisplayName?.trim() ?? '';
    if (displayName.isEmpty) {
      try {
        dynamic rows;
        try {
          rows = await client.from('profiles').select('display_name').eq('id', user.id).limit(1);
        } catch (_) {
          rows = await client.from('profiles').select('display_name').eq('user_id', user.id).limit(1);
        }
        final list = rows as List<dynamic>;
        if (list.isNotEmpty) {
          displayName = ((list.first as Map)['display_name'] as String?)?.trim() ?? '';
        }
      } catch (_) {}
    }
    if (displayName.isEmpty) {
      final metaName = (user.userMetadata?['full_name'] as String?)?.trim();
      final emailName = user.email?.split('@').first.trim();
      displayName = (metaName != null && metaName.isNotEmpty)
          ? metaName
          : ((emailName != null && emailName.isNotEmpty) ? emailName : 'You');
    }

    final createdByRows = await _fetchRowsByOwnerColumn(client, user.id, 'created_by');
    final userIdRows = await _fetchRowsByOwnerColumn(client, user.id, 'user_id');
    final ownerIdRows = await _fetchRowsByOwnerColumn(client, user.id, 'owner_id');
    final unfilteredRows = await _fetchRowsUnfiltered(client);
    final rows = _mergeDistinctRowsByContent([createdByRows, userIdRows, ownerIdRows, unfilteredRows]);
    if (rows.isEmpty) return {};
    return mergeCountsFromRoundRows(rows, displayName, user.id);
  }

  static Future<List<String>> fetchRecentCoPlayerNamesForCurrentUser({
    String? knownDisplayName,
    int limit = 8,
  }) async {
    if (!SupabaseEnv.isConfigured) return const [];
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return const [];

    var displayName = knownDisplayName?.trim() ?? '';
    if (displayName.isEmpty) {
      try {
        dynamic rows;
        try {
          rows = await client.from('profiles').select('display_name').eq('id', user.id).limit(1);
        } catch (_) {
          rows = await client.from('profiles').select('display_name').eq('user_id', user.id).limit(1);
        }
        final list = rows as List<dynamic>;
        if (list.isNotEmpty) {
          displayName = ((list.first as Map)['display_name'] as String?)?.trim() ?? '';
        }
      } catch (_) {}
    }
    if (displayName.isEmpty) {
      final metaName = (user.userMetadata?['full_name'] as String?)?.trim();
      final emailName = user.email?.split('@').first.trim();
      displayName = (metaName != null && metaName.isNotEmpty)
          ? metaName
          : ((emailName != null && emailName.isNotEmpty) ? emailName : 'You');
    }

    final createdByRows = await _fetchRowsByOwnerColumn(client, user.id, 'created_by');
    final userIdRows = await _fetchRowsByOwnerColumn(client, user.id, 'user_id');
    final ownerIdRows = await _fetchRowsByOwnerColumn(client, user.id, 'owner_id');
    final unfilteredRows = await _fetchRowsUnfiltered(client);
    final rows = _mergeDistinctRowsByContent([createdByRows, userIdRows, ownerIdRows, unfilteredRows]);
    if (rows.isEmpty) return const [];
    return recentUniqueNamesFromRoundRows(
      rows,
      displayName,
      myUserId: user.id,
      limit: limit,
    );
  }
}

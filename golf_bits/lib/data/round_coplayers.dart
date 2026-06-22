import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';

/// Reads co-player display names from `rounds.players` / `rounds.participants` with
/// tolerant decoding so one bad row does not wipe the whole list.
abstract final class RoundCoplayers {
  static const _coplayerOverviewRpc = 'coplayer_overview';
  static const _recentCoplayersRpc = 'recent_coplayers';

  static List<Map<String, dynamic>> _roundMaps(dynamic rows) {
    return (rows as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static const _preferredSelectColumns = <String>[
    'players',
    'participants',
    'ended_at',
    'completed_at',
    'created_at',
  ];

  static String? _missingColumn(Object error) {
    if (error is! PostgrestException) return null;
    final m = error.message;
    final pgrst = RegExp(r"Could not find the '([^']+)' column").firstMatch(m);
    if (pgrst != null) return pgrst.group(1);
    final pg = RegExp(r'column\s+rounds\.([a-zA-Z0-9_]+)\s+does not exist').firstMatch(m);
    if (pg != null) return pg.group(1);
    return null;
  }

  static bool _isMissingFilterColumn(Object error, String filterColumn) {
    return _missingColumn(error) == filterColumn;
  }

  /// Result of probing one owner column (`created_by`, legacy `user_id`, etc.).
  static Future<({List<Map<String, dynamic>> rows, bool ownerColumnExists})> _fetchRowsByOwnerColumn(
    SupabaseClient client,
    String userId,
    String ownerColumn,
  ) async {
    var columns = [..._preferredSelectColumns];
    for (var i = 0; i < 12; i++) {
      if (columns.isEmpty) {
        return (rows: const [], ownerColumnExists: true);
      }
      try {
        final rows = await client.from('rounds').select(columns.join(',')).eq(ownerColumn, userId).limit(200);
        return (rows: _roundMaps(rows), ownerColumnExists: true);
      } catch (e) {
        if (_isMissingFilterColumn(e, ownerColumn)) {
          return (rows: const [], ownerColumnExists: false);
        }
        final col = _missingColumn(e);
        if (col != null && columns.remove(col)) {
          continue;
        }
        return (rows: const [], ownerColumnExists: true);
      }
    }
    return (rows: const [], ownerColumnExists: true);
  }

  /// Loads round rows for co-player parsing; stops after the first usable owner column.
  static Future<List<Map<String, dynamic>>> _fetchRowsForCurrentUser(
    SupabaseClient client,
    String userId,
  ) async {
    final primary = await _fetchRowsByOwnerColumn(client, userId, 'created_by');
    if (primary.ownerColumnExists) return primary.rows;

    for (final legacyColumn in ['user_id', 'owner_id']) {
      final legacy = await _fetchRowsByOwnerColumn(client, userId, legacyColumn);
      if (legacy.ownerColumnExists) return legacy.rows;
    }
    return const [];
  }

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

  static Future<List<Map<String, dynamic>>> _fetchCoplayerOverviewRpcRows({
    int limit = 1000,
  }) async {
    final rows = await Supabase.instance.client.rpc(
      _coplayerOverviewRpc,
      params: {'input_limit': limit},
    );
    final list = rows as List<dynamic>;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<List<Map<String, dynamic>>> _fetchRecentCoplayersRpcRows({
    int limit = 8,
  }) async {
    final rows = await Supabase.instance.client.rpc(
      _recentCoplayersRpc,
      params: {'input_limit': limit},
    );
    final list = rows as List<dynamic>;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

    try {
      final rows = await _fetchCoplayerOverviewRpcRows();
      final out = <String, int>{};
      for (final row in rows) {
        final name = (row['display_name'] as String?)?.trim() ?? '';
        final count = (row['rounds_played'] as num?)?.toInt() ?? 0;
        if (name.isEmpty || count <= 0) continue;
        out[name] = count;
      }
      if (out.isNotEmpty) return out;
    } catch (_) {
      // Fall back to legacy row parsing when RPC/migration is unavailable.
    }

    try {
      final rows = await _fetchRowsForCurrentUser(client, user.id);
      if (rows.isEmpty) return {};
      return mergeCountsFromRoundRows(rows, displayName, user.id);
    } catch (_) {
      return {};
    }
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

    try {
      final rows = await _fetchRecentCoplayersRpcRows(limit: limit);
      final out = <String>[];
      final seen = <String>{};
      for (final row in rows) {
        final name = (row['display_name'] as String?)?.trim() ?? '';
        if (name.isEmpty) continue;
        final lowered = name.toLowerCase();
        if (seen.add(lowered)) out.add(name);
      }
      if (out.isNotEmpty) return out.take(limit).toList();
    } catch (_) {
      // Fall back to legacy row parsing when RPC/migration is unavailable.
    }

    try {
      final rows = await _fetchRowsForCurrentUser(client, user.id);
      if (rows.isEmpty) return const [];
      return recentUniqueNamesFromRoundRows(
        rows,
        displayName,
        myUserId: user.id,
        limit: limit,
      );
    } catch (_) {
      return const [];
    }
  }
}

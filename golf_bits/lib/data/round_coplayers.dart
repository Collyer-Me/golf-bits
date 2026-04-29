import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';

/// Reads co-player display names from `rounds.players` / `rounds.participants` with
/// tolerant decoding so one bad row does not wipe the whole list.
abstract final class RoundCoplayers {
  static List<Map<String, dynamic>> _roundMaps(dynamic rows) {
    return (rows as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<List<Map<String, dynamic>>> _fetchRowsByOwnerColumn(
    SupabaseClient client,
    String userId,
    String ownerColumn,
  ) async {
    try {
      final rows = await client.from('rounds').select('players,participants').eq(ownerColumn, userId).limit(200);
      return _roundMaps(rows);
    } catch (_) {
      try {
        // Legacy schema may not have `participants` yet.
        final rows = await client.from('rounds').select('players').eq(ownerColumn, userId).limit(200);
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
      final rows = await client.from('rounds').select('players,participants').limit(200);
      return _roundMaps(rows);
    } catch (_) {
      try {
        final rows = await client.from('rounds').select('players').limit(200);
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
      for (final key in ['display_name', 'displayName', 'name']) {
        final v = m[key];
        if (v is String) {
          final t = v.trim();
          if (t.isNotEmpty) return t;
        }
      }
    }
    final asString = p.toString().trim();
    return asString.isEmpty ? null : asString;
  }

  /// One round row: prefer `participants` (skips `is_you`), else `players` cells.
  static List<String> namesForRoundRow(Map<String, dynamic> row) {
    final participants = row['participants'] as List<dynamic>? ?? const [];
    if (participants.isNotEmpty) {
      final out = <String>[];
      for (final e in participants) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        if (m['is_you'] as bool? ?? false) continue;
        final name = (m['display_name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) out.add(name);
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
  ) {
    final me = myDisplayName.trim().toLowerCase();
    final counts = <String, int>{};
    for (final row in rows) {
      try {
        for (final name in namesForRoundRow(row)) {
          final t = name.trim();
          if (t.isEmpty) continue;
          if (t.toLowerCase() == me) continue;
          counts[t] = (counts[t] ?? 0) + 1;
        }
      } catch (_) {
        // Skip malformed rows; keep counts from others.
      }
    }
    return counts;
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
    return mergeCountsFromRoundRows(rows, displayName);
  }
}

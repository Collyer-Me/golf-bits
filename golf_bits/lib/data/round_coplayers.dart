import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';

/// Reads co-player display names from `rounds.players` / `rounds.participants` with
/// tolerant decoding so one bad row does not wipe the whole list.
abstract final class RoundCoplayers {
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
  static Future<Map<String, int>> fetchCoPlayerCountsForCurrentUser() async {
    if (!SupabaseEnv.isConfigured) return {};
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return {};

    var displayName = '';
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
    if (displayName.isEmpty) {
      final metaName = (user.userMetadata?['full_name'] as String?)?.trim();
      final emailName = user.email?.split('@').first.trim();
      displayName = (metaName != null && metaName.isNotEmpty)
          ? metaName
          : ((emailName != null && emailName.isNotEmpty) ? emailName : 'You');
    }

    try {
      final rows = await client
          .from('rounds')
          .select('players,participants')
          .eq('created_by', user.id)
          .limit(200);
      final maps = (rows as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      return mergeCountsFromRoundRows(maps, displayName);
    } catch (_) {
      return {};
    }
  }
}

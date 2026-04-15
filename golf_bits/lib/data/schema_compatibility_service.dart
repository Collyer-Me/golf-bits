import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';

class SchemaCompatibilityResult {
  const SchemaCompatibilityResult({
    required this.ok,
    required this.errors,
    required this.warnings,
    required this.detectedColumns,
  });

  final bool ok;
  final List<String> errors;
  final List<String> warnings;
  final Map<String, Set<String>> detectedColumns;
}

abstract final class SchemaCompatibilityService {
  static SchemaCompatibilityResult? _cache;

  static Future<SchemaCompatibilityResult> checkRoundSyncSchema({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cache != null) return _cache!;
    if (!SupabaseEnv.isConfigured) {
      return const SchemaCompatibilityResult(
        ok: true,
        errors: [],
        warnings: ['Supabase is not configured.'],
        detectedColumns: {},
      );
    }

    final client = Supabase.instance.client;
    final tables = ['rounds', 'round_bit_events', 'profiles'];
    final detected = <String, Set<String>>{};
    final errors = <String>[];
    final warnings = <String>[];

    try {
      for (final table in tables) {
        final rows = await client
            .schema('information_schema')
            .from('columns')
            .select('column_name')
            .eq('table_schema', 'public')
            .eq('table_name', table);
        final cols = <String>{};
        for (final row in rows as List<dynamic>) {
          cols.add((row as Map)['column_name'] as String);
        }
        detected[table] = cols;
      }
    } catch (_) {
      warnings.add(
        'Could not read information_schema. Column-level diagnostics limited by DB permissions.',
      );
      // We can still return an actionable warning; app write paths still have fallbacks.
      final result = SchemaCompatibilityResult(
        ok: true,
        errors: errors,
        warnings: warnings,
        detectedColumns: detected,
      );
      _cache = result;
      return result;
    }

    final rounds = detected['rounds'] ?? <String>{};
    final events = detected['round_bit_events'] ?? <String>{};
    final profiles = detected['profiles'] ?? <String>{};

    bool hasAny(Set<String> cols, List<String> options) =>
        options.any(cols.contains);

    void requireAny(
      Set<String> cols,
      List<String> options,
      String table,
      String meaning,
    ) {
      if (!hasAny(cols, options)) {
        errors.add(
          '$table is missing $meaning. Expected one of: ${options.join(', ')}.',
        );
      }
    }

    void requireAll(Set<String> cols, List<String> needed, String table) {
      for (final c in needed) {
        if (!cols.contains(c)) {
          errors.add('$table is missing required column: $c.');
        }
      }
    }

    requireAny(rounds, ['created_by', 'user_id', 'owner_id'], 'rounds', 'owner column');
    requireAny(rounds, ['holes', 'hole_count'], 'rounds', 'hole-count column');
    requireAny(rounds, ['course_name'], 'rounds', 'course name');
    requireAny(rounds, ['status', 'completed', 'completed_at'], 'rounds', 'completion state');
    requireAny(rounds, ['score_by_player'], 'rounds', 'score map');
    requireAny(rounds, ['current_hole'], 'rounds', 'current hole');
    requireAny(rounds, ['participants', 'players'], 'rounds', 'participant list');

    requireAll(
      events,
      ['round_id', 'player_name', 'hole', 'event_label', 'delta'],
      'round_bit_events',
    );

    requireAny(profiles, ['id', 'user_id'], 'profiles', 'profile owner id');
    requireAny(profiles, ['display_name'], 'profiles', 'display name');
    if (!profiles.contains('email')) {
      warnings.add('profiles.email missing: email account matching is disabled.');
    }

    final result = SchemaCompatibilityResult(
      ok: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      detectedColumns: detected,
    );
    _cache = result;
    return result;
  }
}

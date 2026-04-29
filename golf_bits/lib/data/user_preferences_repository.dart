import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';
import '../models/event_preferences.dart';

abstract final class UserPreferencesRepository {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<EventPreference>> fetchDefaultEvents() async {
    if (!SupabaseEnv.isConfigured) return defaultEventPreferences();
    final user = _client.auth.currentUser;
    if (user == null) return defaultEventPreferences();

    try {
      final raw = await _client.rpc('get_my_default_events');
      return decodeEventPreferencesJson(raw);
    } catch (_) {
      // Backward compatibility for environments without the RPC.
      final rows = await _client
          .from('profiles')
          .select('default_events_config')
          .eq('id', user.id)
          .limit(1);
      final list = rows as List<dynamic>;
      if (list.isEmpty) return defaultEventPreferences();
      final row = Map<String, dynamic>.from(list.first as Map);
      return decodeEventPreferencesJson(row['default_events_config']);
    }
  }

  static Future<void> saveDefaultEvents(List<EventPreference> events) async {
    if (!SupabaseEnv.isConfigured) return;
    final user = _client.auth.currentUser;
    if (user == null) return;

    final payload = encodeEventPreferencesJson(events);
    try {
      await _client.rpc('save_my_default_events', params: {'input_config': payload});
    } catch (_) {
      // Backward compatibility for environments without the RPC.
      await _client.from('profiles').upsert({
        'id': user.id,
        'default_events_config': payload,
      });
    }
  }

  /// Whether the user opted in to marketing emails (`profiles.marketing_opt_in`).
  static Future<bool> fetchMarketingOptIn() async {
    if (!SupabaseEnv.isConfigured) return false;
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      final row = await _client
          .from('profiles')
          .select('marketing_opt_in')
          .eq('id', user.id)
          .maybeSingle();
      if (row == null) return false;
      final v = row['marketing_opt_in'];
      if (v is bool) return v;
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> saveMarketingOptIn(bool value) async {
    if (!SupabaseEnv.isConfigured) return;
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('profiles').upsert({
      'id': user.id,
      'marketing_opt_in': value,
    });
  }
}

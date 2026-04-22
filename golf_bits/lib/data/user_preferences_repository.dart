import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';
import '../models/event_preferences.dart';

abstract final class UserPreferencesRepository {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<EventPreference>> fetchDefaultEvents() async {
    if (!SupabaseEnv.isConfigured) return defaultEventPreferences();
    final user = _client.auth.currentUser;
    if (user == null) return defaultEventPreferences();

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

  static Future<void> saveDefaultEvents(List<EventPreference> events) async {
    if (!SupabaseEnv.isConfigured) return;
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('profiles').upsert({
      'id': user.id,
      'default_events_config': encodeEventPreferencesJson(events),
    });
  }
}

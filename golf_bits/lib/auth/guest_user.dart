import 'package:supabase_flutter/supabase_flutter.dart';

/// True for Supabase anonymous ("play as guest") sessions.
///
/// The API sets [User.isAnonymous] from `is_anonymous` in the user JSON. Relying
/// only on `app_metadata.provider == 'anonymous'` misses real guest sessions.
bool isSupabaseGuestUser(User? user) {
  if (user == null) return false;
  if (user.isAnonymous) return true;

  final meta = user.appMetadata;
  if (meta['provider'] == 'anonymous') return true;

  final providers = meta['providers'];
  if (providers is List && providers.any((dynamic p) => p == 'anonymous')) {
    return true;
  }

  for (final id in user.identities ?? const <Object?>[]) {
    final p = (id as dynamic).provider;
    if (p == 'anonymous') return true;
  }

  return false;
}

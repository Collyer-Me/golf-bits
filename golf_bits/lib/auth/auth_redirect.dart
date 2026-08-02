import 'package:flutter/foundation.dart';

/// Custom URL scheme for native email auth redirects (recovery, confirm, etc.).
/// Must match Android intent-filters, iOS CFBundleURLTypes, and a Supabase
/// Authentication → URL configuration → Redirect URLs entry.
const String kNativeAuthRedirectUrl = 'golfbits://auth-callback';

/// `redirectTo` / `emailRedirectTo` for Supabase email links.
///
/// - **Web:** current origin (Pages or localhost), fragment stripped.
/// - **iOS/Android:** [kNativeAuthRedirectUrl].
///
/// Must match an allow-listed entry under Authentication → URL configuration →
/// Redirect URLs in the Supabase dashboard.
String? supabaseAuthRedirectUrl() {
  if (kIsWeb) {
    final u = Uri.base;
    return u.replace(fragment: '').toString();
  }
  return kNativeAuthRedirectUrl;
}

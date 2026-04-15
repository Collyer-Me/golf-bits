import 'package:flutter/foundation.dart';

/// Supabase email links put `type` and tokens in the URL query or fragment. With
/// [FlutterAuthClientOptions.detectSessionInUri], [Supabase.initialize] may strip
/// that data before widgets run, so we snapshot [Uri.base] **before** initialize.
abstract final class PendingAuthLink {
  static bool _passwordRecovery = false;
  static bool _emailSignupConfirmed = false;

  /// Call from [main] immediately before [Supabase.initialize] (web only).
  static void captureFromUriBeforeSupabaseInit(Uri uri) {
    if (!kIsWeb) return;
    final params = _mergedQueryAndFragment(uri);
    final type = params['type']?.toLowerCase() ?? '';
    _passwordRecovery = type == 'recovery';
    // New-user email confirmation (verify signup) uses this type in the redirect URL.
    _emailSignupConfirmed = type == 'signup';
  }

  static Map<String, String> _mergedQueryAndFragment(Uri uri) {
    final out = Map<String, String>.from(uri.queryParameters);
    if (uri.fragment.isNotEmpty) {
      out.addAll(Uri.splitQueryString(uri.fragment));
    }
    return out;
  }

  /// Whether the user arrived from a password recovery email link (one-shot).
  static bool takePasswordRecovery() {
    final v = _passwordRecovery;
    _passwordRecovery = false;
    return v;
  }

  /// Whether the user arrived from a signup / confirm-email link (one-shot).
  static bool takeEmailSignupConfirmed() {
    final v = _emailSignupConfirmed;
    _emailSignupConfirmed = false;
    return v;
  }
}

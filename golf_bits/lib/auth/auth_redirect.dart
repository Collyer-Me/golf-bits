import 'package:flutter/foundation.dart';

/// `redirectTo` for Supabase email links (password recovery, etc.). Must match an entry under
/// Authentication → URL configuration → Redirect URLs in the Supabase dashboard.
String? supabaseAuthRedirectUrl() {
  if (!kIsWeb) return null;
  final u = Uri.base;
  return u.replace(fragment: '').toString();
}

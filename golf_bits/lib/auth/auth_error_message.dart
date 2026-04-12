import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps [AuthException] (and fallbacks) to short UI copy.
String authErrorMessage(Object error) {
  if (error is AuthException) {
    final m = error.message.toLowerCase();
    if (m.contains('invalid login')) return 'Email or password is incorrect.';
    if (m.contains('email not confirmed')) return 'Confirm your email before signing in.';
    if (m.contains('user already registered')) return 'An account with this email already exists.';
    if (m.contains('password')) return error.message;
    return error.message;
  }
  return 'Something went wrong. Try again.';
}

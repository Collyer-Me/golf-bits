import 'package:flutter_test/flutter_test.dart';
import 'package:golf_bits/auth/auth_error_message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('authErrorMessage', () {
    test('maps common AuthException messages to friendly copy', () {
      expect(
        authErrorMessage(const AuthException('Invalid login credentials')),
        'Email or password is incorrect.',
      );
      expect(
        authErrorMessage(const AuthException('Email not confirmed')),
        'Confirm your email before signing in.',
      );
      expect(
        authErrorMessage(const AuthException('User already registered')),
        'An account with this email already exists.',
      );
    });

    test('passes through password-related AuthException messages', () {
      const msg = 'Password should be at least 6 characters';
      expect(authErrorMessage(const AuthException(msg)), msg);
    });

    test('falls back for non-auth errors', () {
      expect(authErrorMessage(Exception('network')), 'Something went wrong. Try again.');
    });
  });
}

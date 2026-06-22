import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';
import 'guest_user.dart';

enum GuestCloudSignInOutcome { alreadySignedIn, signedIn, failed, notConfigured }

class GuestCloudSignInResult {
  const GuestCloudSignInResult(this.outcome, {this.errorMessage});

  final GuestCloudSignInOutcome outcome;
  final String? errorMessage;

  bool get ok =>
      outcome == GuestCloudSignInOutcome.alreadySignedIn ||
      outcome == GuestCloudSignInOutcome.signedIn;
}

/// Anonymous Supabase sessions used for guest cloud round sync + history.
abstract final class GuestCloudAuth {
  static const anonymousDisabledMessage =
      'Guest cloud sync is unavailable. Enable Anonymous sign-ins in Supabase '
      '(Authentication → Providers), or create a free account to save rounds.';

  static String messageForError(Object error) {
    if (error is AuthException) {
      final m = error.message.toLowerCase();
      if (m.contains('anonymous') && (m.contains('disabled') || m.contains('not enabled'))) {
        return anonymousDisabledMessage;
      }
      if (error.statusCode == '422') {
        return anonymousDisabledMessage;
      }
      return error.message;
    }
    return 'Guest sign-in failed. Try again or create an account.';
  }

  /// Ensures an anonymous Supabase session for cloud round sync.
  static Future<GuestCloudSignInResult> ensureAnonymousSession({
    bool signOutNonGuestFirst = true,
  }) async {
    if (!SupabaseEnv.isConfigured) {
      return const GuestCloudSignInResult(GuestCloudSignInOutcome.notConfigured);
    }

    final auth = Supabase.instance.client.auth;
    final current = auth.currentUser;
    if (current != null) {
      if (isSupabaseGuestUser(current)) {
        return const GuestCloudSignInResult(GuestCloudSignInOutcome.alreadySignedIn);
      }
      if (!signOutNonGuestFirst) {
        return const GuestCloudSignInResult(
          GuestCloudSignInOutcome.failed,
          errorMessage: 'Sign out to continue as a guest.',
        );
      }
      await auth.signOut();
    }

    try {
      await auth.signInAnonymously();
      if (auth.currentUser == null) {
        return const GuestCloudSignInResult(
          GuestCloudSignInOutcome.failed,
          errorMessage: 'Guest sign-in did not create a session.',
        );
      }
      return const GuestCloudSignInResult(GuestCloudSignInOutcome.signedIn);
    } on AuthException catch (e) {
      return GuestCloudSignInResult(
        GuestCloudSignInOutcome.failed,
        errorMessage: messageForError(e),
      );
    } catch (e) {
      return GuestCloudSignInResult(
        GuestCloudSignInOutcome.failed,
        errorMessage: messageForError(e),
      );
    }
  }
}

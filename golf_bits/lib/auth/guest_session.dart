import 'package:flutter/material.dart';

import 'guest_cloud_auth.dart';
import 'profile_bootstrap.dart';
import '../config/supabase_env.dart';
import '../navigation/auth_navigation.dart';
import '../screens/guest_play_sheet.dart';
import '../screens/sign_up_screen.dart';
import '../theme/app_theme.dart';

/// Bottom sheet: continue as guest, then [openAppHome] (same as Log in flow).
void showGuestPlayBottomSheet(
  BuildContext context, {
  /// When true, "Create account" uses [pushReplacement] (e.g. from log in).
  bool replaceWithSignUpOnCreateAccount = false,
}) {
  GuestPlaySheet.show(
    context,
    onContinueGuest: () async {
      Navigator.of(context).pop();
      if (SupabaseEnv.isConfigured) {
        final result = await GuestCloudAuth.ensureAnonymousSession();
        if (result.ok) {
          await ProfileBootstrap.ensureCurrentUserProfile();
        } else if (result.errorMessage != null && context.mounted) {
          await _showGuestSyncFailedDialog(context, result.errorMessage!);
        }
      }
      if (context.mounted) openAppHome(context);
    },
    onCreateAccountInstead: () {
      Navigator.of(context).pop();
      final route = MaterialPageRoute<void>(builder: (_) => const SignUpScreen());
      if (replaceWithSignUpOnCreateAccount) {
        Navigator.of(context).pushReplacement(route);
      } else {
        Navigator.of(context).push(route);
      }
    },
  );
}

Future<void> _showGuestSyncFailedDialog(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final text = Theme.of(ctx).textTheme;
      final scheme = Theme.of(ctx).colorScheme;
      return AlertDialog(
        title: const Text('Guest sync unavailable'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: text.bodyMedium),
            SizedBox(height: AppTheme.space4),
            Text(
              'You can still play on this device, but finished rounds will not appear in History until guest sync works or you create an account.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Play anyway'),
          ),
        ],
      );
    },
  );
}

/// Retries anonymous sign-in from Profile or History when the user has no session.
Future<bool> retryGuestCloudSignIn(BuildContext context) async {
  if (!SupabaseEnv.isConfigured) return false;
  final result = await GuestCloudAuth.ensureAnonymousSession();
  if (!context.mounted) return result.ok;
  if (result.ok) {
    await ProfileBootstrap.ensureCurrentUserProfile();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Guest profile ready — new rounds will save to History.')),
    );
    return true;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(result.errorMessage ?? 'Guest sign-in failed.')),
  );
  return false;
}

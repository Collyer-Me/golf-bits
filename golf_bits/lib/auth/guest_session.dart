import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';
import '../navigation/auth_navigation.dart';
import '../screens/guest_play_sheet.dart';
import '../screens/sign_up_screen.dart';

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
        try {
          await Supabase.instance.client.auth.signInAnonymously();
        } on AuthException {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Anonymous sign-in is disabled in the project. You can still play on this device.',
                ),
              ),
            );
          }
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

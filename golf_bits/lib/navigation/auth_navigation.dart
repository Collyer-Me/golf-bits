import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_root.dart';
import '../config/supabase_env.dart';
import '../screens/home_screen.dart';

/// Opens the main shell (post-login / guest / location done). Pops auth routes via [AuthRoot].
void openAppHome(BuildContext context) {
  final auth = AuthRoot.maybeOf(context);
  if (auth != null) {
    auth.enterApp();
    return;
  }
  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
    (_) => false,
  );
}

/// Clears the session (when Supabase is configured) and returns to the welcome / auth entry.
Future<void> signOutAndReturnToWelcome(BuildContext context) async {
  try {
    if (SupabaseEnv.isConfigured) {
      await Supabase.instance.client.auth.signOut();
    }
  } catch (_) {
    // Still leave the in-app shell so the user can switch account.
  }
  if (context.mounted) {
    AuthRoot.maybeOf(context)?.exitApp();
  }
}

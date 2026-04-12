import 'package:flutter/material.dart';

import '../auth/auth_root.dart';
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

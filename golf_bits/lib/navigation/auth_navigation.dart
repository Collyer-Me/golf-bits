import 'package:flutter/material.dart';

import '../screens/home_screen.dart';

/// Clears the auth stack and opens the main shell (post-login / guest / location done).
void openAppHome(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
    (_) => false,
  );
}

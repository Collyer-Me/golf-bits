import 'package:flutter/material.dart';

/// Brand palette (style guide). Prefer [ColorScheme] from context in UI.
abstract final class AppColors {
  static const Color primary = Color(0xFF2E7D32);
  static const Color secondary = Color(0xFFFFC107);
  static const Color tertiary = Color(0xFFD32F2F);
  static const Color surface = Color(0xFF121412);

  /// Brighter accent used in product mocks (hole UI, highlights). Not a ColorScheme role — use sparingly.
  static const Color accentLime = Color(0xFFA5FF9B);

  static const Color onSecondaryDark = Color(0xFF0D0D0D);
}

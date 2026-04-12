import 'package:flutter/material.dart';

/// Brand palette (style guide). Prefer [ColorScheme] from context in UI.
abstract final class AppColors {
  static const Color primary = Color(0xFF2E7D32);
  static const Color secondary = Color(0xFFFFC107);
  static const Color tertiary = Color(0xFFD32F2F);
  static const Color surface = Color(0xFF121412);

  /// Dark theme surface ramp (Material 3 roles). Used only in [AppTheme.dark].
  static const Color surfaceContainerLowest = Color(0xFF0E100E);
  static const Color surfaceContainerLow = Color(0xFF1A1C1A);
  static const Color surfaceContainer = Color(0xFF1E201E);
  static const Color surfaceContainerHigh = Color(0xFF292A28);
  static const Color surfaceContainerHighest = Color(0xFF333533);
  static const Color primaryContainer = Color(0xFF1B3D1F);
  static const Color secondaryContainer = Color(0xFF292A28);
  static const Color onSecondaryContainer = Color(0xFFE8EAE8);

  /// Brighter accent used in product mocks (hole UI, highlights). Not a ColorScheme role — use sparingly.
  static const Color accentLime = Color(0xFFA5FF9B);

  static const Color onSecondaryDark = Color(0xFF0D0D0D);
}

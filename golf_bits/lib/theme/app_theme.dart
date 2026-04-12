import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Material 3 theme: seed + explicit brand secondaries / surfaces (style guide).
abstract final class AppTheme {
  static const double stadiumRadius = 999;
  static const double cardRadius = 20;
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 16);

  static ThemeData dark() {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondaryDark,
      tertiary: AppColors.tertiary,
      surface: AppColors.surface,
    );

    final scheme = base.copyWith(
      surfaceContainerLowest: const Color(0xFF0E100E),
      surfaceContainerLow: const Color(0xFF1A1C1A),
      surfaceContainer: const Color(0xFF1E201E),
      surfaceContainerHigh: const Color(0xFF292A28),
      surfaceContainerHighest: const Color(0xFF333533),
      primaryContainer: const Color(0xFF1B3D1F),
      onPrimaryContainer: AppColors.accentLime,
      secondaryContainer: const Color(0xFF292A28),
      onSecondaryContainer: const Color(0xFFE8EAE8),
    );

    final rawText = ThemeData(brightness: Brightness.dark, useMaterial3: true).textTheme;
    final textTheme = GoogleFonts.lexendTextTheme(rawText).apply(
      displayColor: scheme.onSurface,
      bodyColor: scheme.onSurfaceVariant,
    );

    final stadiumShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(stadiumRadius),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surfaceContainerHigh,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: stadiumShape,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: scheme.onSurfaceVariant,
          side: BorderSide(color: scheme.outlineVariant),
          shape: stadiumShape,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: stadiumShape,
        side: BorderSide(color: scheme.outline),
        labelStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primary,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
            size: 24,
          );
        }),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: const WidgetStatePropertyAll(Color(0xFF292A28)),
        elevation: const WidgetStatePropertyAll(0),
        shape: const WidgetStatePropertyAll(stadiumShape),
        side: WidgetStateProperty.resolveWith(
          (_) => BorderSide(color: scheme.outlineVariant),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(stadiumRadius)),
      ),
    );
  }
}

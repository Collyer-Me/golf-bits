import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Material 3 theme + layout/letterspacing tokens (style guide). Prefer these over literals in UI.
abstract final class AppTheme {
  static const double stadiumRadius = 999;
  static const double cardRadius = 20;

  /// Horizontal / vertical padding for full-width screen bodies.
  static const double pageHorizontal = 20;
  static const double pageVertical = 16;
  static const EdgeInsets screenPadding =
      EdgeInsets.symmetric(horizontal: pageHorizontal, vertical: pageVertical);

  /// Text fields, small contained surfaces.
  static const double fieldRadius = 16;
  static const double radiusSm = 4;
  static const double radiusMd = 12;

  /// 4dp-ish spacing scale (prefer over raw `SizedBox` / `EdgeInsets` numbers).
  static const double space1 = 4;
  static const double spaceHalf = 6;
  static const double space2 = 8;
  static const double space25 = 10;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space7 = 28;
  static const double space8 = 32;

  /// Theme button vertical padding (between space3 and space4 on the grid).
  static const double buttonPadV = 14;

  /// Default [OutlinedSurfaceCard] / dense card interiors.
  static const double cardInnerPadding = 20;

  /// Letter-spacing for wordmark / step labels (brand).
  static const double letterWordmark = 1.2;
  static const double letterStepCaps = 1.2;
  static const double letterTagline = 1.4;
  static const double letterBadge = 0.6;
  static const double letterSheetLabel = 1.1;

  /// Shared opacity for borders / overlays (still tokenised).
  static const double opacityBorderEmphasis = 0.55;
  static const double opacitySecondaryFill = 0.18;
  static const double opacitySecondaryBorder = 0.6;
  static const double opacityPrimaryBorder = 0.35;

  /// Card / list tile borders when using primary emphasis.
  static const double emphasisBorderWidth = 1.5;
  static const double outlineBorderWidth = 1;
  static const double selectionRingWidth = 3;

  /// Focus / selection glow (tee picker, etc.).
  static const double elevationBlurSm = 12;

  /// Body copy line height (shared relaxed paragraphs).
  static const double bodyLineHeightRelaxed = 1.45;
  static const double bodyLineHeightTight = 1.35;

  /// Small trailing / chip icons.
  static const double iconDense = 18;
  static const double iconArrow = 20;
  static const double chipOutlineWidth = 1.2;

  /// Marketing / hero illustration sizes.
  static const double iconIllustration = 40;
  static const double iconLarge = 48;
  static const double iconHero = 56;
  static const double iconInline = 22;
  static const double teeGlyphSize = 18;
  static const double locationGlowBlur = 48;
  static const double locationGlowSpread = 4;
  static const double opacityHeroGlow = 0.45;
  static const double opacityMutedPrimary = 0.7;
  static const double pageIndicator = 8;
  static const double pageIndicatorSelected = 10;

  /// Filled button label tracking (matches [FilledButtonTheme]).
  static const double letterButton = 0.8;

  /// Readable label on circular tee / brand fills (uses [ColorScheme]).
  static Color textOnFilledCircle(Color fill, ColorScheme scheme) {
    if (fill == scheme.tertiary) return scheme.onTertiary;
    final bright = ThemeData.estimateBrightnessForColor(fill);
    return bright == Brightness.dark ? scheme.onSurface : scheme.surfaceContainerLowest;
  }

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
      surfaceContainerLowest: AppColors.surfaceContainerLowest,
      surfaceContainerLow: AppColors.surfaceContainerLow,
      surfaceContainer: AppColors.surfaceContainer,
      surfaceContainerHigh: AppColors.surfaceContainerHigh,
      surfaceContainerHighest: AppColors.surfaceContainerHighest,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.accentLime,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
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
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: space4, vertical: space3),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(fieldRadius)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: scheme.error),
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        labelStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: space6, vertical: buttonPadV),
          shape: stadiumShape,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: letterButton,
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
        padding: const EdgeInsets.symmetric(horizontal: space3, vertical: space2),
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
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
        elevation: const WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(stadiumShape),
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

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Material 3 theme + layout/letterspacing tokens (style guide). Prefer these
/// over literals in UI.
///
/// Ships a mirrored **dark** ("on course") and **light** ("in the clubhouse")
/// pair built from one [_baseTheme] so a screen needs no per-theme branching —
/// drive everything from `colorScheme` / `textTheme` / these tokens.
abstract final class AppTheme {
  static const double stadiumRadius = 999;

  /// Cards, [OutlinedSurfaceCard], list tiles.
  static const double cardRadius = 18;

  /// Large feature / hero cards (winner spotlight, etc.).
  static const double featureCardRadius = 22;

  /// Horizontal / vertical padding for full-width screen bodies.
  static const double pageHorizontal = 20;
  static const double pageVertical = 16;
  static const EdgeInsets screenPadding =
      EdgeInsets.symmetric(horizontal: pageHorizontal, vertical: pageVertical);

  /// Text fields, small contained surfaces.
  static const double fieldRadius = 16;
  static const double radiusSm = 8;
  static const double radiusMd = 12;

  /// Rounded-square avatars (initials).
  static const double avatarRadius = 12;

  /// In-round player avatar (hole scoring cards).
  static const double avatarSizeMd = 38;

  /// Circular award (+) control on player cards.
  static const double awardButtonSize = 36;

  /// Hole-progress pip bar — upcoming segments.
  static const double opacityProgressPipUpcoming = 0.12;

  /// Leader card emphasis ring.
  static const double opacityLeaderRing = 0.45;

  /// Current-hole progress pip width multiplier vs completed pips.
  static const double progressPipCurrentFlex = 2.5;

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

  /// All-caps DM Mono "ledger" labels (e.g. `HOLE 7 · PAR 4`, `+5 BITS`).
  static const double letterMonoCaps = 1.8;

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

  /// OAuth / large provider marks (e.g. Google "G").
  static const double iconOAuthGlyph = 28;

  /// [NavigationBar] icon size (matches M3 default, tokenised for consistency).
  static const double iconNavigation = 24;
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
  static const double opacityAlertFill = 0.35;
  /// Inactive carousel dot (width and height).
  static const double pageIndicator = 8;

  /// Active carousel pill width (height is [pageIndicatorHeight]).
  static const double pageIndicatorActiveWidth = 24;

  static const double pageIndicatorHeight = 8;

  /// Welcome / onboarding layout.
  static const double welcomeHorizontal = 26;
  static const double welcomePreviewRadius = 20;
  static const double welcomePrimaryButtonHeight = 56;
  static const double welcomeSecondaryButtonHeight = 54;
  static const double opacityWelcomeParchmentBorder = 0.26;
  static const double opacityWelcomeParchmentDot = 0.22;
  static const double opacityWelcomeInkHairline = 0.08;
  static const double opacityFairwayChipFill = 0.15;
  static const double opacityFairwayChipBorder = 0.4;
  static const double opacityJunkChipFill = 0.13;
  static const double opacityJunkChipBorder = 0.4;
  static const double opacityInkDashedBorder = 0.28;
  static const double welcomePrimaryGlowBlur = 28;
  static const double welcomePrimaryGlowSpread = -12;
  static const double opacityWelcomePrimaryGlow = 0.7;
  static const double welcomePreviewShadowBlur = 46;
  static const double welcomePreviewShadowSpread = -18;
  static const double opacityWelcomePreviewShadow = 0.7;

  /// Preview card idle float (matches design reference `bdjFloat`).
  static const double welcomePreviewTilt = -2;
  static const double welcomePreviewTiltAlt = -5;
  static const double welcomePreviewFloat = 8;
  static const double welcomePreviewFloatAlt = 6;
  static const Duration welcomePreviewFloatDuration = Duration(seconds: 7);
  static const Duration welcomeCarouselAutoAdvance = Duration(milliseconds: 6200);

  /// Vertical breathing room around the guest CTA.
  static const double welcomeGuestSpacingAbove = space4;
  static const double welcomeGuestSpacingBelow = space3;

  /// Filled button label tracking (matches [FilledButtonTheme]).
  static const double letterButton = 0.8;

  /// Radial background for the welcome screen (always dark).
  static BoxDecoration welcomeBackgroundDecoration() => const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.85),
          radius: 1.15,
          colors: [
            AppColors.welcomeGradientTop,
            AppColors.darkSurface,
            AppColors.darkBg,
          ],
          stops: [0.0, 0.42, 1.0],
        ),
      );

  /// Fairway glow behind the welcome primary CTA.
  static List<BoxShadow> welcomePrimaryButtonShadow() => [
        BoxShadow(
          color: AppColors.fairway.withValues(alpha: opacityWelcomePrimaryGlow),
          blurRadius: welcomePrimaryGlowBlur,
          spreadRadius: welcomePrimaryGlowSpread,
          offset: const Offset(0, 14),
        ),
      ];

  /// Elevated shadow for onboarding preview cards.
  static List<BoxShadow> welcomePreviewCardShadow() => [
        BoxShadow(
          color: AppColors.ink.withValues(alpha: opacityWelcomePreviewShadow),
          blurRadius: welcomePreviewShadowBlur,
          spreadRadius: welcomePreviewShadowSpread,
          offset: const Offset(0, 26),
        ),
      ];

  // ── Semantic colour accessors (flip per brightness) ─────────────────────

  /// Points won — birdies, sandies. [AppColors.fairway] on dark, deeper on light.
  static Color bits(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.fairway
          : AppColors.bitsPositiveLight;

  /// Points lost — three-putts, OB.
  static Color junk(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.junkPenalty
          : AppColors.junkPenaltyText;

  /// Leader / payouts / highlights.
  static Color sand(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.sandWinner
          : AppColors.sandWinnerText;

  /// All-caps "ledger" label in DM Mono (the global `labelSmall` family).
  static TextStyle monoLabel(BuildContext context, {Color? color}) {
    final base = Theme.of(context).textTheme.labelSmall ?? const TextStyle();
    return color == null ? base : base.copyWith(color: color);
  }

  /// Big Bricolage 800 score numeral (e.g. `+8`, `−2`), coloured by the caller.
  static TextStyle score(BuildContext context, {double size = 24, Color? color}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.0,
        color: color ?? Theme.of(context).colorScheme.onSurface,
      );

  /// Readable label on circular tee / brand fills (uses [ColorScheme]).
  static Color textOnFilledCircle(Color fill, ColorScheme scheme) {
    if (fill == scheme.tertiary) return scheme.onTertiary;
    final bright = ThemeData.estimateBrightnessForColor(fill);
    return bright == Brightness.dark ? scheme.onSurface : scheme.surfaceContainerLowest;
  }

  // ── Themes ──────────────────────────────────────────────────────────────

  static ThemeData dark() => _baseTheme(_darkScheme());

  static ThemeData light() => _baseTheme(_lightScheme());

  static ColorScheme _darkScheme() {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.ink,
      brightness: Brightness.dark,
    );
    return base.copyWith(
      primary: AppColors.fairway,
      onPrimary: AppColors.ink,
      primaryContainer: AppColors.pine,
      onPrimaryContainer: AppColors.fairway,
      secondary: AppColors.sandWinner,
      onSecondary: AppColors.ink,
      secondaryContainer: AppColors.darkRaised,
      onSecondaryContainer: AppColors.parchment,
      tertiary: AppColors.junkPenalty,
      onTertiary: AppColors.parchment,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkText,
      onSurfaceVariant: AppColors.darkMuted,
      surfaceContainerLowest: AppColors.darkBg,
      surfaceContainerLow: AppColors.darkSurface,
      surfaceContainer: AppColors.darkRaised,
      surfaceContainerHigh: AppColors.darkLine,
      surfaceContainerHighest: AppColors.darkHi,
      outline: AppColors.darkHi,
      outlineVariant: AppColors.darkLine,
      inverseSurface: AppColors.parchment,
      onInverseSurface: AppColors.ink,
      error: AppColors.junkPenalty,
      onError: AppColors.parchment,
      errorContainer: AppColors.darkErrorContainer,
      onErrorContainer: AppColors.darkOnErrorContainer,
    );
  }

  static ColorScheme _lightScheme() {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.ink,
      brightness: Brightness.light,
    );
    return base.copyWith(
      primary: AppColors.ink,
      onPrimary: AppColors.parchment,
      primaryContainer: AppColors.lightPrimaryContainer,
      onPrimaryContainer: AppColors.lightOnPrimaryContainer,
      secondary: AppColors.sandWinner,
      onSecondary: AppColors.ink,
      secondaryContainer: AppColors.lightSecondaryContainer,
      onSecondaryContainer: AppColors.sandWinnerText,
      tertiary: AppColors.junkPenalty,
      onTertiary: AppColors.parchment,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightText,
      onSurfaceVariant: AppColors.lightMuted,
      surfaceContainerLowest: AppColors.lightBg,
      surfaceContainerLow: AppColors.lightContainerLow,
      surfaceContainer: AppColors.lightSurface,
      surfaceContainerHigh: AppColors.lightRaised,
      surfaceContainerHighest: AppColors.lightCard,
      outline: AppColors.lightOutline,
      outlineVariant: AppColors.lightLine,
      inverseSurface: AppColors.ink,
      onInverseSurface: AppColors.parchment,
      error: AppColors.junkPenaltyText,
      onError: AppColors.parchment,
      errorContainer: AppColors.lightErrorContainer,
      onErrorContainer: AppColors.lightOnErrorContainer,
    );
  }

  /// Composes the tri-family text theme: Bricolage Grotesque for display /
  /// headline, Hanken Grotesk for everything interface, and DM Mono for the
  /// all-caps "ledger" `labelSmall`.
  static TextTheme _textTheme(ColorScheme scheme) {
    final base = ThemeData(brightness: scheme.brightness, useMaterial3: true).textTheme;
    final hanken = GoogleFonts.hankenGroteskTextTheme(base);

    TextStyle bric(double size, FontWeight weight, double height, double spacing) =>
        GoogleFonts.bricolageGrotesque(
          fontSize: size,
          fontWeight: weight,
          height: height,
          letterSpacing: spacing,
        );

    final merged = hanken.copyWith(
      displayLarge: bric(52, FontWeight.w800, 0.94, -1.0),
      displayMedium: bric(44, FontWeight.w800, 0.96, -0.9),
      displaySmall: bric(36, FontWeight.w800, 1.0, -0.7),
      headlineLarge: bric(40, FontWeight.w700, 1.0, -0.8),
      headlineMedium: bric(32, FontWeight.w700, 1.04, -0.5),
      headlineSmall: bric(26, FontWeight.w700, 1.08, -0.3),
      titleLarge: hanken.titleLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.w600),
      titleMedium: hanken.titleMedium?.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
      bodyLarge: hanken.bodyLarge?.copyWith(height: bodyLineHeightRelaxed),
      labelLarge: hanken.labelLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: letterButton,
      ),
      labelSmall: GoogleFonts.dmMono(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: letterMonoCaps,
        height: 1.2,
      ),
    );

    final colored = merged.apply(
      displayColor: scheme.onSurface,
      bodyColor: scheme.onSurfaceVariant,
    );
    // Flutter's TextTheme.apply() routes headlineSmall + the title roles to
    // bodyColor. Force all display/headline/title roles onto the bright
    // onSurface so prominent headers and names don't render in the muted body
    // colour (a screen can still opt a specific line down to onSurfaceVariant).
    return colored.copyWith(
      headlineSmall: colored.headlineSmall?.copyWith(color: scheme.onSurface),
      titleLarge: colored.titleLarge?.copyWith(color: scheme.onSurface),
      titleMedium: colored.titleMedium?.copyWith(color: scheme.onSurface),
      titleSmall: colored.titleSmall?.copyWith(color: scheme.onSurface),
    );
  }

  static ThemeData _baseTheme(ColorScheme scheme) {
    final textTheme = _textTheme(scheme);
    final isDark = scheme.brightness == Brightness.dark;
    final navUnselected =
        isDark ? AppColors.darkNavUnselected : AppColors.lightNavUnselected;
    final link = isDark ? AppColors.fairway : AppColors.bitsPositiveLight;
    final stadiumShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(stadiumRadius),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surfaceContainerLowest,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: outlineBorderWidth,
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
          minimumSize: const Size(48, 52),
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
          minimumSize: const Size(48, 52),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          shape: stadiumShape,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: letterButton,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: link,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: stadiumShape,
        side: BorderSide(color: scheme.outline, width: chipOutlineWidth),
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.primary,
        labelStyle: textTheme.labelLarge,
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(color: scheme.onPrimary),
        padding: const EdgeInsets.symmetric(horizontal: space3, vertical: space2),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected)
            ? scheme.onPrimary
            : scheme.onSurfaceVariant),
        trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected)
            ? scheme.primary
            : scheme.surfaceContainerHigh),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected)
            ? scheme.primary
            : scheme.outline),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: scheme.surfaceContainer,
          foregroundColor: scheme.onSurfaceVariant,
          selectedBackgroundColor: scheme.primary,
          selectedForegroundColor: scheme.onPrimary,
          side: BorderSide(color: scheme.outlineVariant),
          shape: stadiumShape,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: opacitySecondaryFill),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? scheme.primary : navUnselected,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : navUnselected,
            size: iconNavigation,
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
        hintStyle: WidgetStatePropertyAll(
          textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(stadiumRadius)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        modalBackgroundColor: scheme.surfaceContainer,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(featureCardRadius)),
        ),
      ),
    );
  }
}

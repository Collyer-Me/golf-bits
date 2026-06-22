import 'package:flutter/material.dart';

/// Bits Dots Junk brand palette. **All hex literals live here** (per AGENTS.md);
/// screens read [ColorScheme] / [TextTheme] from context, never these directly.
///
/// The brand is built on tally marks on a scorecard: deep [ink] green and warm
/// [parchment] cream pulled straight from the logo, with [fairway] green as the
/// live accent. The palette themes both ways — dark = "on course", light = "in
/// the clubhouse" — so each ramp below has a dark and a light variant.
abstract final class AppColors {
  // ── Brand anchors ──────────────────────────────────────────────────────
  /// Primary brand green: dark surface, primary CTA on light, text on light.
  static const Color ink = Color(0xFF0D2B1C);

  /// Warm cream: light surface, text on dark.
  static const Color parchment = Color(0xFFF4EDD8);

  /// Live accent — primary CTA on dark, positive "bits".
  static const Color fairway = Color(0xFF4CAF73);

  /// Raised dark surface / secondary container.
  static const Color pine = Color(0xFF143A26);

  // ── Semantic colours (text-safe shade flips per theme) ──────────────────
  /// Birdies, sandies — points won. On dark use [fairway]; on light, this.
  static const Color bitsPositiveLight = Color(0xFF2F8F5B);

  /// Three-putts, OB — points lost (fill).
  static const Color junkPenalty = Color(0xFFD2603F);

  /// Junk as text on a light surface.
  static const Color junkPenaltyText = Color(0xFFB24E30);

  /// Leader, payouts, highlights (fill).
  static const Color sandWinner = Color(0xFFE0A33E);

  /// Sand as text on a light surface.
  static const Color sandWinnerText = Color(0xFFB87B1E);

  // ── Dark ramp · "on course" (least → most elevated) ─────────────────────
  static const Color darkBg = Color(0xFF0A2017);
  static const Color darkSurface = ink; // #0D2B1C
  static const Color darkRaised = pine; // #143A26
  static const Color darkLine = Color(0xFF1C4A30);
  static const Color darkHi = Color(0xFF26603F);
  static const Color darkText = parchment; // #F4EDD8
  static const Color darkMuted = Color(0xFFA8BBAF);
  static const Color darkNavUnselected = Color(0xFF7E938A);

  // ── Light ramp · "in the clubhouse" (least → most elevated) ─────────────
  static const Color lightBg = Color(0xFFE7DCC2); // the "table"
  static const Color lightContainerLow = Color(0xFFEFE6CF);
  static const Color lightSurface = parchment; // #F4EDD8 — scorecard paper
  static const Color lightRaised = Color(0xFFFBF8EE);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightLine = Color(0xFFD9CFB4);
  static const Color lightOutline = Color(0xFFC8BC9C);
  static const Color lightText = ink; // #0D2B1C
  static const Color lightMuted = Color(0xFF5E7064);
  static const Color lightNavUnselected = Color(0xFF8A9A8E);

  // ── Light container roles for primary / secondary tints ─────────────────
  static const Color lightPrimaryContainer = Color(0xFFDDEFE3);
  static const Color lightOnPrimaryContainer = Color(0xFF1C5A38);
  static const Color lightSecondaryContainer = Color(0xFFF6E6C8);

  // ── Error containers (junk-tinted, per theme) ───────────────────────────
  static const Color darkErrorContainer = Color(0xFF5A2317);
  static const Color darkOnErrorContainer = Color(0xFFF3C9BC);
  static const Color lightErrorContainer = Color(0xFFF3DDD3);
  static const Color lightOnErrorContainer = Color(0xFF7A2E18);

  // ── Welcome / onboarding (always dark "on course") ───────────────────────
  /// Radial gradient top stop on the welcome screen.
  static const Color welcomeGradientTop = Color(0xFF15402A);

  /// DM Mono eyebrow accent on the welcome carousel.
  static const Color welcomeEyebrow = Color(0xFF6FCB97);

  /// Footer caption under the guest CTA.
  static const Color welcomeCaption = Color(0xFF6A7E72);
}

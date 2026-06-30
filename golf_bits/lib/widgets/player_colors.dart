import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Stable per-round player colour from index (Fairway, Sand, Pine, Ink).
Color playerColorForIndex(BuildContext context, int index) {
  final scheme = Theme.of(context).colorScheme;
  return switch (index % 4) {
    0 => scheme.primary,
    1 => scheme.secondary,
    2 => AppColors.pine,
    _ => scheme.surfaceContainerHighest,
  };
}

Color playerOnColorForFill(BuildContext context, Color fill) {
  return AppTheme.textOnFilledCircle(fill, Theme.of(context).colorScheme);
}

String initialForDisplayName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.substring(0, 1).toUpperCase();
}

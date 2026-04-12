import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Material [Card] with an optional emphasis border (round-in-progress / player row pattern).
/// Prefer plain [Card] unless you need the accent outline.
class OutlinedSurfaceCard extends StatelessWidget {
  const OutlinedSurfaceCard({
    super.key,
    required this.child,
    this.borderColor,
    this.padding = const EdgeInsets.all(AppTheme.cardInnerPadding),
  });

  final Widget child;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = borderColor ?? scheme.outlineVariant;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: BorderSide(
          color: border,
          width: borderColor != null ? AppTheme.emphasisBorderWidth : AppTheme.outlineBorderWidth,
        ),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

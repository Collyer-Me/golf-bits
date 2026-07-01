import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tappable card with clipped ripple and subtle selected border — no full-screen splash.
class SelectableSurfaceCard extends StatelessWidget {
  const SelectableSurfaceCard({
    super.key,
    required this.child,
    this.selected = false,
    this.onTap,
    this.borderColor,
    this.padding = const EdgeInsets.all(AppTheme.cardInnerPadding),
    this.borderRadius = AppTheme.cardRadius,
  });

  final Widget child;
  final bool selected;
  final VoidCallback? onTap;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedBorder = borderColor ??
        (selected ? scheme.primary : scheme.outlineVariant);
    final borderWidth =
        selected ? AppTheme.emphasisBorderWidth : AppTheme.outlineBorderWidth;
    final background = selected
        ? scheme.surfaceContainerHigh
        : scheme.surfaceContainer;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: resolvedBorder, width: borderWidth),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          splashFactory: NoSplash.splashFactory,
          highlightColor: scheme.primary.withValues(alpha: 0.06),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

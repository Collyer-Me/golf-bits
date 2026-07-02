import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class HoleProgressBar extends StatelessWidget {
  const HoleProgressBar({
    super.key,
    required this.holeCount,
    required this.currentIndex,
    this.onHoleTap,
    this.maxTappableIndex,
  });

  final int holeCount;
  final int currentIndex;

  /// When set, holes up to [maxTappableIndex] (or [currentIndex] if null) are tappable.
  final ValueChanged<int>? onHoleTap;
  final int? maxTappableIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tapLimit = maxTappableIndex ?? currentIndex;

    return Row(
      children: [
        for (var i = 0; i < holeCount; i++) ...[
          if (i > 0) const SizedBox(width: AppTheme.space1),
          Expanded(
            flex: i == currentIndex ? 25 : 10,
            child: _HolePip(
              index: i,
              currentIndex: currentIndex,
              scheme: scheme,
              tappable: onHoleTap != null && i <= tapLimit,
              onTap: onHoleTap == null ? null : () => onHoleTap!(i),
            ),
          ),
        ],
      ],
    );
  }
}

class _HolePip extends StatelessWidget {
  const _HolePip({
    required this.index,
    required this.currentIndex,
    required this.scheme,
    required this.tappable,
    this.onTap,
  });

  final int index;
  final int currentIndex;
  final ColorScheme scheme;
  final bool tappable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = index < currentIndex
        ? scheme.surfaceContainerHigh
        : index == currentIndex
            ? scheme.primary
            : scheme.onSurface.withValues(alpha: AppTheme.opacityProgressPipUpcoming);

    final pip = Container(
      height: AppTheme.space1,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.stadiumRadius),
      ),
    );

    if (!tappable || onTap == null) return pip;

    return Semantics(
      button: true,
      label: 'Hole ${index + 1}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: pip,
      ),
    );
  }
}

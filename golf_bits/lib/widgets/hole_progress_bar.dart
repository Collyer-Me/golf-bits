import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class HoleProgressBar extends StatelessWidget {
  const HoleProgressBar({
    super.key,
    required this.holeCount,
    required this.currentIndex,
  });

  final int holeCount;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        for (var i = 0; i < holeCount; i++) ...[
          if (i > 0) const SizedBox(width: AppTheme.space1),
          Expanded(
            flex: i == currentIndex ? 25 : 10,
            child: Container(
              height: AppTheme.space1,
              decoration: BoxDecoration(
                color: i < currentIndex
                    ? scheme.surfaceContainerHigh
                    : i == currentIndex
                        ? scheme.primary
                        : scheme.onSurface.withValues(alpha: AppTheme.opacityProgressPipUpcoming),
                borderRadius: BorderRadius.circular(AppTheme.stadiumRadius),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

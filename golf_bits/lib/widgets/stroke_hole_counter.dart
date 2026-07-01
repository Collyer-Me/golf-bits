import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Inline stroke stepper for one hole (defaults to par when known).
class StrokeHoleCounter extends StatelessWidget {
  const StrokeHoleCounter({
    super.key,
    required this.strokes,
    this.par,
    required this.onChanged,
    this.min = 1,
    this.max = 15,
    this.formatValue,
  });

  final int strokes;
  /// Reserved for callers; par defaulting happens upstream.
  final int? par;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final String Function(int value)? formatValue;

  void _bump(int delta) {
    final next = (strokes + delta).clamp(min, max);
    if (next != strokes) onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.stadiumRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: strokes > min ? () => _bump(-1) : null,
            tooltip: 'Fewer strokes',
            icon: const Icon(Icons.remove, size: AppTheme.iconDense),
            style: IconButton.styleFrom(
              minimumSize: const Size(40, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space1),
            child: Text(
              formatValue?.call(strokes) ?? '$strokes',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            onPressed: strokes < max ? () => _bump(1) : null,
            tooltip: 'More strokes',
            icon: const Icon(Icons.add, size: AppTheme.iconDense),
            style: IconButton.styleFrom(
              minimumSize: const Size(40, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

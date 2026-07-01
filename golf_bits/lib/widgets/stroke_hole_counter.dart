import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Inline stroke stepper for one hole (defaults to par when known).
class StrokeHoleCounter extends StatelessWidget {
  const StrokeHoleCounter({
    super.key,
    required this.strokes,
    this.par,
    required this.onChanged,
  });

  final int strokes;
  /// Reserved for callers; par defaulting happens upstream.
  final int? par;
  final ValueChanged<int> onChanged;

  static const int _min = 1;
  static const int _max = 15;

  void _bump(int delta) {
    final next = (strokes + delta).clamp(_min, _max);
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
            onPressed: strokes > _min ? () => _bump(-1) : null,
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
              '$strokes',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            onPressed: strokes < _max ? () => _bump(1) : null,
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

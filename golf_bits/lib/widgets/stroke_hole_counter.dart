import 'package:flutter/material.dart';

import '../models/stroke_tracking.dart';
import '../theme/app_theme.dart';

/// Inline stroke stepper for one hole (defaults to par when known).
class StrokeHoleCounter extends StatelessWidget {
  const StrokeHoleCounter({
    super.key,
    required this.strokes,
    required this.par,
    required this.onChanged,
  });

  final int strokes;
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
    final toPar = scoreToParLabel(strokes: strokes, par: par);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          onPressed: strokes > _min ? () => _bump(-1) : null,
          icon: const Icon(Icons.remove, size: AppTheme.iconDense),
          style: IconButton.styleFrom(
            minimumSize: const Size(40, 40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        SizedBox(width: AppTheme.space2),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$strokes',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (par != null)
              Text(
                toPar,
                style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
          ],
        ),
        SizedBox(width: AppTheme.space2),
        IconButton.filledTonal(
          onPressed: strokes < _max ? () => _bump(1) : null,
          icon: const Icon(Icons.add, size: AppTheme.iconDense),
          style: IconButton.styleFrom(
            minimumSize: const Size(40, 40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class HoleHeader extends StatelessWidget {
  const HoleHeader({
    super.key,
    required this.hole,
    this.par,
    this.yardage,
    this.strokeIndex,
    this.titleOverride,
    this.trailing,
    this.thru,
  });

  final int hole;
  final int? par;
  final int? yardage;
  final int? strokeIndex;
  final String? titleOverride;
  final Widget? trailing;
  final int? thru;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final eyebrowParts = <String>[];
    if (par != null) eyebrowParts.add('PAR $par');
    if (yardage != null) {
      eyebrowParts.add('$yardage YDS');
    } else if (par != null) {
      eyebrowParts.add('COURSE');
    }
    if (strokeIndex != null) eyebrowParts.add('INDEX $strokeIndex');
    final eyebrow = eyebrowParts.join(' · ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow.isNotEmpty)
                Text(
                  eyebrow.toUpperCase(),
                  style: AppTheme.monoLabel(context, color: AppTheme.bits(context)),
                ),
              Text(
                titleOverride ?? 'Hole $hole',
                style: text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              if (titleOverride != null)
                Text(
                  'Hole $hole',
                  style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant),
                )
              else if (thru != null)
                Text(
                  'THRU $thru',
                  style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

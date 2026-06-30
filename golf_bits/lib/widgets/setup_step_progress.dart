import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SetupStepProgress extends StatelessWidget {
  const SetupStepProgress({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.labels,
  });

  final int currentStep;
  final int totalSteps;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'NEW ROUND · STEP $currentStep OF $totalSteps',
          style: text.labelSmall?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: AppTheme.letterStepCaps,
          ),
        ),
        const SizedBox(height: AppTheme.space3),
        Row(
          children: [
            for (var i = 0; i < totalSteps; i++) ...[
              if (i > 0) const SizedBox(width: AppTheme.space1),
              Expanded(
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: i < currentStep
                        ? scheme.primary
                        : scheme.onSurface.withValues(alpha: AppTheme.opacityProgressPipUpcoming),
                    borderRadius: BorderRadius.circular(AppTheme.stadiumRadius),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (labels.length == totalSteps) ...[
          const SizedBox(height: AppTheme.space1),
          Row(
            children: [
              for (var i = 0; i < totalSteps; i++)
                Expanded(
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: AppTheme.monoLabel(
                      context,
                      color: i == currentStep - 1 ? scheme.primary : scheme.onSurfaceVariant,
                    ).copyWith(fontSize: 9),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

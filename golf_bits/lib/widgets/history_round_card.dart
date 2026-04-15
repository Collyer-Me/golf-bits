import 'package:flutter/material.dart';

import '../models/history_round.dart';
import '../theme/app_theme.dart';
import 'outlined_surface_card.dart';

class HistoryRoundCard extends StatelessWidget {
  const HistoryRoundCard({super.key, required this.round, required this.onTap});

  final HistoryRound round;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Material(
      color: scheme.surface.withValues(alpha: 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        onTap: onTap,
        child: OutlinedSurfaceCard(
          borderColor: scheme.outlineVariant,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      round.courseName,
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: round.completed
                          ? scheme.tertiaryContainer.withValues(alpha: AppTheme.opacitySecondaryFill)
                          : scheme.primaryContainer.withValues(alpha: AppTheme.opacitySecondaryFill),
                      borderRadius: BorderRadius.circular(AppTheme.stadiumRadius),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space2, vertical: AppTheme.space1),
                      child: Text(
                        round.completed ? 'COMPLETED' : 'IN PROGRESS',
                        style: text.labelSmall?.copyWith(
                          color: round.completed ? scheme.onTertiaryContainer : scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                          letterSpacing: AppTheme.letterBadge,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppTheme.space1),
              Text(
                round.holesLine,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              SizedBox(height: AppTheme.space3),
              Wrap(
                spacing: AppTheme.space2,
                runSpacing: AppTheme.space2,
                children: round.players
                    .map(
                      (p) => Chip(
                        label: Text(p),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        labelStyle: text.labelMedium,
                        side: BorderSide(color: scheme.outlineVariant),
                        backgroundColor: scheme.surfaceContainerHigh,
                      ),
                    )
                    .toList(),
              ),
              SizedBox(height: AppTheme.space3),
              Row(
                children: [
                  Icon(Icons.emoji_events_outlined, size: AppTheme.iconDense, color: scheme.secondary),
                  SizedBox(width: AppTheme.space2),
                  Text(
                    round.winnerName,
                    style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(
                    '+${round.winnerBits} Bits',
                    style: text.titleSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

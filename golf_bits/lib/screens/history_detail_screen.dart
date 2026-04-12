import 'package:flutter/material.dart';

import '../models/history_round.dart';
import '../theme/app_theme.dart';
import '../widgets/outlined_surface_card.dart';
import 'player_breakdown_screen.dart';

/// Deep dive for one past round (standings + left early).
class HistoryDetailScreen extends StatelessWidget {
  const HistoryDetailScreen({super.key, required this.round});

  final HistoryRound round;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              round.courseShortTitle,
              overflow: TextOverflow.ellipsis,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              round.dateHeader,
              style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share round — coming soon')),
              );
            },
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: AppTheme.screenPadding,
        children: [
          OutlinedSurfaceCard(
            borderColor: scheme.secondary.withValues(alpha: AppTheme.opacityBorderEmphasis),
            child: Column(
              children: [
                CircleAvatar(
                  radius: AppTheme.space5,
                  backgroundColor: scheme.secondaryContainer,
                  child: Icon(Icons.emoji_events, color: scheme.secondary, size: AppTheme.iconLarge),
                ),
                SizedBox(height: AppTheme.space3),
                Text(
                  'ROUND WINNER',
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: AppTheme.letterStepCaps,
                  ),
                ),
                Text(
                  round.winnerName.toUpperCase(),
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                Text(
                  '+${round.winnerBits} BITS',
                  style: text.headlineMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppTheme.space6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'FINAL STANDINGS',
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: AppTheme.letterStepCaps,
                  ),
                ),
              ),
              Text(
                'TOTAL BITS',
                style: text.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: AppTheme.letterStepCaps,
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.space3),
          ...round.standings.map((s) => _StandingTile(standing: s)),
          if (round.leftEarly.isNotEmpty) ...[
            SizedBox(height: AppTheme.space6),
            Text(
              'LEFT EARLY',
              style: text.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                letterSpacing: AppTheme.letterStepCaps,
              ),
            ),
            SizedBox(height: AppTheme.space3),
            ...round.leftEarly.map((r) => _LeftEarlyTile(row: r)),
          ],
        ],
      ),
    );
  }
}

class _StandingTile extends StatelessWidget {
  const _StandingTile({required this.standing});

  final HistoryStanding standing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final win = standing.isWinnerRow;
    final bitsColor = standing.bits < 0
        ? scheme.error
        : (win ? scheme.onPrimaryContainer : scheme.onSurface);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space2),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PlayerBreakdownScreen(playerName: standing.name),
            ),
          );
        },
        child: OutlinedSurfaceCard(
          borderColor: win ? scheme.primary : scheme.outlineVariant,
          padding: EdgeInsets.zero,
          child: Material(
            color: win
                ? scheme.primaryContainer.withValues(alpha: AppTheme.opacitySecondaryFill * 1.3)
                : scheme.surface.withValues(alpha: 0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4, vertical: AppTheme.space3),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: AppTheme.space3,
                    backgroundColor: scheme.surfaceContainerHigh,
                    child: Text(
                      '${standing.rank}',
                      style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  SizedBox(width: AppTheme.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          standing.name,
                          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          standing.subtitle,
                          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    standing.bits >= 0 ? '+${standing.bits}' : '${standing.bits}',
                    style: text.titleLarge?.copyWith(
                      color: bitsColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LeftEarlyTile extends StatelessWidget {
  const _LeftEarlyTile({required this.row});

  final HistoryLeftEarly row;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space2),
      child: OutlinedSurfaceCard(
        borderColor: scheme.outlineVariant,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4, vertical: AppTheme.space3),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Text(
                    'Left hole ${row.leftHole}',
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppTheme.stadiumRadius),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.space3, vertical: AppTheme.space1),
                child: Text(
                  row.bitsLabel,
                  style: text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

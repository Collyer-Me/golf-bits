import 'dart:async';

import 'package:flutter/material.dart';

import '../config/supabase_env.dart';
import '../data/history_repository.dart';
import '../models/history_round.dart';
import '../theme/app_theme.dart';
import '../widgets/outlined_surface_card.dart';
import 'player_breakdown_screen.dart';

/// Deep dive for one past round (standings + left early). Refetches from Supabase when configured.
class HistoryDetailScreen extends StatefulWidget {
  const HistoryDetailScreen({super.key, required this.round});

  final HistoryRound round;

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  late HistoryRound _round;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _round = widget.round;
    unawaited(_refetchRound()); // fire-and-forget; completes in background
  }

  Future<void> _refetchRound() async {
    if (!SupabaseEnv.isConfigured) return;
    if (!mounted) return;
    setState(() => _refreshing = true);
    try {
      final fresh = await HistoryRepository.fetchRoundById(_round.id);
      if (mounted && fresh != null) setState(() => _round = fresh);
    } catch (_) {
      // Keep showing the list payload if refresh fails (offline / RLS).
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

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
              _round.courseShortTitle,
              overflow: TextOverflow.ellipsis,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              _round.dateHeader,
              style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (SupabaseEnv.isConfigured)
            IconButton(
              tooltip: 'Refresh',
              onPressed: _refreshing ? null : () => unawaited(_refetchRound()),
              icon: _refreshing
                  ? SizedBox(
                      width: AppTheme.iconDense,
                      height: AppTheme.iconDense,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onSurface,
                      ),
                    )
                  : const Icon(Icons.refresh),
            ),
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
      body: RefreshIndicator(
        onRefresh: _refetchRound,
        child: ListView(
          padding: AppTheme.screenPadding,
          physics: const AlwaysScrollableScrollPhysics(),
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
                    _round.winnerName.toUpperCase(),
                    style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  Text(
                    '+${_round.winnerBits} BITS',
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
            ..._round.standings.map(
              (s) => _StandingTile(
                roundId: _round.id,
                courseShortTitle: _round.courseShortTitle,
                dateHeader: _round.dateHeader,
                standing: s,
                onReturnFromPlayer: () => unawaited(_refetchRound()),
              ),
            ),
            if (_round.leftEarly.isNotEmpty) ...[
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
              ..._round.leftEarly.map((r) => _LeftEarlyTile(row: r)),
            ],
            SizedBox(height: MediaQuery.paddingOf(context).bottom + AppTheme.space4),
          ],
        ),
      ),
    );
  }
}

class _StandingTile extends StatelessWidget {
  const _StandingTile({
    required this.roundId,
    required this.courseShortTitle,
    required this.dateHeader,
    required this.standing,
    this.onReturnFromPlayer,
  });

  final String roundId;
  final String courseShortTitle;
  final String dateHeader;
  final HistoryStanding standing;
  final VoidCallback? onReturnFromPlayer;

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
        onTap: () async {
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => PlayerBreakdownScreen(
                roundId: roundId,
                playerName: standing.name,
                courseShortTitle: courseShortTitle,
                dateHeader: dateHeader,
              ),
            ),
          );
          onReturnFromPlayer?.call();
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

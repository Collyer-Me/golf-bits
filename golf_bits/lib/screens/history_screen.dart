import 'package:flutter/material.dart';

import '../models/history_round.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/outlined_surface_card.dart';
import 'history_detail_screen.dart';
import 'round_setup_screen.dart';

/// Past rounds list + empty state (demo data from [HistoryRound.demoRounds]).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  /// Flip with the app-bar action to preview the empty layout.
  bool _demoEmpty = false;

  List<HistoryRound> get _rounds => _demoEmpty ? <HistoryRound>[] : HistoryRound.demoRounds;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final rounds = _rounds;

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        automaticallyImplyLeading: false,
        title: const Text('History'),
        actions: [
          IconButton(
            tooltip: 'Toggle empty list (demo)',
            onPressed: () => setState(() => _demoEmpty = !_demoEmpty),
            icon: Icon(_demoEmpty ? Icons.list : Icons.inbox_outlined),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share history — coming soon')),
              );
            },
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: rounds.isEmpty
          ? _HistoryEmpty(onStartRound: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const RoundSetupScreen()),
              );
            })
          : ListView(
              padding: AppTheme.screenPadding,
              children: [
                Row(
                  children: [
                    Text(
                      'RECENT ROUNDS',
                      style: text.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                        letterSpacing: AppTheme.letterStepCaps,
                      ),
                    ),
                    const Spacer(),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(AppTheme.stadiumRadius),
                        border: Border.all(color: scheme.primary.withValues(alpha: AppTheme.opacityPrimaryBorder)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppTheme.space3, vertical: AppTheme.space1),
                        child: Text(
                          '${rounds.length} total',
                          style: text.labelSmall?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.space4),
                ...rounds.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.space3),
                      child: _HistoryRoundCard(
                        round: r,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => HistoryDetailScreen(round: r),
                            ),
                          );
                        },
                      ),
                    )),
                SizedBox(height: AppTheme.space8),
              ],
            ),
    );
  }
}

class _HistoryRoundCard extends StatelessWidget {
  const _HistoryRoundCard({required this.round, required this.onTap});

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
                  if (round.completed)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.tertiaryContainer.withValues(alpha: AppTheme.opacitySecondaryFill),
                        borderRadius: BorderRadius.circular(AppTheme.stadiumRadius),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppTheme.space2, vertical: AppTheme.space1),
                        child: Text(
                          'COMPLETED',
                          style: text.labelSmall?.copyWith(
                            color: scheme.onTertiaryContainer,
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
                      color: AppColors.accentLime,
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

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty({required this.onStartRound});

  final VoidCallback onStartRound;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: AppTheme.screenPadding,
      child: Column(
        children: [
          const Spacer(flex: 2),
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.space8),
              child: Icon(Icons.flag_outlined, size: AppTheme.iconLarge, color: scheme.primary),
            ),
          ),
          SizedBox(height: AppTheme.space6),
          Text(
            'No rounds yet',
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: AppTheme.space2),
          Text(
            'Finish your first round and it’ll appear here',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const Spacer(flex: 3),
          FilledButton(
            onPressed: onStartRound,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Start a Round'),
                SizedBox(width: AppTheme.space2),
                Icon(Icons.arrow_forward, size: AppTheme.iconArrow),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom + AppTheme.space4),
        ],
      ),
    );
  }
}

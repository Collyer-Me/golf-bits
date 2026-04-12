import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/outlined_surface_card.dart';
import 'player_breakdown_screen.dart';

class _Standing {
  const _Standing({
    required this.rank,
    required this.name,
    required this.bits,
    required this.vsLeader,
  });

  final int rank;
  final String name;
  final int bits;
  final String vsLeader;
}

class _Retired {
  const _Retired({required this.name, required this.leftHole, required this.bits});

  final String name;
  final int leftHole;
  final int bits;
}

/// End of round: winner spotlight, standings, retired list, actions.
class RoundSummaryScreen extends StatelessWidget {
  const RoundSummaryScreen({super.key});

  static const _winnerName = 'Alex';
  static const _winnerBits = 7;
  static const _roundId = 42;

  static const _standings = [
    _Standing(rank: 1, name: 'Alex', bits: 7, vsLeader: '—'),
    _Standing(rank: 2, name: 'Jamie', bits: 2, vsLeader: '−5 vs leader'),
    _Standing(rank: 3, name: 'Chris', bits: 0, vsLeader: '−7 vs leader'),
  ];

  static const _retired = [
    _Retired(name: 'Taylor', leftHole: 6, bits: -2),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: AppTheme.screenPadding,
          children: [
            SizedBox(height: AppTheme.space4),
            Icon(Icons.emoji_events_outlined, size: AppTheme.iconLarge, color: scheme.secondary),
            SizedBox(height: AppTheme.space3),
            Text(
              _winnerName,
              textAlign: TextAlign.center,
              style: text.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
              ),
            ),
            Text(
              '+$_winnerBits BITS',
              textAlign: TextAlign.center,
              style: text.displaySmall?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: AppTheme.space3),
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppTheme.stadiumRadius),
                  border: Border.all(color: scheme.primary.withValues(alpha: AppTheme.opacityPrimaryBorder)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space4,
                    vertical: AppTheme.space2,
                  ),
                  child: Text(
                    'WINNER · ROUND #$_roundId',
                    style: text.labelSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                      letterSpacing: AppTheme.letterStepCaps,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: AppTheme.space8),
            Text(
              'FINAL STANDINGS',
              style: text.labelSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: AppTheme.letterStepCaps,
              ),
            ),
            SizedBox(height: AppTheme.space3),
            ..._standings.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.space2),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PlayerBreakdownScreen(playerName: s.name),
                        ),
                      );
                    },
                    child: OutlinedSurfaceCard(
                      borderColor: scheme.outlineVariant,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space4,
                        vertical: AppTheme.space3,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: AppTheme.space3,
                            backgroundColor: scheme.surfaceContainerHigh,
                            child: Text(
                              '${s.rank}',
                              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          SizedBox(width: AppTheme.space3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                Text(
                                  s.vsLeader,
                                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            s.bits >= 0 ? '+${s.bits}' : '${s.bits}',
                            style: text.titleLarge?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
            SizedBox(height: AppTheme.space6),
            Text(
              'RETIRED EARLY',
              style: text.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                letterSpacing: AppTheme.letterStepCaps,
              ),
            ),
            SizedBox(height: AppTheme.space3),
            ..._retired.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.space2),
                child: OutlinedSurfaceCard(
                  borderColor: scheme.outlineVariant,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space4,
                    vertical: AppTheme.space3,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                            Text(
                              'Left hole ${r.leftHole}',
                              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${r.bits}',
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: AppTheme.space8),
            FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Share sheet — coming soon')),
                );
              },
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share Results'),
            ),
            SizedBox(height: AppTheme.space3),
            OutlinedButton(
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}

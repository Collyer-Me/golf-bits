import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/outlined_surface_card.dart';

class _TimelineEvent {
  const _TimelineEvent({
    required this.label,
    required this.bits,
    required this.icon,
    this.negative = false,
  });

  final String label;
  final int bits;
  final IconData icon;
  final bool negative;
}

class _TimelineHole {
  const _TimelineHole({required this.hole, required this.par, required this.events});

  final int hole;
  final int par;
  final List<_TimelineEvent> events;
}

/// Per-player round timeline (stub data for preview).
class PlayerBreakdownScreen extends StatelessWidget {
  const PlayerBreakdownScreen({super.key, required this.playerName});

  final String playerName;

  static const _alexHoles = <_TimelineHole>[
    _TimelineHole(
      hole: 1,
      par: 4,
      events: const [
        _TimelineEvent(label: 'Birdie', bits: 1, icon: Icons.sports_golf),
        _TimelineEvent(label: 'One-Putt', bits: 1, icon: Icons.radio_button_checked_outlined),
      ],
    ),
    _TimelineHole(
      hole: 3,
      par: 5,
      events: const [
        _TimelineEvent(label: 'Sandy', bits: 1, icon: Icons.waves_outlined),
      ],
    ),
    _TimelineHole(
      hole: 7,
      par: 4,
      events: const [
        _TimelineEvent(label: 'Chip-in', bits: 2, icon: Icons.flag_outlined),
        _TimelineEvent(label: 'Eagle', bits: 2, icon: Icons.trending_up),
      ],
    ),
    _TimelineHole(
      hole: 9,
      par: 3,
      events: const [
        _TimelineEvent(label: 'Three-Putt', bits: -1, icon: Icons.remove_circle_outline, negative: true),
      ],
    ),
  ];

  List<_TimelineHole> _holesFor(String name) {
    if (name == 'Alex') return List<_TimelineHole>.of(_alexHoles);
    return <_TimelineHole>[];
  }

  int _totalBitsFor(String name) =>
      _holesFor(name).expand((h) => h.events).fold<int>(0, (s, e) => s + e.bits);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final holes = _holesFor(playerName);
    final total = _totalBitsFor(playerName);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Player Breakdown'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: AppTheme.screenPadding,
              children: [
                Text(
                  'ROUND PERFORMANCE',
                  style: text.labelSmall?.copyWith(
                    color: scheme.secondary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: AppTheme.letterStepCaps,
                  ),
                ),
                SizedBox(height: AppTheme.space2),
                Text(
                  playerName,
                  style: text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                Text(
                  'Royal Melbourne',
                  style: text.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
                Text(
                  '11 Apr 2026',
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                SizedBox(height: AppTheme.space2),
                Text(
                  '${total >= 0 ? '+' : ''}$total BITS',
                  style: text.headlineSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: AppTheme.space6),
                if (holes.isEmpty)
                  Text(
                    'No bit events recorded for this player in the demo data.',
                    style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  )
                else
                  ...holes.expand((h) => [
                        _HoleTimelineBlock(hole: h, scheme: scheme, text: text),
                        SizedBox(height: AppTheme.space4),
                      ]),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              left: AppTheme.pageHorizontal,
              right: AppTheme.pageHorizontal,
              top: AppTheme.space3,
              bottom: MediaQuery.paddingOf(context).bottom + AppTheme.space3,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'TOTAL BREAKDOWN',
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: AppTheme.letterStepCaps,
                  ),
                ),
                Text(
                  '${total >= 0 ? '+' : ''}$total BITS',
                  style: text.headlineSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: AppTheme.space3),
                FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Share breakdown — coming soon')),
                    );
                  },
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share Breakdown'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HoleTimelineBlock extends StatelessWidget {
  const _HoleTimelineBlock({
    required this.hole,
    required this.scheme,
    required this.text,
  });

  final _TimelineHole hole;
  final ColorScheme scheme;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: AppTheme.space8,
              height: AppTheme.space8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primaryContainer,
                border: Border.all(color: scheme.primary.withValues(alpha: AppTheme.opacityPrimaryBorder)),
              ),
              child: Center(
                child: Text(
                  '${hole.hole}',
                  style: text.labelLarge?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            Text(
              'PAR ${hole.par}',
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        SizedBox(width: AppTheme.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: hole.events.map((e) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.space2),
                child: OutlinedSurfaceCard(
                  borderColor: e.negative ? scheme.error : scheme.outlineVariant,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space3,
                    vertical: AppTheme.space2,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        e.icon,
                        color: e.negative ? scheme.error : scheme.primary,
                        size: AppTheme.iconDense,
                      ),
                      SizedBox(width: AppTheme.space3),
                      Expanded(
                        child: Text(
                          e.label,
                          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${e.bits >= 0 ? '+' : ''}${e.bits}',
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: e.negative ? scheme.error : scheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

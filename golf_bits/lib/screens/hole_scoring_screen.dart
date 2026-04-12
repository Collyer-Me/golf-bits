import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/outlined_surface_card.dart';
import 'round_summary_screen.dart';

class _HolePlayer {
  _HolePlayer({
    required this.id,
    required this.name,
    required this.holeScore,
    required this.totalScore,
    this.isActive = false,
  });

  final String id;
  final String name;
  int holeScore;
  int totalScore;
  bool isActive;
}

/// In-round: hole header, player rows, event award bottom sheet.
class HoleScoringScreen extends StatefulWidget {
  const HoleScoringScreen({super.key});

  @override
  State<HoleScoringScreen> createState() => _HoleScoringScreenState();
}

class _HoleScoringScreenState extends State<HoleScoringScreen> {
  int _hole = 7;
  final List<_HolePlayer> _players = [
    _HolePlayer(id: '1', name: 'Alex', holeScore: 3, totalScore: 12, isActive: true),
    _HolePlayer(id: '2', name: 'Jamie', holeScore: -1, totalScore: 4),
    _HolePlayer(id: '3', name: 'Chris', holeScore: 0, totalScore: 7),
  ];

  ({int par, int yards}) get _holeMeta {
    return switch (_hole) {
      7 => (par: 4, yards: 385),
      _ => (par: 4, yards: 360),
    };
  }

  void _prevHole() {
    setState(() => _hole = _hole <= 1 ? 18 : _hole - 1);
  }

  void _nextHole() {
    setState(() => _hole = _hole >= 18 ? 1 : _hole + 1);
  }

  void _openEventSheet(_HolePlayer player) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _EventAwardSheet(
        playerName: player.name,
        onAward: (delta) {
          Navigator.of(ctx).pop();
          setState(() {
            player.holeScore += delta;
            player.totalScore += delta;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${player.name}: ${delta >= 0 ? '+' : ''}$delta bits (stub)')),
            );
          }
        },
      ),
    );
  }

  void _endRound() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RoundSummaryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final meta = _holeMeta;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag, size: AppTheme.iconInline, color: scheme.primary),
            SizedBox(width: AppTheme.space2),
            Text(
              'Golf Bits',
              style: text.titleLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'end') _endRound();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'end', child: Text('End round')),
              PopupMenuItem(value: 'help', child: Text('Help')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: AppTheme.screenPadding,
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: _prevHole,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Hole $_hole',
                      textAlign: TextAlign.center,
                      style: text.headlineMedium?.copyWith(
                        color: AppColors.accentLime,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    SizedBox(height: AppTheme.space1),
                    Text(
                      'PAR ${meta.par} — ${meta.yards} YDS',
                      style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: _nextHole,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          SizedBox(height: AppTheme.space6),
          ..._players.map((p) => _PlayerRowCard(
                player: p,
                scheme: scheme,
                text: text,
                onAward: () => _openEventSheet(p),
              )),
        ],
      ),
    );
  }
}

class _PlayerRowCard extends StatelessWidget {
  const _PlayerRowCard({
    required this.player,
    required this.scheme,
    required this.text,
    required this.onAward,
  });

  final _HolePlayer player;
  final ColorScheme scheme;
  final TextTheme text;
  final VoidCallback onAward;

  @override
  Widget build(BuildContext context) {
    final active = player.isActive;
    final holeStr = player.holeScore >= 0 ? '+${player.holeScore}' : '${player.holeScore}';
    final totalStr = player.totalScore >= 0 ? '+${player.totalScore}' : '${player.totalScore}';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space3),
      child: OutlinedSurfaceCard(
        borderColor: active ? scheme.primary : scheme.outlineVariant,
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
                  if (active)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.space1),
                      child: Text(
                        'ACTIVE PLAYER',
                        style: text.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: AppTheme.letterStepCaps,
                        ),
                      ),
                    ),
                  Text(
                    player.name,
                    style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: AppTheme.space1),
                  if (active)
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: holeStr,
                            style: text.headlineSmall?.copyWith(
                              color: AppColors.accentLime,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          TextSpan(
                            text: '    $totalStr TOTAL',
                            style: text.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      children: [
                        Text(
                          holeStr,
                          style: text.titleMedium?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: AppTheme.space3),
                        Text(
                          '$totalStr total',
                          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            FilledButton(
              onPressed: onAward,
              style: FilledButton.styleFrom(
                minimumSize: Size(active ? 56 : 48, active ? 56 : 48),
                padding: EdgeInsets.zero,
                shape: const CircleBorder(),
              ),
              child: Icon(Icons.add, size: active ? AppTheme.iconLarge : AppTheme.iconDense),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _AwardCallback = void Function(int delta);

class _EventAwardSheet extends StatelessWidget {
  const _EventAwardSheet({
    required this.playerName,
    required this.onAward,
  });

  final String playerName;
  final _AwardCallback onAward;

  static const _positive = [
    _EventDef('Birdie', '+1 BIT', 1),
    _EventDef('Eagle', '+2 BITS', 2),
    _EventDef('Chip-in', '+1 BIT', 1),
    _EventDef('One-Putt', '+1 BIT', 1),
  ];

  static const _negative = [
    _EventDef('Three-Putt', '−1 BIT', -1),
    _EventDef('Water Hazard', '−1 BIT', -1),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.pageHorizontal,
        right: AppTheme.pageHorizontal,
        top: AppTheme.space2,
        bottom: MediaQuery.paddingOf(context).bottom + AppTheme.space6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playerName,
                      style: text.headlineSmall?.copyWith(
                        color: scheme.primary,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'SELECT EVENTS TO AWARD BITS',
                      style: text.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: AppTheme.letterSheetLabel,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                ),
                child: const Icon(Icons.check),
              ),
            ],
          ),
          SizedBox(height: AppTheme.space4),
          _eventGrid(context, _positive, false),
          SizedBox(height: AppTheme.space3),
          _eventGrid(context, _negative, true),
        ],
      ),
    );
  }

  Widget _eventGrid(BuildContext context, List<_EventDef> items, bool negative) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: AppTheme.space2,
      crossAxisSpacing: AppTheme.space2,
      childAspectRatio: 2.35,
      children: items.map((e) {
        if (negative) {
          return OutlinedButton(
            onPressed: () => onAward(e.delta),
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error.withValues(alpha: AppTheme.opacityBorderEmphasis)),
            ),
            child: Text(
              '${e.label.toUpperCase()} ${e.sublabel}',
              textAlign: TextAlign.center,
              style: text.labelSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          );
        }
        return FilledButton(
          onPressed: () => onAward(e.delta),
          style: FilledButton.styleFrom(
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
          ),
          child: Text(
            '${e.label.toUpperCase()} ${e.sublabel}',
            textAlign: TextAlign.center,
            style: text.labelSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      }).toList(),
    );
  }
}

class _EventDef {
  const _EventDef(this.label, this.sublabel, this.delta);
  final String label;
  final String sublabel;
  final int delta;
}

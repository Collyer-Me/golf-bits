import 'dart:async';

import 'package:flutter/material.dart';

import '../data/history_repository.dart';
import '../models/round_bit_event_draft.dart';
import '../models/round_result.dart';
import '../models/round_session_args.dart';
import '../theme/app_theme.dart';
import '../widgets/outlined_surface_card.dart';
import 'round_summary_screen.dart';

class _HolePlayer {
  _HolePlayer({
    required this.id,
    required this.name,
    required this.totalScore,
    this.isActive = false,
  });

  final String id;
  final String name;
  int totalScore;
  bool isActive;
}

/// In-round: hole header, player rows, event award bottom sheet.
class HoleScoringScreen extends StatefulWidget {
  const HoleScoringScreen({super.key, this.session});

  /// When set (from [RoundSetupScreen]), end-of-round summary is saved to Supabase.
  final RoundSessionArgs? session;

  @override
  State<HoleScoringScreen> createState() => _HoleScoringScreenState();
}

class _HoleScoringScreenState extends State<HoleScoringScreen> {
  late final List<int> _holeOrder;
  int _holeIndex = 0;
  late final List<_HolePlayer> _players;
  final List<RoundBitEventDraft> _bitLog = [];
  final Map<String, Map<int, int>> _holeScores = {};

  int get _hole => _holeOrder[_holeIndex];

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    if (s != null) {
      if (s.holeCount == 9) {
        _holeOrder = List<int>.generate(9, (i) => s.startHole + i);
      } else {
        _holeOrder = List<int>.generate(18, (i) => i + 1);
      }
    } else {
      _holeOrder = List<int>.generate(18, (i) => i + 1);
    }
    if (s != null && s.playerNames.isNotEmpty) {
      _players = [
        for (var i = 0; i < s.playerNames.length; i++)
          _HolePlayer(
            id: 'p$i',
            name: s.playerNames[i],
            totalScore: s.initialScoreByPlayer[s.playerNames[i]] ?? 0,
            isActive: i == 0,
          ),
      ];
    } else {
      _players = [
        _HolePlayer(id: '1', name: 'Alex', totalScore: 0, isActive: true),
        _HolePlayer(id: '2', name: 'Jamie', totalScore: 0),
        _HolePlayer(id: '3', name: 'Chris', totalScore: 0),
      ];
    }
    for (final p in _players) {
      _holeScores[p.id] = <int, int>{};
    }
    if (s != null) {
      final idx = _holeOrder.indexOf(s.currentHole);
      if (idx >= 0) _holeIndex = idx;
      unawaited(_persistProgress());
    }
  }

  ({int par, int yards}) get _holeMeta {
    return switch (_hole) {
      7 => (par: 4, yards: 385),
      _ => (par: 4, yards: 360),
    };
  }

  void _prevHole() {
    if (_holeIndex == 0) return;
    setState(() => _holeIndex -= 1);
    unawaited(_persistProgress());
  }

  Future<void> _nextHole() async {
    final isLastHole = _holeIndex >= _holeOrder.length - 1;
    if (isLastHole) {
      final shouldEnd = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('End round?'),
          content: const Text('You are on the final hole. End the round and view summary?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('End round'),
            ),
          ],
        ),
      );
      if (shouldEnd == true) _endRound();
      return;
    }
    setState(() => _holeIndex += 1);
    await _persistProgress();
  }

  int _holeScoreFor(_HolePlayer player) => _holeScores[player.id]?[_hole] ?? 0;

  void _openEventSheet(_HolePlayer player) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _EventAwardSheet(
        playerName: player.name,
        onAward: (label, delta, iconKey) {
          Navigator.of(ctx).pop();
          final draft = RoundBitEventDraft(
            playerName: player.name,
            hole: _hole,
            eventLabel: label,
            delta: delta,
            iconKey: iconKey,
          );
          setState(() {
            final byHole = _holeScores[player.id]!;
            byHole[_hole] = (byHole[_hole] ?? 0) + delta;
            player.totalScore += delta;
            if (widget.session != null) {
              _bitLog.add(draft);
            }
          });
          unawaited(_persistAward(draft));
          unawaited(_persistProgress());
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${player.name}: ${delta >= 0 ? '+' : ''}$delta bits · $label')),
            );
          }
        },
      ),
    );
  }

  void _endRound() {
    final session = widget.session;
    if (session != null && _players.isNotEmpty) {
      final scored = _players.map((p) => (name: p.name, bits: p.totalScore)).toList();
      final result = RoundResult.fromSessionScores(
        session: session,
        scoredPlayers: scored,
        bitEvents: List<RoundBitEventDraft>.from(_bitLog),
      );
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => RoundSummaryScreen(result: result)),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const RoundSummaryScreen()),
      );
    }
  }

  Map<String, int> _scoreByPlayer() {
    return {for (final p in _players) p.name: p.totalScore};
  }

  Future<void> _persistProgress() async {
    final roundId = widget.session?.roundId;
    if (roundId == null || roundId.isEmpty) return;
    try {
      await HistoryRepository.updateRoundProgress(
        roundId: roundId,
        currentHole: _hole,
        scoreByPlayer: _scoreByPlayer(),
      );
    } catch (_) {
      // Keep gameplay responsive if sync fails; user can still finish and retry later.
    }
  }

  Future<void> _persistAward(RoundBitEventDraft event) async {
    final roundId = widget.session?.roundId;
    if (roundId == null || roundId.isEmpty) return;
    try {
      await HistoryRepository.saveBitEventsForRound(roundId, [event]);
    } catch (_) {
      // Non-fatal; summary save still persists final state.
    }
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
                onPressed: _holeIndex > 0 ? _prevHole : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Hole $_hole',
                      textAlign: TextAlign.center,
                      style: text.headlineMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
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
                holeScore: _holeScoreFor(p),
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
    required this.holeScore,
    required this.scheme,
    required this.text,
    required this.onAward,
  });

  final _HolePlayer player;
  final int holeScore;
  final ColorScheme scheme;
  final TextTheme text;
  final VoidCallback onAward;

  @override
  Widget build(BuildContext context) {
    final active = player.isActive;
    final holeStr = holeScore >= 0 ? '+$holeScore' : '$holeScore';
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
                              color: scheme.onPrimaryContainer,
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

typedef _AwardCallback = void Function(String label, int delta, String iconKey);

class _EventAwardSheet extends StatelessWidget {
  const _EventAwardSheet({
    required this.playerName,
    required this.onAward,
  });

  final String playerName;
  final _AwardCallback onAward;

  static const _positive = [
    _EventDef('Birdie', '+1 BIT', 1, 'sports_golf'),
    _EventDef('Eagle', '+2 BITS', 2, 'trending_up'),
    _EventDef('Chip-in', '+1 BIT', 1, 'flag_outlined'),
    _EventDef('One-Putt', '+1 BIT', 1, 'radio_button_checked_outlined'),
  ];

  static const _negative = [
    _EventDef('Three-Putt', '−1 BIT', -1, 'remove_circle_outline'),
    _EventDef('Water Hazard', '−1 BIT', -1, 'waves_outlined'),
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
            onPressed: () => onAward(e.label, e.delta, e.iconKey),
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
          onPressed: () => onAward(e.label, e.delta, e.iconKey),
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
  const _EventDef(this.label, this.sublabel, this.delta, this.iconKey);
  final String label;
  final String sublabel;
  final int delta;
  final String iconKey;
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../data/history_repository.dart';
import '../data/round_session_store.dart';
import '../data/sync_status_notifier.dart';
import '../models/round_bit_event_draft.dart';
import '../models/round_result.dart';
import '../models/round_session_args.dart';
import '../models/stroke_tracking.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_app_bar.dart';
import '../widgets/event_award_sheet.dart';
import '../widgets/outlined_surface_card.dart';
import '../widgets/player_bits_row.dart';
import '../widgets/stroke_hole_counter.dart';
import 'round_summary_screen.dart';

class _HolePlayer {
  _HolePlayer({
    required this.id,
    required this.name,
    this.userId,
    this.isYou = false,
    required this.totalBits,
  });

  final String id;
  final String name;
  final String? userId;
  final bool isYou;
  int totalBits;
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
  late final Map<String, int> _playerColorIndex;
  final List<RoundBitEventDraft> _bitLog = [];
  final Map<String, Map<int, int>> _holeBits = {};
  final Map<String, Map<int, int>> _strokeByHole = {};
  late final StrokeTrackingMode _strokeMode;
  late final Map<String, int> _holePars;
  late final Map<String, int> _holeYardages;

  int get _hole => _holeOrder[_holeIndex];

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    _strokeMode = s?.strokeTrackingMode ?? StrokeTrackingMode.off;
    _holePars = s?.holePars ?? const {};
    _holeYardages = s?.holeYardages ?? const {};
    if (s != null) {
      if (s.holeCount == 9) {
        _holeOrder = List<int>.generate(9, (i) => s.startHole + i);
      } else {
        _holeOrder = List<int>.generate(18, (i) => i + 1);
      }
    } else {
      _holeOrder = List<int>.generate(18, (i) => i + 1);
    }
    if (s != null && s.participants.isNotEmpty) {
      _players = [
        for (final p in s.participants)
          _HolePlayer(
            id: p.key,
            name: p.displayName,
            userId: p.userId,
            isYou: p.isYou,
            totalBits: s.initialScoreByPlayer[p.key] ?? 0,
          ),
      ];
    } else if (s != null && s.playerNames.isNotEmpty) {
      _players = [
        for (var i = 0; i < s.playerNames.length; i++)
          _HolePlayer(
            id: 'p$i',
            name: s.playerNames[i],
            totalBits: s.initialScoreByPlayer['p$i'] ?? 0,
          ),
      ];
    } else {
      _players = [
        _HolePlayer(id: '1', name: 'Alex', totalBits: 0),
        _HolePlayer(id: '2', name: 'Jamie', totalBits: 0),
        _HolePlayer(id: '3', name: 'Chris', totalBits: 0),
      ];
    }
    _playerColorIndex = {for (var i = 0; i < _players.length; i++) _players[i].id: i};
    for (final p in _players) {
      _holeBits[p.id] = <int, int>{};
    }
    if (s != null) {
      for (final entry in s.initialStrokeByHole.entries) {
        _strokeByHole[entry.key] = Map<int, int>.from(entry.value);
      }
      final idx = _holeOrder.indexOf(s.currentHole);
      if (idx >= 0) _holeIndex = idx;
      _seedDefaultStrokesForCurrentHole();
      unawaited(_bootstrapRoundState());
    }
  }

  Future<void> _bootstrapRoundState() async {
    await _restoreFromLocalDraftIfAny();
    await _hydrateFromCloud();
  }

  Future<void> _restoreFromLocalDraftIfAny() async {
    final loaded = await RoundSessionStore.loadDraft();
    if (loaded == null || loaded.kind != 'bits' || !mounted) return;
    final data = loaded.data;
    final sessionJson = data['session'];
    if (sessionJson is! Map) return;
    final draftSession = RoundSessionStore.sessionFromJson(Map<String, dynamic>.from(sessionJson));
    final current = widget.session;
    if (current != null &&
        draftSession.roundId != null &&
        current.roundId != null &&
        draftSession.roundId != current.roundId) {
      return;
    }
    final holeOrder = (data['holeOrder'] as List<dynamic>? ?? [])
        .map((e) => (e as num).toInt())
        .toList();
    final holeIndex = (data['holeIndex'] as num?)?.toInt() ?? 0;
    final playersRaw = data['players'] as List<dynamic>? ?? [];
    final bitLogRaw = data['bitLog'] as List<dynamic>? ?? [];

    setState(() {
      if (holeOrder.isNotEmpty && holeIndex >= 0 && holeIndex < holeOrder.length) {
        _holeIndex = holeIndex;
      }
      for (final raw in playersRaw) {
        final m = Map<String, dynamic>.from(raw as Map);
        final id = m['id'] as String?;
        if (id == null) continue;
        final player = _players.cast<_HolePlayer?>().firstWhere(
              (p) => p?.id == id,
              orElse: () => null,
            );
        if (player == null) continue;
        player.totalBits = (m['totalBits'] as num?)?.toInt() ?? player.totalBits;
      }
      final restoredHoleBits = <String, Map<int, int>>{};
      final holeBitsRaw = data['holeBits'];
      if (holeBitsRaw is Map) {
        for (final e in holeBitsRaw.entries) {
          final inner = e.value;
          if (inner is! Map) continue;
          restoredHoleBits[e.key as String] = {
            for (final h in inner.entries) int.parse(h.key.toString()): (h.value as num).toInt(),
          };
        }
      }
      for (final entry in restoredHoleBits.entries) {
        _holeBits[entry.key] = Map<int, int>.from(entry.value);
      }
      final strokeRaw = data['strokeByHole'];
      if (strokeRaw is Map) {
        for (final e in strokeRaw.entries) {
          final inner = e.value;
          if (inner is! Map) continue;
          _strokeByHole[e.key as String] = {
            for (final h in inner.entries) int.parse(h.key.toString()): (h.value as num).toInt(),
          };
        }
      }
      _bitLog
        ..clear()
        ..addAll(
          bitLogRaw.map((row) {
            final m = Map<String, dynamic>.from(row as Map);
            return RoundBitEventDraft(
              playerName: m['player_name'] as String? ?? '',
              participantKey: m['participant_key'] as String?,
              hole: (m['hole'] as num).toInt(),
              eventLabel: m['event_label'] as String,
              delta: (m['delta'] as num).toInt(),
              iconKey: m['icon_key'] as String?,
            );
          }),
        );
    });
    _seedDefaultStrokesForCurrentHole();

  List<_HolePlayer> get _sortedPlayers {
    final copy = [..._players];
    copy.sort((a, b) => b.totalBits.compareTo(a.totalBits));
    return copy;
  }

  List<int> get _bitsTiers {
    return _sortedPlayers.map((p) => p.totalBits).toSet().toList()..sort((a, b) => b.compareTo(a));
  }

  Future<void> _hydrateFromCloud() async {
    final roundId = widget.session?.roundId;
    if (roundId == null || roundId.isEmpty) {
      _seedDefaultStrokesForCurrentHole();
      await _saveLocalDraft();
      return;
    }
    try {
      await HistoryRepository.replayPendingBitEvents(roundId);
      final events = await HistoryRepository.fetchBitEventsForRound(roundId);
      if (!mounted) return;
      final localTotals = {for (final p in _players) p.id: p.totalBits};
      setState(() {
        for (final p in _players) {
          p.totalBits = 0;
          _holeBits[p.id] = <int, int>{};
        }
        _bitLog.clear();
        for (final row in events) {
          final hole = (row['hole'] as num).toInt();
          final label = row['event_label'] as String;
          final delta = (row['delta'] as num).toInt();
          final pKey = row['participant_key'] as String?;
          final pName = row['player_name'] as String;
          final player = _players.cast<_HolePlayer?>().firstWhere(
                (p) =>
                    p != null &&
                    ((pKey != null && pKey.isNotEmpty && p.id == pKey) || p.name == pName),
                orElse: () => null,
              );
          if (player == null) continue;
          _bitLog.add(
            RoundBitEventDraft(
              playerName: player.name,
              participantKey: player.id,
              participantUserId: player.userId,
              hole: hole,
              eventLabel: label,
              delta: delta,
              iconKey: row['icon_key'] as String?,
            ),
          );
          final byHole = _holeBits[player.id]!;
          byHole[hole] = (byHole[hole] ?? 0) + delta;
          player.totalBits += delta;
        }
        for (final p in _players) {
          final local = localTotals[p.id] ?? 0;
          if (local > p.totalBits) {
            p.totalBits = local;
          }
        }
      });
      _seedDefaultStrokesForCurrentHole();
    } catch (_) {
      // Non-fatal; keep local totals.
    }
    await _persistProgress();
    await _saveLocalDraft();
  }

  Future<void> _saveLocalDraft() async {
    final session = widget.session;
    if (session == null) return;
    await RoundSessionStore.saveBitsDraft(
      session: session,
      holeIndex: _holeIndex,
      players: [
        for (final p in _players)
          {
            'id': p.id,
            'name': p.name,
            'userId': p.userId,
            'isYou': p.isYou,
            'totalBits': p.totalBits,
          },
      ],
      holeBits: _holeBits,
      bitLog: List<RoundBitEventDraft>.from(_bitLog),
      strokeByHole: _strokeByHole,
      holeOrder: _holeOrder,
    );
  }

  int? _parForHole(int hole) => parForHole(_holePars, hole);

  bool _tracksStrokes(_HolePlayer player) {
    final participant = widget.session?.participants
        .cast<RoundParticipant?>()
        .firstWhere((p) => p?.key == player.id, orElse: () => null);
    if (participant != null) {
      return strokeTracksParticipant(mode: _strokeMode, participant: participant);
    }
    if (_strokeMode == StrokeTrackingMode.all) return true;
    if (_strokeMode == StrokeTrackingMode.self) return player.isYou;
    return false;
  }

  int _defaultStrokesForHole(int hole) => _parForHole(hole) ?? 4;

  /// Fills current hole with course par (or 4) for tracked players so the default counts without a tap.
  void _seedDefaultStrokesForCurrentHole() {
    if (!_strokeMode.tracksStrokes) return;
    for (final p in _players) {
      if (!_tracksStrokes(p)) continue;
      final byHole = _strokeByHole.putIfAbsent(p.id, () => <int, int>{});
      byHole.putIfAbsent(_hole, () => _defaultStrokesForHole(_hole));
    }
  }

  int _strokesOnHole(_HolePlayer player) {
    return _strokeByHole[player.id]?[_hole] ?? _defaultStrokesForHole(_hole);
  }

  void _setStrokes(_HolePlayer player, int strokes) {
    setState(() {
      _strokeByHole.putIfAbsent(player.id, () => <int, int>{})[_hole] = strokes;
    });
    unawaited(_persistProgress());
  }

  int _grossFor(_HolePlayer player) {
    final holes = _strokeByHole[player.id];
    if (holes == null || holes.isEmpty) return 0;
    return computeGrossStrokes(holes);
  }

  Map<String, int> _grossByPlayer() => computeGrossByPlayer(_strokeByHole);

  void _prevHole() {
    if (_holeIndex == 0) return;
    setState(() {
      _holeIndex -= 1;
      _seedDefaultStrokesForCurrentHole();
    });
    unawaited(_persistProgress());
  }

  Future<void> _nextHole() async {
    final isLastHole = _holeIndex >= _holeOrder.length - 1;
    if (isLastHole) {
      if (!mounted) return;
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
      if (!mounted) return;
      if (shouldEnd == true) _endRound();
      return;
    }
    if (!mounted) return;
    setState(() {
      _holeIndex += 1;
      _seedDefaultStrokesForCurrentHole();
    });
    await _persistProgress();
  }

  int _holeBitsFor(_HolePlayer player) => _holeBits[player.id]?[_hole] ?? 0;

  Color _playerFill(BuildContext context, _HolePlayer player) {
    final scheme = Theme.of(context).colorScheme;
    if (player.isYou) return scheme.primaryContainer;
    final idx = _playerColorIndex[player.id] ?? 0;
    if (idx == 0) return scheme.primary;
    if (idx == 1) return scheme.secondary;
    return scheme.primaryContainer;
  }

  void _openEventSheet(_HolePlayer player) {
    final rules = widget.session?.eventRules ?? const <RoundEventRule>[];
    String eventKey(String label, int delta) => '$label::$delta';
    final selectedForPlayerHole = _bitLog
        .where((e) => e.participantKey == player.id && e.hole == _hole)
        .map((e) => eventKey(e.eventLabel, e.delta))
        .toSet();
    showEventAwardSheet(
      context: context,
      sheet: EventAwardSheet(
        playerName: player.name,
        hole: _hole,
        par: _parForHole(_hole),
        rules: rules,
        initialSelectedKeys: selectedForPlayerHole,
        onAward: (label, delta, iconKey) {
          final draft = RoundBitEventDraft(
            playerName: player.name,
            participantKey: player.id,
            participantUserId: player.userId,
            hole: _hole,
            eventLabel: label,
            delta: delta,
            iconKey: iconKey,
          );
          var removed = false;
          setState(() {
            final byHole = _holeBits[player.id]!;
            final existingIdx = _bitLog.lastIndexWhere(
              (e) =>
                  e.participantKey == player.id &&
                  e.hole == _hole &&
                  e.eventLabel == label &&
                  e.delta == delta,
            );
            if (existingIdx >= 0) {
              removed = true;
              _bitLog.removeAt(existingIdx);
              final nextHoleScore = (byHole[_hole] ?? 0) - delta;
              if (nextHoleScore == 0) {
                byHole.remove(_hole);
              } else {
                byHole[_hole] = nextHoleScore;
              }
              player.totalBits -= delta;
            } else {
              byHole[_hole] = (byHole[_hole] ?? 0) + delta;
              player.totalBits += delta;
              _bitLog.add(draft);
            }
          });
          if (removed) {
            unawaited(_persistAwardRemoval(draft));
          } else {
            unawaited(_persistAward(draft));
          }
          unawaited(_persistProgress());
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  removed
                      ? '${player.name}: removed $label'
                      : '${player.name}: ${delta >= 0 ? '+' : ''}$delta bits · $label',
                ),
              ),
            );
          }
        },
      ),
    );
  }

  void _endRound() {
    _seedDefaultStrokesForCurrentHole();
    final session = widget.session;
    if (session != null && _players.isNotEmpty) {
      final scored = _players
          .map((p) => (key: p.id, name: p.name, bits: p.totalBits))
          .toList();
      final result = RoundResult.fromSessionScores(
        session: session,
        scoredPlayers: scored,
        bitEvents: List<RoundBitEventDraft>.from(_bitLog),
        strokeByHole: Map<String, Map<int, int>>.from(
          _strokeByHole.map((k, v) => MapEntry(k, Map<int, int>.from(v))),
        ),
        grossByPlayer: _grossByPlayer(),
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
    return {for (final p in _players) p.id: p.totalBits};
  }

  Future<void> _persistProgress() async {
    final roundId = widget.session?.roundId;
    if (roundId == null || roundId.isEmpty) {
      await _saveLocalDraft();
      return;
    }
    try {
      await HistoryRepository.updateRoundProgress(
        roundId: roundId,
        currentHole: _hole,
        scoreByPlayer: _scoreByPlayer(),
        strokeByHole: _strokeMode.tracksStrokes ? _strokeByHole : null,
        grossByPlayer: _strokeMode.tracksStrokes ? _grossByPlayer() : null,
      );
      await _saveLocalDraft();
    } catch (_) {
      SyncStatusNotifier.instance.recordFailure();
      await _saveLocalDraft();
    }
  }

  Future<void> _persistAward(RoundBitEventDraft event) async {
    final roundId = widget.session?.roundId;
    if (roundId == null || roundId.isEmpty) {
      await _saveLocalDraft();
      return;
    }
    try {
      await HistoryRepository.saveBitEventsForRound(roundId, [event]);
      SyncStatusNotifier.instance.recordSuccess();
    } catch (_) {
      SyncStatusNotifier.instance.recordFailure();
      await RoundSessionStore.enqueuePendingBitEvent({
        'action': 'save',
        'round_id': roundId,
        ...event.toRow(roundId),
      });
    }
    await _saveLocalDraft();
  }

  Future<void> _persistAwardRemoval(RoundBitEventDraft event) async {
    final roundId = widget.session?.roundId;
    if (roundId == null || roundId.isEmpty) {
      await _saveLocalDraft();
      return;
    }
    try {
      await HistoryRepository.deleteLatestBitEventForRound(
        roundId: roundId,
        participantKey: event.participantKey,
        playerName: event.playerName,
        hole: event.hole,
        eventLabel: event.eventLabel,
        delta: event.delta,
      );
      SyncStatusNotifier.instance.recordSuccess();
    } catch (_) {
      SyncStatusNotifier.instance.recordFailure();
      await RoundSessionStore.enqueuePendingBitEvent({
        'action': 'delete',
        'round_id': roundId,
        'participant_key': event.participantKey,
        'player_name': event.playerName,
        'hole': event.hole,
        'event_label': event.eventLabel,
        'delta': event.delta,
      });
    }
    await _saveLocalDraft();
  }

  String _headerEyebrow(int? par, int? yardage, int? coursePar) {
    if (par == null) return 'PAR —';
    final parPart = 'PAR $par';
    if (yardage != null) return '$parPart · $yardage YDS';
    if (coursePar != null) return '$parPart · COURSE $coursePar';
    return parPart;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final par = _parForHole(_hole);
    final yardage = yardageForHole(_holeYardages, _hole);
    final coursePar = courseParForHoles(_holePars, _holeOrder);
    final sorted = _sortedPlayers;
    final tiers = _bitsTiers;

    return Scaffold(
      appBar: BrandAppBar(
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Round options',
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
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: AppTheme.screenPadding.copyWith(bottom: AppTheme.space3),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _headerEyebrow(par, yardage, coursePar).toUpperCase(),
                            style: AppTheme.monoLabel(
                              context,
                              color: AppTheme.bits(context),
                            ),
                          ),
                          SizedBox(height: AppTheme.space1),
                          Text(
                            'Hole $_hole',
                            style: text.headlineMedium?.copyWith(color: scheme.onSurface),
                          ),
                        ],
                      ),
                    ),
                    if (_holeIndex > 0)
                      Text(
                        'THRU $_holeIndex',
                        style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
                SizedBox(height: AppTheme.space3),
                _HoleProgressBar(
                  holeCount: _holeOrder.length,
                  currentIndex: _holeIndex,
                ),
                SizedBox(height: AppTheme.space6),
                ...sorted.map(
                  (p) => _PlayerCard(
                    player: p,
                    fillColor: _playerFill(context, p),
                    standingLabel: _standingLabel(p, tiers),
                    isLeader: tiers.isNotEmpty && p.totalBits == tiers.first,
                    holeBits: _holeBitsFor(p),
                    totalBits: p.totalBits,
                    tracksStrokes: _tracksStrokes(p),
                    strokes: _strokesOnHole(p),
                    par: par,
                    gross: _grossFor(p),
                    holePars: _holePars,
                    holeOrder: _holeOrder,
                    playerHoles: _strokeByHole[p.id] ?? const {},
                    onStrokesChanged: (n) => _setStrokes(p, n),
                    onAward: () => _openEventSheet(p),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pageHorizontal,
                AppTheme.space2,
                AppTheme.pageHorizontal,
                AppTheme.space3,
              ),
              child: Row(
                children: [
                  Tooltip(
                    message: 'Previous hole',
                    child: OutlinedButton(
                      onPressed: _holeIndex > 0 ? _prevHole : null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(52, AppTheme.awardButtonSize),
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space3),
                    ),
                    child: const Icon(Icons.chevron_left),
                    ),
                  ),
                  SizedBox(width: AppTheme.space3),
                  Expanded(
                    child: FilledButton(
                      onPressed: _nextHole,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Next hole'),
                          SizedBox(width: AppTheme.space2),
                          Icon(Icons.arrow_forward, size: AppTheme.iconDense),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _standingLabel(_HolePlayer player, List<int> tiers) {
  if (tiers.isEmpty) return '';
  final rank = tiers.indexOf(player.totalBits);
  if (rank == 0) return '★ LEADING';
  return switch (rank) {
    1 => '2ND',
    2 => '3RD',
    _ => '${rank + 1}TH',
  };
}

class _HoleProgressBar extends StatelessWidget {
  const _HoleProgressBar({
    required this.holeCount,
    required this.currentIndex,
  });

  final int holeCount;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        for (var i = 0; i < holeCount; i++) ...[
          if (i > 0) SizedBox(width: AppTheme.space1),
          Expanded(
            flex: i == currentIndex ? 25 : 10,
            child: Container(
              height: AppTheme.space1,
              decoration: BoxDecoration(
                color: i < currentIndex
                    ? scheme.surfaceContainerHigh
                    : i == currentIndex
                        ? scheme.primary
                        : scheme.onSurface.withValues(alpha: AppTheme.opacityProgressPipUpcoming),
                borderRadius: BorderRadius.circular(AppTheme.stadiumRadius),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.player,
    required this.fillColor,
    required this.standingLabel,
    required this.isLeader,
    required this.holeBits,
    required this.totalBits,
    required this.tracksStrokes,
    required this.strokes,
    required this.par,
    required this.gross,
    required this.holePars,
    required this.holeOrder,
    required this.playerHoles,
    required this.onStrokesChanged,
    required this.onAward,
  });

  final _HolePlayer player;
  final Color fillColor;
  final String standingLabel;
  final bool isLeader;
  final int holeBits;
  final int totalBits;
  final bool tracksStrokes;
  final int strokes;
  final int? par;
  final int gross;
  final Map<String, int> holePars;
  final List<int> holeOrder;
  final Map<int, int> playerHoles;
  final ValueChanged<int> onStrokesChanged;
  final VoidCallback onAward;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final onFill = AppTheme.textOnFilledCircle(fillColor, scheme);
    final leaderBorder = isLeader
        ? AppTheme.sand(context).withValues(alpha: AppTheme.opacityLeaderRing)
        : scheme.outlineVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space3),
      child: OutlinedSurfaceCard(
        borderColor: leaderBorder,
        padding: const EdgeInsets.all(AppTheme.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _PlayerAvatar(initial: _initialFor(player.name), fill: fillColor, onFill: onFill),
                SizedBox(width: AppTheme.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.name,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (standingLabel.isNotEmpty)
                        Text(
                          standingLabel,
                          style: AppTheme.monoLabel(
                            context,
                            color: isLeader ? AppTheme.sand(context) : scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: AppTheme.space3),
            PlayerBitsRow(
              totalBits: totalBits,
              holeBits: holeBits,
              onAward: onAward,
            ),
            if (tracksStrokes) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.space3),
                child: Divider(height: 1, color: scheme.outlineVariant),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: _GrossTotalRow(gross: gross, holePars: holePars, holeOrder: holeOrder, playerHoles: playerHoles)),
                  StrokeHoleCounter(
                    strokes: strokes,
                    par: par,
                    onChanged: onStrokesChanged,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _initialFor(String name) {
    final trimmed = name.trim();
    return trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?';
  }
}

class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({
    required this.initial,
    required this.fill,
    required this.onFill,
  });

  final String initial;
  final Color fill;
  final Color onFill;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppTheme.avatarSizeMd,
      height: AppTheme.avatarSizeMd,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppTheme.avatarRadius),
      ),
      child: Text(
        initial,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: onFill,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _GrossTotalRow extends StatelessWidget {
  const _GrossTotalRow({
    required this.gross,
    required this.holePars,
    required this.holeOrder,
    required this.playerHoles,
  });

  final int gross;
  final Map<String, int> holePars;
  final List<int> holeOrder;
  final Map<int, int> playerHoles;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (gross <= 0) {
      return Row(
        children: [
          Text('TOTAL', style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant)),
          SizedBox(width: AppTheme.space2),
          Text('—', style: AppTheme.score(context, size: 16, color: scheme.onSurfaceVariant)),
        ],
      );
    }

    final formatted = formatGrossWithToPar(
      gross: gross,
      holePars: holePars,
      holeOrder: holeOrder,
      playerHoles: playerHoles,
    );
    final paren = formatted.indexOf(' (');
    if (paren >= 0 && formatted.endsWith(')')) {
      final grossNum = formatted.substring(0, paren);
      final toPar = formatted.substring(paren + 2, formatted.length - 1);
      return Row(
        children: [
          Text('TOTAL', style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant)),
          SizedBox(width: AppTheme.space2),
          Text(grossNum, style: AppTheme.score(context, size: 16)),
          SizedBox(width: AppTheme.space1),
          Text(toPar, style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant)),
        ],
      );
    }

    return Row(
      children: [
        Text('TOTAL', style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant)),
        SizedBox(width: AppTheme.space2),
        Text(formatted, style: AppTheme.score(context, size: 16)),
      ],
    );
  }
}

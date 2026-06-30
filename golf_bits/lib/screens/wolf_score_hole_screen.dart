import 'dart:async';

import 'package:flutter/material.dart';

import '../data/history_repository.dart';
import '../data/wolf_round_sync.dart';
import '../models/round_bit_event_draft.dart';
import '../models/round_game_config.dart';
import '../models/round_result.dart';
import '../models/wolf_round_state.dart';
import '../models/wolf_scoring.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_app_bar.dart';
import '../widgets/event_award_sheet.dart';
import '../widgets/hole_footer_nav.dart';
import '../widgets/hole_header.dart';
import '../widgets/outlined_surface_card.dart';
import '../widgets/player_avatar.dart';
import '../widgets/stroke_hole_counter.dart';
import '../widgets/tally_marks.dart';
import 'round_standings_screen.dart';
import 'round_summary_screen.dart';
import 'wolf_call_screen.dart';

/// Screen 04 — Score the hole (teams, strokes, bits sidecar).
class WolfScoreHoleScreen extends StatefulWidget {
  const WolfScoreHoleScreen({super.key, required this.state});

  final WolfRoundState state;

  @override
  State<WolfScoreHoleScreen> createState() => _WolfScoreHoleScreenState();
}

class _WolfScoreHoleScreenState extends State<WolfScoreHoleScreen> {
  late WolfRoundState _state;
  late Map<String, int> _grossByPlayer;
  late final Map<String, Map<int, int>> _strokeByHole;

  @override
  void initState() {
    super.initState();
    _state = widget.state;
    _strokeByHole = _state.strokeByHole.map((k, v) => MapEntry(k, Map<int, int>.from(v)));
    _grossByPlayer = {for (final k in _state.teeOrder) k: _defaultGross(k)};
    _seedDefaults();
    unawaited(_hydrateBits());
  }

  Future<void> _hydrateBits() async {
    if (!_state.session.hasBits || _state.session.roundId == null) return;
    final hydrated = await WolfRoundSync.hydrateBitEvents(_state);
    if (!mounted || identical(hydrated, _state)) return;
    setState(() => _state = hydrated);
  }

  int _defaultGross(String key) {
    final existing = _strokeByHole[key]?[_hole];
    if (existing != null && existing > 0) return existing;
    final par = _state.session.holePars['$_hole'];
    return par ?? 4;
  }

  int get _hole => _state.hole;
  WolfCall get _call => _state.pendingCall ?? const WolfCall(type: WolfCallType.lone);

  void _seedDefaults() {
    for (final key in _state.teeOrder) {
      _strokeByHole.putIfAbsent(key, () => {});
      _strokeByHole[key]![_hole] = _grossByPlayer[key] ?? 4;
    }
  }

  WolfHoleSettlement get _settlement {
    return settleWolfHole(
      teeOrder: _state.teeOrder,
      wolfKey: _state.wolfKey,
      call: _call,
      grossByPlayer: _grossByPlayer,
      basis: _state.basis,
      handicaps: _state.gameConfig.handicaps,
      strokeIndex: _state.strokeIndexForHole(_hole),
    );
  }

  int _holeBitsFor(String key) => _state.holeBits[key]?[_hole] ?? 0;

  int _totalBitsFor(String key) => _state.bitsByPlayer[key] ?? 0;

  void _setGross(String key, int strokes) {
    setState(() {
      _grossByPlayer[key] = strokes;
      _strokeByHole.putIfAbsent(key, () => {});
      _strokeByHole[key]![_hole] = strokes;
    });
    unawaited(_persistDraft());
  }

  Future<void> _persistDraft() async {
    final next = _state.copyWith(strokeByHole: _strokeByHole);
    await WolfRoundSync.persist(next);
  }

  Future<void> _openBitsSheet(String playerKey) async {
    final p = _state.session.participants.firstWhere((x) => x.key == playerKey);
    final rules = _state.gameConfig.eventRules.isNotEmpty
        ? _state.gameConfig.eventRules
        : _state.session.eventRules;
    String eventKey(String label, int delta) => '$label::$delta';
    final selectedForPlayerHole = _state.bitLog
        .where(
          (e) =>
              (e['participant_key'] as String? ?? '') == playerKey &&
              (e['hole'] as num?)?.toInt() == _hole,
        )
        .map(
          (e) => eventKey(
            e['event_label'] as String? ?? '',
            (e['delta'] as num?)?.toInt() ?? 0,
          ),
        )
        .toSet();

    await showEventAwardSheet(
      context: context,
      sheet: EventAwardSheet(
        playerName: p.displayName,
        hole: _hole,
        par: _state.session.holePars['$_hole'],
        rules: rules,
        initialSelectedKeys: selectedForPlayerHole,
        runsAlongsideWolf: _state.session.hasBits && _state.session.hasWolf,
        subtitle: 'HOLE $_hole · SIDE GAME',
        onAward: (label, delta, iconKey) async {
          var removed = false;
          setState(() {
            final log = List<Map<String, dynamic>>.from(_state.bitLog);
            final existingIdx = log.lastIndexWhere(
              (e) =>
                  (e['participant_key'] as String? ?? '') == playerKey &&
                  (e['hole'] as num?)?.toInt() == _hole &&
                  (e['event_label'] as String? ?? '') == label &&
                  (e['delta'] as num?)?.toInt() == delta,
            );
            if (existingIdx >= 0) {
              removed = true;
              log.removeAt(existingIdx);
            } else {
              log.add({
                'participant_key': playerKey,
                'player_name': p.displayName,
                'hole': _hole,
                'event_label': label,
                'delta': delta,
                'icon_key': iconKey,
              });
            }
            final holeBits = _state.holeBits.map(
              (k, v) => MapEntry(k, Map<int, int>.from(v)),
            );
            final holeMap = holeBits.putIfAbsent(playerKey, () => {});
            holeMap[_hole] = (holeMap[_hole] ?? 0) + (removed ? -delta : delta);
            final bitsByPlayer = Map<String, int>.from(_state.bitsByPlayer);
            bitsByPlayer[playerKey] = (bitsByPlayer[playerKey] ?? 0) + (removed ? -delta : delta);
            _state = _state.copyWith(
              bitLog: log,
              holeBits: holeBits,
              bitsByPlayer: bitsByPlayer,
            );
          });
          final roundId = _state.session.roundId;
          if (roundId != null && roundId.isNotEmpty) {
            if (removed) {
              await WolfRoundSync.deleteBitEvent(
                roundId: roundId,
                participantKey: playerKey,
                hole: _hole,
                eventLabel: label,
                delta: delta,
              );
            } else {
              await WolfRoundSync.saveBitEvent(
                roundId: roundId,
                draft: RoundBitEventDraft(
                  participantKey: playerKey,
                  playerName: p.displayName,
                  hole: _hole,
                  eventLabel: label,
                  delta: delta,
                  iconKey: iconKey,
                ),
              );
            }
          }
          await _persistDraft();
        },
      ),
    );
  }

  Future<void> _nextHole() async {
    final settlement = _settlement;
    final result = WolfHoleResult(
      hole: _hole,
      wolfKey: _state.wolfKey,
      call: _call,
      grossByPlayer: Map<String, int>.from(_grossByPlayer),
      pointsByPlayer: settlement.pointsByPlayer,
      wolfBestBall: settlement.wolfBestBall,
      fieldBestBall: settlement.fieldBestBall,
      winner: settlement.winner,
    );

    final results = Map<int, WolfHoleResult>.from(_state.wolfHoleResults);
    results[_hole] = result;

    final wolfTotals = WolfRoundSync.computeWolfTotals(results);

    if (_state.holeIndex >= _state.holeOrder.length - 1) {
      await _finishRound(results, wolfTotals);
      return;
    }

    final next = _state.copyWith(
      holeIndex: _state.holeIndex + 1,
      wolfHoleResults: results,
      wolfPointsByPlayer: wolfTotals,
      strokeByHole: _strokeByHole,
      bitsByPlayer: _state.bitsByPlayer,
      currentPhase: WolfInRoundPhase.call,
      clearPendingCall: true,
      opponentsTeedCount: 0,
    );
    await WolfRoundSync.persist(next);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => WolfCallScreen(state: next)),
    );
  }

  Future<void> _finishRound(
    Map<int, WolfHoleResult> results,
    Map<String, int> wolfTotals,
  ) async {
    final session = _state.session;
    final participants = session.participants;

    String? wolfWinnerName;
    var topWolf = -999999;
    for (final p in participants) {
      final pts = wolfTotals[p.key] ?? 0;
      if (pts > topWolf) {
        topWolf = pts;
        wolfWinnerName = p.displayName;
      }
    }

    await HistoryRepository.syncHandicapsToProfiles(
      participants: participants,
      handicaps: _state.gameConfig.handicaps,
    );

    if (session.roundId != null && session.roundId!.isNotEmpty) {
      await WolfRoundSync.persist(
        _state.copyWith(
          wolfHoleResults: results,
          wolfPointsByPlayer: wolfTotals,
          strokeByHole: _strokeByHole,
        ),
      );
    }

    if (!mounted) return;

    final scoredPlayers = [
      for (final p in participants)
        (key: p.key, name: p.displayName, bits: _state.bitsByPlayer[p.key] ?? 0),
    ];

    final bitEvents = [
      for (final row in _state.bitLog)
        RoundBitEventDraft(
          participantKey: row['participant_key'] as String? ?? '',
          playerName: row['player_name'] as String? ?? '',
          hole: (row['hole'] as num?)?.toInt() ?? 0,
          eventLabel: row['event_label'] as String? ?? '',
          delta: (row['delta'] as num?)?.toInt() ?? 0,
          iconKey: row['icon_key'] as String?,
        ),
    ];

    final result = RoundResult.fromSessionScores(
      session: session,
      scoredPlayers: scoredPlayers,
      strokeByHole: _strokeByHole,
      grossByPlayer: WolfRoundSync.computeGrossByPlayer(_strokeByHole),
      bitEvents: bitEvents,
      wolfPointsByPlayer: wolfTotals,
      wolfHoleResults: results,
      wolfWinnerName: wolfWinnerName,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => RoundSummaryScreen(result: result),
      ),
    );
  }

  void _backToCall() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => WolfCallScreen(
          state: _state.copyWith(currentPhase: WolfInRoundPhase.call),
        ),
      ),
    );
  }

  void _openStandings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => RoundStandingsScreen(state: _state)),
    );
  }

  String _nameFor(String key) {
    try {
      return _state.session.participants.firstWhere((p) => p.key == key).displayName;
    } catch (_) {
      return key;
    }
  }

  int _colorIndex(String key) {
    final idx = _state.teeOrder.indexOf(key);
    return idx >= 0 ? idx : 0;
  }

  int? _netLabel(String key) {
    final gross = _grossByPlayer[key];
    if (gross == null) return null;
    if (_state.basis == WolfScoringBasis.gross) return gross;
    final received = strokesReceivedOnHole(
      courseHandicap: _state.gameConfig.handicaps[key] ?? 0,
      strokeIndex: _state.strokeIndexForHole(_hole),
    );
    return netStrokes(gross: gross, strokesReceived: received);
  }

  String _netCaption(String key) {
    final net = _netLabel(key);
    if (net == null) return '';
    if (_state.basis == WolfScoringBasis.gross) return 'GROSS $net';
    final received = strokesReceivedOnHole(
      courseHandicap: _state.gameConfig.handicaps[key] ?? 0,
      strokeIndex: _state.strokeIndexForHole(_hole),
    );
    return 'NET $net · ${received > 0 ? '$received STROKE' : 'NO STROKE'}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settlement = _settlement;
    final wolfSide = wolfTeamKeys(wolfKey: _state.wolfKey, call: _call);
    final fieldSide = fieldTeamKeys(
      teeOrder: _state.teeOrder,
      wolfKey: _state.wolfKey,
      call: _call,
    );

    final wolfWins = settlement.winner == WolfHoleWinner.wolfSide;
    final fieldWins = settlement.winner == WolfHoleWinner.fieldSide;

    return Scaffold(
      appBar: BrandAppBar(
        actions: [
          IconButton(
            tooltip: 'Standings',
            icon: const Icon(Icons.leaderboard_outlined),
            onPressed: _openStandings,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: AppTheme.screenPadding,
              children: [
                HoleHeader(
                  hole: _hole,
                  par: _state.session.holePars['$_hole'],
                  titleOverride: 'Score the hole',
                  strokeIndex: _state.strokeIndexForHole(_hole),
                ),
                SizedBox(height: AppTheme.space3),
                Text(
                  'TEAMS · STROKES & BITS',
                  style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant),
                ),
                SizedBox(height: AppTheme.space2),
                _TeamCard(
                  label: 'WOLF',
                  teamName: wolfSide.map(_nameFor).join(' + '),
                  bestBall: settlement.wolfBestBall,
                  wins: wolfWins,
                  points: wolfWins ? _call.multiplier : null,
                  accent: scheme.secondary,
                  children: [
                    for (final key in wolfSide) _buildPlayerRow(context, key),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.space2),
                  child: Text(
                    'VS',
                    textAlign: TextAlign.center,
                    style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant),
                  ),
                ),
                _TeamCard(
                  label: 'FIELD',
                  teamName: fieldSide.map(_nameFor).join(' + '),
                  bestBall: settlement.fieldBestBall,
                  wins: fieldWins,
                  points: fieldWins ? _call.multiplier : null,
                  accent: scheme.onSurfaceVariant,
                  children: [
                    for (final key in fieldSide) _buildPlayerRow(context, key),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppTheme.pageHorizontal,
              AppTheme.space2,
              AppTheme.pageHorizontal,
              MediaQuery.paddingOf(context).bottom + AppTheme.space4,
            ),
            child: HoleFooterNav(
              onPrevious: _backToCall,
              onNext: _nextHole,
              previousEnabled: true,
              leading: _state.session.hasWolf
                  ? Padding(
                      padding: const EdgeInsets.only(right: AppTheme.space1),
                      child: Text(
                        '\$${_state.gameConfig.wolfPointValue.toStringAsFixed(0)} / PT',
                        style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant),
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerRow(BuildContext context, String key) {
    final scheme = Theme.of(context).colorScheme;
    final holeBits = _holeBitsFor(key);
    final totalBits = _totalBitsFor(key);
    final gross = _grossByPlayer[key] ?? 4;

    return Column(
      children: [
        Row(
          children: [
            PlayerAvatar(displayName: _nameFor(key), colorIndex: _colorIndex(key), size: 30),
            SizedBox(width: AppTheme.space2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_nameFor(key), style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    _netCaption(key),
                    style: AppTheme.monoLabel(context, color: AppTheme.bits(context)).copyWith(fontSize: 9),
                  ),
                ],
              ),
            ),
            StrokeHoleCounter(
              strokes: gross,
              par: _state.session.holePars['$_hole'],
              onChanged: (v) => _setGross(key, v),
            ),
          ],
        ),
        if (_state.session.hasBits) ...[
          SizedBox(height: AppTheme.space2),
          Row(
            children: [
              Text('BITS', style: AppTheme.monoLabel(context, color: scheme.onSurfaceVariant)),
              SizedBox(width: AppTheme.space1),
              if (holeBits != 0)
                TallyMarks(
                  count: holeBits,
                  height: 18,
                  variant: holeBits < 0 ? TallyVariant.penalty : TallyVariant.positive,
                )
              else
                Text('—', style: AppTheme.score(context, size: 14, color: scheme.onSurfaceVariant)),
              SizedBox(width: AppTheme.space2),
              Text(
                totalBits >= 0 ? '+$totalBits' : '$totalBits',
                style: AppTheme.score(
                  context,
                  size: 14,
                  color: totalBits >= 0 ? AppTheme.bits(context) : AppTheme.junk(context),
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _openBitsSheet(key),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('bits'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: scheme.outlineVariant),
                ),
              ),
            ],
          ),
        ],
        if (key != _state.teeOrder.last) Divider(color: scheme.outlineVariant, height: AppTheme.space4),
      ],
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({
    required this.label,
    required this.teamName,
    required this.bestBall,
    required this.wins,
    required this.accent,
    required this.children,
    this.points,
  });

  final String label;
  final String teamName;
  final int? bestBall;
  final bool wins;
  final int? points;
  final Color accent;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedSurfaceCard(
      borderColor: wins ? scheme.primary.withValues(alpha: 0.5) : scheme.outlineVariant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: label == 'WOLF' ? 1 : 0.3),
                  borderRadius: BorderRadius.circular(AppTheme.stadiumRadius),
                ),
                child: Text(
                  label,
                  style: AppTheme.monoLabel(
                    context,
                    color: label == 'WOLF' ? scheme.onSecondary : scheme.onSurfaceVariant,
                  ).copyWith(fontSize: 8),
                ),
              ),
              SizedBox(width: AppTheme.space2),
              Expanded(
                child: Text(teamName, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              if (wins && points != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.18),
                    border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(AppTheme.stadiumRadius),
                  ),
                  child: Text(
                    'WINS · +$points',
                    style: AppTheme.monoLabel(context, color: AppTheme.bits(context)).copyWith(fontSize: 8),
                  ),
                ),
              SizedBox(width: AppTheme.space2),
              Text('BEST', style: AppTheme.monoLabel(context).copyWith(fontSize: 8)),
              SizedBox(width: AppTheme.space1),
              Text(
                bestBall?.toString() ?? '—',
                style: AppTheme.score(context, size: 22, color: wins ? AppTheme.bits(context) : scheme.onSurfaceVariant),
              ),
            ],
          ),
          SizedBox(height: AppTheme.space3),
          ...children,
        ],
      ),
    );
  }
}

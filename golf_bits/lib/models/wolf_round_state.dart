import 'package:flutter/foundation.dart';

import 'round_game_config.dart';
import 'round_session_args.dart';
import 'wolf_scoring.dart';
import 'wolf_scoring.dart' as wolf_engine show resolveWolfPlayerId, isTrailingPlayerWolfHole;

/// In-round Wolf + optional Bits state carried across call/score screens.
@immutable
class WolfRoundState {
  const WolfRoundState({
    required this.session,
    required this.gameConfig,
    required this.holeOrder,
    required this.holeStrokeIndexes,
    this.holeIndex = 0,
    this.wolfPointsByPlayer = const {},
    this.wolfHoleResults = const {},
    this.bitsByPlayer = const {},
    this.holeBits = const {},
    this.strokeByHole = const {},
    this.bitLog = const [],
    this.pendingCall,
    this.opponentsTeedCount = 0,
    this.currentPhase = WolfInRoundPhase.call,
  });

  final RoundSessionArgs session;
  final RoundGameConfig gameConfig;
  final List<int> holeOrder;
  final Map<String, int> holeStrokeIndexes;
  final int holeIndex;
  final Map<String, int> wolfPointsByPlayer;
  final Map<int, WolfHoleResult> wolfHoleResults;
  final Map<String, int> bitsByPlayer;
  final Map<String, Map<int, int>> holeBits;
  final Map<String, Map<int, int>> strokeByHole;
  final List<Map<String, dynamic>> bitLog;
  final WolfCall? pendingCall;
  final int opponentsTeedCount;
  final WolfInRoundPhase currentPhase;

  int get hole => holeOrder[holeIndex];
  int get holeCount => holeOrder.length;
  List<String> get teeOrder => gameConfig.teeOrder;
  WolfScoringBasis get basis => gameConfig.scoringBasis;

  String get wolfKey => wolf_engine.resolveWolfPlayerId(
        holeIndex: holeIndex,
        holeCount: holeCount,
        teeOrder: teeOrder,
        wolfPointsBeforeHole: wolfPointsBeforeCurrentHole,
      );

  Map<String, int> get wolfPointsBeforeCurrentHole {
    final totals = {for (final k in teeOrder) k: 0};
    for (final entry in wolfHoleResults.entries) {
      final holeNum = entry.key;
      final idx = holeOrder.indexOf(holeNum);
      if (idx < 0 || idx >= holeIndex) continue;
      for (final p in entry.value.pointsByPlayer.entries) {
        totals[p.key] = (totals[p.key] ?? 0) + p.value;
      }
    }
    return totals;
  }

  bool get usesTrailingPlayerWolfRule => wolf_engine.isTrailingPlayerWolfHole(
        holeIndex: holeIndex,
        holeCount: holeCount,
      );

  /// Stroke index for net scoring (1–18 rank). Never uses hole number as SI.
  int? strokeIndexForHole(int hole) => resolveStrokeIndexForHole(hole, holeStrokeIndexes);

  WolfRoundState copyWith({
    int? holeIndex,
    Map<String, int>? wolfPointsByPlayer,
    Map<int, WolfHoleResult>? wolfHoleResults,
    Map<String, int>? bitsByPlayer,
    Map<String, Map<int, int>>? holeBits,
    Map<String, Map<int, int>>? strokeByHole,
    List<Map<String, dynamic>>? bitLog,
    WolfCall? pendingCall,
    int? opponentsTeedCount,
    WolfInRoundPhase? currentPhase,
    bool clearPendingCall = false,
  }) {
    return WolfRoundState(
      session: session,
      gameConfig: gameConfig,
      holeOrder: holeOrder,
      holeStrokeIndexes: holeStrokeIndexes,
      holeIndex: holeIndex ?? this.holeIndex,
      wolfPointsByPlayer: wolfPointsByPlayer ?? this.wolfPointsByPlayer,
      wolfHoleResults: wolfHoleResults ?? this.wolfHoleResults,
      bitsByPlayer: bitsByPlayer ?? this.bitsByPlayer,
      holeBits: holeBits ?? this.holeBits,
      strokeByHole: strokeByHole ?? this.strokeByHole,
      bitLog: bitLog ?? this.bitLog,
      pendingCall: clearPendingCall ? null : (pendingCall ?? this.pendingCall),
      opponentsTeedCount: opponentsTeedCount ?? this.opponentsTeedCount,
      currentPhase: currentPhase ?? this.currentPhase,
    );
  }

  static WolfRoundState fromSession(RoundSessionArgs session) {
    final holeOrder = buildHoleOrder(
      holeCount: session.holeCount,
      startHole: session.startHole,
    );
    return WolfRoundState(
      session: session,
      gameConfig: session.gameConfig,
      holeOrder: holeOrder,
      holeStrokeIndexes: session.holeStrokeIndexes,
      holeIndex: holeOrder.indexOf(session.currentHole).clamp(0, holeOrder.length - 1),
      wolfPointsByPlayer: Map<String, int>.from(session.initialWolfPointsByPlayer),
      wolfHoleResults: Map<int, WolfHoleResult>.from(session.initialWolfHoleResults),
      bitsByPlayer: Map<String, int>.from(session.initialScoreByPlayer),
      strokeByHole: session.initialStrokeByHole.map(
        (k, v) => MapEntry(k, Map<int, int>.from(v)),
      ),
      currentPhase: session.wolfHolePhase == WolfInRoundPhase.score
          ? WolfInRoundPhase.score
          : WolfInRoundPhase.call,
      pendingCall: session.pendingWolfCall,
      opponentsTeedCount: session.opponentsTeedCount,
    );
  }
}

enum WolfInRoundPhase {
  call,
  score;

  static WolfInRoundPhase fromDb(String? raw) {
    return raw?.trim().toLowerCase() == 'score' ? WolfInRoundPhase.score : WolfInRoundPhase.call;
  }

  String toDb() => name;
}

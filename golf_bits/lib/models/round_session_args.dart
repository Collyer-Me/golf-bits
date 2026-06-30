import 'package:flutter/foundation.dart';

import 'history_round.dart';
import 'round_game_config.dart';
import 'stroke_tracking.dart';
import 'wolf_round_state.dart';
import 'wolf_scoring.dart';

@immutable
class RoundEventRule {
  const RoundEventRule({
    required this.label,
    required this.delta,
    required this.iconKey,
  });

  final String label;
  final int delta;
  final String iconKey;
}

@immutable
class RoundParticipant {
  const RoundParticipant({
    required this.key,
    required this.displayName,
    this.email,
    this.userId,
    this.isYou = false,
    this.handicap,
  });

  final String key;
  final String displayName;
  final String? email;
  final String? userId;
  final bool isYou;
  final int? handicap;

  Map<String, dynamic> toJson() => {
        'key': key,
        'display_name': displayName,
        'email': email,
        'user_id': userId,
        'is_you': isYou,
        if (handicap != null) 'handicap': handicap,
      };

  factory RoundParticipant.fromJson(Map<String, dynamic> m) {
    return RoundParticipant(
      key: (m['key'] as String?) ?? '',
      displayName: (m['display_name'] as String?) ?? '',
      email: m['email'] as String?,
      userId: m['user_id'] as String?,
      isYou: m['is_you'] as bool? ?? false,
      handicap: (m['handicap'] as num?)?.toInt(),
    );
  }
}

/// Carries course + players from [RoundSetupScreen] into scoring screens.
@immutable
class RoundSessionArgs {
  const RoundSessionArgs({
    required this.courseName,
    required this.courseShortTitle,
    required this.holeCount,
    required this.startHole,
    required this.playerNames,
    this.roundId,
    this.currentHole = 1,
    this.initialScoreByPlayer = const {},
    this.eventRules = const [],
    this.participants = const [],
    this.strokeTrackingMode = StrokeTrackingMode.off,
    this.holePars = const {},
    this.holeYardages = const {},
    this.holeStrokeIndexes = const {},
    this.initialStrokeByHole = const {},
    this.initialGrossByPlayer = const {},
    this.gameConfig = const RoundGameConfig(),
    this.initialWolfPointsByPlayer = const {},
    this.initialWolfHoleResults = const {},
    this.wolfHolePhase = WolfInRoundPhase.call,
    this.pendingWolfCall,
    this.opponentsTeedCount = 0,
  });

  final String courseName;
  final String courseShortTitle;
  final int holeCount;
  final int startHole;
  final List<String> playerNames;
  final String? roundId;
  final int currentHole;
  final Map<String, int> initialScoreByPlayer;
  final List<RoundEventRule> eventRules;
  final List<RoundParticipant> participants;
  final StrokeTrackingMode strokeTrackingMode;
  final Map<String, int> holePars;
  final Map<String, int> holeYardages;
  final Map<String, int> holeStrokeIndexes;
  final Map<String, Map<int, int>> initialStrokeByHole;
  final Map<String, int> initialGrossByPlayer;
  final RoundGameConfig gameConfig;
  final Map<String, int> initialWolfPointsByPlayer;
  final Map<int, WolfHoleResult> initialWolfHoleResults;
  final WolfInRoundPhase wolfHolePhase;
  final WolfCall? pendingWolfCall;
  final int opponentsTeedCount;

  bool get hasWolf => gameConfig.hasWolf;
  bool get hasBits => gameConfig.hasBits;

  /// Resume UI from a saved in-progress row.
  factory RoundSessionArgs.fromHistoryRound(HistoryRound round) {
    final gameConfig = round.gameConfig;
    final startHole = round.startHole;
    return RoundSessionArgs(
      courseName: round.courseName,
      courseShortTitle: round.courseShortTitle,
      holeCount: round.holeCount,
      startHole: startHole,
      playerNames: round.players,
      roundId: round.id,
      currentHole: round.currentHole ?? startHole,
      initialScoreByPlayer: round.scoreByPlayer,
      eventRules: gameConfig.eventRules,
      participants: round.participants,
      strokeTrackingMode: round.strokeTrackingMode,
      holePars: round.holePars,
      holeYardages: round.holeYardages,
      holeStrokeIndexes: round.holeStrokeIndexes,
      initialStrokeByHole: round.strokeByHole,
      initialGrossByPlayer: round.grossByPlayer,
      gameConfig: gameConfig,
      initialWolfPointsByPlayer: round.wolfPointsByPlayer,
      initialWolfHoleResults: round.wolfHoleResults,
      wolfHolePhase: round.wolfHolePhase,
      pendingWolfCall: round.pendingWolfCall,
      opponentsTeedCount: round.opponentsTeedCount,
    );
  }
}

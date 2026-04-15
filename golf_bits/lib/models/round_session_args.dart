import 'package:flutter/foundation.dart';

import 'history_round.dart';

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

/// Carries course + players from [RoundSetupScreen] into [HoleScoringScreen].
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

  /// Resume UI from a saved in-progress row (start hole defaults to 1).
  factory RoundSessionArgs.fromHistoryRound(HistoryRound round) {
    return RoundSessionArgs(
      courseName: round.courseName,
      courseShortTitle: round.courseShortTitle,
      holeCount: round.holeCount,
      startHole: 1,
      playerNames: round.players,
      roundId: round.id,
      currentHole: round.currentHole ?? 1,
      initialScoreByPlayer: round.scoreByPlayer,
      eventRules: const [],
    );
  }
}

import 'package:flutter/foundation.dart';

import 'history_round.dart';

/// Carries course + players from [RoundSetupScreen] into [HoleScoringScreen].
@immutable
class RoundSessionArgs {
  const RoundSessionArgs({
    required this.courseName,
    required this.courseShortTitle,
    required this.holeCount,
    required this.startHole,
    required this.playerNames,
  });

  final String courseName;
  final String courseShortTitle;
  final int holeCount;
  final int startHole;
  final List<String> playerNames;

  /// Resume UI from a saved in-progress row (start hole defaults to 1).
  factory RoundSessionArgs.fromHistoryRound(HistoryRound round) {
    return RoundSessionArgs(
      courseName: round.courseName,
      courseShortTitle: round.courseShortTitle,
      holeCount: round.holeCount,
      startHole: 1,
      playerNames: round.players,
    );
  }
}

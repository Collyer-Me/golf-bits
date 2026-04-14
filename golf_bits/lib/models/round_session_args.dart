import 'package:flutter/foundation.dart';

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
}

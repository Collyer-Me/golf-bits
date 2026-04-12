import 'package:flutter/foundation.dart';

/// Carries course + players from [RoundSetupScreen] into [HoleScoringScreen].
@immutable
class RoundSessionArgs {
  const RoundSessionArgs({
    required this.courseName,
    required this.courseShortTitle,
    required this.holeCount,
    required this.playerNames,
  });

  final String courseName;
  final String courseShortTitle;
  final int holeCount;
  final List<String> playerNames;
}

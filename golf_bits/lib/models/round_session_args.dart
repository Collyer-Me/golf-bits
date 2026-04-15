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

@immutable
class RoundParticipant {
  const RoundParticipant({
    required this.key,
    required this.displayName,
    this.email,
    this.userId,
    this.isYou = false,
  });

  final String key;
  final String displayName;
  final String? email;
  final String? userId;
  final bool isYou;

  Map<String, dynamic> toJson() => {
        'key': key,
        'display_name': displayName,
        'email': email,
        'user_id': userId,
        'is_you': isYou,
      };

  factory RoundParticipant.fromJson(Map<String, dynamic> m) {
    return RoundParticipant(
      key: (m['key'] as String?) ?? '',
      displayName: (m['display_name'] as String?) ?? '',
      email: m['email'] as String?,
      userId: m['user_id'] as String?,
      isYou: m['is_you'] as bool? ?? false,
    );
  }
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
    this.participants = const [],
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
      participants: round.participants,
    );
  }
}

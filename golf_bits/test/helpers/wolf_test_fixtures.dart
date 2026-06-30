import 'package:golf_bits/models/round_game_config.dart';
import 'package:golf_bits/models/round_session_args.dart';
import 'package:golf_bits/models/wolf_round_state.dart';
import 'package:golf_bits/models/wolf_scoring.dart';

/// Shared Wolf in-round state for widget tests.
WolfRoundState testWolfRoundState({
  List<RoundFormat> formats = const [RoundFormat.wolf],
  Map<int, WolfHoleResult> wolfHoleResults = const {},
  Map<String, int> bitsByPlayer = const {},
}) {
  const teeOrder = ['you', 'sam', 'alex', 'jordan'];
  final participants = const [
    RoundParticipant(key: 'you', displayName: 'You', isYou: true, handicap: 10),
    RoundParticipant(key: 'sam', displayName: 'Sam', handicap: 12),
    RoundParticipant(key: 'alex', displayName: 'Alex', handicap: 8),
    RoundParticipant(key: 'jordan', displayName: 'Jordan', handicap: 14),
  ];
  final gameConfig = RoundGameConfig(
    formats: formats,
    teeOrder: teeOrder,
    handicaps: const {'you': 10, 'sam': 12, 'alex': 8, 'jordan': 14},
  );
  final session = RoundSessionArgs(
    courseName: 'Royal Melbourne Golf Club',
    courseShortTitle: 'Royal Melbourne',
    holeCount: 18,
    startHole: 1,
    playerNames: participants.map((p) => p.displayName).toList(),
    participants: participants,
    gameConfig: gameConfig,
    holePars: {for (var i = 1; i <= 18; i++) '$i': 4},
    holeYardages: {for (var i = 1; i <= 18; i++) '$i': 400},
    holeStrokeIndexes: {for (var i = 1; i <= 18; i++) '$i': i},
  );
  return WolfRoundState.fromSession(session).copyWith(
    wolfHoleResults: wolfHoleResults,
    bitsByPlayer: bitsByPlayer.isEmpty
        ? {for (final p in participants) p.key: 0}
        : bitsByPlayer,
  );
}

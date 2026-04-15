import 'package:flutter/foundation.dart';

import 'history_round.dart';
import 'round_bit_event_draft.dart';
import 'round_session_args.dart';

/// Final round payload for [RoundSummaryScreen] and Supabase `rounds` insert.
@immutable
class RoundResult {
  const RoundResult({
    required this.courseName,
    required this.courseShortTitle,
    required this.holeCount,
    required this.players,
    required this.winnerName,
    required this.winnerBits,
    required this.completed,
    required this.standings,
    required this.leftEarly,
    this.bitEvents = const [],
    this.roundId,
    this.scoreByPlayer = const {},
  });

  final String courseName;
  final String courseShortTitle;
  final int holeCount;
  final List<String> players;
  final String winnerName;
  final int winnerBits;
  final bool completed;
  final List<HistoryStanding> standings;
  final List<HistoryLeftEarly> leftEarly;
  final List<RoundBitEventDraft> bitEvents;
  final String? roundId;
  final Map<String, int> scoreByPlayer;

  /// Builds standings from per-player bit totals at end of round.
  factory RoundResult.fromSessionScores({
    required RoundSessionArgs session,
    required List<({String name, int bits})> scoredPlayers,
    List<RoundBitEventDraft> bitEvents = const [],
  }) {
    if (scoredPlayers.isEmpty) {
      throw ArgumentError('scoredPlayers must not be empty');
    }
    final sorted = [...scoredPlayers]..sort((a, b) => b.bits.compareTo(a.bits));
    final topBits = sorted.first.bits;
    final standings = <HistoryStanding>[];
    for (var i = 0; i < sorted.length; i++) {
      final r = sorted[i];
      final gap = topBits - r.bits;
      final subtitle = i == 0
          ? (sorted.length > 1 ? 'Winner' : 'Leader')
          : (gap == 0 ? 'Tied leader' : '−$gap vs leader');
      standings.add(
        HistoryStanding(
          rank: i + 1,
          name: r.name,
          bits: r.bits,
          subtitle: subtitle,
          isWinnerRow: i == 0,
        ),
      );
    }
    return RoundResult(
      courseName: session.courseName,
      courseShortTitle: session.courseShortTitle,
      holeCount: session.holeCount,
      players: session.playerNames,
      winnerName: sorted.first.name,
      winnerBits: sorted.first.bits,
      completed: true,
      standings: standings,
      leftEarly: const [],
      bitEvents: bitEvents,
      roundId: session.roundId,
      scoreByPlayer: {for (final r in scoredPlayers) r.name: r.bits},
    );
  }

  Map<String, dynamic> toInsertRow() {
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      'course_name': courseName,
      'course_short_title': courseShortTitle,
      'hole_count': holeCount,
      'completed': completed,
      'completed_at': completed ? now : null,
      'ended_at': now,
      'winner_name': winnerName,
      'winner_bits': winnerBits,
      'players': players,
      'standings': standings.map((s) => s.toJson()).toList(),
      'left_early': leftEarly.map((e) => e.toJson()).toList(),
      'current_hole': holeCount,
      'score_by_player': scoreByPlayer,
    };
  }

  /// Matches the former hard-coded [RoundSummaryScreen] preview (not inserted).
  static RoundResult previewDemo() {
    return RoundResult(
      courseName: 'Royal Melbourne Golf Club',
      courseShortTitle: 'Royal Melbourne',
      holeCount: 18,
      players: const ['Alex', 'Jamie', 'Chris'],
      winnerName: 'Alex',
      winnerBits: 7,
      completed: true,
      standings: const [
        HistoryStanding(rank: 1, name: 'Alex', bits: 7, subtitle: 'Winner', isWinnerRow: true),
        HistoryStanding(rank: 2, name: 'Jamie', bits: 2, subtitle: '−5 vs leader'),
        HistoryStanding(rank: 3, name: 'Chris', bits: 0, subtitle: '−7 vs leader'),
      ],
      leftEarly: const [
        HistoryLeftEarly(name: 'Taylor', leftHole: 6, bitsLabel: '-2 bits'),
      ],
      bitEvents: const [],
    );
  }
}

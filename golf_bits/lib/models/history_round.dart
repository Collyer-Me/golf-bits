import 'package:flutter/foundation.dart';

/// One row on the history detail standings table.
@immutable
class HistoryStanding {
  const HistoryStanding({
    required this.rank,
    required this.name,
    required this.bits,
    required this.subtitle,
    this.isWinnerRow = false,
  });

  final int rank;
  final String name;
  final int bits;
  /// e.g. "Winner", "−5 vs leader"
  final String subtitle;
  final bool isWinnerRow;
}

/// Player who left before the round finished (detail screen).
@immutable
class HistoryLeftEarly {
  const HistoryLeftEarly({
    required this.name,
    required this.leftHole,
    required this.bitsLabel,
  });

  final String name;
  final int leftHole;
  final String bitsLabel;
}

/// Summary of a past round for list + detail navigation.
@immutable
class HistoryRound {
  const HistoryRound({
    required this.id,
    required this.courseName,
    required this.courseShortTitle,
    required this.holeCount,
    required this.whenRelative,
    required this.dateHeader,
    required this.players,
    required this.winnerName,
    required this.winnerBits,
    required this.completed,
    required this.standings,
    required this.leftEarly,
  });

  final String id;
  final String courseName;
  /// Shorter title for detail app bar (e.g. "Royal Melbourne").
  final String courseShortTitle;
  final int holeCount;
  /// e.g. "Today", "3 days ago"
  final String whenRelative;
  /// e.g. "Oct 24, 2026"
  final String dateHeader;
  final List<String> players;
  final String winnerName;
  final int winnerBits;
  final bool completed;
  final List<HistoryStanding> standings;
  final List<HistoryLeftEarly> leftEarly;

  String get holesLine => '$holeCount holes · $whenRelative';

  /// Demo rounds for History list / detail (replace with Supabase later).
  static const List<HistoryRound> demoRounds = [
    HistoryRound(
      id: 'r1',
      courseName: 'Royal Melbourne Golf Club',
      courseShortTitle: 'Royal Melbourne',
      holeCount: 18,
      whenRelative: 'Today',
      dateHeader: 'Oct 24, 2026',
      players: ['Alex', 'Jamie', 'Chris', 'Sam'],
      winnerName: 'Alex',
      winnerBits: 7,
      completed: true,
      standings: [
        HistoryStanding(rank: 1, name: 'Alex', bits: 7, subtitle: 'Winner', isWinnerRow: true),
        HistoryStanding(rank: 2, name: 'Jamie', bits: 2, subtitle: '−5 vs leader'),
        HistoryStanding(rank: 3, name: 'Chris', bits: 0, subtitle: '−7 vs leader'),
      ],
      leftEarly: [
        HistoryLeftEarly(name: 'Sam', leftHole: 6, bitsLabel: '+1 bit'),
      ],
    ),
    HistoryRound(
      id: 'r2',
      courseName: 'Royal Sydney Golf Club',
      courseShortTitle: 'Royal Sydney',
      holeCount: 9,
      whenRelative: '3 days ago',
      dateHeader: 'Oct 21, 2026',
      players: ['Alex', 'Jamie'],
      winnerName: 'Jamie',
      winnerBits: 4,
      completed: true,
      standings: [
        HistoryStanding(rank: 1, name: 'Jamie', bits: 4, subtitle: 'Winner', isWinnerRow: true),
        HistoryStanding(rank: 2, name: 'Alex', bits: 1, subtitle: '−3 vs leader'),
      ],
      leftEarly: [],
    ),
    HistoryRound(
      id: 'r3',
      courseName: 'Royal Queensland Golf Club',
      courseShortTitle: 'Royal Queensland',
      holeCount: 18,
      whenRelative: '1 week ago',
      dateHeader: 'Oct 17, 2026',
      players: ['Chris', 'Taylor', 'Riley'],
      winnerName: 'Chris',
      winnerBits: 5,
      completed: false,
      standings: [
        HistoryStanding(rank: 1, name: 'Chris', bits: 5, subtitle: 'Leader', isWinnerRow: true),
        HistoryStanding(rank: 2, name: 'Taylor', bits: 3, subtitle: '−2 vs leader'),
        HistoryStanding(rank: 3, name: 'Riley', bits: -2, subtitle: '−7 vs leader'),
      ],
      leftEarly: [],
    ),
    HistoryRound(
      id: 'r4',
      courseName: 'Kingston Heath Golf Club',
      courseShortTitle: 'Kingston Heath',
      holeCount: 18,
      whenRelative: '2 weeks ago',
      dateHeader: 'Oct 10, 2026',
      players: ['Alex', 'Sam', 'Jordan'],
      winnerName: 'Jordan',
      winnerBits: 6,
      completed: true,
      standings: [
        HistoryStanding(rank: 1, name: 'Jordan', bits: 6, subtitle: 'Winner', isWinnerRow: true),
        HistoryStanding(rank: 2, name: 'Alex', bits: 4, subtitle: '−2 vs leader'),
        HistoryStanding(rank: 3, name: 'Sam', bits: 1, subtitle: '−5 vs leader'),
      ],
      leftEarly: [],
    ),
  ];
}

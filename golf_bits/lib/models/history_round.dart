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

  Map<String, dynamic> toJson() => {
        'rank': rank,
        'name': name,
        'bits': bits,
        'subtitle': subtitle,
        'is_winner_row': isWinnerRow,
      };

  static HistoryStanding fromJson(Map<String, dynamic> m) {
    return HistoryStanding(
      rank: (m['rank'] as num).toInt(),
      name: m['name'] as String,
      bits: (m['bits'] as num).toInt(),
      subtitle: m['subtitle'] as String? ?? '',
      isWinnerRow: m['is_winner_row'] as bool? ?? false,
    );
  }
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

  Map<String, dynamic> toJson() => {
        'name': name,
        'left_hole': leftHole,
        'bits_label': bitsLabel,
      };

  static HistoryLeftEarly fromJson(Map<String, dynamic> m) {
    return HistoryLeftEarly(
      name: m['name'] as String,
      leftHole: (m['left_hole'] as num).toInt(),
      bitsLabel: m['bits_label'] as String? ?? '',
    );
  }
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

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String dateHeaderFromUtc(DateTime endedAtUtc) {
    final local = endedAtUtc.toLocal();
    return '${_months[local.month - 1]} ${local.day}, ${local.year}';
  }

  static String whenRelativeFromUtc(DateTime endedAtUtc, DateTime nowLocal) {
    final ended = endedAtUtc.toLocal();
    final days = DateTime(ended.year, ended.month, ended.day)
        .difference(DateTime(nowLocal.year, nowLocal.month, nowLocal.day))
        .inDays;
    if (days == 0) return 'Today';
    if (days == -1) return 'Yesterday';
    if (days > 0) return 'In $days days';
    final ago = -days;
    if (ago < 7) return ago == 1 ? '1 day ago' : '$ago days ago';
    if (ago < 14) return '1 week ago';
    if (ago < 30) return '${ago ~/ 7} weeks ago';
    if (ago < 365) return '${ago ~/ 30} months ago';
    return '${ago ~/ 365} years ago';
  }

  factory HistoryRound.fromSupabase(Map<String, dynamic> row) {
    final id = row['id'] as String;
    final endedAt = DateTime.parse(row['ended_at'] as String);
    final now = DateTime.now();
    final players = (row['players'] as List<dynamic>).map((e) => e as String).toList();
    final standingsJson = row['standings'] as List<dynamic>? ?? const [];
    final standings = standingsJson.map((e) => HistoryStanding.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    final leftJson = row['left_early'] as List<dynamic>? ?? const [];
    final leftEarly = leftJson.map((e) => HistoryLeftEarly.fromJson(Map<String, dynamic>.from(e as Map))).toList();

    return HistoryRound(
      id: id,
      courseName: row['course_name'] as String,
      courseShortTitle: row['course_short_title'] as String,
      holeCount: (row['hole_count'] as num).toInt(),
      whenRelative: whenRelativeFromUtc(endedAt, now),
      dateHeader: dateHeaderFromUtc(endedAt),
      players: players,
      winnerName: row['winner_name'] as String,
      winnerBits: (row['winner_bits'] as num).toInt(),
      completed: row['completed'] as bool? ?? true,
      standings: standings,
      leftEarly: leftEarly,
    );
  }

  /// Demo rounds when Supabase is off or for layout previews.
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

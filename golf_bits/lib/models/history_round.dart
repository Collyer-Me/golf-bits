import 'package:flutter/foundation.dart';

import '../data/round_coplayers.dart';
import 'round_session_args.dart';

/// One row on the history detail standings table.
@immutable
class HistoryStanding {
  const HistoryStanding({
    required this.rank,
    required this.name,
    required this.bits,
    required this.subtitle,
    this.isWinnerRow = false,
    this.participantKey,
  });

  final int rank;
  final String name;
  final int bits;
  /// e.g. "Winner", "−5 vs leader"
  final String subtitle;
  final bool isWinnerRow;
  final String? participantKey;

  Map<String, dynamic> toJson() => {
        'rank': rank,
        'name': name,
        'bits': bits,
        'subtitle': subtitle,
        'is_winner_row': isWinnerRow,
        'participant_key': participantKey,
      };

  static HistoryStanding fromJson(Map<String, dynamic> m) {
    return HistoryStanding(
      rank: (m['rank'] as num).toInt(),
      name: m['name'] as String,
      bits: (m['bits'] as num).toInt(),
      subtitle: m['subtitle'] as String? ?? '',
      isWinnerRow: m['is_winner_row'] as bool? ?? false,
      participantKey: m['participant_key'] as String?,
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
    this.currentHole,
    this.scoreByPlayer = const {},
    this.participants = const [],
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
  final int? currentHole;
  final Map<String, int> scoreByPlayer;
  final List<RoundParticipant> participants;

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

  /// Display/sort time: prefer `ended_at`, then `completed_at`, then `created_at`.
  static DateTime timestampUtcFromRow(Map<String, dynamic> row) {
    for (final key in ['ended_at', 'completed_at', 'created_at']) {
      final dynamic v = row[key];
      if (v == null) continue;
      if (v is String && v.isNotEmpty) {
        return DateTime.parse(v);
      }
      if (v is DateTime) return v.toUtc();
    }
    return DateTime.now().toUtc();
  }

  /// Some Supabase projects use a boolean `completed`; others use `completed_at` (null = in progress).
  static bool completedFromRow(Map<String, dynamic> row) {
    final dynamic c = row['completed'];
    if (c is bool) return c;
    if (c is String) {
      final s = c.toLowerCase();
      if (s == 'true') return true;
      if (s == 'false') return false;
    }
    if (row['completed_at'] != null) return true;
    return false;
  }

  /// When [standings] was never written (e.g. completion sync failed) but per-hole
  /// sync saved [scores], rebuild the leaderboard for history UI.
  static List<HistoryStanding> _standingsFromScores({
    required Map<String, int> scores,
    required List<RoundParticipant> participants,
    required List<String> players,
  }) {
    if (scores.isEmpty) return [];

    String nameForKey(String key) {
      for (final p in participants) {
        if (p.key == key) return p.displayName;
      }
      final m = RegExp(r'^p(\d+)$').firstMatch(key);
      if (m != null) {
        final i = int.tryParse(m.group(1)!);
        if (i != null && i >= 0 && i < players.length) return players[i];
      }
      return key;
    }

    final entries = scores.entries
        .map(
          (e) => (
            key: e.key,
            name: nameForKey(e.key),
            bits: e.value,
          ),
        )
        .toList()
      ..sort((a, b) => b.bits.compareTo(a.bits));
    if (entries.isEmpty) return [];

    final topBits = entries.first.bits;
    return [
      for (var i = 0; i < entries.length; i++)
        HistoryStanding(
          rank: i + 1,
          name: entries[i].name,
          bits: entries[i].bits,
          subtitle: i == 0
              ? (entries.length > 1 ? 'Winner' : 'Leader')
              : (topBits - entries[i].bits == 0
                  ? 'Tied leader'
                  : '−${topBits - entries[i].bits} vs leader'),
          isWinnerRow: i == 0,
          participantKey: entries[i].key,
        ),
    ];
  }

  factory HistoryRound.fromSupabase(Map<String, dynamic> row) {
    final id = row['id'] as String;
    final endedAt = timestampUtcFromRow(row);
    final now = DateTime.now();
    final rawPlayers = row['players'] as List<dynamic>? ?? const [];
    final players = RoundCoplayers.namesFromPlayersArrayOnly(rawPlayers);
    final standingsJson = row['standings'] as List<dynamic>? ?? const [];
    var standings = standingsJson.map((e) => HistoryStanding.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    final leftJson = row['left_early'] as List<dynamic>? ?? const [];
    final leftEarly = leftJson.map((e) => HistoryLeftEarly.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    final participantsJson = row['participants'] as List<dynamic>? ?? const [];
    final participants = participantsJson
        .map((e) => RoundParticipant.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((p) => p.key.isNotEmpty && p.displayName.isNotEmpty)
        .toList();
    final resolvedPlayers = participants.isNotEmpty
        ? participants.map((p) => p.displayName).toList()
        : players;
    final rawScores = row['score_by_player'];
    final Map<String, int> scores;
    if (rawScores is Map) {
      scores = rawScores.map(
        (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? int.tryParse('$v') ?? 0),
      );
    } else {
      scores = const {};
    }
    if (standings.isEmpty && scores.isNotEmpty) {
      standings = _standingsFromScores(
        scores: scores,
        participants: participants,
        players: players,
      );
    }
    final int holeCountResolved = ((row['hole_count'] as num?)?.toInt()) ??
        ((row['holes'] as num?)?.toInt()) ??
        18;
    final String courseShortResolved =
        (row['course_short_title'] as String?)?.trim().isNotEmpty == true
            ? (row['course_short_title'] as String)
            : ((row['course_name'] as String?)?.split(',').first.trim() ?? 'Course');
    final String winnerNameResolved;
    final int winnerBitsResolved;
    final sortedStandings = [...standings]..sort((a, b) => a.rank.compareTo(b.rank));
    final rawWinner = (row['winner_name'] as String?)?.trim() ?? '';
    final winnerIsPlaceholder = rawWinner.isEmpty || rawWinner == 'TBD';
    if (!winnerIsPlaceholder) {
      winnerNameResolved = rawWinner;
    } else if (sortedStandings.isNotEmpty) {
      winnerNameResolved = sortedStandings.first.name;
    } else {
      winnerNameResolved = resolvedPlayers.isNotEmpty ? resolvedPlayers.first : 'TBD';
    }
    if (!winnerIsPlaceholder && row['winner_bits'] is num) {
      winnerBitsResolved = (row['winner_bits'] as num).toInt();
    } else if (sortedStandings.isNotEmpty) {
      winnerBitsResolved = sortedStandings.first.bits;
    } else if (row['winner_bits'] is num) {
      winnerBitsResolved = (row['winner_bits'] as num).toInt();
    } else {
      winnerBitsResolved = 0;
    }

    return HistoryRound(
      id: id,
      courseName: (row['course_name'] as String?) ?? 'Course',
      courseShortTitle: courseShortResolved,
      holeCount: holeCountResolved,
      whenRelative: whenRelativeFromUtc(endedAt, now),
      dateHeader: dateHeaderFromUtc(endedAt),
      players: resolvedPlayers,
      winnerName: winnerNameResolved,
      winnerBits: winnerBitsResolved,
      completed: completedFromRow(row),
      standings: standings,
      leftEarly: leftEarly,
      currentHole: (row['current_hole'] as num?)?.toInt(),
      scoreByPlayer: scores,
      participants: participants,
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

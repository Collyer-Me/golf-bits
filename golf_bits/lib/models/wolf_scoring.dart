import 'package:flutter/foundation.dart';

/// Gross vs net for Wolf hole comparison.
enum WolfScoringBasis {
  net,
  gross;

  static WolfScoringBasis fromDb(String? raw) {
    return raw?.trim().toLowerCase() == 'gross' ? WolfScoringBasis.gross : WolfScoringBasis.net;
  }

  String toDb() => name;
}

enum WolfCallType {
  partner,
  lone,
  blind;

  int get multiplier => switch (this) {
        WolfCallType.partner => 1,
        WolfCallType.lone => 2,
        WolfCallType.blind => 3,
      };
}

enum WolfHoleWinner {
  wolfSide,
  fieldSide,
  tie,
}

@immutable
class WolfCall {
  const WolfCall({
    required this.type,
    this.partnerKey,
  });

  final WolfCallType type;
  final String? partnerKey;

  int get multiplier => type.multiplier;
}

Map<String, dynamic> wolfCallToJson(WolfCall call) => {
      'type': call.type.name,
      if (call.partnerKey != null && call.partnerKey!.isNotEmpty) 'partner_key': call.partnerKey,
    };

WolfCall? parsePendingWolfCall(dynamic raw) {
  if (raw is! Map) return null;
  final map = Map<String, dynamic>.from(raw);
  final type = WolfCallType.values.asNameMap()[map['type'] as String?] ?? WolfCallType.partner;
  return WolfCall(type: type, partnerKey: map['partner_key'] as String?);
}

@immutable
class WolfHoleSettlement {
  const WolfHoleSettlement({
    required this.winner,
    required this.wolfBestBall,
    required this.fieldBestBall,
    required this.pointsByPlayer,
  });

  final WolfHoleWinner winner;
  final int? wolfBestBall;
  final int? fieldBestBall;
  final Map<String, int> pointsByPlayer;
}

/// Typical stroke-index ranks for a par-72 layout when the catalog lacks SI data.
/// Keyed by physical hole number (1–18), values are difficulty rank 1–18.
const Map<int, int> standardStrokeIndexByHoleNumber = {
  1: 11,
  2: 7,
  3: 3,
  4: 15,
  5: 1,
  6: 13,
  7: 9,
  8: 17,
  9: 5,
  10: 12,
  11: 8,
  12: 2,
  13: 14,
  14: 18,
  15: 4,
  16: 16,
  17: 6,
  18: 10,
};

/// Stroke index (1–18 difficulty rank) for [hole] from catalog map, then standard template.
int? resolveStrokeIndexForHole(int hole, Map<String, int> holeStrokeIndexes) {
  final fromCatalog = holeStrokeIndexes['$hole'] ?? holeStrokeIndexes[hole.toString()];
  if (fromCatalog != null) return fromCatalog;
  return standardStrokeIndexByHoleNumber[hole];
}

/// Strokes received on a hole from course handicap + stroke index.
///
/// Positive [courseHandicap] = receive strokes; negative = plus handicap (give strokes).
int strokesReceivedOnHole({
  required int courseHandicap,
  required int? strokeIndex,
}) {
  if (strokeIndex == null || courseHandicap == 0) return 0;
  if (courseHandicap > 0) {
    var strokes = 0;
    if (strokeIndex <= courseHandicap) strokes++;
    if (strokeIndex <= courseHandicap - 18) strokes++;
    return strokes;
  }
  final give = -courseHandicap;
  var strokes = 0;
  if (strokeIndex <= give) strokes--;
  if (strokeIndex <= give - 18) strokes--;
  return strokes;
}

/// Display label for handicap entry (negative stored value → "+3" plus handicap).
String formatCourseHandicap(int handicap) => handicap < 0 ? '+${-handicap}' : '$handicap';

/// Plain-language strokes received on this hole (for player rows).
String formatExtraShotsLabel(int strokesReceived) {
  if (strokesReceived == 0) return 'No extra shots';
  final abs = strokesReceived.abs();
  final noun = abs == 1 ? 'shot' : 'shots';
  return '$strokesReceived extra $noun';
}

int netStrokes({required int gross, required int strokesReceived}) {
  return gross - strokesReceived;
}

/// Effective score for Wolf comparison (net or gross).
int effectiveHoleScore({
  required int gross,
  required WolfScoringBasis basis,
  required int courseHandicap,
  required int? strokeIndex,
}) {
  if (basis == WolfScoringBasis.gross) return gross;
  final received = strokesReceivedOnHole(
    courseHandicap: courseHandicap,
    strokeIndex: strokeIndex,
  );
  return netStrokes(gross: gross, strokesReceived: received);
}

bool isTrailingPlayerWolfHole({
  required int holeIndex,
  required int holeCount,
}) {
  if (holeCount == 9) return holeIndex == 8;
  if (holeCount == 18) return holeIndex == 16 || holeIndex == 17;
  return false;
}

/// Who is Wolf this hole: rotation or trailing-player override.
String resolveWolfPlayerId({
  required int holeIndex,
  required int holeCount,
  required List<String> teeOrder,
  required Map<String, int> wolfPointsBeforeHole,
}) {
  assert(teeOrder.length == 4, 'Wolf requires exactly 4 players');
  if (isTrailingPlayerWolfHole(holeIndex: holeIndex, holeCount: holeCount)) {
    return _trailingPlayerId(
      teeOrder: teeOrder,
      wolfPoints: wolfPointsBeforeHole,
    );
  }
  return teeOrder[holeIndex % 4];
}

String _trailingPlayerId({
  required List<String> teeOrder,
  required Map<String, int> wolfPoints,
}) {
  var minPoints = 999999;
  for (final key in teeOrder) {
    final p = wolfPoints[key] ?? 0;
    if (p < minPoints) minPoints = p;
  }
  for (final key in teeOrder) {
    if ((wolfPoints[key] ?? 0) == minPoints) return key;
  }
  return teeOrder.first;
}

List<String> wolfTeamKeys({
  required String wolfKey,
  required WolfCall call,
}) {
  switch (call.type) {
    case WolfCallType.partner:
      final partner = call.partnerKey;
      if (partner == null || partner.isEmpty) {
        return [wolfKey];
      }
      return [wolfKey, partner];
    case WolfCallType.lone:
    case WolfCallType.blind:
      return [wolfKey];
  }
}

List<String> fieldTeamKeys({
  required List<String> teeOrder,
  required String wolfKey,
  required WolfCall call,
}) {
  final wolfSide = wolfTeamKeys(wolfKey: wolfKey, call: call).toSet();
  return teeOrder.where((k) => !wolfSide.contains(k)).toList();
}

int? bestBallScore({
  required List<String> teamKeys,
  required Map<String, int> grossByPlayer,
  required WolfScoringBasis basis,
  required Map<String, int> handicaps,
  required int? strokeIndex,
}) {
  int? best;
  for (final key in teamKeys) {
    final gross = grossByPlayer[key];
    if (gross == null || gross <= 0) continue;
    final effective = effectiveHoleScore(
      gross: gross,
      basis: basis,
      courseHandicap: handicaps[key] ?? 0,
      strokeIndex: strokeIndex,
    );
    if (best == null || effective < best) best = effective;
  }
  return best;
}

WolfHoleSettlement settleWolfHole({
  required List<String> teeOrder,
  required String wolfKey,
  required WolfCall call,
  required Map<String, int> grossByPlayer,
  required WolfScoringBasis basis,
  required Map<String, int> handicaps,
  required int? strokeIndex,
}) {
  final wolfSide = wolfTeamKeys(wolfKey: wolfKey, call: call);
  final fieldSide = fieldTeamKeys(teeOrder: teeOrder, wolfKey: wolfKey, call: call);

  final wolfBest = bestBallScore(
    teamKeys: wolfSide,
    grossByPlayer: grossByPlayer,
    basis: basis,
    handicaps: handicaps,
    strokeIndex: strokeIndex,
  );
  final fieldBest = bestBallScore(
    teamKeys: fieldSide,
    grossByPlayer: grossByPlayer,
    basis: basis,
    handicaps: handicaps,
    strokeIndex: strokeIndex,
  );

  final points = {for (final k in teeOrder) k: 0};

  if (wolfBest == null || fieldBest == null) {
    return WolfHoleSettlement(
      winner: WolfHoleWinner.tie,
      wolfBestBall: wolfBest,
      fieldBestBall: fieldBest,
      pointsByPlayer: points,
    );
  }

  if (wolfBest == fieldBest) {
    return WolfHoleSettlement(
      winner: WolfHoleWinner.tie,
      wolfBestBall: wolfBest,
      fieldBestBall: fieldBest,
      pointsByPlayer: points,
    );
  }

  final wolfWins = wolfBest < fieldBest;
  _assignZeroSumWolfPoints(
    points: points,
    wolfSide: wolfSide,
    fieldSide: fieldSide,
    call: call,
    wolfSideWon: wolfWins,
  );

  return WolfHoleSettlement(
    winner: wolfWins ? WolfHoleWinner.wolfSide : WolfHoleWinner.fieldSide,
    wolfBestBall: wolfBest,
    fieldBestBall: fieldBest,
    pointsByPlayer: points,
  );
}

/// Zero-sum point transfers per hole (see docs/GOLF_SETTLEMENT.md).
void _assignZeroSumWolfPoints({
  required Map<String, int> points,
  required List<String> wolfSide,
  required List<String> fieldSide,
  required WolfCall call,
  required bool wolfSideWon,
}) {
  switch (call.type) {
    case WolfCallType.partner:
      const stake = 2;
      final winningSide = wolfSideWon ? wolfSide : fieldSide;
      final losingSide = wolfSideWon ? fieldSide : wolfSide;
      for (final key in winningSide) {
        points[key] = stake;
      }
      for (final key in losingSide) {
        points[key] = -stake;
      }
    case WolfCallType.lone:
    case WolfCallType.blind:
      final multiplier = call.multiplier;
      final wolfStake = 3 * multiplier;
      final fieldStake = multiplier;
      if (wolfSideWon) {
        for (final key in wolfSide) {
          points[key] = wolfStake;
        }
        for (final key in fieldSide) {
          points[key] = -fieldStake;
        }
      } else {
        for (final key in wolfSide) {
          points[key] = -wolfStake;
        }
        for (final key in fieldSide) {
          points[key] = fieldStake;
        }
      }
  }
}

/// Partner rows in tee order after Wolf (non-wolf players in rotation order).
List<String> nonWolfTeeOrder({
  required List<String> teeOrder,
  required String wolfKey,
}) {
  final wolfIdx = teeOrder.indexOf(wolfKey);
  if (wolfIdx < 0) return teeOrder.where((k) => k != wolfKey).toList();
  final out = <String>[];
  for (var i = 1; i <= 3; i++) {
    out.add(teeOrder[(wolfIdx + i) % 4]);
  }
  return out;
}

/// How many opponents have "teed off" for partner-pick timing (0–3).
enum WolfPartnerPhase {
  beforeAnyDrive,
  afterFirstOpponent,
  afterSecondOpponent,
  afterThirdOpponent,
}

WolfPartnerPhase partnerPhaseFromTeedCount(int teedCount) {
  return switch (teedCount.clamp(0, 3)) {
    0 => WolfPartnerPhase.beforeAnyDrive,
    1 => WolfPartnerPhase.afterFirstOpponent,
    2 => WolfPartnerPhase.afterSecondOpponent,
    _ => WolfPartnerPhase.afterThirdOpponent,
  };
}

/// One hole recomputed against stored Wolf results (for post-round verification).
@immutable
class WolfHoleAuditRow {
  const WolfHoleAuditRow({
    required this.hole,
    required this.holeIndex,
    required this.expectedWolfKey,
    required this.storedWolfKey,
    required this.call,
    required this.storedPoints,
    required this.expectedPoints,
    required this.settlement,
  });

  final int hole;
  final int holeIndex;
  final String expectedWolfKey;
  final String storedWolfKey;
  final WolfCall call;
  final Map<String, int> storedPoints;
  final Map<String, int> expectedPoints;
  final WolfHoleSettlement settlement;

  bool get wolfKeyMatch => expectedWolfKey == storedWolfKey;

  bool get pointsMatch {
    final keys = {...storedPoints.keys, ...expectedPoints.keys};
    for (final k in keys) {
      if ((storedPoints[k] ?? 0) != (expectedPoints[k] ?? 0)) return false;
    }
    return true;
  }

  bool get isValid => wolfKeyMatch && pointsMatch;
}

@immutable
class WolfRoundAudit {
  const WolfRoundAudit({
    required this.holes,
    required this.expectedTotals,
    required this.storedTotals,
  });

  final List<WolfHoleAuditRow> holes;
  final Map<String, int> expectedTotals;
  final Map<String, int> storedTotals;

  bool get totalsMatch {
    final keys = {...expectedTotals.keys, ...storedTotals.keys};
    for (final k in keys) {
      if ((expectedTotals[k] ?? 0) != (storedTotals[k] ?? 0)) return false;
    }
    return true;
  }

  bool get allHolesMatch => holes.every((h) => h.isValid);

  bool get isValid => allHolesMatch && totalsMatch;
}

/// Replays each stored hole with current Wolf rules and compares points + totals.
WolfRoundAudit auditWolfRound({
  required List<int> holeOrder,
  required List<String> teeOrder,
  required Map<int, WolfHoleResult> wolfHoleResults,
  required Map<String, int> wolfPointsByPlayer,
  required WolfScoringBasis basis,
  required Map<String, int> handicaps,
  required Map<String, int> holeStrokeIndexes,
  required int holeCount,
}) {
  final holes = <WolfHoleAuditRow>[];
  final expectedTotals = {for (final k in teeOrder) k: 0};

  for (var holeIndex = 0; holeIndex < holeOrder.length; holeIndex++) {
    final hole = holeOrder[holeIndex];
    final stored = wolfHoleResults[hole];
    if (stored == null) continue;

    final wolfKey = resolveWolfPlayerId(
      holeIndex: holeIndex,
      holeCount: holeCount,
      teeOrder: teeOrder,
      wolfPointsBeforeHole: expectedTotals,
    );

    final settlement = settleWolfHole(
      teeOrder: teeOrder,
      wolfKey: wolfKey,
      call: stored.call,
      grossByPlayer: stored.grossByPlayer,
      basis: basis,
      handicaps: handicaps,
      strokeIndex: resolveStrokeIndexForHole(hole, holeStrokeIndexes),
    );

    holes.add(
      WolfHoleAuditRow(
        hole: hole,
        holeIndex: holeIndex,
        expectedWolfKey: wolfKey,
        storedWolfKey: stored.wolfKey,
        call: stored.call,
        storedPoints: stored.pointsByPlayer,
        expectedPoints: settlement.pointsByPlayer,
        settlement: settlement,
      ),
    );

    for (final e in settlement.pointsByPlayer.entries) {
      expectedTotals[e.key] = (expectedTotals[e.key] ?? 0) + e.value;
    }
  }

  return WolfRoundAudit(
    holes: holes,
    expectedTotals: expectedTotals,
    storedTotals: wolfPointsByPlayer,
  );
}

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
  final winners = wolfWins ? wolfSide : fieldSide;
  final multiplier = call.multiplier;
  for (final key in winners) {
    points[key] = 1 * multiplier;
  }

  return WolfHoleSettlement(
    winner: wolfWins ? WolfHoleWinner.wolfSide : WolfHoleWinner.fieldSide,
    wolfBestBall: wolfBest,
    fieldBestBall: fieldBest,
    pointsByPlayer: points,
  );
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

import 'package:flutter/foundation.dart';

import 'round_game_config.dart';
import 'wolf_scoring.dart';

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

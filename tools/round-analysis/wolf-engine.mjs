/** Port of golf_bits/lib/models/wolf_scoring.dart (subset for audits). */

export const standardStrokeIndexByHoleNumber = {
  1: 11, 2: 7, 3: 3, 4: 15, 5: 1, 6: 13, 7: 9, 8: 17, 9: 5,
  10: 12, 11: 8, 12: 2, 13: 14, 14: 18, 15: 4, 16: 16, 17: 6, 18: 10,
};

export function buildHoleOrder(holeCount, startHole = 1) {
  if (holeCount === 9) {
    return Array.from({ length: 9 }, (_, i) => startHole + i);
  }
  return Array.from({ length: 18 }, (_, i) => i + 1);
}

export function resolveStrokeIndexForHole(hole, holeStrokeIndexes = {}) {
  const fromCatalog = holeStrokeIndexes[String(hole)] ?? holeStrokeIndexes[hole];
  if (fromCatalog != null) return Number(fromCatalog);
  return standardStrokeIndexByHoleNumber[hole] ?? null;
}

export function strokesReceivedOnHole(courseHandicap, strokeIndex) {
  if (strokeIndex == null || courseHandicap === 0) return 0;
  if (courseHandicap > 0) {
    let strokes = 0;
    if (strokeIndex <= courseHandicap) strokes++;
    if (strokeIndex <= courseHandicap - 18) strokes++;
    return strokes;
  }
  const give = -courseHandicap;
  let strokes = 0;
  if (strokeIndex <= give) strokes--;
  if (strokeIndex <= give - 18) strokes--;
  return strokes;
}

export function effectiveHoleScore(gross, basis, courseHandicap, strokeIndex) {
  if (basis === "gross") return gross;
  const received = strokesReceivedOnHole(courseHandicap, strokeIndex);
  return gross - received;
}

export function isTrailingPlayerWolfHole(holeIndex, holeCount) {
  if (holeCount === 9) return holeIndex === 8;
  if (holeCount === 18) return holeIndex === 16 || holeIndex === 17;
  return false;
}

function trailingPlayerId(teeOrder, wolfPoints) {
  let minPoints = 999999;
  for (const key of teeOrder) {
    const p = wolfPoints[key] ?? 0;
    if (p < minPoints) minPoints = p;
  }
  for (const key of teeOrder) {
    if ((wolfPoints[key] ?? 0) === minPoints) return key;
  }
  return teeOrder[0];
}

export function resolveWolfPlayerId({ holeIndex, holeCount, teeOrder, wolfPointsBeforeHole }) {
  if (teeOrder.length !== 4) {
    throw new Error(`Wolf requires 4 players; got ${teeOrder.length}`);
  }
  if (isTrailingPlayerWolfHole(holeIndex, holeCount)) {
    return trailingPlayerId(teeOrder, wolfPointsBeforeHole);
  }
  return teeOrder[holeIndex % 4];
}

export function wolfTeamKeys(wolfKey, call) {
  if (call.type === "partner") {
    const partner = call.partnerKey;
    if (!partner) return [wolfKey];
    return [wolfKey, partner];
  }
  return [wolfKey];
}

export function fieldTeamKeys(teeOrder, wolfKey, call) {
  const wolfSide = new Set(wolfTeamKeys(wolfKey, call));
  return teeOrder.filter((k) => !wolfSide.has(k));
}

function bestBallScore(teamKeys, grossByPlayer, basis, handicaps, strokeIndex) {
  let best = null;
  for (const key of teamKeys) {
    const gross = grossByPlayer[key];
    if (gross == null || gross <= 0) continue;
    const effective = effectiveHoleScore(
      gross,
      basis,
      handicaps[key] ?? 0,
      strokeIndex,
    );
    if (best == null || effective < best) best = effective;
  }
  return best;
}

function assignZeroSumWolfPoints({ points, wolfSide, fieldSide, call, wolfSideWon }) {
  if (call.type === "partner") {
    const stake = 1;
    const winningSide = wolfSideWon ? wolfSide : fieldSide;
    const losingSide = wolfSideWon ? fieldSide : wolfSide;
    for (const key of winningSide) points[key] = stake;
    for (const key of losingSide) points[key] = -stake;
    return;
  }
  const multiplier = call.type === "blind" ? 3 : 2;
  const wolfStake = 3 * multiplier;
  const fieldStake = multiplier;
  if (wolfSideWon) {
    for (const key of wolfSide) points[key] = wolfStake;
    for (const key of fieldSide) points[key] = -fieldStake;
  } else {
    for (const key of wolfSide) points[key] = -wolfStake;
    for (const key of fieldSide) points[key] = fieldStake;
  }
}

export function settleWolfHole({
  teeOrder,
  wolfKey,
  call,
  grossByPlayer,
  basis,
  handicaps,
  strokeIndex,
}) {
  const wolfSide = wolfTeamKeys(wolfKey, call);
  const fieldSide = fieldTeamKeys(teeOrder, wolfKey, call);
  const points = Object.fromEntries(teeOrder.map((k) => [k, 0]));

  const wolfBest = bestBallScore(wolfSide, grossByPlayer, basis, handicaps, strokeIndex);
  const fieldBest = bestBallScore(fieldSide, grossByPlayer, basis, handicaps, strokeIndex);

  if (wolfBest == null || fieldBest == null || wolfBest === fieldBest) {
    return {
      winner: "tie",
      wolfBestBall: wolfBest,
      fieldBestBall: fieldBest,
      pointsByPlayer: points,
    };
  }

  const wolfWins = wolfBest < fieldBest;
  assignZeroSumWolfPoints({ points, wolfSide, fieldSide, call, wolfSideWon: wolfWins });

  return {
    winner: wolfWins ? "wolfSide" : "fieldSide",
    wolfBestBall: wolfBest,
    fieldBestBall: fieldBest,
    pointsByPlayer: points,
  };
}

export function parseWolfHoleResults(raw) {
  if (!raw || typeof raw !== "object") return {};
  const out = {};
  for (const [key, value] of Object.entries(raw)) {
    const hole = Number(key);
    if (!Number.isFinite(hole) || !value || typeof value !== "object") continue;
    const grossRaw = value.gross ?? {};
    const pointsRaw = value.points ?? {};
    const gross = Object.fromEntries(
      Object.entries(grossRaw).map(([k, v]) => [k, Number(v) || 0]),
    );
    const points = Object.fromEntries(
      Object.entries(pointsRaw).map(([k, v]) => [k, Number(v) || 0]),
    );
    out[hole] = {
      hole,
      wolfKey: value.wolf_key ?? "",
      call: {
        type: value.call_type ?? "partner",
        partnerKey: value.partner_key ?? null,
      },
      grossByPlayer: gross,
      pointsByPlayer: points,
      wolfBestBall: value.wolf_best_ball ?? null,
      fieldBestBall: value.field_best_ball ?? null,
      winner: value.winner ?? "tie",
    };
  }
  return out;
}

export function auditWolfRound(round) {
  const gameConfig = round.game_config ?? {};
  const teeOrder = gameConfig.tee_order ?? [];
  const handicaps = gameConfig.handicaps ?? {};
  const basis = gameConfig.scoring_basis === "gross" ? "gross" : "net";
  const holeCount = round.hole_count ?? 18;
  const startHole = round.start_hole ?? 1;
  const holeOrder = buildHoleOrder(holeCount, startHole);
  const holeStrokeIndexes = round.hole_stroke_indexes ?? {};
  const wolfHoleResults = parseWolfHoleResults(round.wolf_hole_results);
  const storedTotals = round.wolf_points_by_player ?? {};

  const expectedTotals = Object.fromEntries(teeOrder.map((k) => [k, 0]));
  const holes = [];

  for (let holeIndex = 0; holeIndex < holeOrder.length; holeIndex++) {
    const hole = holeOrder[holeIndex];
    const stored = wolfHoleResults[hole];
    if (!stored) continue;

    const wolfKey = resolveWolfPlayerId({
      holeIndex,
      holeCount,
      teeOrder,
      wolfPointsBeforeHole: expectedTotals,
    });

    const settlement = settleWolfHole({
      teeOrder,
      wolfKey,
      call: stored.call,
      grossByPlayer: stored.grossByPlayer,
      basis,
      handicaps,
      strokeIndex: resolveStrokeIndexForHole(hole, holeStrokeIndexes),
    });

    const pointsMatch = teeOrder.every(
      (k) => (stored.pointsByPlayer[k] ?? 0) === (settlement.pointsByPlayer[k] ?? 0),
    );

    holes.push({
      hole,
      holeIndex,
      expectedWolfKey: wolfKey,
      storedWolfKey: stored.wolfKey,
      wolfKeyMatch: wolfKey === stored.wolfKey,
      call: stored.call,
      storedPoints: stored.pointsByPlayer,
      expectedPoints: settlement.pointsByPlayer,
      pointsMatch,
      wolfBestBall: settlement.wolfBestBall,
      fieldBestBall: settlement.fieldBestBall,
      winner: settlement.winner,
      grossByPlayer: stored.grossByPlayer,
      isValid: wolfKey === stored.wolfKey && pointsMatch,
    });

    for (const [k, v] of Object.entries(settlement.pointsByPlayer)) {
      expectedTotals[k] = (expectedTotals[k] ?? 0) + v;
    }
  }

  const totalsMatch = teeOrder.every(
    (k) => (storedTotals[k] ?? 0) === (expectedTotals[k] ?? 0),
  );

  return {
    roundId: round.id,
    course: round.course_short_title ?? round.course_name,
    teeOrder,
    basis,
    holes,
    expectedTotals,
    storedTotals,
    totalsMatch,
    allHolesMatch: holes.every((h) => h.isValid),
    isValid: holes.every((h) => h.isValid) && totalsMatch,
  };
}

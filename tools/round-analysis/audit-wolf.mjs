#!/usr/bin/env node
/**
 * Replay Wolf hole scoring for a stored round and report mismatches.
 */

import { getSupabaseRestConfig, supabaseRestGet } from "../_shared/load-supabase-env.mjs";
import { auditWolfRound } from "./wolf-engine.mjs";

function completedFromRow(row) {
  const c = row.completed;
  if (typeof c === "boolean") return c;
  if (row.completed_at != null) return true;
  if (String(row.status ?? "").toLowerCase() === "completed") return true;
  return false;
}

function hasWolf(row) {
  const formats = row.round_formats;
  if (Array.isArray(formats)) return formats.includes("wolf");
  const gc = row.game_config;
  if (gc?.formats && Array.isArray(gc.formats)) return gc.formats.includes("wolf");
  return Boolean(row.wolf_hole_results && Object.keys(row.wolf_hole_results).length);
}

function nameForKey(round, key) {
  const participants = round.participants ?? [];
  for (const p of participants) {
    if (p.key === key) return p.display_name ?? p.displayName ?? key;
  }
  return key;
}

function usage() {
  console.error(`Usage:
  node audit-wolf.mjs --id <uuid>
  node audit-wolf.mjs --latest-completed

Env: SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY`);
  process.exit(1);
}

async function main() {
  const config = getSupabaseRestConfig();
  const args = process.argv.slice(2);
  let id = null;
  let latestCompleted = false;

  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === "--id" && args[i + 1]) id = args[++i];
    else if (a === "--latest-completed") latestCompleted = true;
    else if (a === "--help" || a === "-h") usage();
    else usage();
  }

  if (!id && !latestCompleted) usage();

  let row;
  if (id) {
    const rows = await supabaseRestGet(`rounds?select=*&id=eq.${id}&limit=1`, config);
    row = rows?.[0];
    if (!row) throw new Error(`Round not found: ${id}`);
  } else {
    const rows = await supabaseRestGet(
      "rounds?select=*&order=ended_at.desc.nullslast&limit=40",
      config,
    );
    row = (rows ?? []).find((r) => completedFromRow(r) && hasWolf(r));
    if (!row) throw new Error("No completed Wolf round found");
  }

  const audit = auditWolfRound(row);

  const report = {
    summary: {
      roundId: audit.roundId,
      course: audit.course,
      isValid: audit.isValid,
      holeCount: audit.holes.length,
      totalsMatch: audit.totalsMatch,
    },
    teeOrder: audit.teeOrder.map((k) => ({ key: k, name: nameForKey(row, k) })),
    totals: {
      stored: audit.storedTotals,
      expected: audit.expectedTotals,
    },
    holes: audit.holes.map((h) => ({
      hole: h.hole,
      wolf: nameForKey(row, h.expectedWolfKey),
      call: h.call,
      valid: h.isValid,
      wolfKeyMatch: h.wolfKeyMatch,
      pointsMatch: h.pointsMatch,
      bestBall: `${h.wolfBestBall} vs ${h.fieldBestBall}`,
      winner: h.winner,
      storedPoints: h.storedPoints,
      expectedPoints: h.expectedPoints,
      gross: h.grossByPlayer,
    })),
    mismatches: audit.holes.filter((h) => !h.isValid),
  };

  console.log(JSON.stringify(report, null, 2));
  process.exit(audit.isValid ? 0 : 2);
}

main().catch((err) => {
  console.error(err.message ?? err);
  process.exit(1);
});

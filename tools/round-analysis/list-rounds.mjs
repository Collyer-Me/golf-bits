#!/usr/bin/env node
/**
 * List recent rounds from public.rounds (service role — all users).
 * See README.md for env setup.
 */

import { getSupabaseRestConfig, supabaseRestGet } from "../_shared/load-supabase-env.mjs";

function completedFromRow(row) {
  const c = row.completed;
  if (typeof c === "boolean") return c;
  if (typeof c === "string") {
    const s = c.toLowerCase();
    if (s === "true") return true;
    if (s === "false") return false;
  }
  if (row.completed_at != null) return true;
  if (String(row.status ?? "").toLowerCase() === "completed") return true;
  return false;
}

function hasWolf(row) {
  const formats = row.round_formats;
  if (Array.isArray(formats)) return formats.includes("wolf");
  if (typeof formats === "string") return formats.includes("wolf");
  const gc = row.game_config;
  if (gc?.formats && Array.isArray(gc.formats)) return gc.formats.includes("wolf");
  return Boolean(row.wolf_hole_results && Object.keys(row.wolf_hole_results).length);
}

function parseArgs(argv) {
  let limit = 20;
  let wolfOnly = false;
  let completedOnly = false;
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--limit" && argv[i + 1]) {
      limit = Math.min(100, Math.max(1, Number(argv[++i]) || 20));
    } else if (a === "--wolf") {
      wolfOnly = true;
    } else if (a === "--completed") {
      completedOnly = true;
    } else if (a === "--help" || a === "-h") {
      console.log(`Usage: node list-rounds.mjs [--limit N] [--wolf] [--completed]

Lists rounds newest-first (service role).`);
      process.exit(0);
    }
  }
  return { limit, wolfOnly, completedOnly };
}

async function main() {
  const { limit, wolfOnly, completedOnly } = parseArgs(process.argv);
  const config = getSupabaseRestConfig();
  const rows = await supabaseRestGet(
    `rounds?select=id,course_short_title,course_name,ended_at,created_at,completed,completed_at,status,round_formats,game_config,wolf_hole_results,players,winner_name&order=ended_at.desc.nullslast&limit=${limit}`,
    config,
  );

  const mapped = (rows ?? []).map((row) => ({
    id: row.id,
    course: row.course_short_title ?? row.course_name,
    ended_at: row.ended_at ?? row.created_at,
    completed: completedFromRow(row),
    has_wolf: hasWolf(row),
    wolf_holes: row.wolf_hole_results ? Object.keys(row.wolf_hole_results).length : 0,
    players: row.players,
    winner_name: row.winner_name,
  }));

  const filtered = mapped.filter((r) => {
    if (completedOnly && !r.completed) return false;
    if (wolfOnly && !r.has_wolf) return false;
    return true;
  });

  console.log(JSON.stringify(filtered, null, 2));
}

main().catch((err) => {
  console.error(err.message ?? err);
  process.exit(1);
});

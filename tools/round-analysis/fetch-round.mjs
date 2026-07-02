#!/usr/bin/env node
/**
 * Fetch one round row (full JSON) by id or latest completed Wolf round.
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
  const gc = row.game_config;
  if (gc?.formats && Array.isArray(gc.formats)) return gc.formats.includes("wolf");
  return Boolean(row.wolf_hole_results && Object.keys(row.wolf_hole_results).length);
}

function usage() {
  console.error(`Usage:
  node fetch-round.mjs --id <uuid>
  node fetch-round.mjs --latest-completed [--wolf]

Env: SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY`);
  process.exit(1);
}

async function main() {
  const config = getSupabaseRestConfig();
  const args = process.argv.slice(2);
  let id = null;
  let latestCompleted = false;
  let wolfOnly = false;

  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === "--id" && args[i + 1]) id = args[++i];
    else if (a === "--latest-completed") latestCompleted = true;
    else if (a === "--wolf") wolfOnly = true;
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
    row = (rows ?? []).find((r) => completedFromRow(r) && (!wolfOnly || hasWolf(r)));
    if (!row) throw new Error("No matching completed round found");
  }

  console.log(JSON.stringify(row, null, 2));
}

main().catch((err) => {
  console.error(err.message ?? err);
  process.exit(1);
});

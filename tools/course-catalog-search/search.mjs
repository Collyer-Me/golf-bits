#!/usr/bin/env node
/**
 * Dev-only: search public.courses or load one course with scorecard embeds.
 * Requires SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY (see README.md).
 * Loads tools/course-catalog-search/.env if present (no extra deps).
 */

import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));

function loadLocalEnv() {
  const p = join(__dirname, ".env");
  if (!existsSync(p)) return;
  const text = readFileSync(p, "utf8");
  for (const line of text.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq <= 0) continue;
    const k = trimmed.slice(0, eq).trim();
    let v = trimmed.slice(eq + 1).trim();
    if (
      (v.startsWith('"') && v.endsWith('"')) ||
      (v.startsWith("'") && v.endsWith("'"))
    ) {
      v = v.slice(1, -1);
    }
    if (process.env[k] === undefined) process.env[k] = v;
  }
}

loadLocalEnv();

const rawUrl = process.env.SUPABASE_URL?.trim();
const url = rawUrl?.replace(/\/$/, "");
const key = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();

const ENV_TEMPLATE_MARKERS = /YOUR_PROJECT_REF|YOUR_SERVICE_ROLE_KEY_HERE/i;

function usage() {
  console.error(`Usage:
  node search.mjs [search_text] [--limit N]
  node search.mjs --detail <course_uuid>

Env: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
  (set in shell or tools/course-catalog-search/.env)`);
  process.exit(1);
}

function assertEnv() {
  const missing =
    !url ||
    !key ||
    ENV_TEMPLATE_MARKERS.test(rawUrl ?? "") ||
    ENV_TEMPLATE_MARKERS.test(key ?? "");
  if (missing) {
    console.error(
      "Missing or template SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY — edit tools/course-catalog-search/.env.",
    );
    usage();
  }
}

async function restGet(pathAndQuery) {
  const res = await fetch(`${url}/rest/v1/${pathAndQuery}`, {
    headers: {
      apikey: key,
      Authorization: `Bearer ${key}`,
      Accept: "application/json",
    },
  });
  const text = await res.text();
  let body;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    body = text;
  }
  if (!res.ok) {
    console.error(res.status, res.statusText, body);
    process.exit(1);
  }
  return body;
}

function parseArgs(argv) {
  const args = argv.slice(2);
  let detail = null;
  let limit = 40;
  const rest = [];
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === "--detail") {
      detail = args[++i];
      if (!detail) usage();
    } else if (a === "--limit") {
      limit = Math.min(100, Math.max(1, parseInt(args[++i], 10) || 40));
    } else {
      rest.push(a);
    }
  }
  const q = rest.join(" ").trim();
  return { detail, limit, q };
}

async function main() {
  assertEnv();
  const { detail, limit, q } = parseArgs(process.argv);

  if (detail) {
    const select = [
      "id",
      "name",
      "subtitle",
      "coverage_level",
      "source",
      "visibility",
      "locality",
      "region",
      "country_code",
      "latitude",
      "longitude",
      "external_ids",
      "course_tees(id,sort_order,label,color_hint,course_rating,slope_rating,ratings_json,course_tee_holes(hole_number,par,stroke_index,yardage_yds))",
    ].join(",");

    const row = await restGet(
      `courses?id=eq.${encodeURIComponent(detail)}&select=${encodeURIComponent(select)}`,
    );
    if (!Array.isArray(row) || row.length === 0) {
      console.log("No course found for id:", detail);
      process.exit(0);
    }
    console.log(JSON.stringify(row[0], null, 2));
    return;
  }

  // PostgREST: encode % once per ilike pattern (wildcards inside value).
  const patEnc = encodeURIComponent(`%${q}%`);
  const or = q
    ? `or=(name.ilike.${patEnc},subtitle.ilike.${patEnc},locality.ilike.${patEnc})`
    : "";

  const query = [
    "courses?select=id,name,subtitle,coverage_level,source,visibility,locality,region,country_code",
    "order=name.asc",
    `limit=${limit}`,
    or,
  ]
    .filter(Boolean)
    .join("&");

  const rows = await restGet(query);
  console.log(JSON.stringify(rows, null, 2));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

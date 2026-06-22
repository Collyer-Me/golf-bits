#!/usr/bin/env node
/**
 * Catalog health audit: counts, coverage, tee sprawl, label samples.
 * Requires SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY (see README.md).
 */

import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));

function loadLocalEnv() {
  const p = join(__dirname, ".env");
  if (!existsSync(p)) return;
  for (const line of readFileSync(p, "utf8").split(/\r?\n/)) {
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

const url = process.env.SUPABASE_URL?.trim()?.replace(/\/$/, "");
const key = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();

if (!url || !key) {
  console.error("Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY (see README.md).");
  process.exit(1);
}

async function restGet(pathAndQuery) {
  const res = await fetch(`${url}/rest/v1/${pathAndQuery}`, {
    headers: {
      apikey: key,
      Authorization: `Bearer ${key}`,
      Accept: "application/json",
      Prefer: "count=exact",
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
    console.error(res.status, body);
    process.exit(1);
  }
  return body;
}

function groupCount(rows, keyFn) {
  const m = new Map();
  for (const r of rows) {
    const k = keyFn(r);
    m.set(k, (m.get(k) ?? 0) + 1);
  }
  return [...m.entries()].sort((a, b) => b[1] - a[1]);
}

function printSection(title) {
  console.log(`\n=== ${title} ===`);
}

async function main() {
  const courses = await restGet(
    "courses?select=id,name,subtitle,coverage_level,source,country_code,region,locality,external_ids&order=name.asc",
  );

  printSection(`Overview (${courses.length} courses)`);
  console.log("By source:", groupCount(courses, (c) => c.source ?? "?"));
  console.log("By coverage:", groupCount(courses, (c) => c.coverage_level ?? "?"));
  console.log("By country:", groupCount(courses, (c) => c.country_code ?? "(null)"));

  const au = courses.filter((c) => (c.country_code ?? "").toUpperCase() === "AU");
  console.log(`AU courses: ${au.length}`);

  const withGca = courses.filter((c) => c.external_ids?.golfcourseapi);
  console.log(`With golfcourseapi id: ${withGca.length}`);

  printSection("Coverage gaps (action list)");
  const geoOnly = courses.filter((c) => c.coverage_level === "geo_only");
  const partial = courses.filter((c) => c.coverage_level === "partial_scorecard");
  console.log(`geo_only: ${geoOnly.length}`);
  if (geoOnly.length > 0 && geoOnly.length <= 25) {
    for (const c of geoOnly) console.log(`  - ${c.name} (${c.source})`);
  } else if (geoOnly.length > 25) {
    for (const c of geoOnly.slice(0, 15)) console.log(`  - ${c.name}`);
    console.log(`  … and ${geoOnly.length - 15} more`);
  }
  console.log(`partial_scorecard: ${partial.length}`);

  // Tee sprawl: fetch all tees with hole counts via embed
  const detailed = await restGet(
    "courses?select=id,name,coverage_level,source,course_tees(id,label,color_hint,course_rating,slope_rating,course_tee_holes(hole_number))&order=name.asc",
  );

  const teeStats = detailed.map((c) => {
    const tees = c.course_tees ?? [];
    const labels = tees.map((t) => ({
      label: t.label ?? "?",
      color: t.color_hint ?? "",
      holes: (t.course_tee_holes ?? []).length,
      rating: t.course_rating,
      slope: t.slope_rating,
    }));
    return {
      id: c.id,
      name: c.name,
      coverage: c.coverage_level,
      teeCount: labels.length,
      labels,
    };
  });

  const withTees = teeStats.filter((c) => c.teeCount > 0);
  const noTees = teeStats.filter(
    (c) =>
      c.teeCount === 0 &&
      (c.coverage === "full_scorecard" || c.coverage === "partial_scorecard"),
  );

  printSection("Tee counts");
  const buckets = [
    ["0 tees (but scorecard coverage)", noTees.length],
    ["1–3 tees", withTees.filter((c) => c.teeCount <= 3).length],
    ["4–6 tees", withTees.filter((c) => c.teeCount >= 4 && c.teeCount <= 6).length],
    ["7–10 tees", withTees.filter((c) => c.teeCount >= 7 && c.teeCount <= 10).length],
    ["11+ tees", withTees.filter((c) => c.teeCount >= 11).length],
  ];
  for (const [label, n] of buckets) console.log(`  ${label}: ${n}`);

  printSection("Tee sprawl (most tees first)");
  const sprawl = [...withTees].sort((a, b) => b.teeCount - a.teeCount).slice(0, 12);
  for (const c of sprawl) {
    console.log(`\n${c.name} — ${c.teeCount} tees (${c.coverage})`);
    for (const t of c.labels.slice(0, 14)) {
      const meta = [
        t.color ? `color=${t.color}` : null,
        `${t.holes} holes`,
        t.rating != null ? `CR ${t.rating}` : null,
        t.slope != null ? `slope ${t.slope}` : null,
      ]
        .filter(Boolean)
        .join(", ");
      console.log(`  · "${t.label}" (${meta})`);
    }
    if (c.labels.length > 14) console.log(`  … +${c.labels.length - 14} more`);
  }

  printSection("Unfriendly label patterns (sample)");
  const ugly = /^\d+$|combo|front|back|medal|temporary|temp|junior|juniors|senior|member/i;
  let shown = 0;
  for (const c of withTees) {
    for (const t of c.labels) {
      if (ugly.test(t.label) || t.label.length > 28) {
        console.log(`  ${c.name}: "${t.label}"`);
        shown++;
        if (shown >= 25) break;
      }
    }
    if (shown >= 25) break;
  }
  if (shown === 0) console.log("  (none matched heuristics — review sprawl list above)");

  printSection("Spot-check commands");
  console.log("  node search.mjs --detail <uuid>");
  console.log("  node search.mjs \"joondalup\"");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

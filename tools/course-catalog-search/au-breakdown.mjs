#!/usr/bin/env node
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const envPath = join(__dirname, ".env");
if (existsSync(envPath)) {
  for (const line of readFileSync(envPath, "utf8").split(/\r?\n/)) {
    const t = line.trim();
    if (!t || t.startsWith("#")) continue;
    const eq = t.indexOf("=");
    if (eq <= 0) continue;
    const k = t.slice(0, eq).trim();
    let v = t.slice(eq + 1).trim();
    if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
      v = v.slice(1, -1);
    }
    if (process.env[k] === undefined) process.env[k] = v;
  }
}

const url = process.env.SUPABASE_URL?.replace(/\/$/, "");
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
const courses = await fetch(
  `${url}/rest/v1/courses?select=name,source,coverage_level,region,locality&country_code=eq.AU&order=name.asc`,
  { headers: { apikey: key, Authorization: `Bearer ${key}` } },
).then((r) => r.json());

const bySrc = {};
for (const c of courses) {
  (bySrc[c.source] ??= []).push(c);
}

console.log("AU by source:");
for (const [s, arr] of Object.entries(bySrc)) console.log(`  ${s}: ${arr.length}`);

console.log(`\nAU provider (${bySrc.provider?.length ?? 0}):`);
for (const c of bySrc.provider ?? []) {
  console.log(`  - ${c.name}${c.region ? ` (${c.region})` : ""}`);
}

console.log(`\nAU osm (${bySrc.osm?.length ?? 0}):`);
for (const c of bySrc.osm ?? []) console.log(`  - ${c.name}`);

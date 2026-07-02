import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(__dirname, "..", "..");

const ENV_CANDIDATES = [
  join(process.cwd(), ".env"),
  join(repoRoot, "tools", "round-analysis", ".env"),
  join(repoRoot, "tools", "course-catalog-search", ".env"),
  join(repoRoot, ".env"),
];

function parseEnvFile(text) {
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

export function loadSupabaseEnv() {
  for (const path of ENV_CANDIDATES) {
    if (!existsSync(path)) continue;
    parseEnvFile(readFileSync(path, "utf8"));
  }
}

const ENV_TEMPLATE_MARKERS = /YOUR_PROJECT_REF|YOUR_SERVICE_ROLE_KEY_HERE/i;

export function getSupabaseRestConfig() {
  loadSupabaseEnv();
  const rawUrl = process.env.SUPABASE_URL?.trim();
  const url = rawUrl?.replace(/\/$/, "");
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
  const missing =
    !url ||
    !key ||
    ENV_TEMPLATE_MARKERS.test(rawUrl ?? "") ||
    ENV_TEMPLATE_MARKERS.test(key ?? "");
  if (missing) {
    throw new Error(
      "Missing SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY. " +
        "Set shell env or create tools/course-catalog-search/.env (see tools/round-analysis/README.md).",
    );
  }
  return { url, key };
}

export async function supabaseRestGet(pathAndQuery, { url, key }) {
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
    const detail = typeof body === "object" ? JSON.stringify(body) : body;
    throw new Error(`Supabase REST ${res.status}: ${detail}`);
  }
  return body;
}

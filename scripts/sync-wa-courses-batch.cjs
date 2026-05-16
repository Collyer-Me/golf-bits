#!/usr/bin/env node
/**
 * Batch-invokes Edge Function `sync-course-by-name` for WA starter courses.
 *
 * Requires (env):
 *   SUPABASE_URL                 — e.g. https://xxxx.supabase.co
 *   SUPABASE_SERVICE_ROLE_KEY    — service role JWT (Dashboard → Settings → API)
 *
 * Optional:
 *   SUPABASE_ANON_KEY            — sent as `apikey` if set (some gateways expect it)
 *   SYNC_DELAY_MS                — ms between calls (default 800)
 *   SYNC_MAX_UPSERTS             — maps to maxUpserts (default 5)
 *   SYNC_MAX_SEARCH_CANDIDATES   — maps to maxSearchCandidates (default 18)
 *   SYNC_MIN_NAME_MATCH          — e.g. 0.48 (default: server DEFAULT_MIN_NAME_MATCH)
 *   DRY_RUN                      — set to "1" to print payloads only
 *
 * Usage (repo root):
 *   node scripts/sync-wa-courses-batch.cjs
 *
 * Or: npm run sync-wa-courses
 */

const fs = require('fs');
const path = require('path');

const LIST_PATH = path.join(__dirname, 'wa-courses-batch.json');

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function main() {
  const supabaseUrl = (process.env.SUPABASE_URL || '').replace(/\/+$/, '');
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
  const anonKey = process.env.SUPABASE_ANON_KEY || '';
  const delayMs = Math.max(0, parseInt(process.env.SYNC_DELAY_MS || '800', 10) || 800);
  const maxUpserts = Math.min(10, Math.max(1, parseInt(process.env.SYNC_MAX_UPSERTS || '5', 10) || 5));
  const maxSearchCandidates = Math.min(25, Math.max(1, parseInt(process.env.SYNC_MAX_SEARCH_CANDIDATES || '18', 10) || 18));
  const minNameRaw = process.env.SYNC_MIN_NAME_MATCH?.trim();
  const minNameMatchOpt =
    minNameRaw != null && minNameRaw !== '' && Number.isFinite(Number(minNameRaw))
      ? Number(minNameRaw)
      : null;
  const dryRun = process.env.DRY_RUN === '1';

  if (!dryRun && (!supabaseUrl || !serviceKey)) {
    console.error(
      'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY. Set them in the environment (never commit keys).',
    );
    process.exit(1);
  }

  const raw = fs.readFileSync(LIST_PATH, 'utf8');
  /** @type {string[]} */
  const queries = JSON.parse(raw);
  if (!Array.isArray(queries) || queries.some((q) => typeof q !== 'string')) {
    console.error('wa-courses-batch.json must be a JSON array of strings.');
    process.exit(1);
  }

  const endpoint = `${supabaseUrl}/functions/v1/sync-course-by-name`;

  console.error(`Courses to sync: ${queries.length}`);
  if (dryRun) {
    const payloadBase = {
      countryHint: 'AU',
      strictCountry: false,
      maxUpserts,
      maxSearchCandidates,
      ...(minNameMatchOpt != null ? { minNameMatch: minNameMatchOpt } : {}),
    };
    for (const query of queries) {
      console.log(JSON.stringify({ query, ...payloadBase }));
    }
    return;
  }

  /** @type {Record<string, string>} */
  const headers = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${serviceKey}`,
  };
  if (anonKey) headers.apikey = anonKey;

  let ok = 0;
  let partial = 0;

  for (let i = 0; i < queries.length; i++) {
    const query = queries[i];
    const body = JSON.stringify({
      query,
      countryHint: 'AU',
      strictCountry: false,
      maxUpserts,
      maxSearchCandidates,
      ...(minNameMatchOpt != null ? { minNameMatch: minNameMatchOpt } : {}),
    });

    process.stderr.write(`\n[${i + 1}/${queries.length}] ${query}\n`);

    const res = await fetch(endpoint, { method: 'POST', headers, body });
    const text = await res.text();
    let json;
    try {
      json = JSON.parse(text);
    } catch {
      console.error(`  HTTP ${res.status} (non-JSON): ${text.slice(0, 500)}`);
      partial++;
      await sleep(delayMs);
      continue;
    }

    if (!res.ok) {
      console.error(`  HTTP ${res.status}:`, json);
      partial++;
      await sleep(delayMs);
      continue;
    }

    const count = typeof json.count === 'number' ? json.count : 0;
    const synced = Array.isArray(json.synced) ? json.synced : [];
    console.error(`  synced rows: ${count}`);
    for (const row of synced) {
      const name = row && typeof row === 'object' ? row.name : '';
      const id = row && typeof row === 'object' ? row.id : '';
      console.error(`    - ${name} (${id})`);
    }
    if (count === 0) {
      console.error('  warning: no rows upserted — try a shorter query or check GolfCourseAPI / name match.');
      const diag = json.diagnostics;
      if (diag && Array.isArray(diag.searchPreview) && diag.searchPreview.length > 0) {
        console.error('  provider search preview:', JSON.stringify(diag.searchPreview.slice(0, 5)));
      }
      partial++;
    } else {
      ok++;
    }

    await sleep(delayMs);
  }

  console.error(`\nDone. Courses with at least one sync: ${ok}; with warnings/errors: ${partial}.`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

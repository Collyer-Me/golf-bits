# Round analysis (developer / agent tool)

Read-only access to **`public.rounds`** (and related JSON) for verifying Wolf scoring, settlement, and round data quality — without the Flutter app.

## Security

- Uses **`SUPABASE_SERVICE_ROLE_KEY`** — bypasses RLS and can read **all users' rounds**. Same rules as [`tools/course-catalog-search`](../course-catalog-search/README.md): **never commit** the key, never ship it in the app.
- Intended for **your machine only** (or CI secrets with tight scope).

## Prerequisites

- **Node.js 18+** (global `fetch`; no npm install in this folder).

## Setup (one-time)

You already have credentials if [`tools/course-catalog-search/.env`](../course-catalog-search/.env) is configured. The loader checks, in order:

1. Current working directory `.env`
2. `tools/round-analysis/.env`
3. `tools/course-catalog-search/.env`
4. Repo root `.env`

From Supabase Dashboard → **Settings → API**:

| Variable | Value |
|----------|--------|
| `SUPABASE_URL` | Project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | **service_role** secret (not anon) |

## Commands

From repo root (PowerShell):

```powershell
node tools/round-analysis/list-rounds.mjs --completed --wolf --limit 10
```

```powershell
node tools/round-analysis/audit-wolf.mjs --latest-completed
```

```powershell
node tools/round-analysis/audit-wolf.mjs --id <round-uuid>
```

```powershell
node tools/round-analysis/fetch-round.mjs --id <round-uuid>
```

### What each script does

| Script | Purpose |
|--------|---------|
| `list-rounds.mjs` | Newest rounds: id, course, completed, Wolf hole count |
| `fetch-round.mjs` | Full round row JSON (debug / export) |
| `audit-wolf.mjs` | Replay Wolf rules hole-by-hole; exit `0` = valid, `2` = mismatch |

`audit-wolf.mjs` ports the same logic as `golf_bits/lib/models/wolf_scoring.dart` (`auditWolfRound` in the app).

### Saved audit reports

Human-readable write-ups live in [`reports/`](reports/) (e.g. verified rounds during testing).

Rule reference: [`WOLF_SCORING.md`](WOLF_SCORING.md).

## Cursor / agent usage

When investigating scoring or history bugs, agents should:

1. Confirm `tools/course-catalog-search/.env` (or equivalent) exists locally.
2. Run `node tools/round-analysis/audit-wolf.mjs --latest-completed` (or `--id`).
3. Use the JSON report — do **not** paste service-role keys into chat.

See also **AGENTS.md** → *Data analysis (Supabase)*.

# Course catalog search (developer tool)

Internal-only helper to **search `public.courses` and inspect scorecard rows** (tees, holes, yardages) without going through the Flutter app.

## Security

- Uses **`SUPABASE_SERVICE_ROLE_KEY`** so RLS is bypassed and you see **all** catalog rows (including other users’ private manual courses if any exist). **Never** commit this key, paste it into the mobile app, or expose this script as a public endpoint.
- Intended for **your machine** or CI secrets, same as any admin script.

## Prerequisites

- Node.js **18+** (uses global `fetch`).

## Setup

From repo root (PowerShell example):

```powershell
$env:SUPABASE_URL = "https://YOUR_PROJECT.supabase.co"
$env:SUPABASE_SERVICE_ROLE_KEY = "your-service-role-secret"
```

## Usage

```powershell
cd tools/course-catalog-search
node search.mjs "melbourne"
```

Pretty-printed JSON: matching courses (name / subtitle / locality `ilike`).

```powershell
node search.mjs --detail "b1111111-1111-4111-8111-111111111101"
```

Loads that course with **nested** `course_tees` → `course_tee_holes` (par, stroke index, yardage per tee) so you can judge **data quality** (coverage_level, par grid by tee, ratings_json).

### Options

| Flag | Meaning |
|------|---------|
| (positional) | Search string; default `""` lists first 40 courses by name. |
| `--detail <uuid>` | Fetch one course with embeds (ignores positional search). |
| `--limit <n>` | Max rows for list mode (default `40`, max `100`). |

## What this does *not* do (yet)

- It does **not** call GolfCourseAPI or other external tiers; it only reads **your Supabase catalog**. Use it to validate seeds, migrations, and future ETL/Edge writes. External API smoke tests belong in Postman or a separate script keyed with `GOLFCOURSEAPI_KEY` etc.

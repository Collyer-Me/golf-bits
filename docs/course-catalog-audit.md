# Course catalog — audit checklist

Use this before changing providers or ingest. Replace placeholders with findings.

## Quick audit (local)

From `tools/course-catalog-search` with `.env` set (see [README](../tools/course-catalog-search/README.md)):

```powershell
node audit.mjs
node search.mjs "" --limit 100
node search.mjs --detail <course-uuid>
```

## Quick audit (Supabase SQL Editor)

Run these in the Dashboard → SQL Editor.

## Ops (Supabase Dashboard)

- [ ] Edge secret `GOLFCOURSEAPI_KEY` is set (Project Settings → Edge Functions → Secrets).
- [ ] Optional `GOLFCOURSEAPI_BASE_URL` if not using `https://api.golfcourseapi.com`.
- [ ] Functions deployed: `search-courses`, `get-course-detail`, `sync-course-by-name`.
- [ ] Edge logs: typical `search-courses` duration after slim-search deploy.

## Telemetry queries (SQL Editor)

Recent events:

```sql
select kind, payload, created_at
from course_data_telemetry
where kind in ('search', 'provider_error', 'cache_hit', 'search_miss', 'course_hydrate')
order by created_at desc
limit 50;
```

Catalog summary:

```sql
select source, coverage_level, country_code, count(*) as n
from courses
group by 1, 2, 3
order by n desc;
```

Hole coverage for a course name:

```sql
select c.name, c.source, c.coverage_level, c.external_ids,
       count(distinct t.id) as tees,
       count(h.id) as tee_holes
from courses c
left join course_tees t on t.course_id = c.id
left join course_tee_holes h on h.course_tee_id = t.id
where c.name ilike '%YOUR_QUERY%'
group by c.id;
```

Tee sprawl (courses with many tee rows):

```sql
select c.name, c.coverage_level, c.source,
       count(t.id) as tee_count,
       string_agg(t.label, ' | ' order by t.sort_order) as tee_labels
from courses c
join course_tees t on t.course_id = c.id
group by c.id, c.name, c.coverage_level, c.source
having count(t.id) >= 7
order by tee_count desc, c.name;
```

Scorecard rows but zero tees (hydrate failed or bad ingest):

```sql
select c.id, c.name, c.coverage_level, c.source, c.external_ids
from courses c
where c.coverage_level in ('full_scorecard', 'partial_scorecard')
  and not exists (select 1 from course_tees t where t.course_id = c.id);
```

## Target courses (spot-check 10–15)

| Course searched | Coverage | Tees in DB | Tees shown in app | Tee labels OK? | Par on hole 1 |
|-----------------|----------|------------|-------------------|----------------|---------------|
| | | | | | |

## Tee display review

**Symptom:** Some courses show many tee options with cryptic names.

**Root cause (ingest):** `normalizeTees` in `gca-course-sync.ts` merges **all** `tees.male` + `tees.female` (and legacy group keys) into one flat list. GolfCourseAPI often returns 8–16+ variants: men's/women's, 9-hole combos, multiple colors, duplicate names with different ratings.

**Root cause (display):** `prepareTeesForDisplay` only dedupes exact `label|colorHint` matches and drops empty tees. It does **not** cap count, merge by color family, or map to friendly names. The tee picker shows raw `CourseTeeOption.label`.

**What to log during spot-check:**

- Tee count in DB vs after `prepareTeesForDisplay` (usually same unless exact dupes)
- Labels like numeric IDs, "Combination", "Front 9", very long strings
- Whether men's standard tees (Blue/White/Red) are buried below obscure rows

**Fix options (after audit — pick one):**

Implemented: **`tee_label_normalize.dart`** + **`tee-label-normalize.ts`** (keep in sync). Rules apply at **ingest** (new GCA syncs) and **display** (existing DB rows).

| Rule | Effect |
|------|--------|
| One tee per color + gender family | Drops NOV21 / TEMP / 9-hole SP duplicates |
| Friendly label | `Blue (Men)` only when men + women both shown |
| OSM fallback | Off for user search (`allowOsmFallback` service-role only) |
| `countryHint: AU` | Sent from Flutter on every search |

Legacy options if gaps remain:

## Failure modes (top 5 after audit)

1.
2.
3.
4.
5.

## Batch ingest (`sync-course-by-name`)

Pre-seed or repair catalog rows without app releases:

1. Confirm Edge secrets (`GOLFCOURSEAPI_KEY`, service role available to functions).
2. Deploy `sync-course-by-name` with the repo CLI workflow (`functions deploy`) after changes.
3. Invoke via Dashboard test payload or authenticated POST with JSON such as `{ "query": "Royal Melbourne Golf Club", "countryHint": "AU", "maxResults": 3 }`. Tune strings against provider hits before bulk runs.

**Western Australia starter pack:** after `sync-course-by-name` is deployed and `GOLFCOURSEAPI_KEY` is set on Edge Functions, run from repo root (with env vars — do not commit secrets):

`npm run sync-wa-courses`

Course names live in [`scripts/wa-courses-batch.json`](../scripts/wa-courses-batch.json); see header comments in [`scripts/sync-wa-courses-batch.cjs`](../scripts/sync-wa-courses-batch.cjs). The function accepts **`maxSearchCandidates`** (how deep to walk provider search hits), **`maxUpserts`** / legacy **`maxResults`**, and optional **`minNameMatch`** — tuned so everyday/Google-style names still match canonical provider titles after deploy.

## Telemetry kinds (quick reference)

| Kind | Notes |
|------|--------|
| `search` | Payload can include `timedOut`, `budgetMs`, provider sync counters |
| `course_hydrate` | On-demand GolfCourseAPI sync from `get-course-detail` |
| `cache_hit` | Detail reads; includes `hydrateAttempted` / `hydratedOk` when applicable |

## Decision

- [ ] Stay on GolfCourseAPI + wiring fixes (hydrate on detail, slim search).
- [ ] Evaluate alternate provider (document why).

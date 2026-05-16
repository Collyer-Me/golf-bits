# Course catalog — audit checklist

Use this during Phase 0 research. Replace placeholders with findings.

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

## Target courses (spot-check 10–15)

| Course searched | Result coverage | Tees in setup | Par on hole 1 |
|-----------------|-----------------|---------------|---------------|
| | | | |

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

# Deploy Edge Functions without the Supabase CLI

Use this when you cannot run `supabase functions deploy` on your machine. Each function is a **single file** (`index.ts`) with CORS helpers inlined so you can paste into the Dashboard.

## What you deploy

| Function name (exact) | File in repo |
|----------------------|--------------|
| `search-courses` | [supabase/functions/search-courses/index.ts](../supabase/functions/search-courses/index.ts) |
| `get-course-detail` | [supabase/functions/get-course-detail/index.ts](../supabase/functions/get-course-detail/index.ts) |
| `sync-course-by-name` | [supabase/functions/sync-course-by-name/index.ts](../supabase/functions/sync-course-by-name/index.ts) |

The Flutter app calls `search-courses` + `get-course-detail`. `sync-course-by-name` is an internal admin helper for provider ingest testing.

## Steps (Supabase Dashboard)

1. Open [Supabase Dashboard](https://supabase.com/dashboard) → your **project**.
2. Go to **Edge Functions** (left sidebar).
3. **Create / new function** (wording varies by UI).
4. Set the function **name** to exactly `search-courses` (with the hyphen).
5. Open the repo file `supabase/functions/search-courses/index.ts`, copy **all** contents, paste into the editor, **Deploy / Save**.
6. Repeat for **`get-course-detail`** using `supabase/functions/get-course-detail/index.ts`.
7. Repeat for **`sync-course-by-name`** using `supabase/functions/sync-course-by-name/index.ts`.

### JWT

These functions expect a logged-in user (`Authorization: Bearer <user JWT>`). In the Dashboard, if there is a **“Verify JWT”** / **“Enforce JWT”** toggle, leave it **on** so anonymous clients cannot abuse the endpoints. This matches [supabase/config.toml](../supabase/config.toml) (`verify_jwt = true`).

### Secrets / env

On hosted Supabase, Edge Functions typically receive **`SUPABASE_URL`**, **`SUPABASE_ANON_KEY`**, and **`SUPABASE_SERVICE_ROLE_KEY`** automatically.  

You should manually add this custom secret in Dashboard → Edge Functions → Secrets:

- `GOLFCOURSEAPI_KEY` = your provider API key

Optional custom secret:

- `GOLFCOURSEAPI_BASE_URL` (defaults to `https://api.golfcourseapi.com`)

You do **not** need to paste your **anon** or **service** keys into the function body.

### CORS

Functions respond with `Access-Control-Allow-Origin: *` for simple browser/tooling use. Adjust if you lock down origins later.

## Verify after deploy

- **Dashboard:** Edge Functions → select each function → **Invoke** or **Logs** (if available).
- **Local tool:** From the repo, [tools/course-catalog-search](../tools/course-catalog-search/README.md) with `SUPABASE_URL` + service role still tests **PostgREST** directly; to test functions specifically, use `curl` or the app with a valid user session.

Example `curl` (replace placeholders; use a **real** user access token from your app or Auth):

```http
POST https://YOUR_PROJECT.supabase.co/functions/v1/search-courses
Authorization: Bearer USER_JWT
apikey: YOUR_ANON_KEY
Content-Type: application/json

{"query":"","includeRemote":false}
```

Provider sync test (admin helper):

```http
POST https://YOUR_PROJECT.supabase.co/functions/v1/sync-course-by-name
Authorization: Bearer USER_JWT
apikey: YOUR_ANON_KEY
Content-Type: application/json

{"query":"royal melbourne","maxResults":3}
```

Country-focused sync example (no hard-coded country in function):

```http
POST https://YOUR_PROJECT.supabase.co/functions/v1/sync-course-by-name
Authorization: Bearer USER_JWT
apikey: YOUR_ANON_KEY
Content-Type: application/json

{"query":"royal melbourne","maxResults":5,"countryHint":"AU"}
```

For Dashboard testing, this function now accepts either:

- normal user JWT auth (`Authorization: Bearer <user_jwt>`), or
- service-role invocation (`apikey` or bearer token equals service role key).

So the Dashboard test modal can run it using the **service role** option while you are validating ingest.

## When you get CLI access later

From the repo root you can deploy both in one go:

```bash
supabase functions deploy search-courses
supabase functions deploy get-course-detail
supabase functions deploy sync-course-by-name
```

The same `index.ts` files are used.

# Pre-Beta Audit — Bits Dots Junk (golf-bits)

Date: 2026-07-02. Read-only analysis of the full repo: Flutter app (`golf_bits/`), Supabase migrations & edge functions (`supabase/`), CI (`.github/workflows/`), scripts, and docs. Four parallel deep-dives were run: security, backend/data correctness, Flutter app quality, and release/ops readiness. Nothing was modified.

Severity legend: **P0** = fix before beta invite goes out. **P1** = fix before beta or in week 1 (gets worse with user count). **P2** = fix during beta. **P3** = note for later.

---

## P0 — Fix before beta

### 1. `profiles.email` is client-writable and used for authorization → invite-token theft & identity hijack
**Where:** `supabase/migrations/20260412130000_profiles_and_rounds.sql:22-24`, `20260506190000_round_email_invites.sql:46-54,107-109`, `20260504140000_claim_participant_identity.sql`, `golf_bits/lib/auth/profile_bootstrap.dart:22-26`
**Why:** The `profiles_update_own` policy has no column restriction, so any user calling Supabase directly can set `profiles.email` to any address — nothing ties it to the verified `auth.users` email. That spoofed email is then trusted by: (a) the round-invites SELECT policy, which reveals the invite row **including its secret token** to anyone whose profile email matches; (b) `accept_round_invite_for_current_user`, which authorizes acceptance by profile email; (c) `claim_participant_identity_for_current_user`, which links the caller's `user_id` into any round participant slot with a matching email. Attack: set your profile email to the victim's, read their pending invite token, accept it and claim their participant identity.
**Fix:** Never let clients write `email` — populate it only from the `handle_new_user` trigger (column-level privilege revoke, or drop `email` from `profiles`). In the invite/claim RPCs and policies, compare against `auth.jwt()->>'email'` (verified by Supabase) instead of `profiles.email`.

### 2. `search_friend_candidates` allows mass harvesting of every user's email
**Where:** `supabase/migrations/20260422112000_friendships.sql:69-87`
**Why:** SECURITY DEFINER RPC granted to `authenticated`, matching a ≥2-char substring against `display_name` **or `email`**, and returning the email. Iterating short substrings (`aa`, `ab`, `@gmail`, …) dumps the entire user base's names + emails. Because anonymous sign-ins are enabled, even a drive-by visitor can mint a guest JWT and run it. Related: `lookup_player_by_email` (`20260416210000_participants_identity_support.sql:113-140`) is an account-existence oracle returning `user_id` + `display_name` + `email` to guests.
**Fix:** Never return `email` from search results; match on `display_name` only (email exact-match only, if product requires it); raise the minimum query length; gate both RPCs behind `auth.jwt()->>'is_anonymous' = 'false'`.

### 3. In-round state can be lost — no local persistence, and Wolf sync hard-blocks offline
**Where:** `golf_bits/lib/screens/hole_scoring_screen.dart:380-417`, `wolf_call_screen.dart:105-117`, `wolf_score_hole_screen.dart:133-238`, `lib/data/wolf_round_sync.dart:47-100`
**Why (three compounding problems, found independently by two audits):**
- All in-round state (`_bitLog`, hole scores, totals) lives only in widget memory. Local rounds (guest without cloud consent, or failed sync bootstrap) are lost entirely on a browser refresh or tab close — the worst possible beta experience for a scoring app.
- Bits-screen cloud writes are try/caught with `catch (_) {}` — good for responsiveness, but there is **zero user feedback** that sync is failing, so a round played through a dead zone silently resumes from the last successful write. The Wolf screens are worse: `await WolfRoundSync.persist(...)` runs with **no try/catch before navigation**, so offline, "Score the hole"/"Next hole" throws an unhandled async exception and the button silently does nothing — the round is stuck.
- Hydrate-on-resume rebuilds totals from `round_bit_events` **only** and then persists the rebuilt (lower) totals back. If an event insert failed offline but the progress update succeeded, the award is silently and permanently deleted from both places.
**Fix:** (a) Snapshot round state as JSON to `shared_preferences` (already a dependency) on every mutation; offer "resume round" on launch. (b) Wrap all Wolf persist calls in try/catch matching `HoleScoringScreen`, navigate optimistically, retry in background. (c) Buffer unsent bit events and replay them before hydrate (or merge instead of overwrite). (d) Add a small "sync failing" indicator.

### 4. Zero observability: no crash reporting, error logging, analytics, or feedback channel
**Where:** `golf_bits/lib/main.dart` (no `runZonedGuarded`/`FlutterError.onError`), `pubspec.yaml` (no reporting dep)
**Why:** In beta, an uncaught exception on a tester's phone is invisible. There's no version string in the UI either (see item 13), so "it's broken" reports carry no context.
**Fix:** Add `sentry_flutter` (works on Flutter web; free tier suffices) wrapping `main()` — or minimum-viable, a global error handler posting to a Supabase `client_errors` table. Add a "Send feedback" affordance (mailto or Supabase insert) that attaches app version + URL.

### 5. `send-round-invite` function: localhost email links, phishing/abuse vectors, undocumented deploy
**Where:** `supabase/functions/send-round-invite/index.ts:67,97-169`, `supabase/config.toml`, `docs/manual-edge-function-deploy.md`
**Why (bundle of related issues on one function):**
- `APP_BASE_URL` defaults to `http://localhost:3000` — unless that secret is set on the hosted project, every invite email contains a dead localhost link. The function's required secrets (`RESEND_API_KEY`, `INVITE_FROM_EMAIL`, `APP_BASE_URL`) are documented nowhere, the function is missing from `manual-edge-function-deploy.md` (which lists only 3 of 4 functions) and from `config.toml`'s `verify_jwt` entries.
- Client-supplied `courseName` is interpolated **unescaped** into the email HTML — an attacker who owns a round can send arbitrary phishing HTML from your verified sending domain to arbitrary addresses.
- No cap on the `invites` array and no per-user rate limit; anonymous guests can also mint JWTs — unlimited email sending through your Resend account.
- No unique constraint on `(round_id, invited_email)`, tokens never expire, and the accept RPC ignores `status` — invites can be re-created, re-sent, and re-accepted forever.
**Fix:** Set `APP_BASE_URL` on the hosted project now; document all four functions + secrets; HTML-escape user text (prefer server-side `round.course_name`); cap invites per request (≤10) and per user/day; restrict sending to non-anonymous accounts; unique index + upsert on `(round_id, lower(invited_email))`; add `expires_at` and a `status <> 'accepted'` guard.

### 6. One Supabase project, no backups verified, no rollback story
**Where:** whole-repo (single `SUPABASE_URL` secret; 19 forward-only migrations, several `*_compat.sql`; no restore runbook)
**Why:** Beta testers and dev work share one database. If a data-corrupting bug ships, recovery depends on Supabase's tier-dependent automated backups — currently unverified and undocumented. A bad `db push` is likewise irreversible.
**Fix:** Confirm the backup tier / enable PITR or schedule `supabase db dump` snapshots; write a 10-line restore runbook in `docs/`. Ideally add a second free Supabase project as staging and point dev/PR work at it.

---

## P1 — Scale & performance (degrade linearly-or-worse with user count)

### 7. Every hole save fires a table-wide trigger seq-scan via `ended_at`
**Where:** `golf_bits/lib/data/history_repository.dart:268`, `supabase/migrations/20260429153000_round_coplayer_links.sql:266-273`
**Why:** `updateRoundProgress` writes `ended_at = now()` on **every** progress save (every hole, every bits tap). `ended_at` is in the coplayer-links trigger's `update of` column list, so each save runs a full rebuild — starting with `delete from round_coplayer_links where round_id = ...` on a table with **no `round_id` index** (seq scan + jsonb re-parse per hole per active round). Separately, writing `ended_at` for in-progress rounds also corrupts its meaning as a completion timestamp for anything downstream.
**Fix:** Add `create index on round_coplayer_links (round_id);` immediately. Move the per-hole activity timestamp to a new `last_activity_at` column (outside the trigger list) and stop touching `ended_at` until the round actually ends.

### 8. `claim_participant_identity_for_current_user()` scans every round in the DB — on every app launch
**Where:** `supabase/migrations/20260504140000_claim_participant_identity.sql:31-34`, called from `profile_bootstrap.dart:32` on every auth state change
**Why:** The RPC loops over `select id, participants from public.rounds` with no filter, jsonb-re-aggregating each row. Cost is O(total rounds × active users) and grows during beta.
**Fix:** Filter candidate rounds in SQL (`participants @> ...` with a GIN index on `rounds.participants`, or an email jsonb-path predicate), and/or run once per user via a profile flag instead of every launch.

### 9. Permanent "missing column" retry tax on every round insert/update
**Where:** `golf_bits/lib/data/history_repository.dart:45-56,176-183,213-247,264`, `lib/models/round_result.dart:126-127`
**Why:** The client always sends columns the canonical schema doesn't have (`status`, `holes`, `user_id`, `owner_id`); `_insertRoundWithFallback` strips one column per failed request by regex-matching the PostgREST error string, never memoizing. On the canonical schema, round creation costs ~5 sequential round-trips and **every hole save costs 2**. It also breaks entirely if PostgREST rewords its error.
**Fix:** Build payloads from `SchemaCompatibilityService.detectedColumns` (already fetched at round start), or at minimum cache the stripped-column set per session. Longer term, see item 17: consolidate to one canonical schema and delete the fallbacks.

### 10. Home/history round queries are unordered with hard limits
**Where:** `history_repository.dart:103-107,136-140`
**Why:** `.eq('created_by', uid).limit(80)` with no `.order()` returns arbitrary physical order; past 80 rounds, "latest/active round" on the home screen can be picked from the wrong subset (a live round vanishes). `select()` also drags full jsonb blobs (`wolf_hole_results`, `standings`, …) for 80 rows to display 2.
**Fix:** `.order('ended_at', ascending: false)` (the `rounds_created_by_ended_at_idx` index already exists for it), select only needed columns, add pagination to `fetchMyRounds`.

---

## P2 — Fix during beta

### 11. Friendship flow: requester can self-accept; declined pairs dead-end forever
**Where:** `supabase/migrations/20260422112000_friendships.sql:43-47`, `golf_bits/lib/data/friends_repository.dart:71-99`
**Why:** The update policy only checks the caller is a participant, so the **requester** can flip `status` to `accepted` without consent (and either party can rewrite row fields). Client-side, a `declined` row is never reset and the unique pair index blocks re-inserting — the pair can never re-request. The check-then-insert also races (unhandled `23505` on simultaneous mutual requests).
**Fix:** Restrict acceptance to the addressee (trigger comparing OLD/NEW, or a SECURITY DEFINER RPC for transitions); on `declined`, update the row back to `pending` with swapped requester; catch unique-violations.

### 12. Course provider sync can save "full scorecard" courses with zero holes
**Where:** `supabase/functions/_shared/gca-course-sync.ts:443,555-567`
**Why:** Hole rows are filtered for par/hole-number but not `stroke_index` (DB CHECK 1–18; providers send 0 or >18) or `yardage_yds` (CHECK >0; the metre conversion can yield 0). One bad hole fails the whole batch insert **after** the old holes were deleted, and the insert error is unchecked — tee saved with 0 holes while `coverage_level` was already computed as `full_scorecard`. Delete-then-insert is also non-transactional.
**Fix:** Clamp/null out-of-range values in `normalizeHoles`, check insert errors, recompute coverage after writes (or upsert instead of delete+insert).

### 13. CI/versioning: unpinned Flutter, static version, stale service-worker builds
**Where:** `.github/workflows/flutter-web-gh-pages.yml:37-41`, `golf_bits/pubspec.yaml:4`, `golf_bits/web/index.html`
**Why:** CI is the **only** place this code compiles (no local Flutter SDK), yet `channel: stable` is unpinned — a Flutter release can break all deploys overnight (commit history already shows analyzer-fix loops). Version is a static `1.0.0+1` with no in-app display, and the default Flutter service worker serves returning testers the **previous** build on first load — so "the bug is still there" reports may be against yesterday's build with no way to tell.
**Fix:** Pin `flutter-version:`; pass `--dart-define=BUILD_SHA=${{ github.sha }}` and show it on the profile screen; bump the pubspec version per beta drop; optionally add a "new version available — refresh" prompt via `flutter_bootstrap.js`.

### 14. No CI for the backend; deploy state invisible
**Where:** `.github/workflows/` (Flutter-only), `docs/manual-edge-function-deploy.md`, `.cursor/rules/bits-supabase-cli.mdc`
**Why:** Frontend auto-deploys on push; migrations and functions are deployed by hand with no record of what's live. The runtime drift-detection service mitigates but doesn't prevent split-brain (and per item 17, it usually degrades to a warning anyway).
**Fix:** Add a second workflow job (paths `supabase/**`) running `supabase db push` + `supabase functions deploy` with `SUPABASE_ACCESS_TOKEN` secrets, making `main` the source of truth.

### 15. Bits standings resolve ties arbitrarily
**Where:** `golf_bits/lib/models/round_result.dart:75-101`
**Why:** `winnerName = sorted.first.name` — with equal bits, the "winner" depends on input order; the tied player at index 1 shows rank 2. (Money settlement handles ties correctly; the standings/`winner_name` do not.) No test covers ties in `fromSessionScores`.
**Fix:** Detect ties and mark all tied players as winners (or explicit "Tied"); add the test.

### 16. Tests for the fragile paths
**Where:** `golf_bits/test/` (17 files, ~73 cases — scoring/settlement math genuinely well covered)
**Why:** The riskiest code is untested: hydrate/replay (`WolfRoundSync`, the award-loss path in item 3), `HistoryRepository`'s regex column-stripping loops, `_startRound`, `RoundResult` ties, resume via `RoundSessionArgs.fromHistoryRound`, and all edge functions (no Deno tests). Static repositories with hard `Supabase.instance` references currently make these untestable without refactoring.
**Fix:** Introduce an injectable client seam for `HistoryRepository`/`WolfRoundSync`, then cover hydrate-replay and the fallback loops first.

### 17. The schema-compat layer institutionalizes drift — consolidate it
**Where:** `golf_bits/lib/data/schema_compatibility_service.dart`, `round_coplayers.dart:70-77`, several SQL functions branching on `information_schema` at execution time
**Why:** Runtime probing + conditional migrations + client column-stripping means every feature must be written against a schema *set*, not a schema; two environments can converge to permanently different shapes. The PostgREST `information_schema` probe usually isn't granted, so the check mostly degrades to `ok: true` — it doesn't actually protect you. Five `*_compat.sql` migrations are already accumulated tech debt.
**Fix:** For a single-project beta, pick the canonical schema, write one consolidation migration, and delete the fallbacks (which also removes item 9 permanently).

### 18. Repo/docs hygiene
**Where:** root `.gitignore:2`, `README.md`, `docs/`
**Why:** `docs/` is gitignored but four files were force-added — new docs silently don't commit, and key specs (`WOLF_GAME.md`, `HOLE_SCORING_SCREEN.md`, `platform-architecture-brief-FINAL.md`) exist **only on one machine** with no backup. The README quick-start (`flutter run`) contradicts the actual CI-only workflow and will wall a new dev.
**Fix:** Replace the blanket `docs/` ignore with targeted ignores for binary design-handoff folders; commit the markdown specs; align the README with the push→CI→Pages workflow.

---

## P3 — Smaller items (batch when convenient)

- **`rounds.course_catalog_id` FK has no `on delete` action** (`20260416240000_course_catalog.sql:97`) — deleting a private manual course referenced by a round throws an unhandled FK violation. Use `on delete set null` (rounds snapshot course name/pars anyway).
- **`wolf_game_support` migration under-constrained** (`20260630120000_...sql`) — `wolf_hole_phase` has no CHECK, `handicap` no range check, nullable columns unlike house style. Add `not null` + CHECKs mirroring the stroke-tracking migration.
- **`deleteRound` / `deleteLatestBitEventForRound`** (`history_repository.dart:363-435`) — non-transactional delete-events-then-round; select-then-delete double-tap race. Rely on the `on delete cascade` and add an atomic delete.
- **JWT role check without signature verification** (`search-courses/index.ts:62-108`, `sync-course-by-name/index.ts:26-63`) — safe today only because `verify_jwt = true` at the gateway; compare the bearer against the actual service key instead of decoding the role claim.
- **`search-courses` budget not enforced on hung fetches** — no `AbortController`; telemetry inserts awaited inline add latency to every search.
- **`sync-wa-courses-batch.cjs`** — no fetch timeout (one hung request stalls the batch); exits 0 even when every item fails.
- **`course_provider_cache.expires_at`** written but never read or purged; no index.
- **`ensureCurrentUserProfile` clobbers `display_name`** from auth metadata on every sign-in — will conflict with any future in-app name editing.
- **Hydrate matches legacy events by display name** (`wolf_round_sync.dart:69`) — two same-named players misattribute events; the matching logic is also duplicated (and slightly divergent) with `hole_scoring_screen.dart:149-154`.
- **`strokesReceivedOnHole` caps at 2 strokes/hole** — handicap ≥37 should get 3; no clamp on handicap input either.
- **`buildHoleOrder`** — 9-hole round starting on e.g. 15 produces holes >18; only the UI constrains it.
- **`round_setup_screen.dart` structure** — `_startRound` (~200 lines) mixes consent UI, auth, schema checks, insert, invites, telemetry and navigation; `enabledRules`/`gameConfig` are built twice (cloud insert vs local session) and the `u_${userId}` key convention is re-derived inline 4×. Extract a `RoundStarter` service and shared helpers before this file grows further.
- **`search_friend_candidates` LIKE pattern unescaped for `%`/`_`** and no trigram index — quality/perf at scale (the email exposure part is P0 item 2).
- **Lint level is baseline** — enable `strict-casts` (heavy `as` casting of Supabase rows) and `unawaited_futures`.
- **google_fonts fetched at runtime** — bundle the brand fonts before the PWA/mobile push.
- **Dashboard checks (not in repo, verify once):** email confirmation required for signup; Auth redirect-URL allow-list locked to the Pages origin; Anonymous sign-ins intentionally enabled.

---

## Verified in good shape

- **RLS enabled on all 11 tables**, no `USING (true)` policies, nothing granted to `anon`; owner scoping correct on rounds/events/links/telemetry; all SECURITY DEFINER functions pin `search_path`; internal trigger functions revoked from clients.
- **No secrets committed anywhere** (tracked files, scripts, .cursor rules all checked); anon key via `--dart-define` is by-design safe; `.env` ignored with `.env.example` committed.
- **No SQL injection / SSRF** in edge functions (query builder + `sanitizeIlike`; provider URLs from fixed env vars).
- **Repo hygiene:** clean tree, no `build/`/`node_modules` committed, `pubspec.lock` committed, descriptive commits.
- **CI quality gates real:** analyze + test before build, PRs build without deploying, minimal permissions, pinned actions (except flutter-action version — item 13).
- **Flutter lifecycle discipline excellent:** all controllers/timers/subscriptions disposed, consistent `mounted` checks (~40 verified, no misses).
- **Theme & rebrand:** no hardcoded colors outside `lib/theme/`; user-facing surfaces fully "Bits Dots Junk".
- **Scoring math well tested:** Wolf rotation (incl. holes 17/18 and 9-hole), partner/lone/tie settlements, stroke allocation, tracking — 17 test files.
- **Guest→account promotion** keeps the same uid (no session fixation); pending-link capture ordered correctly before `Supabase.initialize`.
- **Course catalog** has sensible constraints, matching indexes, layered offline fallback, and an accurate DBML doc.

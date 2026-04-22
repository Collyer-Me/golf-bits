# Course data providers

This document drives **which external feeds to wire into the hybrid catalog** (Edge Function + Supabase cache + Flutter). Re-read each vendor’s **current** terms, rate limits, and field definitions before production traffic.

## What matters for Golf Bits (priority order)

1. **Scorecard fidelity:** tee sets, per-hole **par**, **yardage** (or metres), **stroke index** where available, and **course/slope rating** per tee (display in v1; WHS-ready later).
2. **Stable identifiers:** a durable `external_ids` key per provider so you can refresh and dedupe.
3. **Search / discovery:** find the right *layout* (club + course) the player is on.
4. **Location (GPS / address):** useful for maps, “near me,” and marketing—but **not** a substitute for hole/tee data. Treat geo as **supplemental** unless a source proves strong scorecards.

---

## Tier A — Evaluate first (structured scorecard APIs)

### [GolfCourseAPI](https://golfcourseapi.com/) — `api.golfcourseapi.com`

- **Why it is a strong default:** positions itself around **global course coverage** with API access; public materials describe **tee-level** bundles (names, ratings/slope, totals) and **per-hole** par, yardage, and handicap/stroke index style fields—i.e. the same shape your normalized schema targets.
- **Pricing (check live site):** a **free tier with a daily request cap** (order of hundreds/day on the marketing page) and paid tiers for higher limits—not “unlimited free,” but cheap to prototype and low-friction for an AU-first launch if coverage is good enough.
- **Auth:** API key; **must** live server-side (Supabase Edge Function + secrets), never in the Flutter client.
- **Integration fit:** map responses into `courses` / `course_tees` / `course_tee_holes` (par, stroke index, and yardage **per tee per hole**); store raw payloads in `course_provider_cache` when the licence allows, for debugging and re-parsing.

**Docs:** [api.golfcourseapi.com/docs/api](https://api.golfcourseapi.com/docs/api)

### Postman documentation — [Golfio / view 1756312](https://documenter.getpostman.com/view/1756312/UVeDsT2b)

- **Use:** run requests in Postman against **real responses** and compare **field-by-field** to GolfCourseAPI (and to your DB contract): number of tees, hole arrays, AU vs global IDs, null rates for SI/yardage.
- **Clarify in your own notes:** whether this collection documents the **same product** as GolfCourseAPI, a separate **Golfio** product, or an older/alternate stack—do not assume equivalence without matching base URLs, auth, and payload shape.

---

## Tier B — Australia-first supplement

### [Zyla Labs — “Australia golf course finder” API](https://zylalabs.com/api-marketplace/sports/australia+golf+course+finder+api/3176)

- **Why it might help:** explicit **Australia** positioning for an AU-first launch.
- **What to verify before building:** response schema—**club list only** vs **full tee/hole scorecards**; update frequency; whether it is a thin wrapper over another database; pricing and redistribution clauses on the marketplace listing.
- **Fit:** if scorecard depth is weak, treat as **search/names** only and still use Tier A (or Tier C trial) for card data.

---

## Tier C — Paid / marketplace; use for comparison or gap-fill

### [RapidAPI — “Golf Course API” (foshesco)](https://rapidapi.com/foshesco-65zCww9c1y0/api/golf-course-api/pricing)

- **Use:** your suggestion is sound: run a **small, controlled comparison** (same AU clubs across providers) on the **free or trial tier** and measure **hole/tee completeness**, not just row counts.
- **Constraints:** RapidAPI billing, overage behaviour, and whether responses may be **proxied** from another vendor—cache and attribution rules still apply.

---

## Tier D — Not recommended as a live data pipe

### [AllSquare Golf — Australia listings](https://www.allsquaregolf.com/golf-courses/australia)

- **Reality:** page **scraping** is brittle (HTML changes break you), often **legally grey** (site ToS / copyright), and poor for **ongoing updates** (ratings and tees change).
- **If you ever use it:** treat as a **one-off, offline ETL** with legal review, explicit robots/ToS compliance, and a decision to **normalize into your DB**—not something the mobile app or a hot Edge Function calls per user search.

---

## Supplemental — Geo only (low scorecard value)

### OpenStreetMap / Nominatim

- **Still useful for:** coarse **name + place** when scorecard APIs return nothing, or for map pins.
- **Not a substitute for:** par, SI, per-tee yardages, slope/rating.
- **Policy:** Nominatim usage rules (User-Agent / `From`, rate limits, caching); [OSM copyright](https://www.openstreetmap.org/copyright) when showing OSM-derived locations.

---

## In-app fallbacks (no external scorecard)

- **`coverage_level = manual`:** name + play; optional `hole_pars` later.
- **Seeded rows:** keep demo courses in migrations for dev UX.

---

## Suggested decision workflow (scorecard-first)

1. **PoC two APIs in Postman:** GolfCourseAPI + (Zyla AU **or** RapidAPI trial)—same 10–20 AU clubs; export JSON; score **% holes with par+yardage+SI**, **% tees with slope+rating**.
2. **Pick a primary** normalised provider for `source = 'provider'` (or split `golfcourseapi` vs `zyla` in `external_ids`).
3. **Implement only via Edge Function** + cache; extend `course_provider_cache` when storing raw payloads is allowed.
4. **Revisit geo** (OSM) only where scorecard coverage is missing and you still want search UX.

---

## Summary (scorecard depth vs role)

| Source | Scorecard depth (typical) | Role |
|--------|---------------------------|------|
| [GolfCourseAPI](https://golfcourseapi.com/) | High (verify per field) | **Primary candidate** — global + structured tees/holes |
| [Postman / Golfio doc](https://documenter.getpostman.com/view/1756312/UVeDsT2b) | *Unknown until compared* | **Evaluation / contract check** against Tier A |
| [Zyla AU finder](https://zylalabs.com/api-marketplace/sports/australia+golf+course+finder+api/3176) | TBD (confirm schema) | **AU supplement** if it beats Tier A on AU gaps |
| [RapidAPI Golf Course API](https://rapidapi.com/foshesco-65zCww9c1y0/api/golf-course-api/pricing) | TBD | **Compare / last-resort trial** |
| [AllSquare](https://www.allsquaregolf.com/golf-courses/australia) | Unknown; access via scrape | **Avoid** for runtime; legal risk if bulk scraping |
| OSM / Nominatim | Low for holes | **Geo supplement** only |

Legacy references (GolfAPI.io, Golfbert, TeeRadar-style vendors) remain valid **alternatives** if GolfCourseAPI or marketplace options underperform in your PoC.

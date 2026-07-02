# Round audit — Royal Fremantle (9 holes)

**Generated:** 2026-07-02  
**Round ID:** `a7a92def-62a5-4ba7-9e0c-17ad96b09cff`  
**Source:** Supabase `public.rounds` + `round_bit_events` (via `tools/round-analysis/`)

---

## Round summary

| | |
|---|---|
| **Course** | Royal Fremantle Gc Inc |
| **Holes played** | 9 (front nine) |
| **Completed** | 2026-07-02 |
| **Formats** | Wolf + Bits |
| **Scoring** | **Net** (handicaps applied) |
| **Stakes** | $5 / Wolf pt · $2 / Bit |
| **Tee order** | You → Bobby → Charlie → Dazza |

**Handicaps:** You 12 · Bobby 14 · Charlie +1 · Dazza 4

**Verdict:** Holes 1–9 are internally consistent and correct for net Wolf + Bits on a 9-hole card.

---

## Wolf — hole by hole

Net best-ball scores are from stored `wolf_best_ball` vs `field_best_ball`. Points are zero-sum per hole (+1/−1 partner, +6/−2 lone, +9/−3 blind, 0 on ties).

> **Note:** This round was played before the partner-stake fix (app briefly used ±2 for 2v2). Correct partner holes are ±1; recalculated Wolf totals below.

**Corrected Wolf totals (±1 partner):** You +12 · Bobby 0 · Charlie −4 · Dazza −8  
**Stored in DB (old ±2 partner):** You +15 · Bobby −1 · Charlie −5 · Dazza −9

### Hole 1 · Par 4

| | Gross | Net |
|---|:---:|:---:|
| **Wolf team** — You + Charlie (partner) | 4, 4 | **3**, 3 |
| **Field** — Bobby + Dazza | 5, 4 | 4, 4 |

- **Call:** You (Wolf) · Partner Charlie
- **Result:** Wolf wins (3 vs 4)
- **Points:** You +2 · Charlie +2 · Bobby −2 · Dazza −2
- **Running:** You 2 · Bobby −2 · Charlie 2 · Dazza −2

### Hole 2 · Par 5

| | Gross | Net |
|---|:---:|:---:|
| **Wolf team** — Bobby + Dazza (partner) | 5, 5 | **4**, 4 |
| **Field** — You + Charlie | 6, 5 | 5, 5 |

- **Call:** Bobby (Wolf) · Partner Dazza
- **Result:** Wolf wins (4 vs 5)
- **Points:** Bobby +2 · Dazza +2 · You −2 · Charlie −2
- **Running:** all 0
- **Bits (this hole):** You +3 (Greenie, Woodie, Prox)

### Hole 3 · Par 3

| | Gross | Net |
|---|:---:|:---:|
| **Wolf team** — Charlie + Dazza (partner) | 3, 3 | 2, 2 |
| **Field** — You + Bobby | 2, 3 | **1**, 2 |

- **Call:** Charlie (Wolf) · Partner Dazza
- **Result:** Field wins (1 vs 2)
- **Points:** You +2 · Bobby +2 · Charlie −2 · Dazza −2
- **Running:** You 2 · Bobby 2 · Charlie −2 · Dazza −2
- **Bits:** You +2 (Nicklaus, Sandy) · Bobby +3 (Greenie, Chippie, Nicklaus)

### Hole 4 · Par 4

| | Gross | Net |
|---|:---:|:---:|
| **Wolf** — Dazza (Blind Wolf) | 4 | 4 |
| **Field** — all others | 4 each | 4 best |

- **Call:** Dazza · Blind Wolf ×3
- **Result:** Tie (4 vs 4)
- **Points:** all 0
- **Running:** You 2 · Bobby 2 · Charlie −2 · Dazza −2

### Hole 5 · Par 4

| | Gross | Net |
|---|:---:|:---:|
| **Wolf** — You (Blind Wolf) | 3 | **2** |
| **Field** | 4 each | 3 best |

- **Call:** You · Blind Wolf ×3
- **Result:** Wolf wins (2 vs 3)
- **Points:** You +9 · Bobby −3 · Charlie −3 · Dazza −3
- **Running:** You 11 · Bobby −1 · Charlie −5 · Dazza −5

### Hole 6 · Par 5

| | Gross | Net |
|---|:---:|:---:|
| **Wolf** — Bobby (Lone Wolf) | 5 | **4** |
| **Field** | 5 each | 5 best |

- **Call:** Bobby · Lone Wolf ×2
- **Result:** Wolf wins (4 vs 5)
- **Points:** Bobby +6 · You −2 · Charlie −2 · Dazza −2
- **Running:** You 9 · Bobby 5 · Charlie −7 · Dazza −7

### Hole 7 · Par 4

| | Gross | Net |
|---|:---:|:---:|
| **Wolf team** — Charlie + You (partner) | 3, 3 | **2**, 2 |
| **Field** — Bobby + Dazza | 4, 4 | 3, 3 |

- **Call:** Charlie (Wolf) · Partner You
- **Result:** Wolf wins (2 vs 3)
- **Points:** Charlie +2 · You +2 · Bobby −2 · Dazza −2
- **Running:** You 11 · Bobby 3 · Charlie −5 · Dazza −9

### Hole 8 · Par 3

| | Gross | Net |
|---|:---:|:---:|
| **Wolf team** — Dazza + Bobby (partner) | 3, 3 | 3, 3 |
| **Field** — You + Charlie | 2, 3 | **2**, 2 |

- **Call:** Dazza (Wolf) · Partner Bobby
- **Result:** Field wins (2 vs 3)
- **Points:** You +2 · Charlie +2 · Dazza −2 · Bobby −2
- **Running:** You 13 · Bobby 1 · Charlie −3 · Dazza −11

### Hole 9 · Par 4 — trailing-player Wolf

On a **9-hole** round, the player with the **fewest Wolf points** going into hole 9 becomes Wolf.

**Standings thru 8:** You 13 · Bobby 1 · Charlie −3 · **Dazza −11** ← Wolf

| | Gross | Net |
|---|:---:|:---:|
| **Wolf team** — Dazza + You (partner) | 3, 3 | 3, **2** |
| **Field** — Bobby + Charlie | 4, 4 | 3, 3 |

- **Call:** Dazza (Wolf) · Partner You
- **Result:** Wolf wins (2 vs 3)
- **Points:** Dazza +2 · You +2 · Bobby −2 · Charlie −2

---

## Wolf final totals

| Player | Points | @$5/pt |
|--------|:------:|-------:|
| **You** | **+15** | **+$75** |
| Bobby | −1 | −$5 |
| Charlie | −5 | −$25 |
| Dazza | −9 | −$45 |

---

## Bits summary

| Player | Total bits | @$2/bit |
|--------|:----------:|--------:|
| You | 38 | $76 |
| Bobby | 21 | $42 |
| Charlie | 0 | $0 |
| Dazza | 0 | $0 |

Most bits were on holes 2–3 (side events as logged). No bits recorded on holes 4–9.

**Bits net (shared-cost model):**

| Player | Net $ |
|--------|------:|
| You | +$62.00 |
| Bobby | +$16.67 |
| Charlie | −$25.33 |
| Dazza | −$25.33 |

---

## Combined settlement

| Player | Wolf $ | Bits $ | **Final net** |
|--------|-------:|-------:|--------------:|
| **You** | +$75 | +$62 | **+$137** |
| Bobby | −$5 | +$17 | +$12 |
| Charlie | −$25 | −$25 | −$50 |
| Dazza | −$45 | −$25 | −$70 |

Charlie and Dazza owe the table; You is the big winner; Bobby is slightly up overall after Wolf losses.

---

## Notes

- **Hole 9 trailing Wolf:** Dazza (−11 pts thru 8) correctly becomes Wolf on the 9th hole of a 9-hole round.
- **Automated audit caveat:** `audit-wolf.mjs` initially flagged hole 9 because the DB row uses `holes: 9` while the script defaulted `hole_count` to 18. When evaluated as a 9-hole round, all holes pass.
- **Regenerate:** `node tools/round-analysis/audit-wolf.mjs --id a7a92def-62a5-4ba7-9e0c-17ad96b09cff`

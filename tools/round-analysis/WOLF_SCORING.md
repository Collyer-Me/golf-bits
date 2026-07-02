# Wolf scoring rules (Bits)

How Wolf points work in the app (`golf_bits/lib/models/wolf_scoring.dart`).

## Per hole

1. **Who is Wolf** — rotates through tee order, except trailing-player holes (9th on a 9-hole round; 17th–18th on 18 holes): fewest Wolf points so far becomes Wolf.
2. **Wolf’s call** — Partner (2v2), Lone Wolf (1v3), or Blind Wolf (1v3, committed blind).
3. **Best ball** — Each side uses its lowest net (or gross) score on the hole. Lower side wins. Tie → 0 points for everyone.
4. **Points** — Zero-sum transfers (total points across four players = 0 every hole).

## Point stakes

The **unit** is 1 point per person on the losing side paid to each winner on a 2v2 hole. Lone and Blind multiply that unit.

### Partner (2v2) — ×1

| Outcome | Each winner | Each loser |
|---------|:-----------:|:----------:|
| Wolf side wins | **+1** | **−1** |
| Field wins | **+1** | **−1** |

Two winners (+2 total), two losers (−2 total).

### Lone Wolf — ×2

Wolf takes 2 units from each of the three losers (6 total), or pays 2 to each if the field wins.

| Outcome | Wolf | Each field player |
|---------|:----:|:-----------------:|
| Wolf wins | **+6** | **−2** |
| Field wins | **−6** | **+2** |

### Blind Wolf — ×3

Wolf takes 3 units from each loser (9 total), or pays 3 to each if the field wins.

| Outcome | Wolf | Each field player |
|---------|:----:|:-----------------:|
| Wolf wins | **+9** | **−3** |
| Field wins | **−9** | **+3** |

### Tie

Everyone **0**.

## Money

`Wolf $ = total Wolf points × wolf point value` (e.g. $5/pt). Wolf dollars are zero-sum across the group.

## Bits

Bits is independent during the round. At round complete, Wolf net and Bits net are added for final settlement.

## See also

- Example audit: [`reports/2026-07-02-royal-fremantle-wolf-audit.md`](reports/2026-07-02-royal-fremantle-wolf-audit.md)
- Verify a round: `node tools/round-analysis/audit-wolf.mjs --latest-completed`

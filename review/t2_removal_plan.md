# Tier 2 — removal & clipping plan

Written 2026-08-02, against the **post-fix data** (restaurant-sales `cac7dc4`).
Supersedes the diagnosis in `t2_problem_list.md`, which was computed on
pre-fix data and is now partly obsolete.

**Nothing has been changed.** Every item below is a decision for you to accept or
reject individually.

---

## The finding that determines the refit budget

| analysis | outcome columns vs the April T2 fits | status |
|---|---|---|
| **T2 A2** (12 models) | `*_outcome_p` all **CHANGED** | must refit regardless |
| **T2 A4** (5 models) | `*_t2_outcome` all **CHANGED** | must refit regardless |
| **T2 A3** (6 models) | general outcomes **bit-identical** | **fits still valid, no refit** |

So the 17 A2/A4 models are already being re-run because the contamination and
union fixes moved their outcomes. **Restaurant removals inside those models are
therefore free** — they change the restaurant list of a model that is being
refit anyway.

The only decision with a real refit cost is whether to **clip EMBVNVD207CC6
globally** in `1_data_ingarch.R`. That is a universal date filter, so it changes
the data for every model containing that restaurant — including all six A3
models, one of which is `total`, the RRR denominator for A3 **and** A4. Clipping
therefore forces 6 extra refits and invalidates the existing A3 fits.

**Recommendation: do the removals, do not clip globally.** Handle EMBVNVD by
removing it from the specific models where it is degenerate, which keeps A3
untouched.

---

## What the contamination fix already resolved

These were on the old problem list and are now healthy. No action needed:

| pair | was | now |
|---|---|---|
| `dairy_t2` / W8T41JZK0ZMEP | 75% contaminated by volume | 9,441 units, 12% zero-days |
| `textured_t2` / SAFK7ND1HR6XS | 21% contaminated | 35,070 units (Pastor Taco recovered) |
| `untextured_t2` / SRQS8F7JWA9MZ | 12% contaminated | 58,606 units, 3% zero-days |
| `breakfast_t2` / 2HRX9P6HKXA8V | 6% contaminated | 328,851 units, 7% zero-days |

Mechanism A (label contamination) is closed. What remains is Mechanism B (onset
confound) and Mechanism C (data-coverage ramp).

---

## Tier 1 — no product exists

Your stated priority: pairs where the restaurant never sold the animal
counterpart, so the outcome is not measuring anything.

### D1. Drop the `chicken_t2` outcome entirely

`V3Q26BHF3SE2H` is the **only** restaurant in `A4_T2_chicken.R`, and its
`chicken_t2_outcome` is now **0 units across the entire series** (100% zero
days, 515 pre-period days also all zero). The old 503 units were entirely
"Wings (V)" — a plant-based item counted as its own counterpart.

Confirmed separately: Oca Mocha's BBQ chicken is grilled, not fried, so it never
matched `fried_chicken`; and their "50 Buffalo Wings" sold 0 units.

There is no model to fit. **Remove `A4_T2_chicken.R` from the run list and the
outcome from the manuscript.**
→ **0 refits** (it cannot be fitted at all)

### D2. `untextured_t2` — remove JHDN7CF1C03X5

**5 units total, 100% zero-days.** Was 4,465 units, all "Fresh Beyond Burger".
This is the RR 134 restaurant. Tier 1 already excludes it from ground meat
(`A4_untextured.R` has `#'JHDN7CF1C03X5'`), so this also restores T1/T2
consistency — the outstanding inconsistency flagged in `t1_overlap_audit.md`.
→ folded into the `untextured_t2` refit

---

## Tier 2 — near-dead in A2

Volume too low to identify anything, though not literally zero.

| # | model | restaurant | units | % zero-days | proposal |
|---|---|---|---|---|---|
| **D3** | `untextured_p` | EMBVNVD207CC6 | **197** | 99% | remove |
| **D4** | `untextured_p` | W8T41JZK0ZMEP | **355** | 89% | remove |
| **D5** | `textured_p` | W8T41JZK0ZMEP | **478** | 86% | remove |

For scale, the median A2 T2 pair carries ~20,000 units. D5 leaves `textured_p`
with 2 restaurants (9XKJD8 21,442 and SAFK7ND 90,044).
→ folded into refits already required

---

## Tier 3 — onset confound

Counterpart sales begin at the introduction, so there is no pre-period to
compare against. Labels are correct; the design simply is not identified.

| # | model | restaurant | pre-days | pre mean/day | pre % zero | proposal |
|---|---|---|---|---|---|---|
| **D6** | `breakfast_t2` | V3Q26BHF3SE2H | 515 | 0.00 | **100%** | remove |
| **D7** | `untextured_t2` | 9XKJD8DQTH559 | 664 | 0.00 | **100%** | remove |
| **D8** | `dairy_t2` | EMBVNVD207CC6 | 2,522 | 0.07 | **95%** | remove |

D8 is the same restaurant as the Tier 4 clipping question; removing it from this
one model is the cheap alternative to clipping globally.
→ folded into refits already required

---

## Tier 4 — EMBVNVD207CC6 data-coverage ramp

The one genuine clipping question, and the only decision with a refit cost.

Yearly mean `total_outcome`:

```
2013  0.2    2016  0.3    2019  1.0    2022 31.2
2014  0.1    2017  1.1    2020  3.8
2015  0.3    2018  2.0    2021 26.6
```

Everything before 2021 is a data-coverage ramp, not trading history. The
universal filter currently keeps `2016-06-01 … 2022-09-01`.

EMBVNVD appears in **13 T2 models**: 6 A2, 1 A4, 6 A3.

### D9. Global clip in `1_data_ingarch.R` — **recommend NO**

Changing the universal filter to start ~2020-08-01 would be the most principled
treatment, but it changes the data for all 13 models, including all six A3
models. A3 is currently valid and needs no refit. Clipping would:

- force **6 extra A3 refits**, including `total`
- invalidate the A3/A4 RRR pairing until `total` is re-fit
- change A3 estimates for a restaurant that is one of ~19

### D10. Instead: remove EMBVNVD from the models where it is degenerate

Already covered by D3 (`untextured_p`, 197 units) and D8 (`dairy_t2`, 95% zero
pre-period). That leaves it in:

| model | units | % zero | proposal |
|---|---|---|---|
| `breakfast_p` | 3,020 | 88% | **your call** — sparse but not empty |
| `dairy_p` | 14,092 | 80% | **your call** — substantial volume |
| A3 (all 6) | general outcomes | — | leave alone, no refit |

Keeping it in A3 is defensible: A3 uses general outcomes where EMBVNVD does have
real (if small) volume, and A3 includes every restaurant by design.

---

## Refit accounting

| scenario | A2 | A4 | A3 | total |
|---|---|---|---|---|
| **Baseline** (data changed, no removals) | 12 | 5 | 0 | **17** |
| **Recommended** (D1–D8, D10) | 12 | **4** | 0 | **16** |
| With global EMBVNVD clip (D9) | 12 | 4 | 6 | **22** |

The recommended path is **one model fewer than doing nothing**, because dropping
`chicken_t2` removes a model that cannot be fitted. Every other removal is free.

---

## Decision list

| # | decision | refit cost |
|---|---|---|
| D1 | Drop `chicken_t2` outcome entirely (0 units) | −1 |
| D2 | `untextured_t2`: remove JHDN7CF1C03X5 (5 units) | 0 |
| D3 | `untextured_p`: remove EMBVNVD207CC6 (197 units) | 0 |
| D4 | `untextured_p`: remove W8T41JZK0ZMEP (355 units) | 0 |
| D5 | `textured_p`: remove W8T41JZK0ZMEP (478 units) | 0 |
| D6 | `breakfast_t2`: remove V3Q26BHF3SE2H (100% zero pre) | 0 |
| D7 | `untextured_t2`: remove 9XKJD8DQTH559 (100% zero pre) | 0 |
| D8 | `dairy_t2`: remove EMBVNVD207CC6 (95% zero pre) | 0 |
| D9 | Global EMBVNVD clip in `1_data_ingarch.R` | **+6** — recommend no |
| D10 | `breakfast_p` / `dairy_p`: keep or drop EMBVNVD | 0 either way |

---

## Open questions for you

1. **D9** — accept the recommendation to skip the global clip, or is the
   principled treatment worth 6 extra refits including the RRR denominator?
2. **D10** — EMBVNVD in `breakfast_p` (3,020 units, 88% zero) and `dairy_p`
   (14,092 units, 80% zero): keep or drop? Both are sparse but not degenerate.
3. **`textured_p` after D5** drops to 2 restaurants. Acceptable, or does that
   outcome need reconsidering?
4. Should the equivalent T1 pairs be re-checked for consistency, or is T1
   settled?

## Not covered here

- T2 A5/A6 have severe non-convergence (pooled rhat up to 3.75) that no
  clipping addresses. Separate problem.
- `A1 clip table is dead code` (`is_proportion` never matches) and
  `A3/A4 bypass apply_proportion_clips()` — both still true, both unaddressed,
  neither affects the decisions above.

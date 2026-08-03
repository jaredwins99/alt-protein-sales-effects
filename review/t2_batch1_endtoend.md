# T2 batch 1 — what was wrong, what changed, and how to extract

Written 2026-08-03, immediately before submitting `slurm_t2_a2_a4_batch1.sh`.

---

## 1. The display transform (get this right first)

`create_forest_plots_restaurants_chosen_recolored_adj_t2.R:748-758` picks the
displayed value by exposure type. Verified against the rendered PDFs:

| exposure type | displayed | used by |
|---|---|---|
| `count` | `exp(gamma) - 1` as % | **A2 count**, A1 count |
| `prop` | `exp(0.1 * gamma) - 1` as % | A1 proportion exposures |
| ITS (no exposure subdir) | `exp(gamma) - 1` as % | **A3, A4** |

Confirmed: T2 A2 breakfast pooled `median(log) = 0.438` renders as **55%**, which
is what the PDF shows. T2 A4 breakfast pooled renders as **-29%**.

**Only the count form is plotted for A2.** The presence fits exist and are run,
but do not appear in the figures. This matters: presence carries far wilder
values (2HRX9P 119,166%, EMBVNVD 120,323%) that never reach a figure.

---

## 2. Every off-chart value in the current figures, and its fix

### T2 A4 — six clipped estimates, all one restaurant

| outcome | restaurant | displayed | fix |
|---|---|---|---|
| `chicken_t2` | V3Q26BHF3SE2H | **7385%** | outcome dropped entirely |
| `breakfast_t2` | V3Q26BHF3SE2H | 1506% | restaurant removed |
| `breakfast_t2` | V3Q26BHF3SE2H | 1283% (slope) | restaurant removed |
| `breakfast_t2` | V3Q26BHF3SE2H | 1176% | restaurant removed |
| `chicken_t2` | V3Q26BHF3SE2H | 309% | outcome dropped |
| `chicken_t2` | V3Q26BHF3SE2H | 118% | outcome dropped |

Plus the `chicken_t2` pooled estimate at 120%, which disappears with the outcome.

**Substantive grounds, independent of the estimates:**
- `chicken_t2`: the counterpart category is `fried_chicken`. V3Q26B sells
  Bbq Chicken (114 u) and a chicken sandwich (90 u) — both unfried. Their 503
  "Wings (V)" were the *analog*, not the counterpart. Post-fix the outcome is
  **0 units**, so the model cannot be fitted at all.
- `breakfast_t2`: the Turkey Sausage counterpart first sells **mid-2022**, about
  15 months after the 2021 introductions. There is no contemporaneous contrast.

### T2 A2 (count, the plotted form) — one off-chart estimate

| outcome | restaurant | displayed | fix |
|---|---|---|---|
| `breakfast_p` | EMBVNVD207CC6 | **51,288%** | clip to 2020-09-01 |

Every other A2 count estimate is between -15% and +106%.

**Grounds:** EMBVNVD records 0.71 purchases/day across 2,522 pre-period days
(a sale on 8-46% of days), then 26.27/day afterwards — a 37x jump. Coverage and
exposure begin in the *same month* (2020-09). Before that, exposure and outcome
are both ~0, so the model reads "availability rose, sales rose" from what is
purely the recording system switching on. The composition shifts too (dairy goes
from 10% to 65% of sales; `chicken_fish` from literally 0 to 2.6%), so the RRR's
total-sales denominator cannot absorb it.

---

## 3. Upstream data fixes (already applied and verified)

These changed every T2 A2/A4 outcome column, which is why all 17 models need
re-running regardless of any removal.

**Contamination** (`restaurant-sales` fd44b90). Anti-keywords (`vegan`, `beyond`,
`impossible`, ...) were tested only against `item_modifications`, never
`item_name`, so a dish whose plant identity is in its name kept the animal flag.
Added the `item_name` mask plus vegan/vegetarian exclusion.
Result: residual contamination **0.0000%**; `chicken_t2` 503 -> 0;
`dairy_t2` -59.3%; `untextured_t2` -12.6%.

**Double counting** (`restaurant-sales` cac7dc4). `*_outcome_p` summed 2-3
category flags, so a dish flagged twice counted twice — `total_outcome` is 1 per
item row, so `outcome_p` could exceed it (2,226 rows did). Cell 4 already
computed the correct boolean union and used it for the price windows; the
outcomes now use it too. Result: exceedances **2,226 -> 0**, 221,391 phantom
units removed.

General outcomes (`vegan`, `vegetarian`, `meat`, `nonvegan`, `chicken_fish`,
`total`) are **bit-identical** throughout, which is why the six T2 A3 fits remain
valid and are not being re-run.

---

## 4. Removals for non-identification

Exposure constant within the analysis window means the restaurant contributes no
information and its coefficient is a prior draw. These produced CI widths to
57,000x.

| model | restaurant | exposure |
|---|---|---|
| A2 breakfast | SAFK7ND1HR6XS | 100% one value |
| A2 chicken | SAFK7ND1HR6XS, LBZEEFSBJNB3Z | 100% |
| A2 untextured | LFZFT3VASXPED | 99% |
| A2 dairy | LFZFT3VASXPED | 99% |

SAFK7ND's constancy follows from its 11-month universal filter
(`2019-04-18 .. 2020-03-25`), which isolates its one contiguous coverage block —
its data is otherwise fragmentary, with total at zero for all of 2021-22.
**Open choice:** widen that window to let the exposure move, at the cost of
pulling in broken coverage.

## 5. Removals where the counterpart product does not exist

| model | restaurant | evidence |
|---|---|---|
| A4 untextured | 9XKJD8DQTH559 | no burger sold; outcome is two isolated pulses, 323 u |
| A2 untextured | EMBVNVD207CC6 | pizza/beer venue, no burger/ground/meatball; 197 u |
| A2 untextured | SAFK7ND1HR6XS | "Burrito" (8,572 u) labelled `ground_meat`, but its modifications are asada/pastor/suadero/chicken/jackfruit — chunked, belongs in `textured` |
| A2 textured | W8T41JZK0ZMEP | no lamb, chunked or pulled pork on a 663-line menu |

## 6. T1/T2 consistency

T2 is a superset of T1, so a restaurant excluded from a T1 model must enter the
matching T2 model the same way. Three starters disagreed and were corrected:
`A2_T2_untextured_{count,presence}` (JHDN7CF, W8T41J) and `A4_T2_untextured`
(JHDN7CF). All other T1 exclusions were already absent from their T2 counterparts.

## 7. Trimming — deliberately one restaurant

Two facts kept this minimal:

1. `run_ingarch.R:270-273` drops `total_outcome == 0` days from the likelihood,
   so coverage **gaps need no trim**. Only low-but-nonzero stretches bias a fit.
   (This reversed a proposed 1SQPTEGYPH0GA clip — its 2014-15 gaps are zeros.)
2. Scanning all 12 T2-only restaurants for years below 20% of their own peak
   flagged **EMBVNVD alone** (2013-2019 at 3-10%). Every other restaurant is clean.

The clip went into `clip_dates_proportion_targeted` (breakfast, dairy), which
gates on `/a2_proportion_t/` — so **A2 only**, leaving the valid A3 fits alone.
Verified: EMBVNVD 3,336 -> 729 rows, range `2020-09-02 .. 2022-08-31`, with the
T1 clips firing unchanged.

---

## 8. The extract protocol

The retired path is `publication/scripts/retired/extract_adj_95ci.R.RETIRED`
(Bug 1 source, retired at 1c9a25b1). Do not use `forest_data_adj_95ci.csv` —
it is from 2026-05-19 and its `mean_exp` column is `mean(exp(draws))`, which is
tail-dominated and unstable.

**Current pipeline, in order:**

```
1. fits land on          $SCRATCH/model_fits/finalized_redone_trunc_cp/
2. pull back             bash_scripts/moving/scp_sherlock_to_windows_one.sh <rel_path>
                         (scratch purges 90 days after last modification)
3. extract (both passes) publication/scripts/run_adj_fixed_extraction.sh
                            pass 1 -> slim_extract_one.R, one subprocess per fit
                            pass 2 -> adj_join_pass2.R
                            -> publication/forest_data_adj_95ci_fixed.csv
                            columns: mean, median, q2.5, q16, q84, q97.5
                         (run_slim_pass1.sh is RETIRED -- superseded by the above)
4. render                ADJ_FIXED=TRUE Rscript publication/render/render_professional_wide_fixed.R
                            adj_fallback.R reads the _fixed CSV and uses exp(median)
                            -> publication/forest_plots/professional_wide_fixed/{t1_adj,t2_adj}/
```

**Why each step matters:**
- Pass 1/2 are split because loading every `samples.rds` at once exhausts memory.
- `median` not `mean`: `mean(exp(draws))` is dominated by the tail of a
  heavy-tailed posterior; `exp(median)` is stable and is what `ADJ_FIXED` uses.
- `q16/q84` are exact Monte Carlo inner-band quantiles (9b863a93), replacing a
  log-normal approximation.
- The RRR baseline is recorded per row in `total_dir` / `total_source`
  (`mu_gamma_total_subset` when restaurant sets match, `matched_restaurant` when
  the outcome model's set is a subset of the total model's).
- Renderers read the CSV, never `samples.rds` — those are multi-GB.

See publication/PIPELINE.md for the authoritative version of this.

**After this batch:** re-run steps 2-4 for the 13 refitted models, then compare
the T2 A4 PDF against this document. Success is zero clip markers in A4 and
`breakfast_p`/EMBVNVD back on-axis in A2.

---

## 9. What this batch does NOT address

- **A2 presence** carries values to 120,000% but is not plotted. If presence is
  ever put in a figure, it needs its own investigation.
- **T2 A5/A6** have pooled rhat to 3.75. Unrelated to any of the above.
- **A1 clip table is dead code** — `is_proportion <- grepl("/a1_proportion/", ...)`
  never matches because the real path is `.../proportion/...`. Never applied in
  either tier. Left alone deliberately: fixing it would change A1 data and force
  re-runs there.
- **A3/A4 bypass `apply_proportion_clips()`** for `its/` paths, so per-category
  trimming is impossible for A4 — any A4 trim must go in the universal filter
  and would affect every analysis for that restaurant.

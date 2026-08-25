# Control flow for `publication/forest_plots/z_precursors/professional_wide/`

Traced end-to-end by reading every hop, and verified against rendered output.
Written because I previously asserted A1/A2 plotted absurd values (45 million)
after reading only the renderer's `case_when` and not following the chain to the
end — `adj_fallback.R` neutralises that two hops later. See "Corrections" below.

---

## 1. Entry point

`publication/render/render_professional_wide.R`

- Sets `SORT_BY_MEAN=TRUE`, `PUB_RECENTER=TRUE`, `PUB_WIDE=TRUE`
- CLI: arg 1 = analysis (`A1`..`A6`/`ALL`), arg 2 = tier (`T1`/`T2`/`BOTH`)
- Single-analysis runs also set `PRO_FAST=TRUE` → PDF only, no PNG/HTML/plotly
- Sources three sub-renderers:

| sub-renderer | covers |
|---|---|
| `create_forest_plots_restaurants_chosen_recolored_adj.R` | T1 A1–A4 |
| `create_forest_plots_restaurants_chosen_recolored_adj_t2.R` | T2 A1–A4 |
| `create_customer_day_forest_plots_consolidated.R` | A5/A6, both tiers |

- Sub-renderers write to `forest_plots/z_precursors/total_adjusted/t{1,2}_sorted_recentered_wide/`
  (suffix built from the three env flags)
- Step 3 **copies** the PDFs into `professional_wide/t{1,2}_adj/`.
  T2 A1/A3 are split (`A1a/b/c`, `A3a/b`), so the T2 stem list differs — 6 files
  for T1, 9 for T2.

## 2. Where the numbers come from — **the CSVs, always**

This is the single most important fact and the one I got wrong before.

- `read_samples()` (`model_scripts/ci95_helpers.R:39`) reads **`samples.rds` only**.
  It never touches `fit.rds`:
  ```r
  samples_file <- file.path(model_path, "samples.rds")
  if (!file.exists(samples_file)) return(NULL)
  ```
- **T1 renderer is samples-first with a CSV fallback**
  (`compute_adjusted_mu_gamma`, `compute_adjusted_restaurant_gammas`).
- **T2 renderer is explicitly CSV-first** — "Prefer precomputed CSV — keeps
  rendering RAM-light".
- Inventory across all 12 subanalyses. `samples.rds` presence decides which path
  the *renderer* takes; **either** `fit.rds` **or** `samples.rds` is sufficient to
  obtain draws for a re-extraction:

| label | analysis | leaves | has samples | has draws (fit **or** samples) |
|---|---|---|---|---|
| T1A1 | a1_proportion | 37 | 0 | 36 |
| T1A2 | a2_proportion_t | 10 | 0 | 10 |
| T1A3 | a3_its | 12 | 0 | 11 |
| T1A4 | a4_its_t | 6 | 0 | 6 |
| T1A5 | a5_customer_day | 6 | 0 | 6 |
| T1A6 | a6_customer_t_day | 2 | 0 | 2 |
| T2A1 | t2_a1_proportion | 36 | 0 | 36 |
| T2A2 | t2_a2_proportion_t | 12 | 0 | 12 |
| T2A3 | t2_a3_its | 9 | 6 | 8 |
| T2A4 | t2_a4_its_t | 8 | 5 | 8 |
| T2A5 | t2_a5_customer_day | 6 | 0 | 6 |
| T2A6 | t2_a6_customer_t_day | 5 | 0 | 5 |

- Only 3 leaves lack both, and **none is referenced by any plot** — they are
  prep-only shells holding just `data_list.rds` + `restaurants_order.rds`:
  `_cp/a1_proportion/chicken_fish/mpbamod_dishes_count`,
  `_trunc/a3_its/total`, `_trunc/t2_a3_its/total`.
- **Of the 133 distinct model dirs the plots reference, 0 lack draws.**
  Nothing needs re-fitting for want of a file.

**Therefore:**

- T1 has no samples anywhere → the fallback always fires → **CSV**.
- T2A3/T2A4 *do* have samples, but the T2 renderer prefers the CSV → **CSV**.
- **No plot in `professional_wide/` reads posterior draws at render time.**
  Every value traces to `forest_data_adj_95ci.csv` (+ supplement).

## 3. `adj_fallback.R` — the CSV reader, and it rewrites two columns

Sourced at the top of both A1–A4 renderers.

- `.adj_load()` reads `forest_data_adj_95ci.csv`, then merges
  `forest_data_adj_95ci_t2_a3_a4.csv`. Supplement **wins**: main rows are dropped
  for any `(analysis, outcome)` the supplement covers, then the supplement is
  appended.
- `adj_mu_gamma_from_csv()` → pooled rows; `adj_restaurant_gammas_from_csv()` →
  restaurant rows.
- **It overrides the stored point estimates** (lines 56–57, 89–90):
  ```r
  mean_exp     = exp(r$mean),        # NOT the CSV's mean(exp(d))
  mean_exp_p10 = exp(0.1 * r$mean),
  ```
  with the comment: *"the CSV's mean_exp is mean(exp(diff_draws)) which explodes
  for heavy-tailed log-ratio posteriors (A2 presence with small-denominator
  total). exp(mean) is the geometric mean / median of a log-normal and is always
  finite."*
- It also sets `median = r$mean` with `# median not stored; fall back to mean` —
  **no median column exists in the CSVs.**

## 4. Per-analysis display transform

CSV `mean`/`q2.5`/`q97.5` are all **log-scale** RRR values.

| analysis | point estimate | interval | net point estimate |
|---|---|---|---|
| A1 (`count`) | `mean_exp` | `exp(q)` | `exp(mean_log)` |
| A1 (`prop`) | `mean_exp_p10` | `exp(q)` | `exp(0.1·mean_log)` — per 10 pp |
| A2 (`count`/`presence`) | `mean_exp` | `exp(q)` | `exp(mean_log)` |
| A3/A4 | `ifelse(!is.na(mean_exp), mean_exp, exp(mean))` | `exp(q)` | `exp(mean_log)` |
| A5/A6 | identity link — no `exp` at all | raw | raw difference |

**Every A1–A4 point estimate on every wide plot is `exp(mean_log)`** (the
geometric mean), because `adj_fallback` overwrote `mean_exp`. Confirmed against
rendered output: `A2_proportion_targeted_restaurants_data.csv` max value is
**2.0005**, matching `exp(mean_log)=2.001` for JHDN7CF dairy/presence — *not* the
CSV's stored `mean_exp` of 45,470,124.

## 5. Geometry pipeline (after the numbers are fixed)

- `clip_to_limits()` — `.pub_overshoot = 0.045`; bars run to the panel border,
  the clipped-marker triangle stops at 0.8× the overshoot
- `add_inner_ci()` — 1-SD band from the 95% CI under a log-normal approximation,
  clamped to the outer CI
- `PUB_RECENTER` → axis and labels shown as `(RR − 1) × 100%`
- `get_plot_cfg(tier, analysis)` → `PLOT_CONFIG` ← `WIDE_OVERRIDES`
  (← `LABELED_OVERRIDES` when `WIDE_LABELED=TRUE`)

## 6. Where the known bugs sit in this chain

| bug | location | reaches the wide plots? |
|---|---|---|
| **1** — restaurant rows subtract wrong `beta[col,rest]` | `extract_adj_95ci.R:192` (CSV contents) | **yes** — CSV is the only source |
| **2** — pooled uses total model's global `mu_gamma` | `extract_adj_95ci.R:153` (CSV contents) | **yes** |
| ~~3~~ — `mean(exp)` point estimate | CSV column `mean_exp` | **no** — `adj_fallback.R:56` overwrites it |

Both live surviving bugs are **upstream of the renderer**, in CSV contents. The
renderer itself is not at fault, and fixing them requires re-extraction, not
re-rendering — though a re-render is needed afterwards to pick up new CSVs.

## 7. Corrections to my earlier claims

- **Wrong:** "A1/A2 plot `mean_exp` = E[exp(X)], so a restaurant shows 45 million."
  **Right:** the *stored* CSV value is 45 million, but `adj_fallback.R` replaces
  it with `exp(mean)` before plotting. Max rendered A2 value is 2.00. There are
  no absurdities in any rendered plot. I read the `case_when` and stopped.
- **Wrong:** "the pipeline is CSV-first."
  **Right:** the T2 renderer is CSV-first; the T1 renderer is samples-first with
  a CSV fallback. They land in the same place only because T1 has no samples.
- **Wrong:** "the median convention is already used elsewhere in the pipeline."
  **Right:** `median(exp(diff_draws))` exists in the renderers' samples path, but
  that path never executes for any wide plot. No median is stored or plotted
  anywhere.
- **Overstated:** Bug 2 framed as needing an estimand "decision". Differencing
  two different restaurant populations is incoherent regardless; restricting the
  baseline is a correction. The only real choice is restaurant- vs
  introduction-weighting, which changes one number (`a4_its_t/untextured`).

## 8. Consequences for the planned work

- Switching to a true **median** means adding a `median` column to the extractors
  and having `adj_fallback` prefer it. Current `exp(mean_log)` is the geometric
  mean — the right estimand only under log-symmetry.
- **Bug 2 needs no re-fitting.** The total model already estimates a separate
  `eta[param, r]` and `beta[col, r]` for every restaurant it contains, so
  restricting the baseline is a different average over draws we already have.
- **Draws are available for everything.** All 133 referenced model dirs have
  `fit.rds` or `samples.rds`. Only the *renderer* is restricted to `samples.rds`;
  a re-extraction can read `fit.rds` via cmdstanr, which runs fine in WSL.
- The practical constraint is size, not availability — `t2_a1_proportion` is 55G
  of `fit.rds`, `a1_proportion` 18G, `t2_a2_proportion_t` 11G, `a3_its` 6.9G — so
  re-extract one fit at a time rather than in a bulk pass.

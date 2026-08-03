# Adjusted (RRR) forest-plot pipeline — what to run, in what order

**Read this before touching anything under `publication/`.** There are two
parallel pipelines in this tree: a corrected one and a superseded one. They share
most of their code and differ by an environment variable, so it is easy to run
the wrong one by accident and get plausible-looking wrong numbers.

Status tags used throughout:

| tag | meaning |
|---|---|
| **[CURRENT]** | use this |
| **[RETIRED]** | superseded or known-wrong — do not run, do not build on |

---

## 1. The short version

```bash
cd /home/godli/testing && ./publication/scripts/run_adj_fixed_extraction.sh && ADJ_FIXED=TRUE Rscript publication/render/render_professional_wide_fixed.R
```

That is the whole corrected pipeline. Everything below explains what it does and
why the alternatives exist.

`run_adj_fixed_extraction.sh` is resumable — it skips any fit whose slim file
already exists, so re-running after an interruption is cheap and safe.

> ### ⚠ The manifests are a moving target
>
> The pipeline *structure* below is stable. What changes underneath it is which
> **fit generation** each outcome points at, in `scripts/adj_fixed_{dirs,pairs}.csv`.
>
> As of this writing the manifests are **mid-migration** to a
> `finalized_uncontaminated` generation, outcome by outcome:
>
> | generation | pairs |
> |---|---|
> | `finalized_redone_trunc` | 59 |
> | `finalized_redone_trunc_cp` | 43 |
> | `finalized_uncontaminated` | 15 (`a2_proportion_t`, `a4_its_t`, `a6_customer_t_day`) |
>
> **Consequences for anyone picking this up:**
>
> - `forest_data_adj_95ci_fixed.csv` and the rendered PDFs were built from the
>   manifests *as they stood at build time*. If the manifests have moved since,
>   those artefacts are stale — re-run both stages.
> - **Pass 1 is resumable by design, and that becomes a hazard here.** It skips a
>   fit when its slim file already exists. If an outcome is repointed to a new
>   generation, the slim path changes too, so the new fit is extracted correctly —
>   but stale slim files from the *old* generation remain in `/var/tmp/adj_slim`
>   and are harmless only because pass 2 reads via the manifest. If you ever
>   re-point an outcome *within* the same generation, delete its slim file first
>   or you will silently join old draws.
> - When claiming "verified", say against which generation. The §6 numbers are
>   pinned to the mixed state above.

---

## 2. Stages, in order

### Stage 0 — inputs

Posterior draws live in `model_fits/**/{fit.rds,samples.rds}`. 133 model
directories are referenced by the plots, ~120 GB total. `fit.rds` is a
`CmdStanMCMC` object; `samples.rds`, where present, is a plain named list.
Either is sufficient.

Two manifests drive the run:

| file | rows | used by |
|---|---|---|
| `scripts/adj_fixed_dirs.csv` | 133 | pass 1 — one row per model dir |
| `scripts/adj_fixed_pairs.csv` | 117 | pass 2 — outcome/total pairings |

### Stage 1 — slim extraction **[CURRENT]**

`scripts/slim_extract_one.R <model_dir> <out.rds>`, invoked once per fit **in its
own subprocess**.

Reading a `fit.rds` materialises every parameter (`lambda`, `log_lik`, `y_rep`…),
roughly 1.5–2.9× the on-disk size in RAM. The variables actually needed are tiny.
One process per fit means the OS reclaims that peak before the next fit starts,
and the outcome and total fits are never resident simultaneously.

Writes `mu_gamma`, `eta`, and the exposure columns of `beta` — **keyed by name**
(`model_col`, restaurant name), not by index. Output ~54 MB total to
`/var/tmp/adj_slim`, deliberately outside the session scratchpad because the
scratchpad was wiped mid-run twice.

Measured: 133/133 fits, zero failures, peak RSS 3.9 GB against an 8 GB target.

### Stage 2 — join **[CURRENT]**

`scripts/adj_join_pass2.R <slim_dir> <pairs_csv> <out_csv>`
→ `publication/forest_data_adj_95ci_fixed.csv` (2200 rows: 268 pooled, 1932 restaurant).

Joins outcome to total **by name**, asserting every match with `stopifnot`.
Computes all summaries as exact Monte Carlo quantiles of the draw vector —
`mean`, `median`, `q2.5`, `q16`, `q84`, `q97.5`, all on the log scale. Peak RSS
257 MB.

Pooled rows use the **superpopulation** estimand unconditionally:
`mu_gamma_outcome − mu_gamma_total`. See §5.

### Stage 3 — render **[CURRENT]**

`render/render_professional_wide_fixed.R` sets `ADJ_FIXED=TRUE` and sources three
sub-renderers:

| sub-renderer | covers |
|---|---|
| `create_forest_plots_restaurants_chosen_recolored_adj.R` | T1 A1–A4 |
| `create_forest_plots_restaurants_chosen_recolored_adj_t2.R` | T2 A1–A4 |
| `create_customer_day_forest_plots_consolidated.R` | A5/A6, both tiers |

Writes to `forest_plots/total_adjusted/t{1,2}_sorted_recentered_wide_fixed/`
(the `_fixed` suffix comes from `ADJ_FIXED`), then copies the PDFs to
`forest_plots/professional_wide_fixed/t{1,2}_adj/`. 15 PDFs: 6 T1, 9 T2 (T2 A1
and A3 are split into a/b/c and a/b).

Each plot also drops a `*_data.csv` sidecar containing exactly what was drawn —
this is what you verify against (§6).

---

## 3. The `ADJ_FIXED` switch

Everything hinges on one environment variable, read in `scripts/adj_fallback.R`:

```r
.ADJ_FIXED <- toupper(Sys.getenv("ADJ_FIXED", "FALSE")) == "TRUE"
```

| | `ADJ_FIXED` unset **[RETIRED]** | `ADJ_FIXED=TRUE` **[CURRENT]** |
|---|---|---|
| CSV read | `forest_data_adj_95ci.csv` + `_t2_a3_a4.csv` supplement | `forest_data_adj_95ci_fixed.csv` |
| point estimate | `exp(mean)` — geometric mean | `exp(median)` — posterior median |
| inner 68% band | backed out of the 95% CI under a log-normal approximation | exact `exp(q16)`/`exp(q84)` |
| output dir | `..._wide/` | `..._wide_fixed/` |

**It is off by default.** Any script that sources the renderers without setting
it silently produces the retired numbers.

---

## 4. File status

### Scripts

| file | status | note |
|---|---|---|
| `scripts/slim_extract_one.R` | **[CURRENT]** | pass 1 |
| `scripts/adj_join_pass2.R` | **[CURRENT]** | pass 2 |
| `scripts/run_adj_fixed_extraction.sh` | **[CURRENT]** | driver for both passes |
| `scripts/adj_fallback.R` | **[CURRENT]** | CSV reader; holds the `ADJ_FIXED` switch |
| `scripts/adj_fixed_{dirs,pairs}.csv` | **[CURRENT]** | manifests |
| `scripts/run_slim_pass1.sh` | **[RETIRED]** | earlier standalone pass-1 driver, reads `$S/need_dirs.csv`; superseded by `run_adj_fixed_extraction.sh` |
| `scripts/retired/extract_adj_95ci.R.RETIRED` | **[RETIRED]** | the original extractor; carried Bug 1 (§5). See `retired/README.md` |
| `scripts/extract_adj_customer_day_only.R` | **[RETIRED]** | writes `forest_data_adj_95ci.csv`; contains the Bug 1 index-join pattern (3 sites) |
| `scripts/extract_prop_reruns_only.R` | **[RETIRED]** | same, 2 sites |
| `scripts/extract_t2_customer_day_only.R` | **[RETIRED]** | same, 2 sites |
| `scripts/extract_t2_a3_adj_from_t1_total.R` | **[RETIRED — DO NOT USE]** | Bug 1, *and* implements the cross-model borrow (T2 A3 restaurants divided by the **T1** total) that was rejected as an invalid adjustment |
| `scripts/extract_95ci.R` | | writes the *unadjusted* `forest_data_95ci.csv`; contains the index-join pattern but there is no outcome/total subtraction there, so Bug 1 may not apply — verify before trusting |
| `scripts/extract_forest_data.R` | | writes `forest_data{,_all}.csv` |
| `scripts/extract_mu_gamma_tables.R` | | *consumes* both 95ci CSVs — inherits whatever they contain |
| `scripts/forest_fallback.R` | | unadjusted counterpart of `adj_fallback.R` |

### Data

| file | status | note |
|---|---|---|
| `forest_data_adj_95ci_fixed.csv` | **[CURRENT]** | 2200 rows, has `median`/`q16`/`q84`/`total_source` |
| `forest_data_adj_95ci.csv` | **[RETIRED]** | written by four Bug-1 scripts; restaurant rows are largely *raw, unadjusted* |
| `forest_data_adj_95ci_t2_a3_a4.csv` | **[RETIRED]** | supplement to the above; contains values for 4 restaurants that are raw/unadjusted |
| `forest_data_95ci.csv`, `forest_data_all.csv` | | unadjusted outputs |

### Renderers and output

| path | status | note |
|---|---|---|
| `render/render_professional_wide_fixed.R` | **[CURRENT]** | sets `ADJ_FIXED=TRUE` |
| `forest_plots/professional_wide_fixed/` | **[CURRENT]** | the 15 PDFs to look at |
| `forest_plots/total_adjusted/t{1,2}_sorted_recentered_wide_fixed/` | **[CURRENT]** | plus `*_data.csv` sidecars |
| `render/render_professional_wide.R` | **[RETIRED]** | same renderers without `ADJ_FIXED` |
| `forest_plots/professional_wide/` | **[RETIRED]** | kept for before/after comparison only |
| `forest_plots/total_adjusted/t{1,2}_sorted_recentered_wide/` | **[RETIRED]** | (no `_fixed` suffix) |
| the other `render_professional_*.R` and `forest_plots/*` variants | | predate this work |

---

## 5. What was actually wrong, and what wasn't

**Bug 1 — real, fixed.** The old extractor built `beta[col,rest]` from the
**outcome** model's indices and applied that name to the **total** model. The two
fits have different `predictor_map` and `restaurants_order`, so it read a
different predictor at a different restaurant — and because a restaurant's `beta`
is structurally 0 for another restaurant's exposure column, the subtraction was
usually **minus zero**. The "adjusted" restaurant estimates were mostly raw and
unadjusted. Impact: 15% of T1 and 20% of T2 restaurant estimates move by >5% on
the log scale; largest |Δlog| 3.24 (RR 2.72 → 0.107).

Fixed by joining on `(model_col, restaurant)` with `stopifnot` assertions, so a
future mismatch fails loudly instead of silently subtracting zero.

**"Bug 2" — retracted, was never a bug.** An intermediate version changed the
pooled baseline when the outcome model held a subset of the total model's
restaurants, substituting the total model's `eta` averaged over the matched
restaurants. That is a *finite-population* quantity (it describes the restaurants
observed) differenced against a *superpopulation* numerator — two different
estimands in one figure. Reverted. The pooled rule is unconditionally
`mu_gamma_outcome − mu_gamma_total`. See Gelman (2005), *Analysis of variance —
why it is more important than ever*, Ann. Statist. 33(1), §3.5 (`0504499v2.pdf`
in the repo root) for the distinction, and `review/adj_fix_audit.md` for the
assumption this commits you to plus its empirical check.

**"Bug 3" — retracted, never reached a figure.** The CSV's `mean_exp` column is
`mean(exp(d))`, which explodes for heavy-tailed posteriors, but `adj_fallback.R`
overwrites it before plotting. No figure ever showed an inflated value.

**Two renderer defects — real, fixed.** Both were silent:

1. The restaurant tibbles enumerate columns explicitly. Omitting `mean_exp` left
   it `NA`, and the display step `ifelse(!is.na(mean_exp), mean_exp, exp(mean))`
   fell through to the geometric mean — so pooled markers used `exp(median)`
   while the dots beside them used `exp(mean)`.
2. The single-restaurant pooled drop used `summarise(n_rest = n())`, counting
   *rows* (introductions) rather than restaurants, so it failed to fire at 8 of
   10 sites.

**The general trap:** these tibbles fail *silently*. A dropped column becomes
`NA` and some downstream `ifelse`/`any_of` quietly takes the other branch. Adding
a column to the extractor is not enough — it must be threaded through every
tibble site, and then verified at the rendered output (§6).

---

## 6. How to verify a render

Do not check only that the columns you added appear. Check that **every plotted
value traces back to the CSV**. This is what caught both renderer defects:

```r
csv <- read.csv("publication/forest_data_adj_95ci_fixed.csv")
pool <- unique(round(c(exp(csv$median), exp(0.1*csv$median),
                       exp(csv$mean), exp(0.1*csv$mean), csv$median, csv$mean), 9))
d <- read.csv("publication/forest_plots/total_adjusted/t2_sorted_recentered_wide_fixed/A4_its_targeted_restaurants_data.csv")
v <- round(d$mean[!is.na(d$mean)], 9)
sum(!(v %in% pool))          # must be 0
sum(v %in% round(exp(csv$median),9))   # should account for the RR-scale rows
```

State when last measured (against the mixed generation described at the top —
re-measure after any manifest change), all 12 RR-scale files: 1222/1222 point
estimates trace, all to the median family; 4896/4896 interval bounds trace;
**zero** geometric-mean values; zero unexplained.

Two gotchas that produced false alarms during this work:

- In the `*_data.csv` sidecars the `mean` column is **already exponentiated** for
  RR-scale plots. Do not `exp()` it again.
- A1 mixes two transforms — count outcomes plot `exp(median)`, proportion
  outcomes plot `exp(0.1·median)` (per 10 percentage points). Match against the
  **union**, or you will see a spurious ~50% mismatch.
- Rows keyed by `(analysis, outcome, type)` are **not unique** (a restaurant can
  have several introductions; A1 has several fits per outcome). Include
  `fit_dir` and `model_col` in any merge key.

---

## 7. Known gaps — not yet done

**A5/A6 are only partly migrated.** They read the corrected CSV (so Bug 1 is
fixed for them), but `create_customer_day_forest_plots_consolidated.R` was never
touched by this work and:

- plots the **posterior mean**, not the median — 515/518 T2 and 115/115 T1 values
  match the mean family, zero match the median family. The paper therefore mixes
  estimands across figures.
- carries no `q16`/`q84`, so its inner band is still the log-normal approximation.
- `z_A5_transaction_*` renders from a source outside the fixed CSV entirely
  (15 values untraceable); three A5/A6 "day" sidecars have a different column
  structure and cannot be checked by the §6 recipe.

These are identity-link plots, so mean-vs-median is a genuine estimand choice
rather than a transform artifact — but consistency across figures argues for the
median.

**Two total models need re-fitting.** Their starters call `run_its_t2()` /
`run_customer_t2()` without `restaurants_to_model` and inherit a default whose
Tier-1 block is commented out:

| model | has | missing | breaks |
|---|---|---|---|
| `_cp/t2_a3_its/total` | 13 | VLZX7K2M9QD4T, SRQS8F, 2HRX9P, JHDN7CF | 6 pairs |
| `_cp/t2_a5_customer_day/total` | 15 | VLZX7K2M9QD4T, JHDN7CF | 1 pair |

Until then `adj_join_pass2.R` **drops** the affected restaurant rows (38
warnings) rather than borrowing a coefficient from another fit, which would not
be a valid adjustment. T1 has zero gaps. Details in
`review/t2_a3_total_restaurant_gap.md`.

**One fit worth inspecting:** `t2_a3_its / meat / slope` at `W8T41JZK0ZMEP` comes
out at RR 6317 with a 95% CI of [13, 147921]. It traces correctly through the
pipeline — the slope is simply unidentified. It is clipped on the plot.

---

## 8. Related documents

| file | contents |
|---|---|
| `review/adj_fix_audit.md` | full audit, plus methods-ready text for the baseline-exchangeability assumption and its diagnostic |
| `review/wide_plot_control_flow.md` | end-to-end trace of the render chain |
| `review/t2_a3_total_restaurant_gap.md` | the missing-restaurant problem and its fix |
| `review/pooled_outside_restaurants_diagnosis.md` | original diagnosis |
| `scripts/retired/README.md` | why the old extractor was retired |
| `0504499v2.pdf` (repo root) | Gelman (2005), the estimand citation |

---

## 9. Standing constraints

- `fit.rds` extractors historically glitch through the WSL Bash tool; the user
  runs those on Windows. Pass 2 reads only slim `.rds` files and is safe locally.
- `CLAUDEM=1` means an 18 GB slice cap. Exit code 137 / `Killed` / `SIGKILL`
  means the cap was hit — **stop and ask**, do not retry.
- Never overwrite the retired CSVs or `professional_wide/`; they are the
  before-side of the comparison.

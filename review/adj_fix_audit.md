# Audit — corrected adjusted (RRR) extraction

Deliverables:

- `publication/scripts/slim_extract_one.R` — pass 1, one fit per subprocess
- `publication/scripts/adj_join_pass2.R` — pass 2, corrected join
- `publication/scripts/run_adj_fixed_extraction.sh` — driver for both passes
- `publication/forest_data_adj_95ci_fixed.csv` — corrected estimates, all 117
  outcome/total pairs across all 12 subanalyses (new file)
- `publication/render/render_professional_wide_fixed.R` — renders to
  `publication/forest_plots/professional_wide_fixed/`

**Nothing existing was overwritten.** The original CSVs, the original extractors,
and `professional_wide/` are untouched. Everything new is gated behind
`ADJ_FIXED=TRUE`, which is off by default.

---

## Bugs fixed

### Bug 1 — restaurant rows subtracted the wrong coefficient

`extract_adj_95ci.R:192` built `beta[col,rest]` from the **outcome** model's
indices and applied that name to the **total** model. Different `predictor_map`,
different `restaurants_order`, so it read a different predictor at a different
restaurant. Because a restaurant's `beta` is structurally 0 for another
restaurant's exposure column, the subtraction was usually **minus zero** — the
"adjusted" restaurant estimates were mostly **raw, unadjusted** values.

Fixed by joining on `(model_col name, restaurant name)`. Every match is asserted
with `stopifnot`, so a future mismatch fails loudly instead of silently
subtracting zero.

### "Bug 2" — RETRACTED. It was never a bug.

I had claimed the pooled baseline was wrong when the outcome model held a subset
of the total model's restaurants, and replaced `mu_gamma_total` with the total
model's `eta` averaged over the matched restaurants.

That was an **estimand substitution, not a fix**. Per Gelman (2005), *Analysis of
variance — why it is more important than ever*, Ann. Statist. 33(1) 1–33, §3.5
(read in full, `0504499v2.pdf`):

> "The superpopulation standard deviation characterizes the uncertainty for
> predicting a new coefficient from batch m, whereas the finite-population
> standard deviation describes the existing J_m coefficients."

`mean(eta_total | matched restaurants)` is a **finite-population** quantity — it
describes the restaurants actually observed. `mu_gamma` is **superpopulation**.
So the rule I shipped differenced a superpopulation numerator against a
finite-population baseline, and the pooled markers were not comparable across
outcomes within one figure: 146 rows were pure superpopulation, 122 were the
mixture.

The reported estimand is superpopulation — "what would we expect at a **new**
restaurant". The pooled rule is therefore unconditionally

```r
base <- mt[seq_len(n), gi]                       # mu_gamma_total, always
src  <- if (same_set) "mu_gamma_total" else "mu_gamma_total_subset"
```

`total_source` still records provenance: 146 `mu_gamma_total`, 122
`mu_gamma_total_subset`.

**What made this hard to see:** Bug 1 left the restaurant dots raw/unadjusted, so
the pooled marker was being compared against a wrong set of dots. "Pooled outside
the dot range" looked like a pooled-side defect when it was a dots-side defect. I
then adopted "pooled inside the dot range" as a correctness criterion, which it
is not — `mu_gamma` is a restaurant-level population parameter while the dots are
per-introduction `gamma`s, so with few restaurants ordinary shrinkage can legitimately
put it outside.

Also verified: for matching restaurant sets the retracted rule and the correct
rule are the *same expression*, so of the 84 pooled rows that moved on reverting,
**all 84 are subset rows and 0 are same-set rows** — the expected invariant.

#### Which analyses this touches

Every **targeted** analysis is 100% subset, because a targeted outcome only
exists at the restaurants that introduced it:

| analysis | subset rows | outcomes |
|---|---|---|
| `a2_proportion_t` | 20/20 | breakfast, chicken, dairy, egg, untextured |
| `a4_its_t` | 6/6 | breakfast, textured, untextured |
| `a6_customer_t_day` | 8/8 | breakfast, untextured |
| `t2_a2_proportion_t` | 24/24 | + textured |
| `t2_a4_its_t` | 10/10 | all five |
| `t2_a6_customer_t_day` | 20/20 | all five |
| `a1_proportion` | 16/60 | chicken_fish, vegan |
| `t2_a1_proportion` | 16/60 | chicken_fish, vegan |
| `a3_its` | 2/10 | chicken_fish |
| `a5`, `t2_a5`, `t2_a3` | 0 | — |

#### Caveat that belongs in the paper, not the code

In subset cases `mu_gamma_outcome` and `mu_gamma_total` are estimated from
**different restaurant sets**, so reading their difference as a superpopulation
RRR assumes the two sets are exchangeable. For targeted outcomes that is exactly
where the assumption is weakest — restaurants serving chicken dishes are not a
random subset of all restaurants. No choice of baseline repairs this; it is a
property of the estimand. `mu_gamma_total_subset` flags the affected rows.

### Estimand — median instead of geometric mean

The CSVs stored no median, so `adj_fallback.R` fell back to `exp(mean_log)` (the
geometric mean), which equals the median only under log-symmetry. Pass 2 now
stores a `median` column and, under `ADJ_FIXED`, the renderer plots
`exp(median)` — exactly the posterior median RR, and consistent with the
quantile-based CI.

### Both intervals are now exact Monte Carlo

All summaries are quantiles of the draw vector -- no distributional assumption:

- **95% CI** = `quantile(d, c(0.025, 0.975))`. This was always Monte Carlo.
  Stan's own summary carries only `q5`/`q95` (90%), which is why the 95% bounds
  are computed from draws.
- **68% inner band** = `quantile(d, c(0.16, 0.84))`, now **stored** as `q16`/`q84`.

Previously only `q2.5`/`q97.5` were stored, so `add_inner_ci()` had to back out
`sigma_hat = (log q97.5 - log q2.5) / (2 x 1.96)` and draw `RR * exp(+/-sigma_hat)`
-- a log-normal approximation, needed only because the intermediate CSV lacked a
68% column. It also required a clamp, since on a skewed posterior the
approximated band could overshoot its own CI.

That is gone. Verified on all 10 A3 pooled rows: plotted inner band equals
`exp(q16)`/`exp(q84)` to machine precision. The clamp is now dead code on the
`ADJ_FIXED` path.

### Not a bug — retracted

`mean_exp = mean(exp(d))` in the CSVs is never plotted: `adj_fallback.R:56`
overwrites it before rendering. No figure ever showed an inflated value.

---

## Memory strategy

Peak RSS is dominated by `readRDS` materialising every parameter in a fit
(`lambda`, `log_lik`, `y_rep`…) — roughly 1.5–2.9× the on-disk size. The
variables actually needed are tiny (`beta` is ~15 MB at 6000 × 324).

So the split is **across fits, not within one**: one subprocess per fit, so the
OS reclaims the peak before the next starts. This also removes something the old
extractor did — it held the outcome **and** total fits in memory simultaneously.

Streaming/chunked quantiles were considered and are unnecessary: once variables
are selected, everything fits comfortably, and exact medians/quantiles need the
full draw vector anyway (only ~6000 values per parameter).

| | |
|---|---|
| fits processed | **133 / 133, zero failures** |
| peak RSS | min 281 MB, median ~1.6 GB, **max 3.9 GB** |
| budget | 8 GB target, 18 GB slice cap — **max was 48% of target** |
| input | 120 GB of `fit.rds` |
| slim output | ~50 MB |
| pass 2 peak | 249 MB |
| output rows | 2200 (268 pooled, 1932 restaurant), all 12 subanalyses |

Slim files are written to `/var/tmp/adj_slim`, deliberately outside the session
scratchpad — the scratchpad was wiped mid-run twice, destroying partial work.

---

## Verification

**Single pair first** (`a3_its/chicken_fish`), before running the rest: all five
restaurant values reproduced the hand-computed `beta_o − beta_t` to 4 dp, and the
pooled moved inside the restaurant range.

| restaurant | pass 2 | hand-computed |
|---|---|---|
| VLZX7K2M9QD4T | −0.4028 | −0.4028 |
| 2HRX9P6HKXA8V | −0.2679 | −0.2679 |
| JHDN7CF1C03X5 | −0.0330 | −0.0330 |
| L69HYJ4Y3TR91 | −0.0732 | −0.0732 |
| ED5J990H5VAZT | 0.6798 | 0.6798 |

**Acceptance across everything**, measured on the **rendered** data
(`*_data.csv`, i.e. what the figures actually draw), not the intermediate CSV.
A5/A6 are identity-link and never exponentiated, so they are excluded from the
RR-scale check:

| | groups | pooled outside |
|---|---|---|
| RR-scale files | 57 | **1** |

The one remaining is `t2_a4_its_t / dairy_t2 / level` — 1.416 vs [0.891, 1.262],
3 restaurants. Under a superpopulation estimand this is **expected, not a
defect**: `mu_gamma` is a restaurant-level population parameter, the dots are
per-introduction `gamma`s, and with 3 restaurants shrinkage can place the
population mean outside the observed spread. Reported rather than papered over.

Note the earlier "before 14 / after 2" figures in this document were computed
with a broken measurement script (it double-exponentiated an
already-exponentiated column, and used a non-unique merge key). They should not
be compared against the table above.

**Estimand consistency, verified end to end.** Every rendered restaurant dot was
matched against the source CSV:

| rendered restaurant dots | count |
|---|---|
| `exp(median)` | 769 |
| `exp(0.1 · median)` (A1 per-10-pp transform) | 352 |
| `exp(mean)` (geometric mean) | **0** |
| unexplained | **0** |

### Two renderer defects found while verifying the above

Both were in the `ADJ_FIXED` path and both are fixed.

1. **Restaurant dots silently plotted the geometric mean.** The restaurant
   tibbles in the T2 `a3_its` and `t2_a4_its_t` builders enumerate columns
   explicitly and omitted `mean_exp`, leaving it `NA`; the display step
   `mean = ifelse(!is.na(mean_exp), mean_exp, exp(mean))` then fell through to
   `exp(mean)`. So pooled markers used `exp(median)` while the dots beside them
   used `exp(mean)` — two estimands in one figure. This is the same
   explicit-column-list trap that previously dropped `q16`/`q84`; those were
   plumbed through, `mean_exp` was missed.

2. **The single-restaurant pooled drop counted introductions, not restaurants.**
   8 of 10 sites used `summarise(n_rest = n())`, which counts rows. A
   single-restaurant outcome with two introductions scored `n_rest = 2` and kept
   its pooled marker. All 10 sites now use
   `summarise(n_rest = n_distinct(restaurant_id))`.

### Unrelated observation, not a pipeline issue

The largest restaurant dot is `t2_a3_its / meat / slope` at
`W8T41JZK0ZMEP` — RR 6317, 95% CI [13, 147921] (log median 8.75, CI
[2.60, 11.90]). It traces correctly to the CSV; the slope for that restaurant is
essentially unidentified. It is clipped on the plot, but the fit is worth a look.

**The originally reported cases, all fixed** (median, RR scale):

| analysis | outcome | type | pooled | restaurant range |
|---|---|---|---|---|
| a2_proportion_t | chicken_p (presence) | level | 1.220 | [0.744, 2.561] |
| a2_proportion_t | dairy_p (presence) | level | 0.908 | [0.623, 2.063] |
| a2_proportion_t | egg_p (presence) | level | 0.716 | [0.655, 0.788] |
| a3_its | chicken_fish | slope | 0.919 | [0.671, 1.984] |
| a4_its_t | untextured | level | 1.001 | [0.990, 1.013] |
| a4_its_t | untextured | slope | 1.009 | [0.587, 1.676] |
| a4_its_t | breakfast | slope | 0.406 | [0.288, 0.622] |

---

## Rows deliberately dropped

20 restaurant-level rows are **absent by design** — see
`t2_a3_total_restaurant_gap.md`. The T2 A3 total was fitted with 13 restaurants
while its outcomes carry 17, so VLZX7K2M9QD4T / SRQS8F / 2HRX9P / JHDN7CF have no
total-model coefficient and their RRR is undefined.

An earlier draft borrowed the coefficient from the T1 total. That was wrong —
mixing effects across fits is not a valid adjustment — and has been removed. The
fallback is now off unless a path is passed explicitly for diagnostics.

The committed `forest_data_adj_95ci_t2_a3_a4.csv` does contain values for these
four, but they are raw/unadjusted (Bug 1 subtracting a structural zero). Dropping
them is a correction, not a regression.

`total_source` records provenance per row: 1932 restaurant rows all `primary`
(no borrowed coefficients anywhere), and pooled rows split 146 `mu_gamma_total` /
122 `eta_total_matched`.

### Models requiring a re-fit: two

Every restaurant-level gap traces to a **total** model fitted without the Tier-1
restaurants, because its starter calls `run_its_t2()` / `run_customer_t2()`
without `restaurants_to_model` and inherits a default that has the Tier-1 block
commented out.

| model to re-fit | n now | missing | pairs it breaks |
|---|---|---|---|
| `_cp/t2_a3_its/total` | 13 | VLZX7K2M9QD4T, SRQS8F, 2HRX9P, JHDN7CF | 6 (T2 A3 x3, T2 A4 x3) |
| `_cp/t2_a5_customer_day/total` | 15 | VLZX7K2M9QD4T, JHDN7CF | 1 (T2 A6 untextured) |

Their starters (`model_starters/t2_a3_its/A3_T2_total.R`,
`model_starters/t2_customer/A5_T2_total.R`) both pass **no** explicit restaurant
list. Fix is to pass the full list explicitly, re-fit, re-run pass 1 for those
two fits and pass 2.

T1 has **zero** gaps.

---

## Not yet addressed

- `extract_adj_95ci.R` itself is unchanged. The corrected logic lives in
  `adj_join_pass2.R`; the old extractor should eventually be retired or patched
  so a future run cannot reintroduce Bug 1.
- The same default-list inheritance affects other pairings — the audit found
  restaurant gaps in `t2_a3_its` (3 outcomes), `t2_a4_its_t` (3), and
  `t2_a6_customer_t_day` (1).
- Tier 1 remains untouched and reproducible.

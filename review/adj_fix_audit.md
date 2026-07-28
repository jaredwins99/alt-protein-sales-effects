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

### Bug 2 — pooled baseline averaged over restaurants not in the outcome model

Pooled was `mu_gamma_outcome − mu_gamma_total`, where `mu_gamma_total` averages
over **all** the total model's restaurants. Where the outcome model held only a
subset, the baseline included restaurants absent from the analysis entirely.

The pooled estimate is a **population-level** quantity (`mu_gamma`), so its
baseline must be population-level too. The rule applied:

- **Same restaurant set** -> keep `mu_gamma_total`. It is already correct.
- **Outcome is a subset** -> restrict to the matched restaurants by averaging the
  total model's `eta` (its per-restaurant means), staying at the same level of
  the hierarchy.

No re-fitting: the total model already estimates a separate `eta` per restaurant.

A first attempt used the empirical mean of per-introduction `beta` as the
baseline in **all** cases. That was wrong and the acceptance test caught it: it
broke `a3_its` (meat and nonvegan slopes moved outside), because `mu_gamma` is
the mean of restaurant-level `eta`s, not of introduction-level `gamma`s, so
mixing levels introduces a spurious offset. Provenance is recorded per row in
`total_source`: 146 pooled rows use `mu_gamma_total`, 122 use
`eta_total_matched`.

### Estimand — median instead of geometric mean

The CSVs stored no median, so `adj_fallback.R` fell back to `exp(mean_log)` (the
geometric mean), which equals the median only under log-symmetry. Pass 2 now
stores a `median` column and, under `ADJ_FIXED`, the renderer plots
`exp(median)` — exactly the posterior median RR, and consistent with the
quantile-based CI.

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

**Acceptance across everything** — pooled inside the restaurant range:

Measured on the **rendered** data (`*_data.csv`, i.e. what the figures actually
draw), not just the CSV:

| | groups | pooled outside |
|---|---|---|
| before | 52 | **14** |
| after | 105 | **2** |

The two remaining, both subset cases where the outcome model has very few
restaurants:

- `a4_its_t / untextured / slope` — 0.425 vs [0.587, 1.676] (1 restaurant)
- `t2_a4_its_t / dairy_t2 / level` — 0.782 vs [0.889, 1.248] (3 restaurants)

These are the residual `eta`-vs-`gamma` level mismatch: the pooled sits at the
restaurant-mean level while the dots are per-introduction, and with 1-3
restaurants the two need not bracket. Forcing them inside would require using an
empirical mean of the dots as the pooled estimate, which abandons the
population-parameter interpretation and (as shown above) corrupts the cases that
are currently correct. Reported rather than papered over.

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

**This is the one issue requiring a model re-fit** — one model, `t2_a3_its/total`
with all 17 restaurants.

---

## Not yet addressed

- `extract_adj_95ci.R` itself is unchanged. The corrected logic lives in
  `adj_join_pass2.R`; the old extractor should eventually be retired or patched
  so a future run cannot reintroduce Bug 1.
- The same default-list inheritance affects other pairings — the audit found
  restaurant gaps in `t2_a3_its` (3 outcomes), `t2_a4_its_t` (3), and
  `t2_a6_customer_t_day` (1).
- Tier 1 remains untouched and reproducible.

# Audit — corrected adjusted (RRR) extraction

Deliverables:

- `publication/scripts/slim_extract_one.R` — pass 1, one fit per subprocess
- `publication/scripts/adj_join_pass2.R` — pass 2, corrected join
- `publication/scripts/run_adj_fixed_extraction.sh` — driver for both passes
- `publication/forest_data_adj_95ci_fixed.csv` — corrected estimates (new file)
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

### Bug 2 — pooled and restaurant rows used different baselines

Pooled was `mu_gamma_outcome − mu_gamma_total`, where `mu_gamma_total` averages
over **all** the total model's restaurants, while each restaurant dot subtracts
that restaurant's **own** total coefficient. Where the outcome model held a
subset, the two sat on different baselines.

Fixed by restricting the pooled baseline, per draw, to exactly the introductions
present in the outcome model. No re-fitting: the total model already estimates a
separate `beta`/`eta` per restaurant.

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
| fits processed | **73 / 73, zero failures** |
| peak RSS | min 281 MB, median 1574 MB, **max 3806 MB** |
| budget | 8 GB target, 18 GB slice cap — **max was 47% of target** |
| input | 55.7 GB of `fit.rds` |
| slim output | ~27 MB |
| pass 2 peak | 249 MB |

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

| | groups | pooled outside |
|---|---|---|
| before | 52 | **14** |
| after | 80 | **2** |

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

**Two residual cases**, both A6 with a single restaurant:

- `a6_customer_t_day / untextured / slope` — 1.074 vs [0.703, 1.055]
- `t2_a6_customer_t_day / untextured_t2 / gender_male` — 0.706 vs [0.737, 1.138]

These are legitimate, not defects: `mu_gamma` is a population mean over
restaurants while the plotted dots are per-*introduction*. With one restaurant,
small excursions beyond the introduction spread are expected.

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

`total_source` records provenance per row: 660 `primary`, 90 `matched_baseline`,
0 `fallback_t1_total`.

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

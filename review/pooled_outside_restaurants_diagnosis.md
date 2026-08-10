# Why pooled estimates fall outside the restaurant-level estimates

Deep dive, no pipeline changes made.

**Answer up front:** it is the RRR adjustment, not the priors. There are two
independent bugs in the *extraction* step, plus a third cosmetic issue in what
the plot draws as the point estimate. All three are post-processing — **no model
re-fits are required.** Fixing the two adjustment bugs takes the number of
affected pooled estimates from **14 → 6 → 0**.

---

## Bug 1 — the restaurant-level "adjusted" values subtract the wrong coefficient

`publication/scripts/extract_adj_95ci.R:189-194`

```r
for (k in seq_along(data_list_o$idx_exposure)) {
  col_idx <- data_list_o$idx_exposure[k]     # index in the OUTCOME model
  r_idx   <- data_list_o$expo_to_rest[k]     # index in the OUTCOME model
  vn      <- sprintf("beta[%d,%d]", col_idx, r_idx)
  ...
  d <- beta_draws_o[seq_len(nb), vn] - beta_draws_t[seq_len(nb), vn]   # SAME name on both
}
```

`vn` is built from the **outcome** model's column and restaurant indices and then
applied unchanged to the **total** model. The two models have different
`predictor_map`s and different `restaurants_order`, so `beta_draws_t[, vn]` is a
different predictor at a different restaurant.

Worked example — `a3_its / chicken_fish` (5 restaurants) against
`a3_its / total` (6 restaurants). Restaurant indices are already off by one from
position 2 onward:

```
outcome: 1=VLZX7K2M9QD4T 2=2HRX9P 3=JHDN7CF 4=L69HYJ 5=ED5J99
total  : 1=VLZX7K2M9QD4T 2=SRQS8F 3=2HRX9P  4=JHDN7CF 5=L69HYJ 6=ED5J99
```

| outcome coefficient (correct) | what `total[vn]` actually is | b_out | subtracted | CSV mean |
|---|---|---|---|---|
| exposure_VLZX7K2M9QD4T_1 | exposure_VLZX7K2M9QD4T_1 @ VLZX7K2M9QD4T | −0.0065 | 0.0469 | −0.0535 |
| exposure_2HRX9P_1 | exposure_SRQS8F_1 @ **SRQS8F** | −0.0708 | 0.0581 | −0.1289 |
| exposure_JHDN7CF_1 | exposure_SRQS8F_2 @ **2HRX9P** | 0.0032 | **0.0000** | 0.0032 |
| exposure_L69HYJ_1 | exposure_2HRX9P_1 @ **JHDN7CF** | −0.0542 | **0.0000** | −0.0542 |
| exposure_ED5J99_1 | exposure_JHDN7CF_1 @ **L69HYJ** | −0.1605 | **0.0000** | −0.1605 |
| all five *_slope | various @ wrong restaurant | — | **0.0000** | = raw |

Every CSV value reproduces exactly, so this is confirmed, not inferred.

In the Stan model a restaurant's `beta` is **0** for every exposure column that
belongs to another restaurant (`model_multilevel_transfer_truncated.stan:206`),
so the mis-indexed lookup usually returns **0**. The practical consequence:

> **The restaurant-level dots are, in most cases, raw *unadjusted* outcome
> effects, while the pooled diamond is a properly adjusted RRR.** They are not
> the same quantity, which is why the pooled can sit anywhere relative to them.

VLZX7K2M9QD4T's level term is correct only by luck (index 1 in both models, and its
column index happened to line up).

### Scope

The bug bites **exactly when the outcome model's restaurant set differs from the
total model's**. When the sets match, the indices coincide and the result is
correct by construction.

| CSV / extractor | analysis | status |
|---|---|---|
| `extract_adj_95ci.R` | a3_its / chicken_fish (5 vs 6) | 9 of 10 wrong |
| | a4_its_t / breakfast (3 vs 6) | 6 of 6 wrong |
| | a2_proportion_t / dairy_p (3 vs 6) | 3 of 3 wrong |
| | t2_a2_proportion_t / dairy_p | 3 wrong |
| | a3_its / nonvegan (6 vs 6) | 14 of 14 correct |
| | t2_a1_proportion / meat (18 vs 18) | correct |
| `extract_t2_a3_adj_from_t1_total.R` | t2_a3_its, t2_a4_its_t | **correct** |

The T2 A3/A4 extractor already does it properly — it maps by `model_col` **name**
and restaurant **name** (`extract_t2_a3_adj_from_t1_total.R:129-137`). That is
the pattern `extract_adj_95ci.R` should adopt.

---

## Bug 2 — pooled and restaurant rows use different baselines

Even with Bug 1 fixed, 6 groups remain outside because:

- **pooled** = `mu_gamma_outcome − mu_gamma_total`, where `mu_gamma_total` is the
  total model's mean across **all** its restaurants
- **restaurant dot** = `beta_outcome[r,k] − beta_total[r,k]`, i.e. that
  restaurant's **own** total-sales coefficient

When the outcome model holds a subset of the total model's restaurants, the
pooled is offset by `beta_total[r] − mu_gamma_total`.

Clearest case, `a4_its_t / untextured` (**1** restaurant vs **6** in total):

- `mu_gamma_total[slope]` = **+0.600** (average over 6 restaurants)
- SRQS8F's own total slopes = **−1.127** and **+0.340** (mean −0.393)
- offset ≈ **−1.0 on the log scale** — the entire discrepancy

Recomputing the pooled against the matched restaurants/introductions resolves
**all six**:

| analysis | outcome | exposure | type | nR out/tot | pooled now | pooled matched | restaurant range |
|---|---|---|---|---|---|---|---|
| a1_proportion | chicken_fish | vegan_dishes_count | level | 5/6 | 0.924 **OUT** | 1.033 ok | [0.943, 1.191] |
| a1_proportion | vegan | vegan_dishes_count | level | 5/6 | 0.941 **OUT** | 1.051 ok | [0.999, 1.116] |
| a2_proportion_t | dairy_p | dairy_dishes_count | level | 3/6 | 0.994 **OUT** | 1.012 ok | [1.010, 1.036] |
| a2_proportion_t | egg_p | egg_dishes_presence | level | 2/6 | 0.878 **OUT** | 0.712 ok | [0.629, 0.790] |
| a3_its | nonvegan | — | level | 6/6 | 0.988 **OUT** | 0.994 ok | [0.989, 1.002] |
| a4_its_t | untextured | — | slope | 1/6 | 0.381 **OUT** | 1.028 ok | [0.622, 1.584] |

(`a3_its / nonvegan` is a 0.1% edge case — mu_gamma is the mean of the *etas*
while the dots are *introduction*-level gammas. Cosmetic.)

---

## Bug 3 — A1/A2 plot E[exp(X)] while their CI uses exp(quantiles)

**Scope correction:** this is *not* a pooled-vs-restaurant asymmetry. Both levels
are treated identically by the extractor (`mean(exp(d))`, lines 166 and 214).
The split is by analysis:

| analysis | plotted point estimate | inflated? |
|---|---|---|
| A1, A2 | `mean_exp` = `mean(exp(d))` | **yes** |
| A3, A4 | `exp(mean_log)` | no |

Verified on `a3_its / nonvegan` pooled level: source `mean(log) = -0.01157`,
`exp(mean) = 0.98850`, `mean_exp = 0.99083`; the rendered data csv contains
**0.98850**, i.e. `exp(mean_log)`.

For A1/A2 the point estimate is the posterior **mean** of the rate ratio while
the CI is built from `exp` of the log-scale quantiles. Since
`E[exp(X)] = exp(mu + sigma^2/2)`, the inflation grows with each row's posterior
**variance** — so rows are distorted by *different* amounts, which is what
reorders pooled against restaurants. Binary `*_presence` exposures have very wide
posteriors and blow up:

| a2 / dairy_p / presence | plotted point | exp(mean log) | 95% CI |
|---|---|---|---|
| POOLED | 1.094 | 0.835 | [0.205, 3.653] |
| ED5J990H5VAZT | 1.000 | 0.997 | [0.871, 1.143] |
| **JHDN7CF1C03X5** | **45,470,124** | 2.001 | [0.311, 3372] |
| W8T41JZK0ZMEP | 7.121 | 1.094 | [0.144, 9.298] |

A point estimate of 45 million inside a CI of [0.31, 3372] is internally
inconsistent. On the panel that restaurant clips to the right edge while the
pooled sits mid-plot.

**Fix:** plot the posterior median RR (`exp(median(X))`) — consistent with the
quantile CI and invariant under the log transform. Note A3/A4 already plot
`exp(mean_log)`, which is close to the median for a symmetric log posterior.

### Note on the dead median code

`median(exp(diff_draws))` appears in the renderer's `compute_adjusted_*`
functions, but those read `samples.rds` **first** and only fall back to the CSV
if it is absent. `samples.rds` is **missing for every T1 fit**, so the CSV path
always runs and the median code never executes. (The T2 renderer is explicitly
CSV-first; the T1 renderer is samples-first with a CSV fallback — they differ.)

## Answers to the specific questions

- **Artifact of the RRR adjustment with the total model?** Yes — two separate
  defects, both in the adjustment/extraction, not in the models.
- **Fixable?** Yes, entirely in post-processing. **No re-fitting.** It does need
  re-extraction from the fit draws, then a re-render.
- **A CI-representation-of-the-posterior thing?** Not for the ordering problem,
  but Bug 3 is exactly that, and it is what makes the presence panels look
  extreme.
- **Priors pulling too hard?** **No.** After Bugs 1 and 2 are corrected, every one
  of the 52 pooled estimates lies within its restaurant range. No re-run with
  different priors is warranted.

### Is Bug 2 a judgement call?

Mostly no. When the outcome and total models hold different restaurant sets, the
current formula differences two *different populations*, which is incoherent —
restricting the baseline to the matched restaurants is the correct fix, not a
preference. Two genuinely open points remain, both minor:

- **Weighting.** The dots are per-*introduction*, so a restaurant with two
  introductions contributes two dots. Average over restaurants or over
  introductions? Introductions are balanced everywhere except
  `a4_its_t / untextured` (SRQS8F has 2), so this changes one number.
- **Estimand wording.** A population mean may legitimately fall outside the
  sample range in a hierarchical model. Guaranteeing it sits among the dots means
  reporting a sample average rather than a population parameter — worth stating
  in the methods.

---

## Suggested order of work

1. Fix `extract_adj_95ci.R` to map by `model_col` name + restaurant name (copy
   the logic from `extract_t2_a3_adj_from_t1_total.R:127-138`).
2. Decide the pooled estimand so it is comparable with the dots — recommend
   computing the pooled RRR against the matched restaurants' total-model
   baseline, per draw.
3. Switch the plotted point estimate from `mean_exp` to the posterior median RR.
4. Re-extract the 95ci CSVs, re-render, re-check all 52 groups.

Nothing above changes any model, so Tier 1 stays reproducible — only the derived
CSVs and figures change.

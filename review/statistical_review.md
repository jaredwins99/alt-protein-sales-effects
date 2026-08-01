# Statistical Overlap Analysis

## Summary

This analysis investigates **statistical overlap (positivity)** issues in the MPBA study data. Statistical overlap is critical for causal identification - without sufficient variation in exposure within each restaurant over time, the effect of exposure on outcomes becomes unidentifiable.

**Key Findings:**

1. **A1/A2 Proportion Analyses**:
   - **MPBA Proportion**: 2 restaurants have zero variance (never adopt MPBA), 8 restaurants have variance < 0.001 (essentially constant exposure)
   - **Vegan Proportion**: 1 restaurant has zero variance, 2 with variance < 0.001
   - **Vegetarian Proportion**: 1 restaurant has zero variance

2. **A1/A2 Proportion Targeted Analyses** (binary presence indicators):
   - **Severe overlap violations**: Many exposure indicators are constant within restaurants
   - Textured: 17/20 restaurants have zero variance (all zeros or all ones)
   - Chicken: 14/20 restaurants have zero variance
   - Egg: 13/20 restaurants have zero variance

3. **A3-A6 ITS Analyses**:
   - **Exposure is restaurant-specific by design**: Each ITS exposure column is a step function that only "turns on" for one restaurant
   - For each exposure, 19/20 restaurants have zero variance (they never experience that specific MPBA introduction)
   - The ITS design is fundamentally different - it leverages the timing of introduction within each restaurant

4. **Outcome Variance in Constant Exposure Cases**:
   - Even where exposure is constant, outcomes have substantial variance (outcome still varies day-to-day)
   - This means the problem is **lack of exposure variation**, not lack of outcome variation

---

## A1/A2: Menu Proportion Exposures

### Exposure Variation by Restaurant

#### MPBA Proportion (`mpbamod_dishes_prop`)

| location_id | n_obs | exposure_min | exposure_max | exposure_range | exposure_var | n_unique |
|-------------|-------|--------------|--------------|----------------|--------------|----------|
| 75WYSXR9QBK5M | 1324 | 0 | 0 | 0 | **0.000** | 1 |
| VLZX7K2M9QD4T | 365 | 0 | 0 | 0 | **0.000** | 1 |
| C0BE4NDSW26QN | 2265 | 0.020 | 0.500 | 0.480 | 0.000221 | 14 |
| L69HYJ4Y3TR91 | 335 | 0 | 0.071 | 0.071 | 0.000229 | 3 |
| 78AY09MVJVTYE | 3208 | 0 | 0.083 | 0.083 | 0.000322 | 3 |
| LBZEEFSBJNB3Z | 712 | 0.167 | 0.308 | 0.141 | 0.000386 | 6 |
| S8MT0YGD2KTN9 | 1964 | 0 | 0.200 | 0.200 | 0.000390 | 4 |
| 2HRX9P6HKXA8V | 1733 | 0 | 0.143 | 0.143 | 0.000899 | 5 |
| 1SQPTEGYPH0GA | 3805 | 0 | 0.143 | 0.143 | 0.00133 | 5 |
| LQ5EH4BKGV61T | 806 | 0 | 0.222 | 0.222 | 0.00145 | 5 |
| LFZFT3VASXPED | 694 | 0 | 0.200 | 0.200 | 0.00214 | 5 |
| W8T41JZK0ZMEP | 1265 | 0.160 | 0.476 | 0.316 | 0.00332 | 11 |
| JHDN7CF1C03X5 | 1669 | 0.355 | 1.000 | 0.645 | 0.00558 | 15 |
| 9XKJD8DQTH559 | 1522 | 0 | 0.321 | 0.321 | 0.00601 | 12 |
| SRQS8F7JWA9MZ | 1587 | 0 | 0.250 | 0.250 | 0.00686 | 9 |
| V3Q26BHF3SE2H | 1393 | 0 | 0.571 | 0.571 | 0.0152 | 12 |
| CB2KHY1C2G9PT | 1888 | 0 | 0.500 | 0.500 | 0.0160 | 13 |
| SAFK7ND1HR6XS | 2001 | 0 | 1.000 | 1.000 | 0.0259 | 16 |
| EMBVNVD207CC6 | 3336 | 0 | 1.000 | 1.000 | 0.0349 | 32 |
| ED5J990H5VAZT | 2756 | 0 | 0.818 | 0.818 | 0.0378 | 20 |

**Summary Statistics:**
- Total restaurants: 20
- Restaurants with zero variance: 2 (75WYSXR9QBK5M, VLZX7K2M9QD4T)
- Restaurants with <5 unique exposure values: 7
- Restaurants with variance < 0.001: 8 (40%)
- Restaurants with exposure range < 0.05: 2

#### Vegan Proportion (`vegan_dishes_prop`)

| location_id | exposure_range | exposure_var | n_unique |
|-------------|----------------|--------------|----------|
| VLZX7K2M9QD4T | 0 | **0.000** | 1 |
| S8MT0YGD2KTN9 | 0.133 | 0.000372 | 6 |
| C0BE4NDSW26QN | 0.292 | 0.000987 | 18 |
| ... | ... | ... | ... |
| EMBVNVD207CC6 | 1.000 | 0.0326 | 40 |

**Summary Statistics:**
- Total restaurants: 20
- Restaurants with zero variance: 1 (VLZX7K2M9QD4T)
- Restaurants with variance < 0.001: 2

#### Vegetarian Proportion (`vegetarian_dishes_prop`)

**Summary Statistics:**
- Total restaurants: 20
- Restaurants with zero variance: 1 (VLZX7K2M9QD4T)
- Restaurants with variance < 0.001: 1

### Problematic Cases for A1/A2 Proportion Analyses

**Restaurants with CONSTANT or NEAR-CONSTANT MPBA exposure:**

1. **75WYSXR9QBK5M**: Always 0 MPBA proportion (never adopted MPBA dishes) - **CANNOT IDENTIFY EFFECT**
2. **VLZX7K2M9QD4T**: Always 0 MPBA proportion - **CANNOT IDENTIFY EFFECT**
3. **C0BE4NDSW26QN**: Very low variance (0.000221), range 0.02-0.50 but mostly constant
4. **L69HYJ4Y3TR91**: Very low variance (0.000229), only 3 unique values
5. **78AY09MVJVTYE**: Very low variance (0.000322), only 3 unique values
6. **LBZEEFSBJNB3Z**: Very low variance (0.000386)
7. **S8MT0YGD2KTN9**: Very low variance (0.000390)
8. **2HRX9P6HKXA8V**: Very low variance (0.000899)

**Note**: Having only 3-5 unique exposure values combined with low variance means the model may struggle to distinguish signal from noise for these restaurants.

---

## A1/A2: Proportion Targeted (Binary Presence Indicators)

### Exposure Variation by Restaurant (Binary Indicators)

#### Breakfast Dishes Presence

| Issue | Count |
|-------|-------|
| Restaurants always 0 (never have breakfast MPBA) | 6 |
| Restaurants always 1 (always have breakfast MPBA) | 0 |
| Restaurants with zero variance | 6 |

**Restaurants with zero variance:** 1SQPTEGYPH0GA, 75WYSXR9QBK5M, C0BE4NDSW26QN, LFZFT3VASXPED, S8MT0YGD2KTN9, VLZX7K2M9QD4T

#### Chicken Dishes Presence

| Issue | Count |
|-------|-------|
| Restaurants always 0 | 13 |
| Restaurants always 1 | 1 |
| Restaurants with zero variance | **14 (70%)** |

#### Dairy Dishes Presence

| Issue | Count |
|-------|-------|
| Restaurants always 0 | 5 |
| Restaurants always 1 | 4 |
| Restaurants with zero variance | **9 (45%)** |

#### Egg Dishes Presence

| Issue | Count |
|-------|-------|
| Restaurants always 0 | 11 |
| Restaurants always 1 | 2 |
| Restaurants with zero variance | **13 (65%)** |

#### Textured Dishes Presence

| Issue | Count |
|-------|-------|
| Restaurants always 0 | 17 |
| Restaurants always 1 | 0 |
| Restaurants with zero variance | **17 (85%)** |

Only 3 restaurants (9XKJD8DQTH559, W8T41JZK0ZMEP, SAFK7ND1HR6XS) have any variation in textured dishes presence.

#### Untextured Dishes Presence

| Issue | Count |
|-------|-------|
| Restaurants always 0 | 8 |
| Restaurants always 1 | 1 |
| Restaurants with zero variance | **9 (45%)** |

### Problematic Cases for Proportion Targeted

The binary presence indicators have **severe overlap violations**:

| Exposure | Restaurants with Zero Variance | Identifiable Restaurants |
|----------|--------------------------------|--------------------------|
| Textured | 17 (85%) | 3 |
| Chicken | 14 (70%) | 6 |
| Egg | 13 (65%) | 7 |
| Dairy | 9 (45%) | 11 |
| Untextured | 9 (45%) | 11 |
| Breakfast | 6 (30%) | 14 |

**Implication**: For textured dishes, only 3 restaurants contribute to identification. The pooled effect estimate will be driven almost entirely by these restaurants.

---

## A3-A6: ITS Exposures

### Understanding the ITS Data Structure

The ITS (Interrupted Time Series) data has a fundamentally different structure than the proportion analyses:

- **31 exposure columns** representing different MPBA introduction events
- Each column is a **step function** (0 before introduction, 1 after)
- Each exposure is **restaurant-specific** - only one restaurant experiences each MPBA introduction
- Format: `exposure_[LOCATION_ID]_[MPBA_NUMBER]`

### Pre/Post Observation Counts

For each exposure variable, only the target restaurant has both pre and post observations. All other restaurants have **zero variance** (they never experience that specific treatment).

| Exposure | Target Restaurant | n_pre | n_post | Pre % | Post % |
|----------|-------------------|-------|--------|-------|--------|
| exposure_VLZX7K2M9QD4T_1 | VLZX7K2M9QD4T | 183 | 182 | 50.1% | 49.9% |
| exposure_L69HYJ4Y3TR91_1 | L69HYJ4Y3TR91 | 134 | 201 | 40.0% | 60.0% |
| exposure_2HRX9P6HKXA8V_1 | 2HRX9P6HKXA8V | 215 | 1518 | 12.4% | 87.6% |
| exposure_JHDN7CF1C03X5_1 | JHDN7CF1C03X5 | 245 | 1424 | 14.7% | 85.3% |
| exposure_JHDN7CF1C03X5_2 | JHDN7CF1C03X5 | 432 | 1237 | 25.9% | 74.1% |
| exposure_ED5J990H5VAZT_1 | ED5J990H5VAZT | 2074 | 682 | 75.3% | 24.7% |
| exposure_W8T41JZK0ZMEP_1 | W8T41JZK0ZMEP | 388 | 877 | 30.7% | 69.3% |
| exposure_W8T41JZK0ZMEP_2-5 | W8T41JZK0ZMEP | various | various | various | various |
| exposure_EMBVNVD207CC6_1 | EMBVNVD207CC6 | 1227 | 2109 | 36.8% | 63.2% |
| exposure_C0BE4NDSW26QN_1 | C0BE4NDSW26QN | 1605 | 660 | 70.9% | 29.1% |
| exposure_C0BE4NDSW26QN_2 | C0BE4NDSW26QN | 1618 | 647 | 71.4% | 28.6% |
| exposure_75WYSXR9QBK5M_1 | 75WYSXR9QBK5M | 1145 | 179 | 86.5% | 13.5% |
| exposure_V3Q26BHF3SE2H_1-4 | V3Q26BHF3SE2H | various | various | various | various |
| exposure_LBZEEFSBJNB3Z_1 | LBZEEFSBJNB3Z | 171 | 541 | 24.0% | 76.0% |
| exposure_SAFK7ND1HR6XS_1 | SAFK7ND1HR6XS | 903 | 1098 | 45.1% | 54.9% |
| exposure_CB2KHY1C2G9PT_1 | CB2KHY1C2G9PT | 797 | 1091 | 42.2% | 57.8% |
| exposure_S8MT0YGD2KTN9_1 | S8MT0YGD2KTN9 | 1502 | 462 | 76.5% | 23.5% |
| exposure_LFZFT3VASXPED_1 | LFZFT3VASXPED | 443 | 251 | 63.8% | 36.2% |
| exposure_1SQPTEGYPH0GA_1 | 1SQPTEGYPH0GA | 1131 | 2674 | 29.7% | 70.3% |
| exposure_9XKJD8DQTH559_1 | 9XKJD8DQTH559 | 578 | 944 | 38.0% | 62.0% |
| exposure_9XKJD8DQTH559_2 | 9XKJD8DQTH559 | 664 | 858 | 43.6% | 56.4% |
| exposure_LQ5EH4BKGV61T_1 | LQ5EH4BKGV61T | 599 | 207 | 74.3% | 25.7% |
| exposure_78AY09MVJVTYE_1 | 78AY09MVJVTYE | 297 | 2911 | 9.3% | 90.7% |
| exposure_SRQS8F7JWA9MZ_1 | SRQS8F7JWA9MZ | 456 | 1131 | 28.7% | 71.3% |
| exposure_SRQS8F7JWA9MZ_2 | SRQS8F7JWA9MZ | 533 | 1054 | 33.6% | 66.4% |

### Problematic Cases for ITS

**Low pre-period observations (<100):**
- None (all have at least 134 pre-period observations)

**Low post-period observations (<100):**
- None (all have at least 179 post-period observations)

**Severely imbalanced pre/post splits (>85% in one period):**
- 78AY09MVJVTYE: 9.3% pre / 90.7% post - Very short baseline period
- 2HRX9P6HKXA8V: 12.4% pre / 87.6% post - Short baseline
- 75WYSXR9QBK5M: 86.5% pre / 13.5% post - Short post-treatment period
- JHDN7CF1C03X5_1: 14.7% pre / 85.3% post - Short baseline

**Key Issue with ITS Design**: Each exposure is restaurant-specific, meaning pooling across restaurants in a hierarchical model will estimate a **pooled effect across different MPBA introductions at different restaurants**. This is the intended design, but it means:
1. Each restaurant-MPBA combination contributes one observation to the pooled estimate
2. There are only ~20-30 such observations for the pooled effect
3. Between-restaurant variation may dominate within-restaurant treatment effects

---

## Cross-Check: Outcome Variance Where Exposure is Constant

For restaurants with near-constant MPBA proportion exposure:

| Restaurant | Exposure Variance | Mean Exposure | Mean Outcome | Outcome Variance |
|------------|-------------------|---------------|--------------|------------------|
| 75WYSXR9QBK5M | 0.000 | 0 | 16.5 | 697 |
| VLZX7K2M9QD4T | 0.000 | 0 | 2004 | 127,648 |
| C0BE4NDSW26QN | 0.000221 | 0.049 | 72.6 | 3,772 |
| L69HYJ4Y3TR91 | 0.000229 | 0.040 | 19.1 | 90.5 |
| 78AY09MVJVTYE | 0.000322 | 0.042 | 46.9 | 1,758 |
| LBZEEFSBJNB3Z | 0.000386 | 0.211 | 20.6 | 381 |
| S8MT0YGD2KTN9 | 0.000390 | 0.150 | 31.8 | 390 |
| 2HRX9P6HKXA8V | 0.000899 | 0.114 | 229 | 26,955 |

**Key Finding**: Even where exposure is essentially constant, outcomes still have substantial variance. This confirms the problem is **lack of exposure variation**, not lack of outcome variation. The outcome varies due to:
- Day-of-week effects
- Seasonality
- Weather
- Holidays
- Random noise

But without exposure variation, we cannot attribute any of this outcome variation to the exposure.

---

## Recommendations

### For A1/A2 Proportion Analyses

1. **Consider excluding restaurants with zero exposure variance**:
   - 75WYSXR9QBK5M (always 0 MPBA)
   - VLZX7K2M9QD4T (always 0 MPBA)

2. **Flag restaurants with very low variance** (variance < 0.001):
   - These contribute little to identification
   - Effect estimates for these restaurants will be dominated by the prior/pooling

3. **Report sensitivity analyses**:
   - Run models excluding low-variance restaurants
   - Compare results to full sample

4. **Use informative priors carefully**:
   - In Bayesian models, restaurants with no exposure variation will have posteriors dominated by priors
   - The hierarchical structure provides regularization, but the pooled effect may be driven by only ~12 restaurants with meaningful variation

### For Proportion Targeted (Binary) Analyses

1. **Textured dishes presence is essentially non-identifiable**:
   - Only 3 restaurants have any variation
   - Consider dropping this exposure or reporting with strong caveats

2. **Chicken and egg dishes presence** are also problematic:
   - Only 6-7 restaurants have variation
   - Results should be interpreted with caution

3. **Report the number of restaurants contributing to identification** for each exposure

### For A3-A6 ITS Analyses

1. **The ITS design is fundamentally different and does not have the same overlap problem**:
   - Each restaurant acts as its own control (pre-treatment period)
   - The "overlap" is temporal, not cross-sectional

2. **Concerns for ITS**:
   - Restaurants with imbalanced pre/post periods may have less reliable estimates
   - 78AY09MVJVTYE has only 9.3% pre-period data (297 days)
   - 75WYSXR9QBK5M has only 13.5% post-period data (179 days)

3. **Consider weighting by precision** or reporting heterogeneity in pre/post balance

### General Recommendations

1. **Report transparent overlap diagnostics** in the paper
2. **Conduct sensitivity analyses** excluding problematic restaurants
3. **Be cautious about interpreting restaurant-specific effects** (eta_r) for restaurants with low exposure variance
4. **Focus interpretation on the pooled effect** (mu_gamma) for proportion analyses, acknowledging it is driven by ~12 restaurants with meaningful variation

---

## Appendix: Overall Exposure Distributions

**MPBA Proportion (mpbamod_dishes_prop):**
- Min: 0.00000
- 1st Qu: 0.00000
- Median: 0.07143
- Mean: 0.15129
- 3rd Qu: 0.20833
- Max: 1.00000

**Vegan Proportion (vegan_dishes_prop):**
- Min: 0.00000
- 1st Qu: 0.08571
- Median: 0.14286
- Mean: 0.17027
- 3rd Qu: 0.21053
- Max: 1.00000

**Vegetarian Proportion (vegetarian_dishes_prop):**
- Min: 0.0000
- 1st Qu: 0.3095
- Median: 0.5385
- Mean: 0.5079
- 3rd Qu: 0.6875
- Max: 1.0000

---

# Statistical Methodology Review

## 1. Overdispersion Analysis

### Negative Binomial Distribution Choice

The model uses a **negative binomial type 2 (NB2)** distribution parameterized as `neg_binomial_2(lambda, phi)` in Stan:
- `lambda`: the conditional mean (rate parameter)
- `phi`: the dispersion parameter (larger phi = less overdispersion, closer to Poisson)

The NB2 parameterization has variance:
```
Var(Y) = lambda + lambda^2/phi
```

This is appropriate for count data where variance exceeds the mean, which is typical for restaurant sales data due to:
- Day-to-day volatility
- Special events/holidays
- Weather effects
- Seasonal patterns

### Evidence of Overdispersion from Existing Data

From the overlap analysis, we observe substantial outcome variance even where exposure is constant:

| Restaurant | Mean Outcome | Outcome Variance | Variance/Mean Ratio |
|------------|--------------|------------------|---------------------|
| VLZX7K2M9QD4T | 2004 | 127,648 | 63.7 |
| 2HRX9P6HKXA8V | 229 | 26,955 | 117.7 |
| C0BE4NDSW26QN | 72.6 | 3,772 | 51.9 |
| 78AY09MVJVTYE | 46.9 | 1,758 | 37.5 |
| 75WYSXR9QBK5M | 16.5 | 697 | 42.2 |
| LBZEEFSBJNB3Z | 20.6 | 381 | 18.5 |
| S8MT0YGD2KTN9 | 31.8 | 390 | 12.3 |
| L69HYJ4Y3TR91 | 19.1 | 90.5 | 4.7 |

**Key Finding**: All restaurants show variance/mean ratios substantially greater than 1, confirming overdispersion. The Poisson model (where variance = mean) would be inappropriate. The NB2 model is well-motivated.

### Restaurant-Level Dispersion

The model estimates restaurant-specific dispersion parameters via:
- `mu_phi_log`: pooled log-dispersion
- `sigma_phi_log`: between-restaurant variance in log-dispersion
- `phi[r] = exp(mu_phi_log + sigma_phi_log * z_phi_log[r])`

This allows each restaurant to have its own overdispersion level, which is appropriate given the heterogeneity in variance/mean ratios (ranging from ~5 to ~118 across restaurants).

---

## 2. Rate Ratio Interpretation

### Parameter Hierarchy

The model estimates a **three-level hierarchy** for exposure effects:

1. **mu_gamma** (PRIMARY): Pooled effect across all restaurants
   - This is the **primary estimate of interest**
   - exp(mu_gamma) = Rate Ratio (RR)
   - **Null hypothesis: exp(mu_gamma) = 1** (no effect)

2. **eta[r]** (SECONDARY): Restaurant-level effect (pooled within restaurant)
   - eta[r] = mu_gamma + sigma_gamma_between * z_eta[r]
   - Captures between-restaurant heterogeneity

3. **gamma[k]** (TERTIARY): Individual exposure coefficient (per MPBA introduction)
   - gamma[k] = eta[r] + sigma_gamma_within * z_gamma[k]
   - Only relevant when a restaurant has multiple MPBA introductions

### Verification of Forest Plot Rate Ratios

From `create_forest_plots.R`, the rate ratio transformation is correctly implemented:

```r
# For proportion analyses (A1, A2)
df <- df %>%
  mutate(
    across(c(mean, q5, q95), ~ case_when(
      exposure_type == "Count" ~ exp(.x),
      exposure_type == "Proportion" ~ exp(.1 * .x),  # Scaled by 0.1 for 10% change
      TRUE ~ .x)))
```

```r
# For ITS analyses (A3, A4)
df <- exp_params(df, col = "effect_type", slope_id = "Slope", unit = "year")
```

The `exp_params()` function in `view_params_funcs.R`:
```r
exp_params <- function(df, col, slope_id, unit='year') {
  units <- list(day=365.25, year=1, month=365.25/12)
  scale <- units[[unit]]
  df %>%
    mutate(
      is_slope = str_detect(.data[[col]], slope_id) & !is.infinite(ess_bulk)) %>%
    mutate(across(
      where(is.numeric) & !matches("rhat|ess"),
      ~ if_else(is_slope, exp(.x / scale), exp(.x))))
```

**Verification**:
- Level change parameters: exp(coefficient) directly
- Slope parameters: exp(coefficient/365.25) for annualized rate ratios
- Proportion exposures: exp(0.1 * coefficient) for interpretation per 10% increase

### Interpretation Guide

| Analysis | Parameter | Interpretation |
|----------|-----------|----------------|
| A1/A2 Proportion (count) | exp(mu_gamma) | RR per 1-unit increase in MPBA count |
| A1/A2 Proportion (prop) | exp(0.1 * mu_gamma) | RR per 10% increase in MPBA proportion |
| A3/A4 ITS Level | exp(mu_gamma[1]) | Immediate RR after MPBA introduction |
| A3/A4 ITS Slope | exp(mu_gamma[2]/365.25) | Annual multiplicative trend change |

### Sample Results Verification

From `A1_proportion_mu_gamma.csv`:
- total/mpbamod/Count: RR = 0.945 [0.766, 1.162], rhat = 1.003
- total/mpbamod/Proportion: RR = 0.927 [0.832, 1.033], rhat = 1.003

These are correctly exponentiated (raw coefficients would be negative for RR < 1).

---

## 3. MCMC Diagnostics

### Convergence Monitoring in run_ingarch.R

The model uses CmdStanR with the following settings:
```r
fit <- mod$sample(
  data = data_list,
  seed = seed,
  chains = chains,                    # Default: 3
  parallel_chains = parallel_chains,  # Default: 3
  iter_warmup = iter_warmup,          # Default: 700
  iter_sampling = iter_sampling,      # Default: 1500
  adapt_delta = adapt_delta,          # Default: 0.95 (relatively high)
  max_treedepth = max_treedepth)      # Default: 12
```

### Diagnostic Metrics Computed

From `run_ingarch.R`:
```r
max_rhat <- max(summ$rhat, na.rm = TRUE)
min_ess_bulk <- min(summ$ess_bulk, na.rm = TRUE)
min_ess_tail <- min(summ$ess_tail, na.rm = TRUE)
```

These are logged to MLflow for tracking.

### Observed Diagnostic Issues (from logs)

**1. Numerical Warnings During Warmup**:
```
neg_binomial_2_lpmf: Location parameter is -nan/0/inf, but must be positive finite!
```
These occur during initial warmup when the sampler explores extreme regions. The message "if this warning occurs sporadically... the sampler is fine" applies here. These are rejected proposals, not accepted samples.

**2. Chain Failures**:
Some models show chain initialization failures:
```
Chain 3 finished unexpectedly!
Warning: 1 chain(s) finished unexpectedly!
```
This reduces the effective sample size but doesn't invalidate results if remaining chains converge.

**3. Divergent Transitions**:
From A1 model log:
```
Warning: 10 of 3000 (0.0%) transitions ended with a divergence.
```
This is a very low rate (<1%) and is generally acceptable. The high adapt_delta (0.95) helps minimize divergences.

**4. Treedepth Warnings**:
```
Warning: 2990 of 3000 (100.0%) transitions hit the maximum treedepth limit of 10.
```
This is concerning and indicates the sampler is working hard. However, this is from an earlier model run; the current `max_treedepth = 12` should alleviate this.

### Rhat Values in Final Results

From the forest plot CSVs, all mu_gamma parameters have rhat values close to 1.0:
- Range: 1.0004 to 1.0241
- All values < 1.05 (acceptable threshold)
- Most values < 1.01 (excellent convergence)

**Exceptions flagged**:
- A4 ITS targeted/textured Level Change: rhat = 1.060 (marginal, should be monitored)
- A1 chicken_fish/vegetarian Count: rhat = 1.024 (acceptable)

### Recommendations

1. **Continue using adapt_delta = 0.95** - this high value reduces divergences
2. **max_treedepth = 12** is appropriate for this model complexity
3. **Monitor models with rhat > 1.05** - consider longer sampling or reparameterization
4. **Chain failures** should be investigated for specific models, but results remain valid with 2+ converged chains

---

## 4. Bonferroni Correction

### Analysis Structure

The study conducts multiple hypothesis tests across:
- **6 outcomes**: total, nonvegan, meat, chicken_fish, vegetarian, vegan
- **3 exposure types** (A1): mpbamod, vegan, vegetarian
- **2 measurement types**: count, proportion

### Within-Analysis Corrections

For each analysis type, tests are corrected within:

| Analysis | Tests per Analysis | Bonferroni alpha |
|----------|-------------------|------------------|
| A1 Proportion | 6 outcomes x 3 exposures = 18 | 0.05/18 = 0.00278 |
| A2 Proportion Targeted | 5 outcomes x 2 types = 10 | 0.05/10 = 0.005 |
| A3 ITS | 6 outcomes x 2 effects = 12 | 0.05/12 = 0.00417 |
| A4 ITS Targeted | 3 outcomes x 2 effects = 6 | 0.05/6 = 0.00833 |

### Cross-Analysis Corrections

With 12 total subanalyses (A1-A6 with T1/T2 variants), a study-wide correction would use:
- alpha = 0.05 / 12 = 0.00417 per subanalysis family

### Implementation Status

**Current implementation**: The forest plots display 90% credible intervals (q5, q95), which corresponds to a two-sided 10% significance level per test.

**For Bonferroni-corrected inference**:
- 95% CI (q2.5, q97.5) would be more appropriate for family-wise error control
- With 18 tests, would need ~99.7% CI for strict Bonferroni (alpha/18 = 0.00278)

### Bayesian Perspective

In the Bayesian framework:
- Credible intervals are not p-values
- Partial pooling already provides implicit regularization
- The primary interest is in posterior probability of effect direction, not null hypothesis rejection

**Recommendation**:
1. Report both 90% and 95% credible intervals
2. Emphasize effect sizes (rate ratios) over statistical significance
3. Use the hierarchical structure (mu_gamma shrinkage) as the primary guard against false positives
4. Consider posterior probability of meaningful effect (e.g., P(RR > 0.95) or P(RR < 1.05)) rather than point null testing

---

## Summary of Statistical Methodology

| Aspect | Implementation | Assessment |
|--------|---------------|------------|
| Overdispersion | NB2 with restaurant-specific phi | Appropriate - data shows clear overdispersion |
| Rate Ratio | exp(mu_gamma) with correct scaling | Verified - forest plots correctly transform |
| MCMC | 3 chains, 1500 samples, adapt_delta=0.95 | Adequate - rhat values generally <1.02 |
| Convergence | max_rhat, min_ess tracked | Good - monitored via MLflow |
| Multiple Testing | 90% CI displayed | Consider reporting 95% CI for stricter control |
| Pooling | Three-level hierarchy | Provides implicit regularization |

---

## 5. Flagged: Implausible Rate Ratios

**Guideline**: Think qualitatively about rate ratios - anything **over 3 is potentially suspect** and warrants investigation. This is not a hard threshold; use judgment about whether effects make biological/behavioral sense.

**Qualitative scale**:
- RR = 1.1 (10% change): Plausible small effect
- RR = 1.5 (50% change): Large but potentially believable
- RR = 2.0 (100% change): Very large, needs explanation
- RR = 3.0+ (3x increase): Suspect - requires justification
- RR = 5.0+ (5x increase): Highly suspect - likely data/model issue
- RR = 10+ (10x increase): Almost certainly artifact

### Complete Flagged List (RR > 3)

| Analysis | Outcome | Exposure | Restaurant | Mean RR | Status |
|----------|---------|----------|------------|---------|--------|
| A2 | Breakfast | Count | L69HYJ4Y3TR91 | **17.41** | Investigate |
| A2 | Breakfast | Presence | L69HYJ4Y3TR91 | **17.24** | Investigate |
| A2 | Breakfast | Presence | 2HRX9P6HKXA8V | **4.89** | Review |
| A2 | Untextured | Presence | W8T41JZK0ZMEP | **4.76** | Review |
| A4 | Untextured | Level Change | JHDN7CF1C03X5 | **35.99** | Investigate |

**Note**: A1 results all have rate ratios very close to 1.0 (range ~0.99-1.02) - no concerns there.

### Possible Causes
1. Small sample sizes at these restaurants
2. Near-zero baseline counts inflating ratios
3. Data quality issues at specific restaurants
4. Exposure timing coinciding with other confounders

### Recommendation
Investigate L69HYJ4Y3TR91 (breakfast) and JHDN7CF1C03X5 (untextured) data before publication

---

## 6. Rate Ratio Investigation

This section provides detailed investigation of the flagged implausible rate ratios identified in Section 5.

### Summary of Findings

| Restaurant | Analysis | Outcome | RR | Primary Issue | Recommendation |
|------------|----------|---------|------|---------------|----------------|
| L69HYJ4Y3TR91 | A2 | Breakfast | 17.41 | Complete separation | **Exclude or flag** |
| L69HYJ4Y3TR91 | A2 | Breakfast Presence | 17.24 | Complete separation | **Exclude or flag** |
| 2HRX9P6HKXA8V | A2 | Breakfast Presence | 4.89 | Severe imbalance + separation | **Exclude or flag** |
| W8T41JZK0ZMEP | A2 | Untextured Presence | 4.76 | Separation in exposure | Review - may be real |
| JHDN7CF1C03X5 | A4 | Untextured | 35.99 | Near-zero baseline | **Exclude or flag** |

### Detailed Investigation

#### 1. L69HYJ4Y3TR91 - Breakfast (RR = 17.41 Count, 17.24 Presence)

**Data Characteristics:**
- Pre-exposure observations: 9 (2.7%)
- Post-exposure observations: 326 (97.3%)
- `breakfast_dishes_count` pre-exposure: ALL ZEROS (9/9)
- `breakfast_dishes_count` post-exposure: ALL ONES (326/326)

**Diagnosis: QUASI-COMPLETE SEPARATION**

The exposure variable (`breakfast_dishes_count`) shows perfect separation with respect to time. Before the intervention, the restaurant never offered breakfast MPBA items (always 0). After the intervention, breakfast MPBA items were always on the menu (always 1). This creates a situation where:

1. The exposure effect is perfectly confounded with time
2. The model cannot distinguish the effect of the exposure from the effect of time passing
3. The large RR is driven by this mathematical artifact, not a true causal effect

**Convergence:** Excellent (rhat = 0.9997 for Count, 1.0001 for Presence)

**Credible Intervals:**
- Count: [6.92, 46.95] - does not include 1
- Presence: [7.00, 45.09] - does not include 1

Despite good convergence and CIs that exclude 1, the estimate is unreliable due to separation.

**Recommendation:** Exclude this restaurant from the breakfast analysis or clearly flag the estimate as potentially artifactual.

---

#### 2. 2HRX9P6HKXA8V - Breakfast Presence (RR = 4.89)

**Data Characteristics:**
- Pre-exposure observations: 59 (3.4%)
- Post-exposure observations: 1674 (96.6%)
- `breakfast_dishes_presence` pre-exposure: ALL ZEROS
- `breakfast_dishes_presence` post-exposure: ALL ONES

**Diagnosis: SEVERE IMBALANCE + SEPARATION**

This restaurant has two compounding problems:
1. **Extreme temporal imbalance:** Only 59 pre-exposure days vs. 1674 post-exposure days
2. **Complete separation:** The exposure variable has zero variance within each time period

**Convergence:** Good (rhat = 1.002)

**Credible Interval:** [0.43, 60.19] - EXTREMELY WIDE, includes 1

The 90% CI spans from 0.43 to 60.19 (140x ratio between upper and lower bounds). This indicates the model has very little information about the true effect size. The estimate is essentially uninformative.

**Recommendation:** Exclude this restaurant from the breakfast presence analysis. The wide CI already indicates the estimate is unreliable.

---

#### 3. W8T41JZK0ZMEP - Untextured Presence (RR = 4.76)

**Data Characteristics:**
- Pre-exposure observations: 233 (18.4%)
- Post-exposure observations: 1032 (81.6%)
- `untextured_dishes_presence` pre-exposure: ALL ZEROS
- `untextured_dishes_presence` post-exposure: ALL ONES
- `untextured_outcome_p` pre mean: 0.34
- `untextured_outcome_p` post mean: 3.16
- Raw fold change in outcome: 9.3x

**Diagnosis: SEPARATION IN EXPOSURE, BUT REAL OUTCOME CHANGE**

Unlike the previous cases, this restaurant shows:
1. Separation in the exposure variable (typical for proportion targeted analyses)
2. But meaningful variation in the outcome in BOTH periods
3. A substantial increase in outcomes post-exposure

**Convergence:** Good (rhat = 1.003)

**Credible Interval:** [3.40, 6.82] - RELATIVELY NARROW, excludes 1

The CI is relatively tight (2x ratio) and excludes 1. The raw data shows a ~9x increase in untextured dish outcomes, so the model estimate of 4.76x is actually more conservative than the raw comparison. This may reflect a real effect that is being partially shrunk toward the pooled estimate.

**Recommendation:** This estimate warrants scrutiny but may reflect a real (albeit large) effect. Report with appropriate caveats about the separation in the exposure variable.

---

#### 4. JHDN7CF1C03X5 - ITS Untextured Level Change (RR = 35.99)

**Data Characteristics:**
- Pre-intervention observations: 245 (14.7%)
- Post-intervention observations: 1424 (85.3%)
- `untextured_outcome` pre mean: 0.037
- `untextured_outcome` post mean: 2.77
- Pre-period zeros: 242/245 (98.8%)
- Post-period zeros: 422/1424 (29.6%)
- Raw fold change: 75.5x

**Diagnosis: NEAR-ZERO BASELINE (Quasi-Separation in Outcome)**

This case is different from the A2 cases because the ITS model measures the outcome directly rather than using an exposure variable. However, the pre-intervention outcome is essentially zero:
- Mean of 0.037 untextured dish sales per day
- 98.8% of pre-intervention days had ZERO untextured dish sales

This creates quasi-separation in the outcome: the model is comparing "almost never" to "sometimes," which mathematically produces extreme rate ratios. The raw data shows a 75.5x increase; the model estimate of 35.99 reflects some shrinkage toward the prior.

**Convergence:** Excellent (rhat = 1.0003)

**Credible Interval:** [16.47, 81.50] - wide but excludes 1

**Important Context:**
The slope change parameter is 0.23 [0.12, 0.40], indicating that after the initial spike, untextured sales were declining. This pattern is consistent with:
1. A new menu item being introduced (large level change)
2. Initial novelty wearing off (negative slope change)

This may actually reflect a real business phenomenon, but the extreme magnitude suggests caution.

**Recommendation:** Flag this estimate and note that the pre-intervention baseline was near-zero. Consider reporting the raw counts alongside the rate ratio to provide context.

---

### Root Cause Analysis

| Issue | Restaurants Affected | Analysis Types |
|-------|---------------------|----------------|
| Complete separation in exposure | L69HYJ4Y3TR91, 2HRX9P6HKXA8V | A2 Proportion Targeted |
| Severe temporal imbalance (<5% pre) | L69HYJ4Y3TR91, 2HRX9P6HKXA8V | A2 Proportion Targeted |
| Near-zero baseline outcomes | JHDN7CF1C03X5 | A4 ITS |
| Separation in exposure (but real effect?) | W8T41JZK0ZMEP | A2 Proportion Targeted |

### Recommendations

1. **For L69HYJ4Y3TR91 and 2HRX9P6HKXA8V (Breakfast):**
   - Exclude from restaurant-specific forest plots
   - These estimates should NOT contribute to the pooled effect
   - If included, add prominent caveat about data limitations

2. **For JHDN7CF1C03X5 (ITS Untextured):**
   - Report with explicit caveat about near-zero baseline
   - Include raw counts in supplementary materials
   - Consider whether this restaurant should be in the untextured analysis at all

3. **For W8T41JZK0ZMEP (Untextured):**
   - Lower concern - may reflect real effect
   - Report but note the separation in exposure variable
   - The estimate is conservative relative to raw data

4. **General:**
   - Add pre/post sample size columns to forest plot data
   - Flag any estimate where pre-period is <10% of total or N < 50
   - Consider reporting separation diagnostics for proportion targeted models

### Model Diagnostics Summary

All flagged estimates have excellent MCMC convergence (rhat < 1.01), indicating that the extreme values are not due to sampling issues but rather reflect the underlying data structure. The Bayesian hierarchical model is doing its job correctly - it's just being asked to estimate effects in situations where the data provide little information.

---

## 7. Deep Dive: Flagged Restaurants (T1 Only)

This section provides a comprehensive investigation of the four restaurants with the most extreme rate ratio estimates in the T1 (primary) analyses.

### Executive Summary

| Restaurant | Analysis | Outcome | RR | Root Cause | Severity |
|------------|----------|---------|------|------------|----------|
| L69HYJ4Y3TR91 | A2 Breakfast | Count & Presence | ~17x | Near-complete separation (9 pre vs 326 post) | **CRITICAL** |
| JHDN7CF1C03X5 | A4 Untextured | Level Change | ~36x | Near-zero baseline (98.8% zeros pre) | **CRITICAL** |
| 2HRX9P6HKXA8V | A2 Breakfast | Presence | ~4.9x | Complete separation (1 pre-outcome vs 155 post) | **HIGH** |
| W8T41JZK0ZMEP | A2 Untextured | Presence | ~4.8x | Genuine large effect with some separation | **MODERATE** |

---

### Restaurant 1: L69HYJ4Y3TR91 (A2 Breakfast, RR ~17x)

#### Source Data Investigation

**Data Location:** `data/4_data_parquet_modeling/proportion_targeted/finalized_breakfast_dishes_count.parquet`

**Observations:**
- **Total observations:** 335
- **Pre-exposure (exposed=0):** 9 observations (2.7%)
- **Post-exposure (exposed=1):** 326 observations (97.3%)
- **Date range:** 2022-08-30 to 2023-07-30

**Outcome Distribution (breakfast_outcome_p):**

| Period | N | Mean | Median | Min | Max | Zeros | Non-zeros |
|--------|---|------|--------|-----|-----|-------|-----------|
| Pre (exposed=0) | 9 | 0.222 | 0.000 | 0 | 1 | 7 | 2 |
| Post (exposed=1) | 326 | 28.30 | 26.00 | 0 | 78 | 2 | 324 |

**Exposure Variable (breakfast_dishes_count):**

| Period | Value | Notes |
|--------|-------|-------|
| Pre (exposed=0) | Always 0 | No MPBA breakfast items before intervention |
| Post (exposed=1) | Always 1 | Exactly 1 MPBA breakfast item after intervention |

#### Model Fit Diagnostics

**Model:** A2 Proportion Targeted (breakfast_dishes_count)

**Predictor Map Position:** exposure_L69HYJ4Y3TR91_1 = column 44

**Eta Parameter Estimates:**
```
eta[1,3] (Count):    mean = 2.86, median = 2.83, SD = 0.58
                     90% CI: [1.93, 3.85]
                     rhat = 1.00, ESS_bulk = 5167

eta[1,3] (Presence): mean = 2.85, median = 2.83, SD = 0.58
                     90% CI: [1.95, 3.81]
                     rhat = 1.00, ESS_bulk = 4062
```

**Rate Ratios:**
- Count: exp(2.86) = **17.41** [exp(1.93), exp(3.85)] = [6.89, 47.0]
- Presence: exp(2.85) = **17.24** [exp(1.95), exp(3.81)] = [7.03, 45.1]

**Convergence:** Excellent (rhat = 1.00, ESS > 4000)

#### Root Cause Analysis

**Primary Issue: QUASI-COMPLETE SEPARATION**

1. **Temporal Imbalance:** Only 9 pre-exposure observations (2.7%) vs 326 post-exposure (97.3%)
2. **Perfect Exposure Separation:** Exposure is always 0 before and always 1 after - the exposure variable perfectly predicts the time period
3. **Near-Zero Baseline:** Only 2 of 9 pre-exposure days had any breakfast outcomes (mean = 0.22)
4. **Large Post-Exposure Outcomes:** Mean of 28.3 breakfast items sold per day after intervention

The model is mathematically forced to attribute the 127-fold increase in raw outcomes (0.22 to 28.3) to the exposure, because:
- The exposure perfectly separates the time periods
- There is no variation in exposure within either period
- Time trends, seasonality, and other confounders cannot be distinguished from the exposure effect

**Verdict:** The RR of 17x is an **artifact of separation**, not a reliable causal estimate.

---

### Restaurant 2: JHDN7CF1C03X5 (A4 Untextured ITS, RR ~36x)

#### Source Data Investigation

**Data Location:** `data/4_data_parquet_modeling/its/finalized.parquet`

**Observations:**
- **Total observations:** 1669
- **Pre-exposure (exposed=0):** 245 observations (14.7%)
- **Post-exposure (exposed=1):** 1424 observations (85.3%)
- **Date range:** 2019-01-05 to 2023-07-31

**Outcome Distribution (untextured_outcome):**

| Period | N | Mean | Median | Min | Max | Zeros | Non-zeros |
|--------|---|------|--------|-----|-----|-------|-----------|
| Pre (exposed=0) | 245 | 0.037 | 0.00 | 0 | 7 | 242 (98.8%) | 3 |
| Post (exposed=1) | 1424 | 2.77 | 2.00 | 0 | 14 | 422 (29.6%) | 1002 |

**Raw Fold Change:** 2.77 / 0.037 = **75.5x**

#### Model Fit Diagnostics

**Model:** A4 ITS Targeted (untextured)

**Predictor Map Position:** exposure_JHDN7CF1C03X5_1 = column 44 (level), column 47 (slope)

**Eta Parameter Estimates:**
```
eta[1,2] (Level):  mean = 3.58, median = 3.57, SD = 0.49
                   90% CI: [2.80, 4.40]
                   rhat = 1.00, ESS_bulk = 353

eta[2,2] (Slope):  mean = -1.48, median = -1.45, SD = 0.36
                   90% CI: [-2.09, -0.92]
                   rhat = 1.00, ESS_bulk = 97
```

**Rate Ratios:**
- Level Change: exp(3.58) = **35.99** [exp(2.80), exp(4.40)] = [16.5, 81.5]
- Slope Change: exp(-1.48/365.25) = **0.996** per day = **0.23** per year

**Convergence:**
- Overall model: max_rhat = 1.116 (concerning), min_ESS_bulk = 14 (low)
- Level parameter: Good (rhat = 1.00)
- Slope parameter: Marginal (ESS_bulk = 97)

#### Root Cause Analysis

**Primary Issue: NEAR-ZERO BASELINE**

1. **Pre-Period Outcome Distribution:** 98.8% of pre-intervention days had ZERO untextured dish sales
2. **Only 3 Non-Zero Pre-Observations:** Mean of 0.037 is driven by just 3 observations
3. **Post-Period Shows Actual Sales:** 70.4% of days have non-zero sales, mean = 2.77

The extreme RR of 36x (model) vs 75x (raw) reflects the mathematical reality that any increase from near-zero will produce a large ratio. However:
- This is an ITS model, so the estimate represents the "immediate level change" at intervention
- The negative slope change (0.23x per year) suggests the initial spike diminished over time
- This pattern is consistent with a new menu item introduction

**Key Question:** Should a restaurant that never sold untextured items pre-intervention be included in the untextured analysis?

**Verdict:** The RR of 36x is **mathematically correct but substantively meaningless** for causal inference because the baseline is effectively zero.

---

### Restaurant 3: 2HRX9P6HKXA8V (A2 Breakfast, RR ~4.9x Presence)

#### Source Data Investigation

**Data Location:** `data/4_data_parquet_modeling/proportion_targeted/finalized_breakfast_dishes_count.parquet`

**Observations:**
- **Total observations:** 1733
- **Pre-exposure (exposed=0):** 59 observations (3.4%)
- **Post-exposure (exposed=1):** 155 observations (8.9%)
- **Post-exposure (exposed=2):** 1519 observations (87.7%)
- **Date range:** 2018-11-03 to 2023-08-01

**Outcome Distribution (breakfast_outcome_p):**

| Period | N | Mean | Median | Min | Max | Zeros | Non-zeros |
|--------|---|------|--------|-----|-----|-------|-----------|
| Pre (exposed=0) | 59 | 0.034 | 0.00 | 0 | 2 | 58 | 1 |
| Post (exposed=1) | 155 | 225.1 | 197.0 | 6 | 705 | 0 | 155 |
| Post (exposed=2) | 1519 | ... | ... | ... | ... | ... | ... |

**Note:** The Count model uses count exposure (0, 1, 2); the Presence model uses binary (0 vs 1+).

#### Model Fit Diagnostics

**Model:** A2 Proportion Targeted (breakfast_dishes_presence)

**Predictor Map Position:** exposure_2HRX9P6HKXA8V_1 = column 42

**Eta Parameter Estimates:**
```
eta[1,1] (Presence): mean = 1.59, median = 1.60, SD = 1.51
                     90% CI: [-0.86, 4.10]
                     rhat = 1.00, ESS_bulk = 1383
```

**Rate Ratio:**
- Presence: exp(1.59) = **4.89** [exp(-0.86), exp(4.10)] = [0.42, 60.3]

**Credible Interval:** EXTREMELY WIDE - spans from 0.42 to 60.3 (140x range)

#### Root Cause Analysis

**Primary Issue: COMPLETE SEPARATION + EXTREME IMBALANCE**

1. **Pre-Period Outcome:** Only 1 of 59 pre-exposure days had any breakfast outcomes (98.3% zeros)
2. **Post-Period Outcome:** ALL 155 post-exposure days had breakfast outcomes (0% zeros)
3. **Separation:** The presence of breakfast outcomes perfectly predicts exposure status
4. **Wide CI:** The model correctly reports high uncertainty (0.42 to 60.3)

The model is attempting to estimate an effect where:
- Pre: 1.7% of days have outcome = 1
- Post: 100% of days have outcome = 1

This is textbook separation.

**Verdict:** The RR of 4.9x is **not reliable** due to separation. The wide CI correctly reflects the uncertainty.

---

### Restaurant 4: W8T41JZK0ZMEP (A2 Untextured, RR ~4.8x Presence)

#### Source Data Investigation

**Data Location:** `data/4_data_parquet_modeling/proportion_targeted/finalized_untextured_dishes_count.parquet`

**Observations:**
- **Total observations:** 1265
- **Pre-exposure (exposed=0):** 233 observations (18.4%)
- **Post-exposure (exposed=1):** 176 observations (13.9%)
- **Post-exposure (exposed=2):** 762 observations (60.2%)
- **Post-exposure (exposed=3):** 94 observations (7.4%)
- **Date range:** 2020-02-13 to 2023-07-31

**Outcome Distribution (untextured_outcome_p):**

| Period | N | Mean | Median | Min | Max | Zeros | Non-zeros |
|--------|---|------|--------|-----|-----|-------|-----------|
| Pre (exposed=0) | 233 | 0.34 | 0.00 | 0 | 5 | 190 (81.5%) | 43 (18.5%) |
| Post (exposed=1) | 176 | 1.20 | 1.00 | 0 | 7 | 83 (47.2%) | 93 (52.8%) |
| Post (exposed=2) | 762 | 3.43 | 3.00 | 0 | 19 | 193 (25.3%) | 569 (74.7%) |
| Post (exposed=3) | 94 | 4.66 | 4.00 | 0 | 23 | 14 (14.9%) | 80 (85.1%) |

#### Model Fit Diagnostics

**Model:** A2 Proportion Targeted (untextured_dishes_presence)

**Predictor Map Position:** exposure_W8T41JZK0ZMEP_1 = column 44

**Eta Parameter Estimates:**
```
eta[1,3] (Presence): mean = 1.56, median = 1.55, SD = 0.21
                     90% CI: [1.22, 1.92]
                     rhat = 1.00, ESS_bulk = 822
```

**Rate Ratio:**
- Presence: exp(1.56) = **4.76** [exp(1.22), exp(1.92)] = [3.39, 6.82]

**Credible Interval:** RELATIVELY NARROW (2x range), excludes 1.0

#### Root Cause Analysis

**Primary Issue: REAL EFFECT WITH SOME SEPARATION**

This case is notably different from the others:

1. **Meaningful Pre-Period Variation:** 18.5% of pre-exposure days had non-zero outcomes (vs <2% for other flagged restaurants)
2. **Clear Dose-Response:** Outcomes increase monotonically with exposure level (0.34 -> 1.20 -> 3.43 -> 4.66)
3. **Narrow CI:** The model is confident in the estimate
4. **Raw Data Supports Effect:** Pre mean = 0.34, Post mean (pooled) = ~3.0, raw ratio = ~9x

**Why RR = 4.76 when raw ratio is ~9x?**
- The model uses a presence indicator (0 vs 1+), not the count
- The hierarchical structure shrinks the estimate toward the pooled effect
- The pooled mu_gamma for untextured presence is ~1.8x

**Verdict:** This estimate is **more credible** than the others. The effect may be real, though large. The separation is less severe because:
- There IS variation in outcomes within the pre-period (43 non-zero days)
- The exposure has multiple levels with a clear gradient

---

### Model Starter Configuration Review

**A2 Breakfast (L69HYJ4Y3TR91, 2HRX9P6HKXA8V):**
```r
# From model_starters/a2_proportion_t/A2_breakfast_count.R
restaurants_to_model = c('2HRX9P6HKXA8V', 'ED5J990H5VAZT', 'L69HYJ4Y3TR91')
```
- Both flagged restaurants ARE included in the model
- JHDN7CF1C03X5 was commented out (excluded)

**A2 Untextured (W8T41JZK0ZMEP):**
```r
# From model_starters/a2_proportion_t/A2_untextured_count.R
restaurants_to_model = c('JHDN7CF1C03X5', 'SRQS8F7JWA9MZ', 'W8T41JZK0ZMEP')
```
- W8T41JZK0ZMEP IS included in the model

**A4 Untextured ITS (JHDN7CF1C03X5):**
```r
# From model_starters/a4_its_t/A4_untextured.R
restaurants_to_model = c('SRQS8F7JWA9MZ', 'JHDN7CF1C03X5')
```
- JHDN7CF1C03X5 IS included in the model

**Key Finding:** No special handling or exclusion flags for the problematic restaurants.

---

### Summary of Root Causes

| Restaurant | Issue | Evidence | Severity |
|------------|-------|----------|----------|
| L69HYJ4Y3TR91 | Quasi-complete separation | 9 pre obs (2.7%), 97.3% post, exposure perfectly predicts time | **CRITICAL** |
| JHDN7CF1C03X5 | Near-zero baseline | 98.8% pre-days had zero outcomes, only 3 non-zero pre-observations | **CRITICAL** |
| 2HRX9P6HKXA8V | Complete separation + imbalance | 1/59 pre-days non-zero (1.7%), 155/155 post-days non-zero (100%) | **HIGH** |
| W8T41JZK0ZMEP | Large effect with minor separation | 43/233 pre-days non-zero (18.5%), clear dose-response gradient | **MODERATE** |

---

### Recommendations

#### Immediate Actions

1. **L69HYJ4Y3TR91 (Breakfast):**
   - **EXCLUDE** from A2 breakfast analysis
   - Only 9 pre-exposure observations is insufficient
   - Perfect separation makes estimate meaningless

2. **JHDN7CF1C03X5 (ITS Untextured):**
   - **FLAG prominently** in results
   - Consider excluding from pooled estimate
   - Report raw counts alongside RR to show baseline was essentially zero

3. **2HRX9P6HKXA8V (Breakfast):**
   - **EXCLUDE** from A2 breakfast presence analysis
   - The wide CI (0.42 to 60.3) already indicates unreliability
   - Complete separation makes estimate meaningless

4. **W8T41JZK0ZMEP (Untextured):**
   - **INCLUDE with caveat**
   - The estimate may reflect a real (large) effect
   - Note that the 4.8x estimate is conservative compared to raw 9x ratio

#### Forest Plot Modifications

1. Add columns for:
   - Pre-period sample size
   - Post-period sample size
   - Pre-period non-zero rate

2. Flag estimates where:
   - Pre-period N < 50
   - Pre-period non-zero rate < 10%
   - CI spans more than 50x (e.g., 0.5 to 25)

#### Sensitivity Analyses

1. Run models excluding flagged restaurants
2. Compare pooled mu_gamma with and without problematic restaurants
3. Report both sets of results in supplementary materials

#### Documentation

1. Add data quality section to methods describing exclusion criteria
2. Document that quasi-separation cases are excluded from inference
3. Note that ITS analyses for restaurants with near-zero baselines should be interpreted with caution

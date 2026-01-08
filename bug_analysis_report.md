# Bug Analysis Report: Statistical Modeling Project

## Executive Summary

After detailed code tracing and mathematical verification, I found that **most initially flagged issues are NOT bugs**. There is **one confirmed bug** in A2 (proportion_targeted) forest plot exponentiation that affects the displayed rate ratios for Presence exposure type.

**Bottom line:** One bug found in forest plot code only. No model re-runs needed.

---

## Bug 1: Stan Model Bounds Check - **NOT A BUG**

**Initial Concern:** Lines 467-468 in `models/model_multilevel_transfer.stan` check `lag < current_pos_in_test` but don't explicitly verify `lag_source_idx_test >= r_test_start_idx`.

**Mathematical Verification:**

Given:
- `current_pos_in_test = t_test_idx - r_test_start_idx + 1`
- `lag_source_idx_test = t_test_idx - lag`

The condition `lag < current_pos_in_test` expands to:
```
lag < t_test_idx - r_test_start_idx + 1
⟹ lag ≤ t_test_idx - r_test_start_idx     (integer arithmetic)
⟹ t_test_idx - lag ≥ r_test_start_idx
⟹ lag_source_idx_test ≥ r_test_start_idx   ✓
```

**Conclusion:** The existing condition IS algebraically equivalent to the bounds check. The code is correct as written. No action needed.

---

## Bug 2: A1 Proportion Exponentiation - **NOT A BUG**

**Initial Concern:** Line 206 uses `.x^0.1` for restaurant-level proportion estimates while pooled uses `exp(.1 * .x)`.

**Transformation Chain Analysis:**

**Restaurant estimates:**
1. `extract_restaurant_gammas()` calls `exp_betas(unit = "year")`
2. `exp_betas()` → `exp_params('model_col', 'slope', 'year')`
3. For non-slope params: applies `exp(x)`
4. Returns: exp(x)
5. Then in forest plot code: `exposure_type == "Proportion" & estimate_type == "Restaurant" ~ .x^0.1`
6. Final result: `exp(x)^0.1 = exp(0.1*x)`

**Pooled estimates:**
1. `extract_mu_gamma()` returns raw values (no exponentiation)
2. Then in forest plot code: `exposure_type == "Proportion" & estimate_type == "Pooled" ~ exp(.1 * .x)`
3. Final result: `exp(0.1*x)`

**Conclusion:** Both transformations produce `exp(0.1*x)`. The `.x^0.1` compensates for the prior `exp()` in `exp_betas()`. This is intentional design, not a bug.

---

## Bug 3: A2 Proportion_Targeted Exponentiation - **CONFIRMED BUG**

**File:** `forest_plots_restaurants/create_forest_plots_restaurants.R` (lines 392-397)

**The Issue:**

In A2 `create_proportion_targeted_forest_restaurants()`:
```r
df_all <- df_all %>%
  mutate(
    across(c(mean, q5, q95), ~ case_when(
      exposure_type == "Count" & estimate_type == "Pooled" ~ exp(.x),
      exposure_type == "Presence" & estimate_type == "Pooled" ~ exp(.1 * .x),
      TRUE ~ .x)))
```

**Transformation results:**
| Estimate Type | Exposure Type | Transformation | Final Value |
|---------------|---------------|----------------|-------------|
| Restaurant | Count | exp_betas() only | exp(x) |
| Restaurant | Presence | exp_betas() only | exp(x) |
| Pooled | Count | exp(.x) | exp(x) |
| Pooled | Presence | exp(.1 * .x) | exp(0.1*x) |

**Inconsistency:**
- Restaurant Presence: `exp(x)`
- Pooled Presence: `exp(0.1*x)`

These don't match. Restaurant estimates would appear ~10x larger on the forest plot relative to pooled estimates (for the same underlying coefficient).

**However:** The 0.1 scaling for presence (binary indicator) may be statistically inappropriate anyway. For a binary predictor (has MPBA = 1 vs doesn't have = 0), the coefficient represents `log(rate_ratio)`, so `exp(β)` gives the rate ratio directly. The 0.1 scaling only makes sense for continuous proportions where you want "effect per 10 percentage point increase."

---

## A3/A4 ITS Analysis - **APPEARS CORRECT**

The ITS analysis explicitly handles this differently:
```r
# Exponentiate pooled parameters only (restaurant already done)
df_pooled_exp <- df_all %>%
    filter(estimate_type == "Pooled") %>%
    exp_params(col = "effect_type", slope_id = "Slope", unit = "year")

df_restaurant_only <- df_all %>% filter(estimate_type == "Restaurant")
```

Both restaurant (via `exp_betas()` in `extract_restaurant_gammas()`) and pooled (via `exp_params()`) use the same function family with consistent slope handling. No mismatch detected.

---

## Summary Table

| Issue | Location | Status | Forest Plot Impact |
|-------|----------|--------|-------------------|
| Stan bounds check | model_multilevel_transfer.stan:467,490 | **NOT A BUG** | None |
| A1 Proportion exp | create_forest_plots_restaurants.R:206 | **NOT A BUG** | None |
| A2 Presence exp | create_forest_plots_restaurants.R:396 | **CONFIRMED BUG** | Forest plot incorrect |
| A3/A4 ITS exp | create_forest_plots_restaurants.R:561 | **APPEARS CORRECT** | None |

---

## CONFIRMED BUG: A2 Presence Exponentiation Fix

**User confirmed:** Presence is a binary (0/1) indicator.

**Statistical Issue:** For a binary predictor, the coefficient β represents `log(rate_ratio)`, so `exp(β)` gives the rate ratio directly. The 0.1 scaling is ONLY appropriate for continuous proportions where you want "effect per 10 percentage point increase."

**Current behavior:** Pooled presence uses `exp(0.1 * x)`, which understates the rate ratio.

### Fix Required

**File:** `forest_plots_restaurants/create_forest_plots_restaurants.R`
**Line:** 396 (in `create_proportion_targeted_forest_restaurants()`)

**Change:**
```r
# FROM:
exposure_type == "Presence" & estimate_type == "Pooled" ~ exp(.1 * .x),

# TO:
exposure_type == "Presence" & estimate_type == "Pooled" ~ exp(.x),
```

**Impact:** This only affects forest plot generation, NOT model fitting. No models need to be re-run. Just regenerate the A2 forest plot after the fix.

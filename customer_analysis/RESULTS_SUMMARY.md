# Conditional Poisson Customer FE Analysis - Results Summary

**Completed:** 2025-12-18
**Runtime:** 0.2 minutes

## Overview

Conditional Poisson regression with customer fixed effects. Conditions on customer's total count sum (sufficient statistic) to absorb customer FEs. Includes **slope terms** (transfer function: exposure × continuous time) and gender interactions.

## Output Structure

```
customer_analysis/
├── results_exposures/       # Exposure estimates for forest plots
│   ├── A5_nonvegan.csv
│   ├── A5_meat.csv
│   ├── A5_chicken_fish.csv
│   ├── A5_vegan.csv
│   ├── A5_vegetarian.csv
│   ├── A6_breakfast.csv
│   └── A6_untextured.csv
│
└── results_other/           # Full model results (all coefficients)
    ├── A5_{outcome}_{restaurant}.csv   # Per-restaurant models
    ├── A5_{outcome}_pooled.csv         # Pooled models
    ├── A5_{outcome}_combined.csv       # Combined
    └── A6_*                            # Same for A6
```

## Key Files for Forest Plots

**`results_exposures/` contains 7 files** with exposure-only terms:

### A5 (5 files)
- `A5_nonvegan.csv`
- `A5_meat.csv`
- `A5_chicken_fish.csv`
- `A5_vegan.csv`
- `A5_vegetarian.csv`

### A6 (2 files)
- `A6_breakfast.csv` (3 restaurants + pooled)
- `A6_untextured.csv` (1 restaurant, no pooled)

## Exposure File Structure

Each exposure file contains:

### Per-Restaurant Terms
For each restaurant (e.g., SRQS8F7JWA9MZ with 2 exposures):
1. **Main effects**: `exposure_SRQS8F7JWA9MZ_1`, `exposure_SRQS8F7JWA9MZ_2`
2. **Slope terms** (transfer function): `exposure_SRQS8F7JWA9MZ_1:date_code`, `exposure_SRQS8F7JWA9MZ_2:date_code`
3. **Gender interactions**: `exposure_SRQS8F7JWA9MZ_1:gendermale`, `exposure_SRQS8F7JWA9MZ_2:gendermale`

### Pooled Terms
1. **Main effect**: `any_exposureTRUE`
2. **Slope term**: `any_exposureTRUE:date_code`
3. **Gender interaction**: `any_exposureTRUE:gendermale`

### Columns
- model_id (restaurant ID or "pooled")
- term (exposure variable name)
- estimate, std_error, p_value
- ci_lower, ci_upper
- location_id, n_obs, n_customers
- analysis, outcome_name

## Analysis Summary

**A5**: 5 outcomes × 4 restaurants + pooled
**A6**: 2 outcomes (breakfast: 3 rest + pooled, untextured: 1 rest)

### Restaurants
- **A5**: SRQS8F7JWA9MZ, 2HRX9P6HKXA8V, L69HYJ4Y3TR91, ED5J990H5VAZT
- **A6 breakfast**: 2HRX9P6HKXA8V, L69HYJ4Y3TR91, ED5J990H5VAZT
- **A6 untextured**: SRQS8F7JWA9MZ

### Example: A5_nonvegan.csv
Contains ~18 rows:
- SRQS8F7JWA9MZ: 6 terms (2 main + 2 slopes + 2 gender)
- 2HRX9P6HKXA8V: 3 terms (1 main + 1 slope + 1 gender)
- L69HYJ4Y3TR91: 3 terms
- ED5J990H5VAZT: 3 terms
- pooled: 3 terms (1 main + 1 slope + 1 gender)

## Model Details

### Formula Structure
```r
outcome ~ exposure_1 + exposure_2 + ... +           # Main effects
          exposure_1:date_code + ... +             # Slope terms (transfer function)
          gender + exposure_1:gender + ... +       # Gender interactions
          covariates |                             # Covariates
          customer_id                              # Customer FE (absorbed)
```

### Covariates
Transaction-level only (no weather):
- Prices: vegan, vegetarian, meat (+ outcome-specific for A6)
- Temporal: weekend, holiday_window, month, season, year, date_code, day_of_week
- Economic: inflation

### Standard Errors
- Per-restaurant: Clustered at customer level
- Pooled: Two-way clustering (customer + restaurant)

### Filtering
- Customers with observations both pre and post MPBA
- Automatic removal of singletons/collinear variables

## Interpretation

**Main effect** (`exposure_X`): Level change in outcome when MPBA introduced

**Slope term** (`exposure_X:date_code`): Change in trend after MPBA introduction (transfer function)

**Gender interaction** (`exposure_X:gendermale`): Differential effect for male vs female customers

## Next Steps

Use `results_exposures/*.csv` for forest plots:
1. Plot main effects with CIs across restaurants
2. Show slope terms (trend changes)
3. Display gender interactions if significant
4. Compare pooled vs per-restaurant estimates

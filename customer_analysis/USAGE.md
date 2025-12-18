# Customer Fixed Effects Analysis using Conditional Poisson

Conditional Poisson regression with customer fixed effects via `fixest`. Addresses time-invariant unmeasured confounding from customer characteristics.

## Overview

**Method**: Conditional Poisson with customer FE
- Conditions on sufficient statistic (customer's total count)
- Absorbs customer FEs without dummy variables
- Robust/clustered SEs handle overdispersion
- Includes slope terms (transfer function: exposure × time)

## Files

- `run_customer_fixest.R` - Main orchestration
- `model_functions.R` - Helper functions
- `run_all_analyses.R` - Run all A5/A6 models
- `results_exposures/` - Exposure estimates only
- `results_other/` - Full model results
- `pred_plots/` - Time series prediction plots (train/test)

## Usage

### Run All Analyses

```r
source("customer_analysis/run_all_analyses.R")
results <- run_all()
```

Outputs:
- `results_exposures/A5_{outcome}.csv` - Exposure estimates for forest plots
- `results_exposures/A6_{outcome}.csv` - Exposure estimates for targeted analyses
- `results_other/` - Full model results with all coefficients

### Quick Test

```r
source("customer_analysis/run_customer_fixest.R")
test_single_model(location_id = "SRQS8F7JWA9MZ", outcome = "nonvegan_outcome")
```

## Outcomes

**A5** (5 outcomes): nonvegan, meat, chicken_fish, vegan, vegetarian
**A6** (2 outcomes): breakfast, untextured

## Restaurants

**A5**: SRQS8F7JWA9MZ, 2HRX9P6HKXA8V, L69HYJ4Y3TR91, ED5J990H5VAZT
**A6 breakfast**: 2HRX9P6HKXA8V, L69HYJ4Y3TR91, ED5J990H5VAZT
**A6 untextured**: SRQS8F7JWA9MZ

## Exposure Summary Files

The `results_exposures/*.csv` files contain:
- **Main effects**: `exposure_{restaurant}_{n}`
- **Slope terms**: `exposure_{restaurant}_{n}:date_code` (transfer function)
- **Gender interactions**: `exposure_{restaurant}_{n}:gendermale`
- **Pooled**: `any_exposureTRUE`, `any_exposureTRUE:date_code`, `any_exposureTRUE:gendermale`

Columns: model_id, term, estimate, std_error, p_value, ci_lower, ci_upper, location_id, n_obs, n_customers

## Covariates

Transaction-level (no weather):
- Prices: vegan_price_real, vegetarian_price_real, meat_price_real
- Temporal: weekend, holiday_window, month_cat, season, year_cat, date_code, day_of_week_cat
- Economic: inflation
- A6: outcome-specific price (breakfast_price_real, untextured_price_real)

## Filtering

- Customers with observations both pre and post MPBA
- Automatic singleton/collinearity removal by fixest
- Gender interactions when sufficient variation

## Standard Errors

- Per-restaurant: Clustered at customer level
- Pooled: Two-way clustering (customer + restaurant)

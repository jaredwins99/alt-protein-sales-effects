# Customer Analysis

Fixed-customer-base analyses (A5/A6) using conditional Poisson regression with customer fixed effects.

## Directory Structure

```
customer_analysis/
├── transaction_level/
│   ├── fixest/                          # Frequentist conditional Poisson (fixest::fepois)
│   │   ├── model_functions.R            # Core helpers (load, filter, fit, extract, plot)
│   │   ├── run_all_analyses.R           # Run all A5/A6 outcomes
│   │   ├── run_customer_fixest.R        # Main orchestration script
│   │   ├── run_top_customers.R          # Top 25% most frequent customers
│   │   ├── create_forest_plots.R        # Forest plots from fixest results
│   │   ├── create_forest_plots_top.R    # Forest plots for top-customer subset
│   │   ├── pred_plots/                  # Time series prediction plots
│   │   ├── results_exposures/           # Exposure-only CSVs (for forest plots)
│   │   └── results_other/               # Full model results
│   └── stan_poisson/                    # Bayesian conditional Poisson (Stan)
│       ├── create_forest_plots_stan.R   # Forest plots from Stan results
│       └── results/{outcome}/           # Stan model outputs (summ.rds, fit.rds, etc.)
├── day_level/
│   └── stan_gaussian/                   # Day-level Stan Gaussian model (not yet run)
│       └── aggregate_customer_data.R    # Aggregation from transaction to customer-day
├── forest_plots/                        # All forest plots organized by method
│   ├── transaction_level/
│   │   ├── fixest/                      # fixest forest plots (A5, A6)
│   │   ├── fixest_top_customers/        # Top 25% customer forest plots
│   │   └── stan_poisson/                # Stan forest plots
│   └── day_level/
│       └── stan_gaussian/               # (placeholder)
├── compare_models.R                     # Model specification comparison
├── compare_models_summary.md            # Comparison writeup
└── transaction_level/compare_results.R  # Numerical results comparison (fixest vs stan)
```

## Quick Start

### Run All Fixest Analyses
```r
source("customer_analysis/transaction_level/fixest/run_all_analyses.R")
results <- run_all()
```

### Generate Forest Plots
```r
source("customer_analysis/transaction_level/fixest/create_forest_plots.R")
source("customer_analysis/transaction_level/stan_poisson/create_forest_plots_stan.R")
```

### Compare Fixest vs Stan
```r
source("customer_analysis/transaction_level/compare_results.R")
```

## Methods

### Transaction-Level Fixest
- `fixest::fepois(outcome ~ predictors | customer_id, vcov = ~customer_id)`
- Per-restaurant models, clustered SEs
- Frequentist CIs (estimate +/- 1.96*SE)

### Transaction-Level Stan
- Custom conditional Poisson likelihood in Stan
- 3-level hierarchy: mu_gamma → eta (between-restaurant) → gamma (within-restaurant)
- Bayesian credible intervals (posterior quantiles)

### Day-Level Stan Gaussian
- Aggregated customer-day data
- Stan Gaussian model (model_multilevel_transfer_customer_gaussian.stan)
- Not yet run

## Outcomes & Restaurants

**A5** (6 outcomes): nonvegan, meat, chicken_fish, vegan, vegetarian, total
**A6** (2 outcomes): breakfast, untextured

**A5 restaurants**: SRQS8F7JWA9MZ, 2HRX9P6HKXA8V, L69HYJ4Y3TR91, ED5J990H5VAZT
**A6 breakfast**: 2HRX9P6HKXA8V, L69HYJ4Y3TR91, ED5J990H5VAZT
**A6 untextured**: SRQS8F7JWA9MZ

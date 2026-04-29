# Customer Analysis - Results Summary

## Current Results

### Transaction-Level Fixest (A5)
**Location:** `transaction_level/fixest/results_exposures/`
- A5_nonvegan.csv, A5_meat.csv, A5_chicken_fish.csv, A5_vegan.csv, A5_vegetarian.csv
- 4 restaurants per outcome, exposure level + slope terms + gender interactions
- Forest plots: `forest_plots/transaction_level/fixest/`

### Transaction-Level Fixest (A6)
- A6_breakfast.csv (3 restaurants), A6_untextured.csv (1 restaurant)

### Transaction-Level Stan Poisson
**Location:** `transaction_level/stan_poisson/results/`
- `total/` - completed (3 chains, ~27.6 hours each)
  - mu_gamma[1] (level): mean=0.000089, rhat=1.00, ESS=3300
  - mu_gamma[2] (slope): mean=0.000078, rhat=1.00, ESS=2541
  - 355/6000 (6%) divergences
  - Results: essentially null effects at transaction level

### Day-Level Stan Gaussian
- Not yet run. Model file exists at `models/model_multilevel_transfer_customer_gaussian.stan`

## Interpretation Notes

Both fixest and Stan conditional Poisson estimate rate ratios:
- **Level change**: exp(gamma) = multiplicative change in purchase rate when exposure active
- **Slope change**: exp(gamma * 365) = annual rate ratio change in trend

Stan mu_gamma represents the global average across restaurants (partial pooling).
Fixest estimates are independent per-restaurant (no pooling).

# Model Simulation Study Notes

## Original User Request
> "ok can we make a folder called model_simulations where we have R code that uses the stan model exactly as in models/model_multilevel_transfer_opt.stan and uses that generative model to simulate data so that we can check the recovery of exposures by applying our model to that data"
>
> Clarifications:
> - Recovery of gamma parameters (exposure effects)
> - Use same number of restaurants and time periods as actual data
> - Time exposures come naturally, price exposures randomly generated
> - Single simulation (not full simulation study)
> - Use `model_multilevel_transfer_opt.stan` (the _opt version)
> - First create a simple 2-restaurant version as proof of concept
> - Each simulation represents just ONE outcome

## Objective
Simulate data from the generative model in `models/model_multilevel_transfer_opt.stan` and verify recovery of exposure effects (gamma parameters).

## Stan Model Summary
- **Model type**: Zero-inflated Negative Binomial INGARCH
- **Key parameters to recover**:
  - `mu_gamma[M]`: Global mean exposure effect (primary)
  - `sigma_gamma_between[M]`: Between-restaurant SD
  - `sigma_gamma_within[M]`: Within-restaurant SD
  - `eta[M, R]`: Per-restaurant exposure effects (secondary)
  - `gamma[K_exposure]`: Per-exposure effects (tertiary)

## Hierarchical Structure for Exposures
```
Level 2 (between restaurants):
  eta[m, r] = mu_gamma[m] + sigma_gamma_between[m] * z_eta[m, r]

Level 1 (within restaurant, multiple exposures):
  gamma[k] = eta[m, r] + sigma_gamma_within[m] * z_gamma[k]
```

## Simulation Plan

### Phase 1: Simple 2-Restaurant Version (Proof of Concept)
- 2 restaurants
- 1 outcome variable
- Minimal covariates (intercept + 1-2 simple predictors)
- Single exposure per restaurant
- No INGARCH lags (p_effective=0, q_effective=0)
- Goal: Verify basic simulation and recovery works

### Phase 2: Full Simulation
- Use actual number of restaurants and time periods from data
- 1 outcome variable
- Include all covariate structure
- Randomly generate price exposures
- Full INGARCH structure

### Phase 3: Realistic Simulation with Real Covariates
- Use real X matrix from ITS total data (actual covariate values)
- Simulate only the coefficients (betas, gammas, alphas, deltas)
- Full INGARCH lags (12 outcome + 12 intensity lags)
- 6 tier-1 restaurants with real exposure structure
- Goal: Verify recovery with realistic covariate structure and temporal dependencies

## Progress Log

### 2026-02-13
- [x] Simple 2-restaurant simulation created (`simulate_simple.R`)
- [x] Simple simulation tested - mu_gamma recovered (True: 0.2, Est: 0.23, 90% CI covers)
- [x] Full simulation created (`simulate_full.R`) - 6 restaurants, 8 exposures, 8026 train obs
- [x] Full simulation tested - Results below

#### Full Simulation Results (6 restaurants, 8 exposures):
| Parameter | True | Estimated | 90% CI | Recovered? |
|-----------|------|-----------|--------|------------|
| mu_gamma | 0.200 | 0.341 | [0.23, 0.44] | NO (bias) |
| sigma_gamma_between | 0.100 | 0.115 | [0.02, 0.26] | Yes |
| sigma_gamma_within | 0.050 | 0.181 | [0.01, 0.46] | Yes |
| mu_beta_intercept | 2.000 | 2.103 | [1.94, 2.27] | Yes |

**Diagnostics**: 1% divergences, all Rhat < 1.01, good ESS

**Note**: mu_gamma is biased upward (true 0.2, est 0.34). This may be due to
random variation in this single simulation run - the generated per-restaurant
effects (eta) happened to be higher than mu_gamma on average.
- [ ] Recovery analysis complete

### 2026-02-14
- [ ] Realistic simulation created (`simulate_total.R`) - uses REAL X matrix from ITS total data
  - Key difference from `simulate_full.R`: uses actual covariate data (not synthetic)
  - Sources the real data pipeline (prepare_data, index_data from ingarch scripts)
  - ITS "total" outcome with 6 tier-1 restaurants
  - Full INGARCH structure: p_effective=12, q_effective=12 (lags 1-7, 14, 21, 28, 35, 42)
  - Random lags at 1 and 7 for both alpha and delta
  - All random predictors: prices, weekend, holiday, month, season, year, date_num
  - All fixed predictors: day_of_week, inflation, temp, precip
  - Exposures from real mpba_introductions.csv (M=2: level shift + slope)
  - True mu_gamma = c(0.15, -0.01) (15% level shift, ~0 slope)
  - Zero-inflated negative binomial with ~5% structural zeros
  - Recovery check for all global, restaurant-level, and exposure parameters
- [ ] Simulation tested

## Files
- `simulate_simple.R`: Simple 2-restaurant proof of concept (1 outcome)
- `simulate_full.R`: Full simulation matching actual data structure (1 outcome)
- `simulate_total.R`: Realistic simulation using real X matrix from ITS total data (full INGARCH)
- `recovery_analysis.R`: Analysis of parameter recovery

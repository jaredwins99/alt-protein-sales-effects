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

## Progress Log

### 2026-02-13
- [x] Simple 2-restaurant simulation created (`simulate_simple.R`)
- [ ] Simple simulation tested and verified
- [ ] Full simulation structure created
- [ ] Data generation code complete
- [ ] Model fitting on simulated data
- [ ] Recovery analysis complete

## Files
- `simulate_simple.R`: Simple 2-restaurant proof of concept (1 outcome)
- `simulate_full.R`: Full simulation matching actual data structure (1 outcome)
- `recovery_analysis.R`: Analysis of parameter recovery

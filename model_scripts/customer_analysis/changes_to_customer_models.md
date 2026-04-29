# Changes to Customer Models

Two new Stan models derived from `models/model_multilevel_transfer_opt.stan` for A5/A6 customer fixed-effects analyses.

## Model Comparison

| | Poisson (`_customer_poisson.stan`) | Gaussian (`_customer_gaussian.stan`) |
|---|---|---|
| **Data level** | Customer-day | Restaurant-day (demeaned) |
| **Customer FE strategy** | Condition on sufficient statistic n_i | Within-customer demeaning |
| **Likelihood** | Conditional Poisson | Normal |
| **Link function** | Log (lambda = exp(nu)) | Identity (mu = nu) |
| **INGARCH AR lags** | Removed from model; pre-computed in X | Preserved (sequential loop) |
| **INGARCH delta (latent intensity lags)** | Dropped entirely | Preserved (sequential loop) |
| **Dispersion parameter** | None | sigma (Gaussian SD) |
| **Distributional purity** | High (exact conditional Poisson) | Lower (Gaussian approximation for counts) |

## Poisson Model: All Changes from `_opt.stan`

### DATA block

**Removed (INGARCH structure):**
- `p_effective`, `q_effective` (lag dimensions)
- `effective_lags_alpha`, `K_alpha_random`, `idx_alpha_random`, `K_alpha_fixed`, `idx_alpha_fixed` (outcome lag indices)
- `effective_lags_delta`, `K_delta_random`, `idx_delta_random`, `K_delta_fixed`, `idx_delta_fixed` (latent intensity lag indices)
- `idx_to_rest_train`, `idx_to_rest_test` (per-observation restaurant mapping)
- `mu_alpha_scale`, `sigma_alpha_scale` (outcome lag hyperprior scales)
- `mu_delta_scale`, `sigma_delta_scale` (latent intensity hyperprior scales)
- `mu_phi_log_scale`, `sigma_phi_log_scale` (NegBin dispersion hyperprior scales)
- `z_alpha_scale`, `z_delta_scale`, `z_phi_scale` (deviate scales)

**Added (customer indexing):**
- `C` — total number of customers (train)
- `customer_start_idx[C]`, `customer_end_idx[C]` — start/end indices in concatenated data per customer
- `customer_to_rest[C]` — maps customer to restaurant (for R-side post-processing, unused in Stan likelihood)
- `n_i[C]` — sufficient statistic: total count per customer (sum of y over all days)
- Same set for test data: `C_test`, `customer_start_idx_test`, `customer_end_idx_test`, `customer_to_rest_test`, `n_i_test`

### PARAMETERS block

**Removed (all INGARCH parameters):**
- `mu_alpha_random_raw`, `mu_alpha_fixed_raw` (global outcome lag params)
- `mu_delta_random_raw`, `mu_delta_fixed_raw` (global latent intensity lag params)
- `mu_phi_log` (global NegBin dispersion)
- `sigma_alpha_random`, `sigma_delta_random` (between-restaurant variability for lags)
- `sigma_phi_log` (between-restaurant variability for dispersion)
- `z_alpha_random`, `z_delta_random` (local deviate matrices for lags)
- `z_phi_log` (local dispersion deviates)

### TRANSFORMED PARAMETERS block

**Removed:**
- Entire `alpha` block (outcome lags, ~28 lines) — AR is now pre-computed in X
- Entire `delta` block (latent intensity lags, ~26 lines) — dropped, cannot pre-compute
- `phi = exp(...)` (NegBin dispersion) — not needed for conditional Poisson

**Changed (nu computation):**
- _opt.stan: vectorized `X * beta_r` PLUS sequential loop adding `alpha * log1p(y[t-lag])` and `delta * nu[t-lag]`
- Poisson: vectorized `X * beta_r` ONLY — fully vectorized, no sequential loop
- `lambda = exp(nu)` retained (still log link)

### MODEL block

**Removed priors:**
- All INGARCH global priors: `mu_alpha_*`, `mu_delta_*`, `mu_phi_log`
- All INGARCH between-restaurant priors: `sigma_alpha_*`, `sigma_delta_*`, `sigma_phi_log`
- All INGARCH local priors: `z_alpha_*`, `z_delta_*`, `z_phi_log`

**Changed likelihood:**
- _opt.stan: `y_train ~ neg_binomial_2(lambda, phi[idx_to_rest_train])`
- Poisson: conditional Poisson per customer:
  ```
  for (c in 1:C) {
      target += dot_product(y[c_start:c_end], nu[c_start:c_end])
             - n_i[c] * log_sum_exp(nu[c_start:c_end]);
  }
  ```

### GENERATED QUANTITIES block

| What | _opt.stan | _customer_poisson.stan |
|---|---|---|
| `log_lik` | `vector[N_train]`, per-obs NegBin | `vector[C]`, per-customer conditional Poisson |
| `y_rep` | `neg_binomial_2_rng(lambda, phi)` | `poisson_rng(lambda)` (unconditional) |
| Test nu | Sequential INGARCH loop | Fully vectorized `X_test * beta_r` |
| `y_test_rep` | `neg_binomial_2_rng` | `poisson_rng` |
| `log_lik_test` | Not present | Added, `vector[C_test]`, per-customer |

### UNCHANGED from _opt.stan

- Entire `beta` construction (intercept, random, fixed, exposure insertion)
- Entire 3-level exposure hierarchy: `mu_gamma` -> `eta` (per-restaurant) -> `gamma` (per-exposure)
- All hyperprior scales for beta and gamma
- All priors for beta and gamma parameters

### Known Identification Issues

1. **Intercept is not identified.** The conditional Poisson likelihood absorbs any constant within a customer. Since each customer belongs to one restaurant, the restaurant-level intercept is absorbed. Its posterior equals its prior. Recommend dropping the intercept column from X in data prep.

2. **Customer-level constants are absorbed.** Gender main effect, age, etc. are not identified. Only time-varying covariates and interactions (e.g., gender x exposure) contribute to the likelihood.

3. **`customer_to_rest` / `customer_to_rest_test`** are passed to Stan for R-side convenience but unused in the model itself.

---

## Gaussian Model: All Changes from `_opt.stan`

### DATA block

| What | _opt.stan | _customer_gaussian.stan |
|---|---|---|
| `y_train` | `array[N_train] int` | `vector[N_train]` (continuous demeaned) |
| `y_test` | `array[N_test] int` | `vector[N_test]` (continuous demeaned) |
| `mu_phi_log_scale` | NegBin dispersion | renamed `mu_sigma_log_scale` |
| `sigma_phi_log_scale` | NegBin dispersion | renamed `sigma_sigma_log_scale` |
| `z_phi_scale` | NegBin deviate scale | renamed `z_sigma_scale` |

Everything else in the data block is **identical** (including all INGARCH lag indices).

### PARAMETERS block

| _opt.stan | _customer_gaussian.stan |
|---|---|
| `mu_phi_log` | `mu_sigma_log` |
| `sigma_phi_log` | `sigma_sigma_log` |
| `z_phi_log` | `z_sigma_log` |

Everything else is **identical** (all alpha/delta parameters preserved).

### TRANSFORMED PARAMETERS block

| What | _opt.stan | _customer_gaussian.stan |
|---|---|---|
| Dispersion | `phi = exp(mu_phi_log + sigma_phi_log * z_phi_log)` | `sigma = exp(mu_sigma_log + sigma_sigma_log * z_sigma_log)` |
| AR lag transform | `log1p(y_train[t - lag])` | `y_train[t - lag]` (direct, since demeaned can be negative) |
| Link function | `lambda = exp(nu)` | `mu = nu` (identity link) |

The INGARCH sequential loop structure (alpha AR + delta latent lags) is **fully preserved**.

### MODEL block

| What | _opt.stan | _customer_gaussian.stan |
|---|---|---|
| Dispersion priors | `mu_phi_log`, `sigma_phi_log`, `z_phi_log` | `mu_sigma_log`, `sigma_sigma_log`, `z_sigma_log` |
| Likelihood | `y_train ~ neg_binomial_2(lambda, phi[...])` | `y_train ~ normal(mu, sigma[...])` |

All alpha/delta priors **identical**.

### GENERATED QUANTITIES block

| What | _opt.stan | _customer_gaussian.stan |
|---|---|---|
| `y_rep` type | `array[N_train] int` | `vector[N_train]` |
| `y_rep` draw | `neg_binomial_2_rng(lambda, phi)` | `normal_rng(mu, sigma)` |
| `log_lik` | `neg_binomial_2_lpmf` | `normal_lpdf` |
| Test AR lags | `log1p(y_test[...])` | `y_test[...]` (direct) |
| `lambda_test` | `exp(nu_test)` | `mu_test = nu_test` (identity) |
| `y_test_rep` type | `array[N_test] int` | `vector[N_test]` |
| `y_test_rep` draw | `neg_binomial_2_rng` | `normal_rng` |

### UNCHANGED from _opt.stan

- Entire `beta` construction
- Entire 3-level exposure hierarchy
- Full INGARCH sequential structure (alpha + delta)
- tanh(-1,1) constraint on alpha/delta for stationarity
- `idx_to_rest_train`, `idx_to_rest_test` mappings
- `p_effective`, `q_effective` and all lag index arrays

---

## Aggregation Script (`customer_analysis_day/aggregate_customer_data.R`)

Aggregates item-level customer transactions to customer-day level for the Poisson model.

- Input parquet is pre-filtered to customers with pre+post exposure data (no additional filtering needed)
- Outcomes summed within customer-day: all 22 outcome columns
- AR lags computed at restaurant-day aggregate level (log1p transform, lags 1/2/3/7) for all 13 modeled outcomes:
  - A5 main: vegan, vegetarian, total, nonvegan, meat, chicken_fish
  - A6 targeted: breakfast, untextured
  - A6 T2 targeted: breakfast_t2, chicken_t2, dairy_t2, textured_t2, untextured_t2
- Per-customer total counts computed (sufficient statistics for conditional Poisson)

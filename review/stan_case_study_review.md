# Assessment of `model_multilevel_transfer_truncated.stan`

Review based on reading the entire dev_template Stan reference library (users-guide, reference-manual, forum posts, example models, case studies, prior choice recommendations), all 7 precursor models, the Gaussian IID sibling model, and agent test results.

---

## What This Model Is

A **3-level hierarchical zero-truncated negative binomial INGARCH model** for restaurant-day count data. It estimates causal exposure effects (e.g., menu changes) on daily transaction counts across multiple restaurants, with autoregressive structure on both observed outcomes and latent intensities.

---

## What It Does Well

### 1. Multilevel Exposure Hierarchy (Excellent)
The 3-level structure (global `mu_gamma` -> per-restaurant `eta` -> per-exposure `gamma`) with adaptive pooling is the crown jewel. The logic that collapses levels when there's only one unit (lines 243-258) is correct and avoids degenerate hierarchies. This matches the best practices from the reference material on partial pooling.

### 2. Truncation Implementation (Correct)
The zero-truncated NB correction at lines 496-500 is mathematically sound:
```stan
target += -sum(log1m_exp(log_nb0));
```
This matches the Stan users-guide pattern for truncated likelihoods (subtract log P(Y=0) from the log-likelihood). The `apply_truncation` flag giving the option to toggle it off is a nice design choice.

### 3. Stationarity Constraints (Good)
The `tanh(raw / 2.0)` transform (lines 301, 337) constrains alpha and delta to (-1, 1), ensuring INGARCH stationarity. The division by 2 spreads the prior mass away from the boundaries, which the forum's reparameterization guidelines recommend for better HMC geometry.

### 4. Conditional R=1 Logic (Smart)
The pattern of collapsing to global means when R=1 (lines 183-198, 285-292) with independent priors on unused parameters (lines 457-468) prevents funnel pathologies. This directly addresses Neal's funnel problem described in the reference material -- unused hierarchical parameters with sigma priors create divergences if not handled.

### 5. Vectorized Predictor Computation (Good)
The matrix multiply `nu[r_start:r_end] = X_train[r_start:r_end] * beta_r` (line 371) follows the performance optimization guidance. Only the sequential INGARCH lags are looped, which is unavoidable due to dependencies.

### 6. Open-Day Indexing (Clean)
Using `idx_total_nonzero` to subset to open-day observations (lines 493-500) rather than looping over all N with conditionals is the correct Stan pattern from the multi-indexing reference.

---

## Issues and Concerns

### 1. Mixed Parameterization -- CP for Most, NCP for Exposures

This is the most significant design decision. The model uses:
- **Centered (CP)** for: `beta_intercept_r`, `beta_random_r`, `alpha_random_raw_r`, `delta_random_raw_r`, `phi_log_r`
- **Non-centered (NCP)** for: `z_eta` (between-restaurant exposure), `z_gamma` (within-restaurant exposure)

The reference material is clear: CP works best with abundant data per group; NCP works best with sparse data. The precursor models (all 7) used NCP uniformly. The shift to CP for betas/alpha/delta is justified by the computational cost of NCP in a model this complex, and the fact that these parameters are not the primary inferential target.

**No statistical bias from mixing CP/NCP.** They define the same joint posterior -- it's a change of variables with an identity Jacobian (for the location-scale NCP). The posterior being sampled is mathematically identical regardless of parameterization. The only difference is computational efficiency -- how well HMC explores that posterior.

The forum reparameterization guidelines explicitly recommend mixing parameterizations per-parameter based on data density, not choosing uniformly. NCP on exposures (where the hierarchy matters most and data may be sparse per exposure) and CP on everything else (where restaurant-days are abundant) is the right call.

### 2. Laplace Prior on INGARCH Parameters (Purposeful Regularization)

Lines 412-415 put `double_exponential(0, scale)` (Laplace) priors on `mu_alpha_random_raw` and `mu_delta_random_raw`. This is an intentional sparsity-inducing choice (L1 regularization) -- the goal is to shrink unnecessary lags toward zero rather than keeping all of them active. This is appropriate when the model includes more lags than may be needed and the analyst wants the data to select which lags matter.

### 3. No Joint Stationarity Constraint on (alpha, delta)

Individual alpha and delta are constrained to (-1,1), but the INGARCH stationarity condition requires `sum(alpha) + sum(delta) < 1` jointly. The reference time-series guide warns about non-stationary models. Currently, the model allows `alpha[1] = 0.6` and `delta[1] = 0.6` simultaneously, which would be non-stationary.

This is a known limitation but not something worth addressing in this work -- the data should naturally constrain this if the process is stationary. If explosive posterior predictive draws appear, this would be the likely cause.

### 4. Rejection Sampling in Generated Quantities (Performance Risk)

Lines 530-531:
```stan
while (y_rep[t] == 0)
    y_rep[t] = neg_binomial_2_rng(lambda[t], phi_r);
```

When lambda is small and phi is small, P(Y=0) can be large, making rejection sampling slow. The reference material on custom probability functions suggests inverse-CDF approaches for bounded variates, though Stan doesn't provide a NB quantile function natively.

Minor issue -- only affects generated quantities speed, not parameter estimation. Watch for slow GQ blocks on days with very low expected counts.

### 5. Dispersion Prior Structure (Well-Chosen)

The model uses `student_t(3, 0, scale)` for all variance/SD parameters:
- `sigma_beta_intercept` (line 423)
- `sigma_beta_random` (line 424)
- `sigma_gamma_between` (line 427)
- `sigma_alpha_random` (line 430)
- `sigma_delta_random` (line 431)
- `sigma_phi_log` (line 432)
- `sigma_gamma_within` (line 478)

This is one of the standard recommendations from the prior choice guide -- heavier tails than half-normal (accommodates surprise), but finite variance unlike half-Cauchy. The forum prior recommendations specifically endorse `half-t(3, 0, scale)` as a sensible default for hierarchical scales.

The global mean `mu_phi_log ~ normal(0, mu_phi_log_scale)` (line 416) correctly uses `normal` since it's a location parameter, not a scale. The SD `sigma_phi_log` gets the `student_t(3)` treatment. Prior structure is consistent.

**Key tuning opportunity:** The implied prior on phi itself depends heavily on `mu_phi_log_scale`. Since `phi = exp(phi_log_r)` and `phi_log_r ~ normal(mu_phi_log, sigma_phi_log)`, the prior on phi is log-normal. If `mu_phi_log_scale` is wide (say, 5), substantial mass is placed on both very small phi (underdispersed, nearly Poisson) and very large phi (nearly Gaussian). Tightening `mu_phi_log_scale` around the typical overdispersion in the data is the highest-value prior tuning available -- it directly affects how much the model trusts the NB shape vs. letting the mean do the work.

### 6. No Test Log-Likelihood

The generated quantities compute `log_lik` for training data only. The reference cross-validation guide emphasizes computing log predictive densities on held-out data for model comparison. `y_test_rep` is computed but not `log_lik_test`, which means proper out-of-sample ELPD comparison isn't available.

Worth adding in the future for formal model comparison.

---

## Comparison with the Gaussian IID Sibling

The `_customer_gaussian_iid` model strips out INGARCH entirely and uses a Gaussian likelihood on demeaned transaction-level data.

| Aspect | Truncated NB INGARCH | Gaussian IID |
|--------|---------------------|--------------|
| Data level | Restaurant-day aggregate | Transaction-level |
| Likelihood | Zero-truncated NegBin | Gaussian |
| Temporal structure | AR on outcomes + latent intensity | None |
| Customer effects | Not modeled | Pre-period demeaning |
| Complexity | ~50+ params per restaurant | ~10 params per restaurant |
| Computational cost | High (sequential loops) | Low (fully vectorized) |

The Gaussian IID model is the "does the effect survive without temporal modeling" check, while the truncated model is the full structural model. Good experimental design.

---

## Evolution from Precursors

The truncated model represents a convergence of the model family:
- From the **base model**: kept the NB INGARCH structure
- From the **_opt model**: adopted vectorized likelihood, student_t priors on scales, controllable z-scales
- From the **_zi models**: replaced zero-inflation with zero-truncation (simpler, avoids identifiability issues between structural and sampling zeros)
- **Dropped**: zero-inflation parameters, group stratification, conditional Poisson approach

This evolution is sensible. The truncation approach is cleaner than ZI when you can observe which days are "open" vs "closed" -- you just model open days with truncated NB rather than mixing structural zeros.

---

## Bottom Line

This is a well-engineered model. The core structure is sound, the exposure hierarchy is the right design for causal inference with partial pooling, and the truncation implementation is correct. Prior choices are consistent and well-motivated. The main areas to monitor:

1. **CP on sparse restaurants** -- watch for divergences on restaurant-specific alpha/delta/phi if any restaurant has little data
2. **Joint stationarity** -- not enforced; check posterior predictive for explosive draws
3. **mu_phi_log_scale** -- the highest-value prior tuning knob; tighten around known overdispersion
4. **Test log-likelihood** -- add for future model comparison work

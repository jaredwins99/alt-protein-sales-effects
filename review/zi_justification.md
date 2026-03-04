# Zero-Inflated INGARCH: Methodology and Verification

## 1. Mathematical Verification of _zi Model

The ZINB likelihood for observation y_i at restaurant r is:

**y > 0:** `P(Y=y) = (1-pi_r) * NB(y|lambda_i, phi_r)`
**y = 0:** `P(Y=0) = pi_r + (1-pi_r) * NB(0|lambda_i, phi_r)`

The model block (`_zi.stan:477-496`) computes this in three vectorized steps:

**Step 1** (line 478): `y_train ~ neg_binomial_2(lambda, phi[...])` adds `sum log NB(y_i|lambda_i, phi_i)` for ALL observations.

**Step 2** (line 481): `target += sum(log1m(pi[...]))` adds `sum log(1-pi_i)` for ALL observations.

After steps 1+2:
- **y>0**: `log NB(y|lambda,phi) + log(1-pi) = log[(1-pi) * NB(y|lambda,phi)]` -- correct.
- **y=0**: `log NB(0|lambda,phi) + log(1-pi) = log[(1-pi) * NB(0|lambda,phi)]` -- **wrong**, we need `log[pi + (1-pi)*NB(0)]`.

**Step 3** (lines 486-496) fixes the zeros. The correction needed is:

```
log[pi + (1-pi)*NB(0)] - log[(1-pi)*NB(0)]
= log[pi/((1-pi)*NB(0)) + 1]
= log1p_exp(log(pi) - log(1-pi) - log_nb0)
```

where `log_nb0 = phi*(log phi - log(phi+lambda))` since `NB(0|lambda,phi) = (phi/(phi+lambda))^phi`.

The code computes exactly this: `target += sum(log1p_exp(log_pi_z - log1m_pi_z - log_nb0))`. **Correct.**

**Generated quantities verification** (`_zi.stan:509-540`):

- `structural_zero_prob[t] = pi / (pi + (1-pi)*NB(0))` -- Bayes' rule for P(structural | y=0). **Correct.**
- `log_lik` for y=0: `log_sum_exp(log(pi), log(1-pi) + log_nb0)` = `log[pi + (1-pi)*NB(0)]`. **Correct.**
- `log_lik` for y>0: `log(1-pi) + log NB(y|lambda,phi)`. **Correct.**

## 2. Line-by-Line Verification of _zi_data Model

### Data block (lines 1-94)

**Line 61**: `vector<lower=0,upper=1>[R] pi_known;`
Per-restaurant pi, bounded [0,1]. Compare to _zi which has `pi` as a transformed parameter computed from `mu_pi_logit`, `sigma_pi_logit`, `z_pi_logit`. Here it is data. No `mu_pi_logit_scale`, `sigma_pi_logit_scale`, or `z_pi_scale` in the data block -- correct, since pi is not estimated.

**Lines 64-65**: `N_zeros` and `idx_zeros[N_zeros]`
Indices into y_train where y=0. These capture ALL zeros (both structural and sampling). Correct -- the ZINB likelihood for y=0 applies to all observed zeros regardless of their origin.

### Parameters block (lines 96-163)

No `mu_pi_logit`, `sigma_pi_logit`, `z_pi_logit`. The parameter space is identical to `_opt.stan`. No extra ZI parameters since pi is data.

### Transformed parameters (lines 165-375)

No `pi = inv_logit(...)` line (which is line 348 in `_zi.stan`). Everything else (INGARCH structure: beta, eta, alpha, delta, phi, lambda) is identical to `_zi.stan`.

### Model block (lines 377-470)

**Lines 383-443**: Priors identical to `_zi.stan` except no pi priors. Correct.

**Line 451**: `y_train ~ neg_binomial_2(lambda, phi[idx_to_rest_train]);`
Adds `sum_i log NB(y_i | lambda_i, phi_{r(i)})` for ALL N_train observations.
Check: `phi` is length R, `idx_to_rest_train` maps each observation to its restaurant, so `phi[idx_to_rest_train]` produces a vector of length N_train. Vectorized call with matching lengths. **Correct.**

**Line 454**: `target += sum(log1m(pi_known[idx_to_rest_train]));`
Adds `sum_i log(1 - pi_{r(i)})` for ALL observations.
Since `pi_known` is data (not parameters), this entire term is a **constant** with respect to the parameters. It has zero gradient and does NOT affect the sampler's behavior or parameter estimates. It only matters for correct absolute log-likelihood values (used in WAIC/LOO). But it is mathematically necessary: the ZINB likelihood for y>0 is `(1-pi) * NB(y)`, so `log(1-pi)` must appear. **Correct.**

**Lines 459-469**: Zero correction.

Line 460: `log(pi_known[idx_to_rest_train[idx_zeros]])`
- `idx_zeros`: indices of y=0 observations in training data
- `idx_to_rest_train[idx_zeros]`: restaurant IDs for those zero observations
- `pi_known[...]`: restaurant-specific pi for each zero
- Double-indexing is valid Stan. **Correct.**

Line 461: `log1m(pi_known[idx_to_rest_train[idx_zeros]])` -- same double-index for log(1-pi). **Correct.**

Line 464: `lambda_z = lambda[idx_zeros]` -- lambda values at zero observations. **Correct.**

Line 465: `phi_z = phi[idx_to_rest_train[idx_zeros]]` -- restaurant-specific phi at zero observations. **Correct.**

Line 466: `log_nb0 = phi_z .* (log(phi_z) - log(phi_z + lambda_z))`
Computes log NB(0|lambda,phi). Derivation: `NB(0) = (phi/(phi+lambda))^phi`, so `log NB(0) = phi * (log phi - log(phi+lambda))`. Element-wise `.*` correct for vectors. **Correct.**

Line 468: `target += sum(log1p_exp(log_pi_z - log1m_pi_z - log_nb0))`
Full accounting for a zero observation after all three steps:

```
Step 1: + log NB(0|lambda,phi)          [from line 451]
Step 2: + log(1-pi)                     [from line 454]
Step 3: + log1p_exp(log(pi) - log(1-pi) - log NB(0))   [from line 468]
```

Let A = log NB(0), B = log(1-pi), C = log(pi):
```
Total = A + B + log(1 + exp(C - B - A))
      = log(exp(A+B)) + log(1 + exp(C - B - A))
      = log(exp(A+B) * (1 + exp(C - B - A)))
      = log(exp(A+B) + exp(C))
      = log((1-pi)*NB(0) + pi)
```
This equals `log(pi + (1-pi)*NB(0))`, the correct ZINB likelihood for y=0. **Correct.**

For y>0 (no correction applied):
```
Step 1: + log NB(y|lambda,phi)
Step 2: + log(1-pi)
Total:  log((1-pi) * NB(y))
```
**Correct.**

### Generated quantities -- Train (lines 472-503)

**Lines 482-483**: `r = idx_to_rest_train[t]`, `pi_t = pi_known[r]`
Maps observation to restaurant, gets the fixed pi. **Correct.**

**Lines 487-491**: Posterior predictive.
Draw `bernoulli_rng(pi_t)`. If 1, y_rep=0 (structural zero). Else, `neg_binomial_2_rng(lambda[t], phi_r)`. Standard ZINB data generating process. **Correct.**

**Lines 494-502**: Pointwise log-likelihood.

For y=0:
```stan
log_nb0 = neg_binomial_2_lpmf(0 | lambda[t], phi_r);
log_lik[t] = log_sum_exp(log(pi_t), log1m(pi_t) + log_nb0);
```
= `log(pi + (1-pi)*NB(0))`. Matches ZINB formula. Note: uses `neg_binomial_2_lpmf` rather than the manual formula used in the model block -- both compute the same thing, different blocks have different optimization needs. **Correct.**

For y>0:
```stan
log_lik[t] = log1m(pi_t) + neg_binomial_2_lpmf(y_train[t] | lambda[t], phi_r);
```
= `log((1-pi)*NB(y))`. **Correct.**

### Generated quantities -- Test (lines 505-594)

**Lines 530-574**: INGARCH test loop identical to `_zi.stan` and `_opt.stan`. **Correct.**

**Line 581**: `lambda_test = exp(nu_test)`. Standard. **Correct.**

**Lines 584-591**: Test posterior predictive. `pi_t = pi_known[r]`, then same ZINB draw as training. **Correct.**

### What is missing compared to _zi

1. **No `structural_zero_prob` output** -- `_zi.stan` computes `P(structural | y=0) = pi/(pi + (1-pi)*NB(0))` per observation for both train and test. `_zi_data.stan` does not. This is not a bug -- it is a feature omission. For `_zi_data`, the structural zero probability for each restaurant is just `pi_known[r]`, and the posterior classification could be computed but is not needed. Downstream code (`run_ingarch.R:402`) handles this by checking `"structural_zero_prob" %in% fit$metadata()$stan_variables`, so NULL is passed to plotting.

2. **No test log-likelihood** -- neither `_zi.stan` nor `_zi_data.stan` compute `log_lik_test`. Consistent across both.

### Verdict

The `_zi_data.stan` model is implemented correctly. The ZINB log-likelihood with known pi is mathematically exact, the indexing is consistent, the generated quantities match the standard ZINB formulas, and the parameter space is appropriately reduced (no pi-related parameters). The only substantive difference from `_zi.stan` is replacing `pi[r]` (transformed parameter from estimated mu/sigma/z) with `pi_known[r]` (data), which is applied consistently throughout.

## 3. Intuitive Walkthrough of _zi_data

The key insight is what "structural zero" means here.

**A structural zero is a restaurant-level event** -- the restaurant is closed, or it had a catastrophic day (no deliveries, emergency closure, etc.). When this happens, **every dish category** is zero: total=0, chicken=0, vegan=0, meat=0. The zero isn't about any specific dish; it's about the restaurant not operating.

**The total model is the cleanest estimator of this.** If a restaurant sold 0 total dishes on a day, it was almost certainly closed. If it sold 50 total dishes but 0 chicken dishes, it was clearly open -- that chicken zero is a "sampling zero" (just didn't sell chicken that day, happens naturally under NB).

**The subset models can't distinguish these on their own.** If chicken=0, is it because:
- (a) The restaurant was closed (structural), or
- (b) They were open but nobody ordered chicken (sampling)?

The total model can tell: if total=0, it's (a); if total>0, it's (b). The subset model alone sees only chicken=0 and can't tell.

**So the pipeline is:**
1. Fit total model with `_zi.stan` -> estimates pi_r per restaurant (P(structural zero))
2. Feed those pi_r values as known data to subset models via `_zi_data.stan`
3. Subset models focus on estimating lambda (the NB intensity) without confusing structural vs sampling zeros

This is a **modular Bayesian approach** -- intentionally "cutting" feedback so the subset model doesn't corrupt the total model's pi estimates.

## 3. Citations

The core methodology is supported by established literature:

**ZINB foundation:**
- Lambert (1992), "Zero-Inflated Poisson Regression" -- *Technometrics* -- established the ZI mixture framework
- Greene (1994), "Accounting for Excess Zeros" -- extended to NB
- Hilbe (2011), *Negative Binomial Regression* -- textbook treatment

**Modular/cut Bayesian inference (the _zi_data approach):**
- **Plummer (2015)**, "Cuts in Bayesian Graphical Models" -- *Statistics and Computing* -- formalizes the "cut" that prevents feedback between model modules. This is exactly what _zi_data does: cuts feedback from subset model -> total model's pi.
- **Bayarri, Berger & Liu (2009)**, "Modularization in Bayesian Analysis" -- *Bayesian Analysis* -- when one module is more trusted, cutting feedback prevents misspecification in the other from contaminating it.
- **Jacob, Murray, Holmes & Robert (2017)**, "Better Together?" -- *arXiv:1708.08719* -- shows modular approaches can actually improve prediction under misspecification.

**Two-stage estimation (frequentist justification):**
- **Pagan (1984)**, "Regressions with Generated Regressors" -- *International Economic Review* -- plug-in first-stage estimates produce consistent second-stage estimators, but standard errors are understated.
- **Murphy & Topel (1985)**, "Two-Step Econometric Models" -- *JBES* -- variance correction for two-stage estimation.

**Shared ZI structure across outcomes:**
- **Li et al. (1999)**, "Multivariate Zero-Inflated Poisson Models" -- *Technometrics* -- multiple outcomes sharing a common zero-inflation mechanism.
- **Cho et al. (2023)**, "Bivariate ZINB Model" -- *Statistical Methods in Medical Research* -- shared vs outcome-specific zero-inflation decomposition.

**Numerically stable implementation:**
- Stan User's Guide, Section 5.6 (Zero-Inflated Models) -- the `log_sum_exp` / `log1p_exp` formulation.
- brms package (Buerkner) -- uses the same vectorized pattern.

## 4. Known Limitation

The main caveat from Pagan (1984) and Murphy & Topel (1985): **using point estimates of pi from the total model ignores first-stage uncertainty.** The _zi_data model treats pi as perfectly known. A more rigorous approach would propagate posterior uncertainty in pi (e.g., by integrating over draws from the total model's posterior). In practice, the pi estimates from the total model are likely well-identified (lots of data for total counts), so the point-estimate approximation is reasonable but worth noting.

## 5. Validation Approaches

Three concrete things we can do to verify:

1. **Cross-check pi estimates**: Run one subset model (e.g., chicken_fish) with `_zi.stan` (estimating its own pi) and compare those pi estimates to the total model's pi. If the restaurant-closure interpretation is correct, the _zi estimates should be >= the total pi (since subsets have additional sampling zeros the model might misattribute to structural zeros).

2. **Posterior predictive zero rates**: For a completed _zi_data model, compare the predicted zero rate to the observed zero rate per restaurant. If the model is correctly accounting for structural zeros, these should match.

3. **LOO/WAIC comparison**: Compare _opt (no ZI) vs _zi_data (known ZI) on the same data. If structural zeros are real, _zi_data should have better out-of-sample log-likelihood for zero observations.

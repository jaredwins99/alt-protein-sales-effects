# Model Comparison: Fixest vs Stan Conditional Poisson

## Overview

Both models estimate the effect of plant-based menu item exposure on customer
purchasing behavior using a **conditional Poisson** likelihood that conditions
on each customer's total purchase count (the sufficient statistic). This
eliminates customer fixed effects without estimating them.

The key difference is **structure**: fixest estimates each restaurant independently,
while Stan estimates all restaurants jointly with a multilevel hierarchy that shares
information across restaurants.

## Specification Comparison

| Feature | Fixest (`fepois`) | Stan (multilevel) |
|---------|-------------------|-------------------|
| Likelihood | Conditional Poisson | Conditional Poisson |
| Software | fixest::fepois() | CmdStan (custom .stan) |
| Formula | outcome ~ X \| customer_id | target += sum_y_nu - n_i * log_sum_exp(nu) |
| Customer FE | Conditioned out (sufficient stat) | Conditioned out (sufficient stat) |
| Estimation | ML via IRLS (frequentist) | Full Bayesian (NUTS HMC) |
| Restaurant structure | Independent per-restaurant models | Joint model, all restaurants simultaneously |
| Multilevel exposure | None | 3-level: mu_gamma -> eta[k,r] -> gamma[k,r,e] |
| Partial pooling | No -- each restaurant estimated in isolation | Yes -- shrinks extreme estimates toward global mean |
| Covariate effects | Per-restaurant (independent) | Per-restaurant (random effects w/ shared mean) |
| Exposure level effect | beta (MLE per restaurant) | gamma = mu_gamma + eta + epsilon (posterior) |
| Exposure slope effect | beta:date_code (MLE per restaurant) | Same 3-level hierarchy for slopes |
| Standard errors | Clustered sandwich (vcov = ~customer_id) | Not applicable (Bayesian) |
| Confidence/credible int | estimate +/- 1.96*SE (95% Wald CI) | Posterior quantiles (q5, q95 = 90% CI) |
| Priors | None (pure likelihood) | Normal(0, scale) on mu_gamma; t(3,0,scale) on sigmas |
| Overdispersion | Handled via clustered SEs | Handled by conditional likelihood + posterior |
| Train/test split | 90/10 by date | 90/10 by date |
| Gender interactions | exposure:gender (if available) | Not included (absorbed by conditional likelihood) |

## Likelihood

Both models use an **identical** conditional Poisson likelihood:

```
log p(y_i | beta) = sum_t y_it * nu_it - n_i * log(sum_t exp(nu_it))
```

where `nu_it = X_it * beta` is the linear predictor and `n_i = sum_t y_it`
is the customer's total count. This form cancels out any customer-level
constant (the customer fixed effect), so it does not need to be estimated.

- **Fixest**: `fixest::fepois(outcome ~ predictors | customer_id, vcov = ~customer_id)`
- **Stan**: Implemented directly in the `model` block via `target += sum_y_nu - n_i[c] * log_sum_exp(nu[c_start:c_end])`

## Inference Framework

| Aspect | Fixest | Stan |
|--------|--------|------|
| Point estimate | Maximum Likelihood Estimate (MLE) | Posterior mean (or median) |
| Uncertainty | Sandwich/clustered SE at customer level | Full posterior distribution |
| Intervals | 95% Wald CI: estimate +/- 1.96 * SE | 90% credible interval: [q5, q95] |
| p-values | Wald test | Not directly; check if CI excludes zero |
| Priors | None (pure likelihood) | Normal(0, scale) on mu_gamma; Student-t(3,0,scale) on sigmas |

## Structural Differences

### Fixest: Independent Per-Restaurant Models

Each restaurant is estimated in complete isolation. The exposure effect for
restaurant r is simply the MLE from that restaurant's data alone. If a restaurant
has very few customers or extreme data, its estimate can be noisy or extreme.

### Stan: 3-Level Multilevel Hierarchy

All restaurants are estimated jointly. The exposure effect for a specific exposure
column at restaurant r is decomposed as:

```
gamma[k,r,e] = mu_gamma[k] + eta[k,r] + epsilon[k,r,e]
```

where:
- `mu_gamma[k]` = global mean effect for parameter k (k=1: level, k=2: slope)
- `eta[k,r] ~ N(0, sigma_gamma_between[k])` = between-restaurant deviation
- `epsilon[k,r,e] ~ N(0, sigma_gamma_within[k])` = within-restaurant deviation (multiple exposures)
- `sigma_gamma_between` controls how much restaurants can differ from the global mean
- `sigma_gamma_within` controls how much exposures within a restaurant can differ

This is a **partial pooling** model. It shares information across restaurants,
which has two key implications:

1. **Shrinkage**: Extreme restaurant-specific estimates are pulled toward the global mean
2. **Borrowing strength**: Restaurants with less data borrow information from data-rich restaurants

## When the Models Should Agree

With sufficient data per restaurant and weak/diffuse priors, the Stan posterior
means should approximately equal the fixest MLEs. Specifically:

- Large N per restaurant -> likelihood dominates prior -> posterior ~ MLE
- Weak priors (large scale parameters) -> minimal shrinkage
- Similar effect sizes across restaurants -> little tension between pooled and unpooled

In the limit, with flat priors and a single restaurant, the Stan model reduces
to the fixest model (the conditional Poisson MLE).

## When the Models Should Diverge

1. **Small samples**: Restaurants with few customers will see their Stan estimates
   shrunk substantially toward the global mean, while fixest gives the raw MLE
   (which may be noisy or extreme).

2. **Strong priors**: If the prior scales are tight (small mu_gamma_scale,
   sigma_gamma_between_scale), the Stan model applies more regularization.

3. **Heterogeneous effects**: If true effects vary widely across restaurants,
   the Stan model will partially pool, producing estimates between the restaurant-
   specific MLE and the grand mean. The degree of shrinkage is estimated from data
   (via sigma_gamma_between).

4. **Extreme estimates**: A restaurant with an unusually large or small fixest
   estimate will be pulled toward the center by the multilevel model. This is
   desirable if the extreme estimate is due to noise, but conservative if the
   restaurant truly has an unusual effect.

## Current Data Availability

- **Fixest outcomes available**: chicken_fish, meat, nonvegan, vegan, vegetarian
- **Stan outcomes available**: total

**No overlapping outcomes exist for direct comparison.**

The fixest models have been run for category-specific outcomes (nonvegan, meat,
chicken_fish, vegan, vegetarian), while the Stan model has only been run for the
`total` outcome. To enable a head-to-head comparison of estimates:

1. Run fixest for the `total` outcome (already listed in `A5_OUTCOMES` in
   `run_all_analyses.R`), or
2. Run the Stan multilevel model for one of the existing fixest outcomes.

Once overlapping outcomes exist, re-run this script to generate scatter plots
of fixest MLE vs Stan posterior mean and shrinkage visualizations.

## Summary

| Question | Answer |
|----------|--------|
| Same likelihood? | Yes -- both use conditional Poisson |
| Same point estimates? | Only asymptotically (large N, weak priors) |
| Same intervals? | No -- Wald CI vs posterior credible interval |
| Key advantage of fixest? | Fast, simple, no priors needed |
| Key advantage of Stan? | Partial pooling, full posterior, better in small samples |
| When to prefer fixest? | Quick exploratory analysis, large samples, no pooling desired |
| When to prefer Stan? | Publication results, small samples, want shrinkage/regularization |

*Generated by `compare_models.R` on 2026-03-04*


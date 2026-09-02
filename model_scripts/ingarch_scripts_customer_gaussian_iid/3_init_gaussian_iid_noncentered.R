## 3_init_gaussian_iid_noncentered.R
##
## init_gaussian_iid() as it stood at commit c0c8d560 (2026-03-10, "tier one trunc_cp models redone, finished"). Emits the
## non-centered names required by
## models/model_multilevel_transfer_customer_gaussian_iid_noncentered.stan.
##
## Paired with that model for 13 published fits (8 in _cp, 5 in
## _uncontaminated2).
##
## Not on any live code path. Used only by refit_exact.R.
## Renamed from 3_init_gaussian_iid.R; contents otherwise verbatim.

library(tidyverse)

# ──────────────────────────────────
#         Initialize Params
# ──────────────────────────────────
# For the Gaussian IID model (no INGARCH lags).
#
# Key differences from init_customer_gaussian:
#   - No alpha/delta inits (no INGARCH lags)
#   - Keeps sigma (Gaussian SD) and all beta/gamma inits

init_gaussian_iid <- function(data_list, chain_id = 1) {

    R <- data_list$R
    K_beta_random <- data_list$K_beta_random
    K_beta_fixed <- data_list$K_beta_fixed
    K_exposure <- data_list$K_exposure
    M <- data_list$M

    init_list <- list(
        # Intercept: near 0 for demeaned data
        mu_beta_intercept = rnorm(1, 0, 0.1),
        # Gaussian SD on log scale
        mu_sigma_log      = rnorm(1, 0, 0.5),

        sigma_beta_intercept = abs(rnorm(1, 0, 0.5)) + 0.1,
        sigma_sigma_log      = abs(rnorm(1, 0, 0.5)) + 0.1,

        # NCP deviates (standard normal)
        z_beta_intercept = rnorm(R, 0, 1),
        z_sigma_log      = rnorm(R, 0, 1)
    )

    if (0 < K_beta_random) {
        init_list$mu_beta_random    = rnorm(K_beta_random, 0, 0.1)
        init_list$sigma_beta_random = abs(rnorm(K_beta_random, 0, 0.5)) + 0.1
        init_list$z_beta_random     = matrix(rnorm(K_beta_random * R, 0, 1), K_beta_random, R)
        }

    if (0 < K_beta_fixed) {
        init_list$mu_beta_fixed = rnorm(K_beta_fixed, 0, 0.1)}

    # Conditionally add gamma-related initial values
    if (0 < K_exposure) {
        init_list$mu_gamma <- rnorm(M, 0, 0.1)
        init_list$sigma_gamma_between <- abs(rnorm(M, 0, 0.5)) + 0.1
        init_list$sigma_gamma_within <- abs(rnorm(M, 0, 0.5)) + 0.1
        init_list$z_eta <- matrix(rnorm(M * R, 0, 1), M, R)
        init_list$z_gamma <- rnorm(K_exposure, 0, 1)}

    return(init_list)
}

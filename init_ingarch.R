library(tidyverse)

# ──────────────────────────────────
#         Initialize Params
# ──────────────────────────────────

init_ingarch <- function(data_list, chain_id = 1) {
  
    # The function now uses data_list to get dimensions
    R <- data_list$R
    K_beta_random <- data_list$K_beta_random
    K_beta_fixed <- data_list$K_beta_fixed
    K_alpha_random <- data_list$K_alpha_random
    K_alpha_fixed <- data_list$K_alpha_fixed
    K_delta_random <- data_list$K_delta_random
    K_delta_fixed <- data_list$K_delta_fixed
    K_exposure <- data_list$K_exposure
    M <- data_list$M

    init_list <- list(
        mu_beta_intercept = rnorm(1, 0.5, 0.1),
        mu_phi_log        = rnorm(1, log(5), 0.5),

        sigma_beta_intercept = abs(rnorm(1, 0, 0.5)) + 0.1,
        sigma_phi_log        = abs(rnorm(1, 0, 0.5)) + 0.1,

        z_beta_intercept = rnorm(R, 0, 1),
        z_phi_log        = rnorm(R, 0, 1)
    )

    if (0 < K_beta_random) {
        init_list$mu_beta_random    = rnorm(K_beta_random, 0, 0.1)
        init_list$sigma_beta_random = abs(rnorm(K_beta_random, 0, 0.5)) + 0.1
        init_list$z_beta_random     = matrix(rnorm(K_beta_random * R, 0, 1), K_beta_random, R)
        }

    if (0 < K_beta_fixed) {
        init_list$mu_beta_fixed = rnorm(K_beta_fixed, 0, 0.1)}

    if (0 < K_alpha_random) {
        init_list$mu_alpha_random_raw    = rnorm(K_alpha_random, 0, 0.1)
        init_list$sigma_alpha_random     = abs(rnorm(K_alpha_random, 0, 0.5)) + 0.1
        init_list$z_alpha_random         = matrix(rnorm(K_alpha_random * R, 0, 1), K_alpha_random, R)}

    if (0 < K_alpha_fixed) {
        init_list$mu_alpha_fixed_raw = rnorm(K_alpha_fixed, 0, 0.1)}

    if (0 < K_delta_random) {
        init_list$mu_delta_random_raw    = rnorm(K_delta_random, 0, 0.1)
        init_list$sigma_delta_random     = abs(rnorm(K_delta_random, 0, 0.5)) + 0.1
        init_list$z_delta_random         = matrix(rnorm(K_delta_random * R, 0, 1), K_delta_random, R)}

    if (0 < K_delta_fixed) {
        init_list$mu_delta_fixed_raw = rnorm(K_delta_fixed, 0, 0.1)}
    
    # Conditionally add gamma-related initial values
    if (0 < K_exposure) {
        init_list$mu_gamma <- rnorm(M, 0, 0.1)
        init_list$sigma_gamma_between <- abs(rnorm(M, 0, 0.5)) + 0.1
        init_list$sigma_gamma_within <- abs(rnorm(M, 0, 0.5)) + 0.1
        init_list$z_eta <- matrix(rnorm(M * R, 0, 1), M, R)
        init_list$z_gamma <- rnorm(K_exposure, 0, 1)}
    
    return(init_list)
}
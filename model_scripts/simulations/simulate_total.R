# ==============================================================================
# Total Simulation Script for Parameter Recovery
# ==============================================================================
#
# This script generates FULLY SYNTHETIC data from the model's generative process
# (model_multilevel_transfer_zi.stan) and fits the model to recover parameters.
#
# PRIMARY GOAL: Test whether the model recovers mu_gamma (exposure effect).
#
# KEY DIFFERENCES FROM simulate_full.R:
#   - simulate_full.R has NO covariates (intercept + exposures only) and NO INGARCH
#   - This script adds simple synthetic covariates + INGARCH lags, making it closer
#     to the real model while keeping the data simple and easy to recover
#   - All covariates are synthetically generated (NOT the real X matrix)
#   - INGARCH lags match the real model: effective_lags = c(1,...,7,14,21,28,35,42)
#   - M=1 (no slope, single transfer function parameter)
#
# KEY DIFFERENCES FROM simulate_total.R (old version using real X matrix):
#   - Old version sourced the real data pipeline and truncated the X matrix
#   - This version builds everything from scratch with simple synthetic predictors
#   - Simpler = easier recovery = better test of core model mechanics
#
# RESTAURANT STRUCTURE:
#   R1: ~400 train, ~20 test, 1 exposure
#   R2: ~400 train, ~20 test, 2 exposures
#   R3: ~400 train, ~20 test, 1 exposure
#   R4: ~400 train, ~20 test, 2 exposures
#   R5: ~400 train, ~20 test, 1 exposure
#   R6: ~400 train, ~20 test, 1 exposure
#
# PREDICTOR STRUCTURE (X matrix columns):
#   Col 1:         intercept (always 1)
#   Cols 2-4:      random predictors (price, weekend, season) - vary by restaurant
#   Cols 5-6:      fixed predictors (temp, precip) - same effect across restaurants
#   Cols 7-14:     exposure columns (K_exposure = 8, step functions)
#
# INGARCH STRUCTURE:
#   effective_lags_alpha = c(1,2,3,4,5,6,7,14,21,28,35,42) - 12 outcome lags
#   effective_lags_delta = c(1,2,3,4,5,6,7,14,21,28,35,42) - 12 intensity lags
#   Random lags at positions 1 and 7 (lag values 1 and 7)
#   Fixed lags at all other positions
#
# NOTE ON GAMMA INTERPRETATION:
#   gamma enters the linear predictor: nu = X * beta
#   lambda = exp(nu)
#   So gamma is on the LOG scale. exp(gamma) = rate ratio.
#   e.g., gamma = 0.15 means exp(0.15) = 1.16 = 16% increase in rate
#
# ==============================================================================

library(cmdstanr)
library(dplyr)
library(tibble)

set.seed(99)  # Changed from 42 for diagnostic

# ==============================================================================
# STEP 1: Set True Parameter Values (Ground Truth)
# ==============================================================================

cat("=== STEP 1: Setting True Parameter Values ===\n\n")

# Simulation settings
R <- 12  # Number of restaurants (increased from 6 for diagnostic)

# Restaurant-specific settings (~400 train, ~20 test each)
restaurant_config <- list(
  R1  = list(name = "R1",  N_train = 400, N_test = 20, n_exposures = 1),
  R2  = list(name = "R2",  N_train = 400, N_test = 20, n_exposures = 2),
  R3  = list(name = "R3",  N_train = 400, N_test = 20, n_exposures = 1),
  R4  = list(name = "R4",  N_train = 400, N_test = 20, n_exposures = 2),
  R5  = list(name = "R5",  N_train = 400, N_test = 20, n_exposures = 1),
  R6  = list(name = "R6",  N_train = 400, N_test = 20, n_exposures = 1),
  R7  = list(name = "R7",  N_train = 400, N_test = 20, n_exposures = 1),
  R8  = list(name = "R8",  N_train = 400, N_test = 20, n_exposures = 2),
  R9  = list(name = "R9",  N_train = 400, N_test = 20, n_exposures = 1),
  R10 = list(name = "R10", N_train = 400, N_test = 20, n_exposures = 2),
  R11 = list(name = "R11", N_train = 400, N_test = 20, n_exposures = 1),
  R12 = list(name = "R12", N_train = 400, N_test = 20, n_exposures = 1)
)

# Total exposures
K_exposure <- sum(sapply(restaurant_config, function(x) x$n_exposures))  # Should be 8
M <- 1  # Single transfer function parameter (no slope)

# Predictor dimensions
K_beta_random <- 3  # price, weekend, season (vary by restaurant)
K_beta_fixed <- 2   # temp, precip (same effect across restaurants)

# INGARCH lag structure
effective_lags_alpha <- c(1L, 2L, 3L, 4L, 5L, 6L, 7L, 14L, 21L, 28L, 35L, 42L)
## DIAGNOSTIC: delta lags disabled to test delta-gamma confounding hypothesis
effective_lags_delta <- integer(0)
p_effective <- length(effective_lags_alpha)  # 12
q_effective <- 0L  # DISABLED for diagnostic

# Random lags: positions 1 and 7 in effective_lags (lag values 1 and 7)
idx_alpha_random <- c(1L, 7L)
idx_alpha_fixed <- c(2L, 3L, 4L, 5L, 6L, 8L, 9L, 10L, 11L, 12L)
## DIAGNOSTIC: delta lags disabled
idx_delta_random <- integer(0)
idx_delta_fixed <- integer(0)
K_alpha_random <- length(idx_alpha_random)  # 2
K_alpha_fixed <- length(idx_alpha_fixed)    # 10
K_delta_random <- 0L  # DISABLED for diagnostic
K_delta_fixed <- 0L   # DISABLED for diagnostic

# True parameter values we want to recover
true_params <- list(
  # Exposure effect (PRIMARY INTEREST) - ON LOG SCALE
  # mu_gamma = 0.15 means rate ratio = exp(0.15) = 1.16 (16% increase)
  mu_gamma = 0.15,                # Global mean exposure effect (log scale)
  sigma_gamma_between = 0.08,     # SD across restaurants (log scale)
  sigma_gamma_within = 0.04,      # SD within restaurant for multiple exposures

  # Intercept
  mu_beta_intercept = 3.5,        # Baseline ~exp(3.5) = 33 counts
  sigma_beta_intercept = 0.3,     # Variability across restaurants

  # Dispersion (phi) - on log scale for generation
  mu_phi_log = log(5.0),          # Mean phi ~5
  sigma_phi_log = 0.2,            # SD on log scale

  # Zero-inflation (pi) - on logit scale for generation
  mu_pi_logit = qlogis(0.05),     # ~5% structural zeros
  sigma_pi_logit = 0.2            # SD on logit scale
)

# Random predictor effects (small effects)
true_mu_beta_random <- c(0.05, 0.1, 0.02)   # price, weekend, season
true_sigma_beta_random <- c(0.03, 0.05, 0.01)  # small between-restaurant variation

# Fixed predictor effects (very small)
true_mu_beta_fixed <- c(-0.02, -0.01)  # temp, precip

# INGARCH alpha (outcome lags) - raw scale, before tanh(raw/2)
# raw=0.2 -> tanh(0.1) = 0.0997
true_mu_alpha_random_raw <- c(0.2, 0.1)    # Lag 1 stronger than lag 7
true_sigma_alpha_random <- c(0.08, 0.05)    # Small between-restaurant variability
true_mu_alpha_fixed_raw <- rep(0.0, K_alpha_fixed)  # All fixed lags at zero

# INGARCH delta (latent intensity lags) - raw scale
# raw=0.15 -> tanh(0.075) = 0.0749
true_mu_delta_random_raw <- c(0.15, 0.08)
true_sigma_delta_random <- c(0.06, 0.04)
true_mu_delta_fixed_raw <- rep(0.0, K_delta_fixed)

cat("True parameters:\n")
cat(sprintf("  mu_gamma (global exposure effect, log scale): %.3f  [rate ratio = %.3f]\n",
            true_params$mu_gamma, exp(true_params$mu_gamma)))
cat(sprintf("  sigma_gamma_between: %.3f\n", true_params$sigma_gamma_between))
cat(sprintf("  sigma_gamma_within: %.3f\n", true_params$sigma_gamma_within))
cat(sprintf("  mu_beta_intercept: %.3f (baseline count ~ %.1f)\n",
            true_params$mu_beta_intercept, exp(true_params$mu_beta_intercept)))
cat(sprintf("  sigma_beta_intercept: %.3f\n", true_params$sigma_beta_intercept))
cat(sprintf("  mu_phi_log: %.3f (phi ~ %.1f)\n", true_params$mu_phi_log, exp(true_params$mu_phi_log)))
cat(sprintf("  sigma_phi_log: %.3f\n", true_params$sigma_phi_log))
cat(sprintf("  mu_pi_logit: %.3f (pi ~ %.3f)\n", true_params$mu_pi_logit, plogis(true_params$mu_pi_logit)))
cat(sprintf("  sigma_pi_logit: %.3f\n", true_params$sigma_pi_logit))

cat("\nTrue random predictor effects (mu_beta_random):\n")
pred_names_random <- c("price", "weekend", "season")
for (k in 1:K_beta_random) {
  cat(sprintf("  k=%d (%s): mu=%.4f, sigma=%.4f\n",
              k, pred_names_random[k], true_mu_beta_random[k], true_sigma_beta_random[k]))
}

cat("\nTrue fixed predictor effects (mu_beta_fixed):\n")
pred_names_fixed <- c("temp", "precip")
for (k in 1:K_beta_fixed) {
  cat(sprintf("  k=%d (%s): mu=%.4f\n", k, pred_names_fixed[k], true_mu_beta_fixed[k]))
}

cat("\nTrue INGARCH alpha (raw scale):\n")
cat(sprintf("  mu_alpha_random_raw: %s\n", paste(sprintf("%.3f", true_mu_alpha_random_raw), collapse = ", ")))
cat(sprintf("  sigma_alpha_random: %s\n", paste(sprintf("%.3f", true_sigma_alpha_random), collapse = ", ")))
cat(sprintf("  mu_alpha_fixed_raw: all %.3f (%d values)\n", true_mu_alpha_fixed_raw[1], K_alpha_fixed))

if (q_effective > 0) {
  cat("\nTrue INGARCH delta (raw scale):\n")
  cat(sprintf("  mu_delta_random_raw: %s\n", paste(sprintf("%.3f", true_mu_delta_random_raw), collapse = ", ")))
  cat(sprintf("  sigma_delta_random: %s\n", paste(sprintf("%.3f", true_sigma_delta_random), collapse = ", ")))
  cat(sprintf("  mu_delta_fixed_raw: all %.3f (%d values)\n", true_mu_delta_fixed_raw[1], K_delta_fixed))
} else {
  cat("\nINGARCH delta: DISABLED (q_effective = 0)\n")
}

cat("\nINGARCH stability check:\n")
alpha_1_eff <- tanh(true_mu_alpha_random_raw[1] / 2.0)
alpha_7_eff <- tanh(true_mu_alpha_random_raw[2] / 2.0)
cat(sprintf("  alpha_1 = tanh(%.3f/2) = %.4f\n", true_mu_alpha_random_raw[1], alpha_1_eff))
cat(sprintf("  alpha_7 = tanh(%.3f/2) = %.4f\n", true_mu_alpha_random_raw[2], alpha_7_eff))
if (q_effective > 0) {
  delta_1_eff <- tanh(true_mu_delta_random_raw[1] / 2.0)
  delta_7_eff <- tanh(true_mu_delta_random_raw[2] / 2.0)
  cat(sprintf("  delta_1 = tanh(%.3f/2) = %.4f\n", true_mu_delta_random_raw[1], delta_1_eff))
  cat(sprintf("  delta_7 = tanh(%.3f/2) = %.4f\n", true_mu_delta_random_raw[2], delta_7_eff))
  cat(sprintf("  Sum of active INGARCH coefficients: %.4f (must be << 1 for stability)\n",
              alpha_1_eff + alpha_7_eff + delta_1_eff + delta_7_eff))
} else {
  cat("  delta: DISABLED\n")
  cat(sprintf("  Sum of active INGARCH coefficients: %.4f (alpha only)\n",
              alpha_1_eff + alpha_7_eff))
}

cat("\nRestaurant configuration:\n")
for (r in 1:R) {
  config <- restaurant_config[[r]]
  cat(sprintf("  R%d (%s): %d train, %d test, %d exposure(s)\n",
              r, config$name, config$N_train, config$N_test, config$n_exposures))
}
cat(sprintf("\nTotal exposures: K_exposure = %d\n", K_exposure))

# ==============================================================================
# STEP 2: Generate Hierarchical Parameters (Non-Centered)
# ==============================================================================

cat("\n=== STEP 2: Generating Hierarchical Parameters ===\n\n")

# Sample standard normal deviates (the "z" parameters)
z_beta_intercept <- rnorm(R)
z_beta_random <- matrix(rnorm(K_beta_random * R), K_beta_random, R)
z_phi_log <- rnorm(R)
z_pi_logit <- rnorm(R)
z_eta <- matrix(rnorm(M * R), M, R)  # M x R
z_gamma <- rnorm(K_exposure)
z_alpha_random <- matrix(rnorm(K_alpha_random * R), K_alpha_random, R)
z_delta_random <- matrix(rnorm(K_delta_random * R), K_delta_random, R)

# Compute restaurant-level parameters using non-centered parameterization
beta_intercept_r <- true_params$mu_beta_intercept +
                    true_params$sigma_beta_intercept * z_beta_intercept

# Random predictor betas: matrix[K_beta_random, R]
beta_random_r <- diag(true_sigma_beta_random) %*% z_beta_random +
                 matrix(true_mu_beta_random, K_beta_random, R)

# Dispersion and zero-inflation
phi <- exp(true_params$mu_phi_log + true_params$sigma_phi_log * z_phi_log)
pi_zi <- plogis(true_params$mu_pi_logit + true_params$sigma_pi_logit * z_pi_logit)

cat("Restaurant-level intercepts:\n")
for (r in 1:R) {
  cat(sprintf("  Restaurant %d: beta_intercept = %.3f\n", r, beta_intercept_r[r]))
}

cat("\nRestaurant-level dispersion and zero-inflation:\n")
for (r in 1:R) {
  cat(sprintf("  Restaurant %d: phi = %.3f, pi = %.4f\n", r, phi[r], pi_zi[r]))
}

# --- INGARCH alpha (outcome lags) ---
alpha_raw <- matrix(0, p_effective, R)

alpha_random_raw_r <- diag(true_sigma_alpha_random) %*% z_alpha_random +
                      matrix(true_mu_alpha_random_raw, K_alpha_random, R)
for (r in 1:R) {
  alpha_raw[idx_alpha_random, r] <- alpha_random_raw_r[, r]
}
if (K_alpha_fixed > 0) {
  for (r in 1:R) {
    alpha_raw[idx_alpha_fixed, r] <- true_mu_alpha_fixed_raw
  }
}
# Transform: alpha = tanh(alpha_raw / 2)
alpha <- tanh(alpha_raw / 2.0)

cat("\nAlpha (transformed) for each restaurant (first 4 lags shown):\n")
for (r in 1:R) {
  cat(sprintf("  Restaurant %d: %s ...\n", r,
              paste(sprintf("%.4f", alpha[1:min(4, p_effective), r]), collapse = ", ")))
}

# --- INGARCH delta (latent intensity lags) ---
if (q_effective > 0) {
  delta_raw <- matrix(0, q_effective, R)

  delta_random_raw_r <- diag(true_sigma_delta_random) %*% z_delta_random +
                        matrix(true_mu_delta_random_raw, K_delta_random, R)
  for (r in 1:R) {
    delta_raw[idx_delta_random, r] <- delta_random_raw_r[, r]
  }
  if (K_delta_fixed > 0) {
    for (r in 1:R) {
      delta_raw[idx_delta_fixed, r] <- true_mu_delta_fixed_raw
    }
  }
  delta <- tanh(delta_raw / 2.0)

  cat("\nDelta (transformed) for each restaurant (first 4 lags shown):\n")
  for (r in 1:R) {
    cat(sprintf("  Restaurant %d: %s ...\n", r,
                paste(sprintf("%.4f", delta[1:min(4, q_effective), r]), collapse = ", ")))
  }
} else {
  delta <- matrix(0, 0, R)
  cat("\nDelta: DISABLED (q_effective = 0)\n")
}

# --- Exposure structure ---
expo_to_rest <- integer(K_exposure)
expo_to_param <- rep(1L, K_exposure)  # All exposures use param 1 (M=1)

exposure_idx <- 1
exposures_per_rest <- sapply(restaurant_config, function(x) x$n_exposures)

for (r in 1:R) {
  n_expo <- exposures_per_rest[r]
  for (e in 1:n_expo) {
    expo_to_rest[exposure_idx] <- r
    exposure_idx <- exposure_idx + 1
  }
}

# Level 2: eta (restaurant-level exposure effect)
eta <- matrix(0, M, R)
for (r in 1:R) {
  eta[1, r] <- true_params$mu_gamma +
               true_params$sigma_gamma_between * z_eta[1, r]
}

# Level 1: gamma (per-exposure effect)
gamma_vals <- numeric(K_exposure)
exposure_idx <- 1
for (r in 1:R) {
  n_expo <- exposures_per_rest[r]
  for (e in 1:n_expo) {
    if (n_expo > 1) {
      gamma_vals[exposure_idx] <- eta[1, r] + true_params$sigma_gamma_within * z_gamma[exposure_idx]
    } else {
      gamma_vals[exposure_idx] <- eta[1, r]
    }
    exposure_idx <- exposure_idx + 1
  }
}

cat("\nExposure-to-restaurant mapping and gamma values:\n")
for (k in 1:K_exposure) {
  r <- expo_to_rest[k]
  cat(sprintf("  Exposure %d -> Restaurant %d (%s), param %d: gamma = %.4f\n",
              k, r, restaurant_config[[r]]$name, expo_to_param[k], gamma_vals[k]))
}

cat("\nEta (restaurant-level exposure means):\n")
for (r in 1:R) {
  cat(sprintf("  Restaurant %d: eta = %.4f\n", r, eta[1, r]))
}

# Save the true z values for comparison
true_z_params <- list(
  z_beta_intercept = z_beta_intercept,
  z_beta_random = z_beta_random,
  z_eta = z_eta,
  z_gamma = z_gamma,
  z_phi_log = z_phi_log,
  z_pi_logit = z_pi_logit,
  z_alpha_random = z_alpha_random,
  z_delta_random = z_delta_random
)

# ==============================================================================
# STEP 3: Generate Predictor Data (Design Matrix)
# ==============================================================================

cat("\n=== STEP 3: Generating Design Matrix ===\n\n")

# Total observations
N_train <- sum(sapply(restaurant_config, function(x) x$N_train))
N_test <- sum(sapply(restaurant_config, function(x) x$N_test))

# Design matrix columns:
# 1 intercept + K_beta_random + K_beta_fixed + K_exposure
# = 1 + 3 + 2 + 8 = 14
J <- 1 + K_beta_random + K_beta_fixed + K_exposure

# Column index definitions
idx_intercept <- 1L
idx_beta_random_cols <- 2L:(1L + K_beta_random)       # cols 2, 3, 4
idx_beta_fixed_cols <- (2L + K_beta_random):(1L + K_beta_random + K_beta_fixed)  # cols 5, 6
idx_exposure_cols <- (2L + K_beta_random + K_beta_fixed):(1L + K_beta_random + K_beta_fixed + K_exposure)  # cols 7-14

cat(sprintf("Design matrix column layout (J = %d):\n", J))
cat(sprintf("  idx_intercept: %d\n", idx_intercept))
cat(sprintf("  idx_beta_random: %s (price, weekend, season)\n",
            paste(idx_beta_random_cols, collapse = ", ")))
cat(sprintf("  idx_beta_fixed: %s (temp, precip)\n",
            paste(idx_beta_fixed_cols, collapse = ", ")))
cat(sprintf("  idx_exposure: %s\n",
            paste(idx_exposure_cols, collapse = ", ")))

# Initialize matrices
X_train <- matrix(0, nrow = N_train, ncol = J)
X_test <- matrix(0, nrow = N_test, ncol = J)
y_train <- integer(N_train)
y_test <- integer(N_test)

# Create index mappings
idx_to_rest_train <- integer(N_train)
idx_to_rest_test <- integer(N_test)
train_start_idx <- integer(R)
train_end_idx <- integer(R)
test_start_idx <- integer(R)
test_end_idx <- integer(R)

# Generate random intervention times for each exposure
intervention_times <- list()
exposure_idx <- 1
exposure_start_idx_per_rest <- integer(R)
current_exposure_idx <- 1

for (r in 1:R) {
  exposure_start_idx_per_rest[r] <- current_exposure_idx
  current_exposure_idx <- current_exposure_idx + restaurant_config[[r]]$n_exposures
}

exposure_idx <- 1
for (r in 1:R) {
  n_expo <- restaurant_config[[r]]$n_exposures
  N_train_r <- restaurant_config[[r]]$N_train

  for (e in 1:n_expo) {
    # Random intervention time between 20-80% of training period
    min_time <- round(0.20 * N_train_r)
    max_time <- round(0.80 * N_train_r)
    intervention_times[[exposure_idx]] <- sample(min_time:max_time, 1)
    exposure_idx <- exposure_idx + 1
  }
}

cat("\nIntervention times (randomly generated):\n")
exposure_idx <- 1
for (r in 1:R) {
  n_expo <- restaurant_config[[r]]$n_exposures
  N_train_r <- restaurant_config[[r]]$N_train
  for (e in 1:n_expo) {
    cat(sprintf("  Exposure %d (Restaurant %d): t = %d (%.0f%% of %d training obs)\n",
                exposure_idx, r, intervention_times[[exposure_idx]],
                100 * intervention_times[[exposure_idx]] / N_train_r,
                N_train_r))
    exposure_idx <- exposure_idx + 1
  }
}

# Generate synthetic covariates and fill design matrices
train_offset <- 0
test_offset <- 0

for (r in 1:R) {
  config <- restaurant_config[[r]]
  N_train_r <- config$N_train
  N_test_r <- config$N_test
  n_expo <- config$n_exposures

  # Training data indices
  train_start_idx[r] <- train_offset + 1
  train_end_idx[r] <- train_offset + N_train_r
  train_rows <- (train_start_idx[r]):(train_end_idx[r])
  idx_to_rest_train[train_rows] <- r

  # Test data indices
  test_start_idx[r] <- test_offset + 1
  test_end_idx[r] <- test_offset + N_test_r
  test_rows <- (test_start_idx[r]):(test_end_idx[r])
  idx_to_rest_test[test_rows] <- r

  # --- Col 1: Intercept ---
  X_train[train_rows, 1] <- 1
  X_test[test_rows, 1] <- 1

  # --- Col 2: "price" (continuous, z-scored, random per restaurant) ---
  price_train <- rnorm(N_train_r)
  price_test <- rnorm(N_test_r)
  X_train[train_rows, idx_beta_random_cols[1]] <- price_train
  X_test[test_rows, idx_beta_random_cols[1]] <- price_test

  # --- Col 3: "weekend" (binary, ~2/7 probability) ---
  weekend_train <- rbinom(N_train_r, 1, 2/7)
  weekend_test <- rbinom(N_test_r, 1, 2/7)
  X_train[train_rows, idx_beta_random_cols[2]] <- weekend_train
  X_test[test_rows, idx_beta_random_cols[2]] <- weekend_test

  # --- Col 4: "season" (continuous, z-scored sinusoidal cycle, uncorrelated with step functions) ---
  season_train_raw <- sin(2 * pi * seq(1, N_train_r) / 52)  # ~weekly period approx annual cycle
  season_train <- (season_train_raw - mean(season_train_raw)) / sd(season_train_raw)
  season_test_raw <- sin(2 * pi * seq(N_train_r + 1, N_train_r + N_test_r) / 52)
  season_test <- (season_test_raw - mean(season_train_raw)) / sd(season_train_raw)
  X_train[train_rows, idx_beta_random_cols[3]] <- season_train
  X_test[test_rows, idx_beta_random_cols[3]] <- season_test

  # --- Col 5: "temp" (continuous, z-scored, shared generation) ---
  temp_train <- rnorm(N_train_r)
  temp_test <- rnorm(N_test_r)
  X_train[train_rows, idx_beta_fixed_cols[1]] <- temp_train
  X_test[test_rows, idx_beta_fixed_cols[1]] <- temp_test

  # --- Col 6: "precip" (continuous, z-scored, shared generation) ---
  precip_train <- rnorm(N_train_r)
  precip_test <- rnorm(N_test_r)
  X_train[train_rows, idx_beta_fixed_cols[2]] <- precip_train
  X_test[test_rows, idx_beta_fixed_cols[2]] <- precip_test

  # --- Exposure columns (step functions) ---
  for (e in 1:n_expo) {
    global_expo_idx <- exposure_start_idx_per_rest[r] + e - 1
    exposure_col <- idx_exposure_cols[global_expo_idx]

    # Training: step function at intervention time
    time_points <- 1:N_train_r
    exposure_indicator <- as.integer(time_points >= intervention_times[[global_expo_idx]])
    X_train[train_rows, exposure_col] <- exposure_indicator

    # Test: all post-intervention
    X_test[test_rows, exposure_col] <- 1
  }

  train_offset <- train_end_idx[r]
  test_offset <- test_end_idx[r]
}

cat(sprintf("\nDesign matrix dimensions:\n"))
cat(sprintf("  J (total predictors): %d (1 intercept + %d random + %d fixed + %d exposures)\n",
            J, K_beta_random, K_beta_fixed, K_exposure))
cat(sprintf("  N_train: %d\n", N_train))
cat(sprintf("  N_test: %d\n", N_test))

# ==============================================================================
# STEP 4: Build Full Beta Matrix and Simulate Outcomes (INGARCH)
# ==============================================================================

cat("\n=== STEP 4: Simulating Outcomes (INGARCH Process) ===\n\n")

# Build beta matrix [J, R]
beta <- matrix(0, J, R)

# Intercept
beta[idx_intercept, ] <- beta_intercept_r

# Random predictors
for (r in 1:R) {
  beta[idx_beta_random_cols, r] <- beta_random_r[, r]
}

# Fixed predictors (same across restaurants)
for (r in 1:R) {
  beta[idx_beta_fixed_cols, r] <- true_mu_beta_fixed
}

# Exposures
for (k in 1:K_exposure) {
  r <- expo_to_rest[k]
  beta[idx_exposure_cols[k], r] <- gamma_vals[k]
}

cat("Beta matrix [J, R] constructed.\n")
for (r in 1:R) {
  cat(sprintf("  Restaurant %d: intercept=%.3f, price=%.4f, weekend=%.4f, season=%.4f, temp=%.4f, precip=%.4f\n",
              r, beta[1, r], beta[2, r], beta[3, r], beta[4, r], beta[5, r], beta[6, r]))
}

# Zero-inflated negative binomial generator
rzinb <- function(n, lambda, phi, pi_zi) {
  y <- integer(n)
  is_structural_zero <- rbinom(n, 1, pi_zi)
  for (i in 1:n) {
    if (is_structural_zero[i] == 1) {
      y[i] <- 0
    } else {
      y[i] <- rnbinom(1, size = phi, mu = lambda[i])
    }
  }
  return(y)
}

# --- Training data simulation (sequential INGARCH) ---
cat("\nSimulating training data (sequential INGARCH)...\n")

nu_train <- numeric(N_train)
y_train_sim <- integer(N_train)

for (r in 1:R) {
  r_start <- train_start_idx[r]
  r_end <- train_end_idx[r]
  beta_r <- beta[, r]
  alpha_r <- alpha[, r]
  if (q_effective > 0) delta_r <- delta[, r]

  # Vectorized: covariate part
  nu_train[r_start:r_end] <- as.vector(X_train[r_start:r_end, , drop = FALSE] %*% beta_r)

  # Sequential: INGARCH lags + outcome generation
  for (t in r_start:r_end) {
    # Outcome lags
    for (i in 1:p_effective) {
      lag <- effective_lags_alpha[i]
      if (t - lag >= r_start) {
        nu_train[t] <- nu_train[t] + alpha_r[i] * log1p(y_train_sim[t - lag])
      }
    }

    # Latent intensity lags
    if (q_effective > 0) {
      for (j in 1:q_effective) {
        lag <- effective_lags_delta[j]
        if (t - lag >= r_start) {
          nu_train[t] <- nu_train[t] + delta_r[j] * nu_train[t - lag]
        }
      }
    }

    # Generate outcome
    lambda_t <- exp(nu_train[t])
    y_train_sim[t] <- rzinb(1, lambda_t, phi[r], pi_zi[r])
  }

  cat(sprintf("  Restaurant %d: %d obs simulated, mean=%.2f, zeros=%.1f%%, max=%.0f\n",
              r, r_end - r_start + 1, mean(y_train_sim[r_start:r_end]),
              100 * mean(y_train_sim[r_start:r_end] == 0), max(y_train_sim[r_start:r_end])))
}

# --- Test data simulation ---
cat("\nSimulating test data (sequential INGARCH with training data for early lags)...\n")

nu_test_sim <- numeric(N_test)
y_test_sim <- integer(N_test)

for (r in 1:R) {
  r_test_start <- test_start_idx[r]
  r_test_end <- test_end_idx[r]
  r_train_end <- train_end_idx[r]
  beta_r <- beta[, r]
  alpha_r <- alpha[, r]
  if (q_effective > 0) delta_r <- delta[, r]

  # Vectorized: covariate part
  nu_test_sim[r_test_start:r_test_end] <- as.vector(X_test[r_test_start:r_test_end, , drop = FALSE] %*% beta_r)

  # Sequential INGARCH lags (matching Stan generated quantities logic)
  for (t_test_idx in r_test_start:r_test_end) {
    current_pos_in_test <- t_test_idx - r_test_start + 1

    # Outcome lags
    for (i in 1:p_effective) {
      lag <- effective_lags_alpha[i]
      lag_source_idx_test <- t_test_idx - lag

      if (lag < current_pos_in_test) {
        # Use test data (simulated)
        nu_test_sim[t_test_idx] <- nu_test_sim[t_test_idx] + alpha_r[i] * log1p(y_test_sim[lag_source_idx_test])
      } else {
        # Use training data for lags reaching back before test start
        train_lag_offset <- lag - current_pos_in_test
        lag_source_idx_train <- r_train_end - train_lag_offset
        if (lag_source_idx_train >= train_start_idx[r] && lag_source_idx_train <= r_train_end) {
          nu_test_sim[t_test_idx] <- nu_test_sim[t_test_idx] + alpha_r[i] * log1p(y_train_sim[lag_source_idx_train])
        }
      }
    }

    # Latent intensity lags
    if (q_effective > 0) {
      for (j in 1:q_effective) {
        lag <- effective_lags_delta[j]
        lag_source_idx_test <- t_test_idx - lag

        if (lag < current_pos_in_test) {
          nu_test_sim[t_test_idx] <- nu_test_sim[t_test_idx] + delta_r[j] * nu_test_sim[lag_source_idx_test]
        } else {
          train_lag_offset <- lag - current_pos_in_test
          lag_source_idx_train <- r_train_end - train_lag_offset
          if (lag_source_idx_train >= train_start_idx[r] && lag_source_idx_train <= r_train_end) {
            nu_test_sim[t_test_idx] <- nu_test_sim[t_test_idx] + delta_r[j] * nu_train[lag_source_idx_train]
          }
        }
      }
    }

    # Generate test outcome
    lambda_t <- exp(nu_test_sim[t_test_idx])
    y_test_sim[t_test_idx] <- rzinb(1, lambda_t, phi[r], pi_zi[r])
  }

  cat(sprintf("  Restaurant %d: %d test obs simulated, mean=%.2f, zeros=%.1f%%\n",
              r, r_test_end - r_test_start + 1, mean(y_test_sim[r_test_start:r_test_end]),
              100 * mean(y_test_sim[r_test_start:r_test_end] == 0)))
}

# Overall summary
cat("\nOverall simulated outcome summary (training data):\n")
cat(sprintf("  Total observations: %d\n", N_train))
cat(sprintf("  Zeros: %d (%.1f%%)\n", sum(y_train_sim == 0), 100 * mean(y_train_sim == 0)))
cat(sprintf("  Mean: %.2f, Median: %.0f, Max: %.0f\n",
            mean(y_train_sim), median(y_train_sim), max(y_train_sim)))

cat("\nOverall simulated outcome summary (test data):\n")
cat(sprintf("  Total observations: %d\n", N_test))
cat(sprintf("  Zeros: %d (%.1f%%)\n", sum(y_test_sim == 0), 100 * mean(y_test_sim == 0)))
cat(sprintf("  Mean: %.2f, Median: %.0f, Max: %.0f\n",
            mean(y_test_sim), median(y_test_sim), max(y_test_sim)))

# ==============================================================================
# STEP 5: Prepare Stan Data List
# ==============================================================================

cat("\n=== STEP 5: Preparing Stan Data List ===\n\n")

# Recompute zero indices for simulated data
idx_zeros_sim <- which(y_train_sim == 0)
N_zeros_sim <- length(idx_zeros_sim)

# Hyperprior scales (matching run_ingarch.R defaults)
mu_beta_scale <- 1.0
sigma_beta_scale <- 1.0
mu_gamma_scale <- 1.0
sigma_gamma_between_scale <- 1.0
sigma_gamma_within_scale <- 1.0
mu_alpha_scale <- 1.0
sigma_alpha_scale <- 1.0
mu_delta_scale <- 1.0
sigma_delta_scale <- 1.0
mu_phi_log_scale <- 1.0
sigma_phi_log_scale <- 1.0
mu_pi_logit_scale <- 2.0
sigma_pi_logit_scale <- 1.0

# Scales for non-centered deviates
z_eta_scale <- 1.0
z_gamma_scale <- 1.0
z_beta_scale <- 1.0
z_alpha_scale <- 1.0
z_delta_scale <- 1.0
z_phi_scale <- 1.0
z_pi_scale <- 1.0

# Build the Stan data list
data_list <- list(
  # __ Metadata __
  R = R,
  J = J,
  p_effective = p_effective,
  q_effective = q_effective,
  M = M,

  # Indices for intercept
  idx_intercept = idx_intercept,
  K_beta_random = K_beta_random,
  idx_beta_random = idx_beta_random_cols,
  K_beta_fixed = K_beta_fixed,
  idx_beta_fixed = idx_beta_fixed_cols,

  # Exposure indices
  K_exposure = K_exposure,
  idx_exposure = idx_exposure_cols,
  expo_to_rest = expo_to_rest,
  expo_to_param = expo_to_param,

  # Outcome lag indices
  effective_lags_alpha = effective_lags_alpha,
  K_alpha_random = K_alpha_random,
  idx_alpha_random = idx_alpha_random,
  K_alpha_fixed = K_alpha_fixed,
  idx_alpha_fixed = idx_alpha_fixed,

  # Latent intensity lag indices
  effective_lags_delta = effective_lags_delta,
  K_delta_random = K_delta_random,
  idx_delta_random = idx_delta_random,
  K_delta_fixed = K_delta_fixed,
  idx_delta_fixed = idx_delta_fixed,

  # __ Training Data __
  N_train = N_train,
  X_train = X_train,
  y_train = y_train_sim,
  train_start_idx = train_start_idx,
  train_end_idx = train_end_idx,
  idx_to_rest_train = idx_to_rest_train,

  # __ Test Data __
  N_test = N_test,
  X_test = X_test,
  y_test = y_test_sim,
  test_start_idx = test_start_idx,
  test_end_idx = test_end_idx,
  idx_to_rest_test = idx_to_rest_test,

  # __ Zero Indices __
  N_zeros = N_zeros_sim,
  idx_zeros = if (N_zeros_sim == 0) array(integer(0), dim = 0) else idx_zeros_sim,

  # __ Hyperprior Scales __
  mu_beta_scale = mu_beta_scale,
  sigma_beta_scale = sigma_beta_scale,
  mu_gamma_scale = mu_gamma_scale,
  sigma_gamma_between_scale = sigma_gamma_between_scale,
  sigma_gamma_within_scale = sigma_gamma_within_scale,
  mu_alpha_scale = mu_alpha_scale,
  sigma_alpha_scale = sigma_alpha_scale,
  mu_delta_scale = mu_delta_scale,
  sigma_delta_scale = sigma_delta_scale,
  mu_phi_log_scale = mu_phi_log_scale,
  sigma_phi_log_scale = sigma_phi_log_scale,
  mu_pi_logit_scale = mu_pi_logit_scale,
  sigma_pi_logit_scale = sigma_pi_logit_scale,

  # Scales for non-centered deviates
  z_eta_scale = z_eta_scale,
  z_gamma_scale = z_gamma_scale,
  z_beta_scale = z_beta_scale,
  z_alpha_scale = z_alpha_scale,
  z_delta_scale = z_delta_scale,
  z_phi_scale = z_phi_scale,
  z_pi_scale = z_pi_scale
)

cat("Stan data list created successfully.\n")
cat(sprintf("  R: %d, J: %d, M: %d\n", R, J, M))
cat(sprintf("  K_exposure: %d, K_beta_random: %d, K_beta_fixed: %d\n",
            K_exposure, K_beta_random, K_beta_fixed))
cat(sprintf("  p_effective: %d, q_effective: %d\n", p_effective, q_effective))
cat(sprintf("  K_alpha_random: %d, K_alpha_fixed: %d\n", K_alpha_random, K_alpha_fixed))
cat(sprintf("  K_delta_random: %d, K_delta_fixed: %d\n", K_delta_random, K_delta_fixed))
cat(sprintf("  N_train: %d, N_test: %d\n", N_train, N_test))
cat(sprintf("  N_zeros (simulated): %d (%.1f%%)\n", N_zeros_sim, 100 * N_zeros_sim / N_train))

cat("\nExposure-to-restaurant mapping:\n")
for (k in 1:K_exposure) {
  cat(sprintf("  Exposure %d -> Restaurant %d (%s), param %d\n",
              k, expo_to_rest[k], restaurant_config[[expo_to_rest[k]]]$name, expo_to_param[k]))
}

# ==============================================================================
# STEP 6: Compile and Fit the Stan Model
# ==============================================================================

cat("\n=== STEP 6: Fitting the Stan Model ===\n\n")

# Compile the model
model_path <- here::here("models", "model_multilevel_transfer_zi.stan")
cat(sprintf("Compiling model from: %s\n", model_path))

model <- cmdstan_model(model_path)

# Source init function
source(file.path("model_scripts", "ingarch_scripts", "3_init_ingarch.R"))
init_fn <- function(chain_id = 1) init_ingarch(data_list, chain_id)

cat("Starting MCMC sampling...\n")
cat("Using synthetic data with INGARCH lags + simple covariates...\n\n")

fit <- model$sample(
  data = data_list,
  seed = 123,
  chains = 3,
  parallel_chains = 3,
  iter_warmup = 700,
  iter_sampling = 800,
  init = init_fn,
  adapt_delta = 0.85,
  max_treedepth = 12,
  refresh = 200
)

cat("\nSampling complete.\n")

# ==============================================================================
# STEP 7: Compare Recovered vs True Parameters
# ==============================================================================

cat("\n=== STEP 7: Parameter Recovery Diagnostics ===\n\n")

# Extract summary
summ <- fit$summary()

# Function to print comparison
print_comparison <- function(param_name, true_value, summ_df, transform_label = NULL) {
  row <- summ_df[summ_df$variable == param_name, ]
  if (nrow(row) > 0) {
    est_mean <- row$mean
    est_median <- row$median
    est_q5 <- row$q5
    est_q95 <- row$q95
    rhat <- row$rhat

    # Check if true value is within 90% CI
    in_ci <- true_value >= est_q5 && true_value <= est_q95
    ci_marker <- if (in_ci) "  " else "**"

    if (!is.null(transform_label)) {
      cat(sprintf("  %-30s True: %7.3f | Est: %7.3f (median: %7.3f) | 90%% CI: [%7.3f, %7.3f] | Rhat: %.3f %s [%s]\n",
                  param_name, true_value, est_mean, est_median, est_q5, est_q95, rhat, ci_marker, transform_label))
    } else {
      cat(sprintf("  %-30s True: %7.3f | Est: %7.3f (median: %7.3f) | 90%% CI: [%7.3f, %7.3f] | Rhat: %.3f %s\n",
                  param_name, true_value, est_mean, est_median, est_q5, est_q95, rhat, ci_marker))
    }
  } else {
    cat(sprintf("  %-30s Not found in summary\n", param_name))
  }
}

# Function to check coverage
check_coverage <- function(param_names, true_values, summ_df) {
  n_params <- length(param_names)
  covered <- numeric(n_params)

  for (i in 1:n_params) {
    row <- summ_df[summ_df$variable == param_names[i], ]
    if (nrow(row) > 0) {
      covered[i] <- (true_values[i] >= row$q5 && true_values[i] <= row$q95)
    } else {
      covered[i] <- NA
    }
  }

  return(mean(covered, na.rm = TRUE))
}

# Print comparison for key parameters
cat("Parameter Recovery Results:\n")
cat(paste(rep("=", 130), collapse = ""), "\n")
cat("** indicates true value outside 90% CI\n\n")

# --- Global Parameters - Primary Interest ---
cat("[Global Parameters - Primary Interest (Exposure Effects)]\n")
cat(paste(rep("-", 100), collapse = ""), "\n")
print_comparison("mu_gamma[1]", true_params$mu_gamma, summ,
                 sprintf("rate ratio = %.3f", exp(true_params$mu_gamma)))
print_comparison("sigma_gamma_between[1]", true_params$sigma_gamma_between, summ)
print_comparison("sigma_gamma_within[1]", true_params$sigma_gamma_within, summ)

# --- Global Parameters - Nuisance ---
cat("\n[Global Parameters - Nuisance]\n")
cat(paste(rep("-", 100), collapse = ""), "\n")
print_comparison("mu_beta_intercept", true_params$mu_beta_intercept, summ)
print_comparison("sigma_beta_intercept", true_params$sigma_beta_intercept, summ)
print_comparison("mu_phi_log", true_params$mu_phi_log, summ,
                 sprintf("phi ~ %.1f", exp(true_params$mu_phi_log)))
print_comparison("sigma_phi_log", true_params$sigma_phi_log, summ)
print_comparison("mu_pi_logit", true_params$mu_pi_logit, summ,
                 sprintf("pi ~ %.3f", plogis(true_params$mu_pi_logit)))
print_comparison("sigma_pi_logit", true_params$sigma_pi_logit, summ)

# --- INGARCH Global Parameters ---
cat("\n[INGARCH Global Parameters (Raw Scale)]\n")
cat(paste(rep("-", 100), collapse = ""), "\n")
if (K_alpha_random > 0) {
  for (k in 1:K_alpha_random) {
    print_comparison(sprintf("mu_alpha_random_raw[%d]", k), true_mu_alpha_random_raw[k], summ,
                     sprintf("alpha = tanh(%.3f/2) = %.4f", true_mu_alpha_random_raw[k],
                             tanh(true_mu_alpha_random_raw[k] / 2.0)))
  }
  for (k in 1:K_alpha_random) {
    print_comparison(sprintf("sigma_alpha_random[%d]", k), true_sigma_alpha_random[k], summ)
  }
}
if (K_alpha_fixed > 0) {
  for (k in 1:K_alpha_fixed) {
    print_comparison(sprintf("mu_alpha_fixed_raw[%d]", k), true_mu_alpha_fixed_raw[k], summ)
  }
}
if (K_delta_random > 0) {
  for (k in 1:K_delta_random) {
    print_comparison(sprintf("mu_delta_random_raw[%d]", k), true_mu_delta_random_raw[k], summ,
                     sprintf("delta = tanh(%.3f/2) = %.4f", true_mu_delta_random_raw[k],
                             tanh(true_mu_delta_random_raw[k] / 2.0)))
  }
  for (k in 1:K_delta_random) {
    print_comparison(sprintf("sigma_delta_random[%d]", k), true_sigma_delta_random[k], summ)
  }
}
if (K_delta_fixed > 0) {
  for (k in 1:K_delta_fixed) {
    print_comparison(sprintf("mu_delta_fixed_raw[%d]", k), true_mu_delta_fixed_raw[k], summ)
  }
}

# --- Random Predictor Global Parameters ---
cat("\n[Random Predictor Global Parameters]\n")
cat(paste(rep("-", 100), collapse = ""), "\n")
for (k in 1:K_beta_random) {
  print_comparison(sprintf("mu_beta_random[%d]", k), true_mu_beta_random[k], summ,
                   pred_names_random[k])
}
for (k in 1:K_beta_random) {
  print_comparison(sprintf("sigma_beta_random[%d]", k), true_sigma_beta_random[k], summ,
                   pred_names_random[k])
}

# --- Fixed Predictor Global Parameters ---
cat("\n[Fixed Predictor Global Parameters]\n")
cat(paste(rep("-", 100), collapse = ""), "\n")
for (k in 1:K_beta_fixed) {
  print_comparison(sprintf("mu_beta_fixed[%d]", k), true_mu_beta_fixed[k], summ,
                   pred_names_fixed[k])
}

# --- Restaurant-Level Parameters ---
cat("\n[Restaurant-Level Parameters]\n")
cat(paste(rep("-", 100), collapse = ""), "\n")
for (r in 1:R) {
  cat(sprintf("\n  Restaurant %d:\n", r))
  print_comparison(sprintf("phi[%d]", r), phi[r], summ)
  print_comparison(sprintf("pi[%d]", r), pi_zi[r], summ)
}

# --- Per-Exposure Gamma Values ---
cat("\n[Per-Exposure Gamma Values]\n")
cat(paste(rep("-", 100), collapse = ""), "\n")
for (k in 1:K_exposure) {
  r <- expo_to_rest[k]
  param_name <- sprintf("beta[%d,%d]", idx_exposure_cols[k], r)
  cat(sprintf("  Exposure %d (Rest %d, param %d):\n", k, r, expo_to_param[k]))

  row <- summ[summ$variable == param_name, ]
  if (nrow(row) > 0) {
    in_ci <- gamma_vals[k] >= row$q5 && gamma_vals[k] <= row$q95
    ci_marker <- if (in_ci) "  " else "**"
    cat(sprintf("    %-28s True: %7.4f | Est: %7.4f | 90%% CI: [%7.4f, %7.4f] %s\n",
                param_name, gamma_vals[k], row$mean, row$q5, row$q95, ci_marker))
  } else {
    cat(sprintf("    %-28s Not found in summary\n", param_name))
  }

  # Also check z_gamma for restaurants with multiple exposures
  if (restaurant_config[[r]]$n_exposures > 1) {
    print_comparison(sprintf("z_gamma[%d]", k), true_z_params$z_gamma[k], summ)
  }
}

# ==============================================================================
# STEP 8: Model Diagnostics
# ==============================================================================

cat("\n=== STEP 8: Model Diagnostics ===\n\n")

cat("[Sampling Diagnostics]\n")
cat(paste(rep("=", 80), collapse = ""), "\n")
diag <- fit$diagnostic_summary()
cat(sprintf("  Divergences: %d\n", sum(diag$num_divergent)))
cat(sprintf("  Max treedepth hits: %d\n", sum(diag$num_max_treedepth)))

# Check Rhat values
rhat_vals <- summ$rhat[!is.na(summ$rhat)]
cat(sprintf("  Max Rhat: %.3f\n", max(rhat_vals)))
cat(sprintf("  Parameters with Rhat > 1.01: %d\n", sum(rhat_vals > 1.01)))
cat(sprintf("  Parameters with Rhat > 1.05: %d\n", sum(rhat_vals > 1.05)))
cat(sprintf("  Parameters with Rhat > 1.10: %d\n", sum(rhat_vals > 1.10)))

# ESS diagnostics
ess_bulk <- summ$ess_bulk[!is.na(summ$ess_bulk)]
ess_tail <- summ$ess_tail[!is.na(summ$ess_tail)]
cat(sprintf("  Min ESS bulk: %.0f\n", min(ess_bulk)))
cat(sprintf("  Min ESS tail: %.0f\n", min(ess_tail)))
cat(sprintf("  Median ESS bulk: %.0f\n", median(ess_bulk)))
cat(sprintf("  Median ESS tail: %.0f\n", median(ess_tail)))

# List worst Rhat parameters
cat("\nWorst Rhat parameters (top 10):\n")
worst_rhat <- summ %>%
  filter(!is.na(rhat)) %>%
  arrange(desc(rhat)) %>%
  head(10)
for (i in 1:nrow(worst_rhat)) {
  cat(sprintf("  %-30s Rhat: %.4f, ESS_bulk: %.0f, ESS_tail: %.0f\n",
              worst_rhat$variable[i], worst_rhat$rhat[i],
              worst_rhat$ess_bulk[i], worst_rhat$ess_tail[i]))
}

# ==============================================================================
# STEP 9: Coverage Analysis
# ==============================================================================

cat("\n=== STEP 9: Coverage Analysis ===\n\n")

# --- Global exposure parameters ---
exposure_params <- c("mu_gamma[1]", "sigma_gamma_between[1]", "sigma_gamma_within[1]")
exposure_true <- c(true_params$mu_gamma, true_params$sigma_gamma_between, true_params$sigma_gamma_within)
exposure_coverage <- check_coverage(exposure_params, exposure_true, summ)
cat(sprintf("Exposure parameter 90%% CI coverage: %.1f%% (%d params, expected ~90%%)\n",
            100 * exposure_coverage, length(exposure_params)))

# --- Global nuisance parameters ---
nuisance_params <- c("mu_beta_intercept", "sigma_beta_intercept",
                     "mu_phi_log", "sigma_phi_log",
                     "mu_pi_logit", "sigma_pi_logit")
nuisance_true <- c(true_params$mu_beta_intercept, true_params$sigma_beta_intercept,
                   true_params$mu_phi_log, true_params$sigma_phi_log,
                   true_params$mu_pi_logit, true_params$sigma_pi_logit)
nuisance_coverage <- check_coverage(nuisance_params, nuisance_true, summ)
cat(sprintf("Nuisance parameter 90%% CI coverage: %.1f%% (%d params, expected ~90%%)\n",
            100 * nuisance_coverage, length(nuisance_params)))

# --- INGARCH global parameters ---
ingarch_params <- c()
ingarch_true <- c()
if (K_alpha_random > 0) {
  for (k in 1:K_alpha_random) {
    ingarch_params <- c(ingarch_params, sprintf("mu_alpha_random_raw[%d]", k), sprintf("sigma_alpha_random[%d]", k))
    ingarch_true <- c(ingarch_true, true_mu_alpha_random_raw[k], true_sigma_alpha_random[k])
  }
}
if (K_alpha_fixed > 0) {
  for (k in 1:K_alpha_fixed) {
    ingarch_params <- c(ingarch_params, sprintf("mu_alpha_fixed_raw[%d]", k))
    ingarch_true <- c(ingarch_true, true_mu_alpha_fixed_raw[k])
  }
}
if (K_delta_random > 0) {
  for (k in 1:K_delta_random) {
    ingarch_params <- c(ingarch_params, sprintf("mu_delta_random_raw[%d]", k), sprintf("sigma_delta_random[%d]", k))
    ingarch_true <- c(ingarch_true, true_mu_delta_random_raw[k], true_sigma_delta_random[k])
  }
}
if (K_delta_fixed > 0) {
  for (k in 1:K_delta_fixed) {
    ingarch_params <- c(ingarch_params, sprintf("mu_delta_fixed_raw[%d]", k))
    ingarch_true <- c(ingarch_true, true_mu_delta_fixed_raw[k])
  }
}
if (length(ingarch_params) > 0) {
  ingarch_coverage <- check_coverage(ingarch_params, ingarch_true, summ)
  cat(sprintf("INGARCH global parameter 90%% CI coverage: %.1f%% (%d params, expected ~90%%)\n",
              100 * ingarch_coverage, length(ingarch_params)))
}

# --- Predictor parameters ---
predictor_params <- c()
predictor_true <- c()
for (k in 1:K_beta_random) {
  predictor_params <- c(predictor_params, sprintf("mu_beta_random[%d]", k), sprintf("sigma_beta_random[%d]", k))
  predictor_true <- c(predictor_true, true_mu_beta_random[k], true_sigma_beta_random[k])
}
for (k in 1:K_beta_fixed) {
  predictor_params <- c(predictor_params, sprintf("mu_beta_fixed[%d]", k))
  predictor_true <- c(predictor_true, true_mu_beta_fixed[k])
}
predictor_coverage <- check_coverage(predictor_params, predictor_true, summ)
cat(sprintf("Predictor parameter 90%% CI coverage: %.1f%% (%d params, expected ~90%%)\n",
            100 * predictor_coverage, length(predictor_params)))

# --- Restaurant-level parameters ---
rest_params <- c()
rest_true <- c()
for (r in 1:R) {
  rest_params <- c(rest_params, sprintf("phi[%d]", r), sprintf("pi[%d]", r))
  rest_true <- c(rest_true, phi[r], pi_zi[r])
}
rest_coverage <- check_coverage(rest_params, rest_true, summ)
cat(sprintf("Restaurant-level 90%% CI coverage: %.1f%% (%d params, expected ~90%%)\n",
            100 * rest_coverage, length(rest_params)))

# --- All global parameters combined ---
all_global_params <- c(exposure_params, nuisance_params, ingarch_params, predictor_params)
all_global_true <- c(exposure_true, nuisance_true, ingarch_true, predictor_true)
all_global_coverage <- check_coverage(all_global_params, all_global_true, summ)
cat(sprintf("\nOverall global parameter 90%% CI coverage: %.1f%% (%d params, expected ~90%%)\n",
            100 * all_global_coverage, length(all_global_params)))

# ==============================================================================
# STEP 10: Save Results
# ==============================================================================

cat("\n=== STEP 10: Saving Results ===\n\n")

results <- list(
  # Configuration
  restaurant_config = restaurant_config,

  # True parameters
  true_params = true_params,
  true_predictor_params = list(
    mu_beta_random = true_mu_beta_random,
    sigma_beta_random = true_sigma_beta_random,
    mu_beta_fixed = true_mu_beta_fixed
  ),
  true_ingarch_params = list(
    mu_alpha_random_raw = true_mu_alpha_random_raw,
    sigma_alpha_random = true_sigma_alpha_random,
    mu_alpha_fixed_raw = true_mu_alpha_fixed_raw,
    mu_delta_random_raw = true_mu_delta_random_raw,
    sigma_delta_random = true_sigma_delta_random,
    mu_delta_fixed_raw = true_mu_delta_fixed_raw
  ),

  # True z parameters
  true_z_params = true_z_params,

  # True derived parameters
  true_derived = list(
    beta = beta,
    alpha = alpha,
    delta = delta,
    eta = eta,
    gamma = gamma_vals,
    phi = phi,
    pi = pi_zi,
    expo_to_rest = expo_to_rest,
    expo_to_param = expo_to_param,
    intervention_times = intervention_times
  ),

  # Data
  data_list = data_list,

  # Fit
  fit = fit,
  summary = summ,

  # Dimensions
  dimensions = list(
    R = R, J = J, M = M,
    K_exposure = K_exposure,
    K_beta_random = K_beta_random,
    K_beta_fixed = K_beta_fixed,
    K_alpha_random = K_alpha_random,
    K_alpha_fixed = K_alpha_fixed,
    K_delta_random = K_delta_random,
    K_delta_fixed = K_delta_fixed,
    p_effective = p_effective,
    q_effective = q_effective
  ),

  # Coverage
  coverage = list(
    exposure = exposure_coverage,
    nuisance = nuisance_coverage,
    ingarch = if (length(ingarch_params) > 0) ingarch_coverage else NA,
    predictor = predictor_coverage,
    restaurant = rest_coverage,
    overall_global = all_global_coverage
  )
)

output_path <- here::here("model_scripts", "simulations", "simulate_total_results.rds")
saveRDS(results, output_path)
cat(sprintf("Results saved to: %s\n", output_path))

cat("\n=== Simulation Complete ===\n")
cat("\nKey findings summary:\n")
cat(sprintf("  - mu_gamma[1] (exposure effect): true = %.3f [rate ratio = %.3f], check 90%% CI above\n",
            true_params$mu_gamma, exp(true_params$mu_gamma)))
cat(sprintf("  - Total data points: %d (train) + %d (test) = %d\n", N_train, N_test, N_train + N_test))
cat(sprintf("  - Predictors: %d random + %d fixed + %d exposures = %d total (+ intercept)\n",
            K_beta_random, K_beta_fixed, K_exposure, K_beta_random + K_beta_fixed + K_exposure))
cat(sprintf("  - INGARCH lags: p_effective = %d, q_effective = %d\n", p_effective, q_effective))
cat(sprintf("  - Divergences: %d\n", sum(diag$num_divergent)))
cat(sprintf("  - Max Rhat: %.3f\n", max(rhat_vals)))
cat(sprintf("  - Overall global 90%% coverage: %.1f%%\n", 100 * all_global_coverage))

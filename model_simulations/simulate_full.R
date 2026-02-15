# ==============================================================================
# Full Simulation Script for Parameter Recovery
# ==============================================================================
#
# This script generates synthetic data from the model's generative process
# (model_multilevel_transfer_opt.stan) and fits the model to recover parameters.
#
# FULL VERSION (matches tier 1 restaurant structure):
#   - 6 restaurants (R=6)
#   - 8 total exposures (K_exposure=8): 4 restaurants have 1 exposure, 2 have 2 exposures
#   - Realistic observation counts: ~350 to ~2750 per restaurant
#   - M=1 transfer function parameter
#   - No predictors (matching finalized_simple models)
#   - No INGARCH lags: p_effective=0, q_effective=0
#   - 95/5 train/test split
#
# RESTAURANT STRUCTURE:
#   R1 (VLZX7K2M9QD4T):        ~350 obs,  1 exposure
#   R2 (SRQS8F7JWA9MZ): ~1600 obs, 2 exposures
#   R3 (2HRX9P6HKXA8V): ~1700 obs, 1 exposure
#   R4 (JHDN7CF1C03X5): ~1700 obs, 2 exposures
#   R5 (L69HYJ4Y3TR91): ~350 obs,  1 exposure
#   R6 (ED5J990H5VAZT): ~2750 obs, 1 exposure
#
# NOTE ON GAMMA INTERPRETATION:
#   gamma enters the linear predictor: nu = X * beta
#   lambda = exp(nu)
#   So gamma is on the LOG scale. exp(gamma) = rate ratio.
#   e.g., gamma = 0.2 means exp(0.2) = 1.22 = 22% increase in rate
#
# NOTE ON SIGMA_GAMMA_WITHIN:
#   This parameter captures variability WITHIN a restaurant when that
#   restaurant has multiple exposures. In this simulation, R2 and R4
#   have 2 exposures each, so sigma_gamma_within matters for them.
#
# ==============================================================================

library(cmdstanr)
library(dplyr)
library(tibble)

set.seed(42)

# ==============================================================================
# STEP 1: Set True Parameter Values (Ground Truth)
# ==============================================================================

cat("=== STEP 1: Setting True Parameter Values ===\n\n")

# Simulation settings (matching tier 1 restaurant structure)
R <- 6  # Number of restaurants

# Restaurant-specific settings
# Using rounded values close to actual data
restaurant_config <- list(
  R1 = list(name = "VLZX7K2M9QD4T",        N_total = 350,  n_exposures = 1),
  R2 = list(name = "SRQS8F7JWA9MZ", N_total = 1600, n_exposures = 2),
  R3 = list(name = "2HRX9P6HKXA8V", N_total = 1700, n_exposures = 1),
  R4 = list(name = "JHDN7CF1C03X5", N_total = 1700, n_exposures = 2),
  R5 = list(name = "L69HYJ4Y3TR91", N_total = 350,  n_exposures = 1),
  R6 = list(name = "ED5J990H5VAZT", N_total = 2750, n_exposures = 1)
)

# Calculate 95/5 train/test split for each restaurant
for (r in 1:R) {
  config <- restaurant_config[[r]]
  restaurant_config[[r]]$N_train <- round(config$N_total * 0.95)
  restaurant_config[[r]]$N_test  <- config$N_total - restaurant_config[[r]]$N_train
}

# Total exposures
K_exposure <- sum(sapply(restaurant_config, function(x) x$n_exposures))  # Should be 8
M <- 1  # Single parameter in transfer function

# True parameter values we want to recover
true_params <- list(
  # Exposure effect (primary interest) - ON LOG SCALE
  # mu_gamma = 0.2 means rate ratio = exp(0.2) = 1.22 (22% increase)
  mu_gamma = 0.2,               # Global mean exposure effect (log scale)
  sigma_gamma_between = 0.1,    # SD across restaurants (log scale)
  sigma_gamma_within = 0.05,    # SD within restaurant for multiple exposures

  # Intercept
  mu_beta_intercept = 2.0,      # Baseline ~exp(2) = 7 counts
  sigma_beta_intercept = 0.3,   # Variability across restaurants

  # Dispersion (phi) - on log scale for generation
  mu_phi_log = log(5.0),        # Mean phi ~5
  sigma_phi_log = 0.2,          # SD on log scale

  # Zero-inflation (pi) - on logit scale for generation
  # logit(0.08) = log(0.08/0.92) ~ -2.44
  mu_pi_logit = qlogis(0.08),   # ~8% structural zeros
  sigma_pi_logit = 0.3          # SD on logit scale
)

cat("True parameters:\n")
cat(sprintf("  mu_gamma (global exposure effect, log scale): %.3f  [rate ratio = %.3f]\n",
            true_params$mu_gamma, exp(true_params$mu_gamma)))
cat(sprintf("  sigma_gamma_between: %.3f\n", true_params$sigma_gamma_between))
cat(sprintf("  sigma_gamma_within: %.3f\n", true_params$sigma_gamma_within))
cat(sprintf("  mu_beta_intercept: %.3f\n", true_params$mu_beta_intercept))
cat(sprintf("  sigma_beta_intercept: %.3f\n", true_params$sigma_beta_intercept))
cat(sprintf("  mu_phi_log: %.3f (phi ~ %.1f)\n", true_params$mu_phi_log, exp(true_params$mu_phi_log)))
cat(sprintf("  sigma_phi_log: %.3f\n", true_params$sigma_phi_log))
cat(sprintf("  mu_pi_logit: %.3f (pi ~ %.3f)\n", true_params$mu_pi_logit, plogis(true_params$mu_pi_logit)))
cat(sprintf("  sigma_pi_logit: %.3f\n", true_params$sigma_pi_logit))

cat("\nRestaurant configuration:\n")
for (r in 1:R) {
  config <- restaurant_config[[r]]
  cat(sprintf("  R%d (%s): %d train, %d test, %d exposure(s)\n",
              r, config$name, config$N_train, config$N_test, config$n_exposures))
}
cat(sprintf("\nTotal exposures: K_exposure = %d\n", K_exposure))

# ==============================================================================
# STEP 2: Generate Parameters Using Hierarchical Structure
# ==============================================================================

cat("\n=== STEP 2: Generating Hierarchical Parameters ===\n\n")

# Sample standard normal deviates (the "z" parameters)
z_beta_intercept <- rnorm(R)   # Per-restaurant intercept deviates
z_eta <- rnorm(R)              # Per-restaurant exposure effect deviates (M=1, so just a vector)
z_phi_log <- rnorm(R)          # Per-restaurant dispersion deviates
z_pi_logit <- rnorm(R)         # Per-restaurant zero-inflation deviates

# Generate z_gamma for each exposure (K_exposure total)
z_gamma <- rnorm(K_exposure)

# Compute restaurant-level parameters using non-centered parameterization
beta_intercept <- true_params$mu_beta_intercept +
                  true_params$sigma_beta_intercept * z_beta_intercept

# Compute eta: per-restaurant mean exposure effect (Level 2)
eta <- true_params$mu_gamma +
       true_params$sigma_gamma_between * z_eta

# Compute gamma: per-exposure effect (Level 1)
# gamma[k] = eta[r] + sigma_gamma_within * z_gamma[k] if restaurant r has >1 exposure
# gamma[k] = eta[r] if restaurant r has only 1 exposure
gamma <- numeric(K_exposure)

# Build exposure-to-restaurant mapping
expo_to_rest <- integer(K_exposure)
expo_to_param <- rep(1L, K_exposure)  # All exposures use param 1 (M=1)

# Track which exposure belongs to which restaurant
exposure_idx <- 1
exposures_per_rest <- sapply(restaurant_config, function(x) x$n_exposures)

for (r in 1:R) {
  n_expo <- exposures_per_rest[r]
  for (e in 1:n_expo) {
    expo_to_rest[exposure_idx] <- r

    if (n_expo > 1) {
      # Multiple exposures: add within-restaurant variability
      gamma[exposure_idx] <- eta[r] + true_params$sigma_gamma_within * z_gamma[exposure_idx]
    } else {
      # Single exposure: gamma equals eta
      gamma[exposure_idx] <- eta[r]
    }

    exposure_idx <- exposure_idx + 1
  }
}

# Dispersion and zero-inflation
phi <- exp(true_params$mu_phi_log + true_params$sigma_phi_log * z_phi_log)
pi_zi <- plogis(true_params$mu_pi_logit + true_params$sigma_pi_logit * z_pi_logit)

cat("Restaurant-level parameters:\n")
for (r in 1:R) {
  cat(sprintf("  Restaurant %d (%s):\n", r, restaurant_config[[r]]$name))
  cat(sprintf("    beta_intercept: %.3f\n", beta_intercept[r]))
  cat(sprintf("    eta (restaurant-level exposure effect): %.3f\n", eta[r]))
  cat(sprintf("    phi (dispersion): %.3f\n", phi[r]))
  cat(sprintf("    pi (zero-inflation prob): %.3f\n", pi_zi[r]))
}

cat("\nPer-exposure gamma values:\n")
for (k in 1:K_exposure) {
  r <- expo_to_rest[k]
  cat(sprintf("  Exposure %d (Restaurant %d - %s): gamma = %.3f\n",
              k, r, restaurant_config[[r]]$name, gamma[k]))
}

# Save the true z values for comparison
true_z_params <- list(
  z_beta_intercept = z_beta_intercept,
  z_eta = z_eta,
  z_gamma = z_gamma,
  z_phi_log = z_phi_log,
  z_pi_logit = z_pi_logit
)

# ==============================================================================
# STEP 3: Generate Predictor Data (Design Matrix)
# ==============================================================================

cat("\n=== STEP 3: Generating Design Matrix ===\n\n")

# Total observations
N_train <- sum(sapply(restaurant_config, function(x) x$N_train))
N_test <- sum(sapply(restaurant_config, function(x) x$N_test))

# Initialize matrices
# J = 1 + K_exposure columns: intercept (col 1), then one column per exposure
J <- 1 + K_exposure

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
# Interventions occur between 20-80% through the time series
intervention_times <- list()
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

cat("Intervention times (randomly generated):\n")
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

# Generate data for each restaurant
train_offset <- 0
test_offset <- 0
exposure_start_idx_per_rest <- integer(R)  # Track which exposure index each restaurant starts at

current_exposure_idx <- 1
for (r in 1:R) {
  exposure_start_idx_per_rest[r] <- current_exposure_idx
  current_exposure_idx <- current_exposure_idx + restaurant_config[[r]]$n_exposures
}

for (r in 1:R) {
  config <- restaurant_config[[r]]
  N_train_r <- config$N_train
  N_test_r <- config$N_test
  n_expo <- config$n_exposures

  # Training data indices
  train_start_idx[r] <- train_offset + 1
  train_end_idx[r] <- train_offset + N_train_r
  train_rows <- (train_start_idx[r]):(train_end_idx[r])

  # Fill in design matrix for training
  X_train[train_rows, 1] <- 1  # Intercept

  # Exposure columns for this restaurant
  for (e in 1:n_expo) {
    global_expo_idx <- exposure_start_idx_per_rest[r] + e - 1
    exposure_col <- 1 + global_expo_idx  # Column in design matrix

    # Step function: 0 before intervention, 1 after
    time_points <- 1:N_train_r
    exposure_indicator <- as.integer(time_points >= intervention_times[[global_expo_idx]])
    X_train[train_rows, exposure_col] <- exposure_indicator
  }

  idx_to_rest_train[train_rows] <- r

  # Test data indices
  test_start_idx[r] <- test_offset + 1
  test_end_idx[r] <- test_offset + N_test_r
  test_rows <- (test_start_idx[r]):(test_end_idx[r])

  # Fill in design matrix for testing (all post-intervention)
  X_test[test_rows, 1] <- 1  # Intercept

  for (e in 1:n_expo) {
    global_expo_idx <- exposure_start_idx_per_rest[r] + e - 1
    exposure_col <- 1 + global_expo_idx
    X_test[test_rows, exposure_col] <- 1  # All test data is post-intervention
  }

  idx_to_rest_test[test_rows] <- r

  train_offset <- train_end_idx[r]
  test_offset <- test_end_idx[r]
}

cat(sprintf("\nDesign matrix dimensions:\n"))
cat(sprintf("  J (total predictors): %d (1 intercept + %d exposures)\n", J, K_exposure))
cat(sprintf("  N_train: %d\n", N_train))
cat(sprintf("  N_test: %d\n", N_test))

# ==============================================================================
# STEP 4: Generate Outcomes
# ==============================================================================

cat("\n=== STEP 4: Generating Outcomes ===\n\n")

# Function to generate zero-inflated negative binomial
rzinb <- function(n, lambda, phi, pi_zi) {
  # With probability pi_zi, return 0 (structural zero)
  # Otherwise, draw from NegBinom(lambda, phi)
  y <- integer(n)
  is_structural_zero <- rbinom(n, 1, pi_zi)
  for (i in 1:n) {
    if (is_structural_zero[i] == 1) {
      y[i] <- 0
    } else {
      # rnbinom uses (size=phi, mu=lambda) parameterization
      y[i] <- rnbinom(1, size = phi, mu = lambda[i])
    }
  }
  return(y)
}

# Generate training outcomes
for (r in 1:R) {
  train_rows <- (train_start_idx[r]):(train_end_idx[r])
  n_expo <- restaurant_config[[r]]$n_exposures

  # Build beta vector for this restaurant
  beta_r <- rep(0, J)
  beta_r[1] <- beta_intercept[r]  # Intercept

  # Add exposure effects
  for (e in 1:n_expo) {
    global_expo_idx <- exposure_start_idx_per_rest[r] + e - 1
    exposure_col <- 1 + global_expo_idx
    beta_r[exposure_col] <- gamma[global_expo_idx]
  }

  # Compute linear predictor and lambda
  nu_r <- X_train[train_rows, , drop = FALSE] %*% beta_r
  lambda_r <- exp(as.vector(nu_r))

  # Generate outcomes
  y_train[train_rows] <- rzinb(length(train_rows), lambda_r, phi[r], pi_zi[r])
}

# Generate test outcomes
for (r in 1:R) {
  test_rows <- (test_start_idx[r]):(test_end_idx[r])
  n_expo <- restaurant_config[[r]]$n_exposures

  # Build beta vector for this restaurant
  beta_r <- rep(0, J)
  beta_r[1] <- beta_intercept[r]

  for (e in 1:n_expo) {
    global_expo_idx <- exposure_start_idx_per_rest[r] + e - 1
    exposure_col <- 1 + global_expo_idx
    beta_r[exposure_col] <- gamma[global_expo_idx]
  }

  # Compute linear predictor and lambda
  nu_r <- X_test[test_rows, , drop = FALSE] %*% beta_r
  lambda_r <- exp(as.vector(nu_r))

  # Generate outcomes
  y_test[test_rows] <- rzinb(length(test_rows), lambda_r, phi[r], pi_zi[r])
}

# Summary statistics
cat("Outcome summary (training data):\n")
cat(sprintf("  Total observations: %d\n", N_train))
cat(sprintf("  Zeros: %d (%.1f%%)\n", sum(y_train == 0), 100 * mean(y_train == 0)))
cat(sprintf("  Mean: %.2f, Median: %.0f, Max: %d\n", mean(y_train), median(y_train), max(y_train)))

cat("\nPer-restaurant training summary:\n")
for (r in 1:R) {
  train_rows <- (train_start_idx[r]):(train_end_idx[r])
  y_r <- y_train[train_rows]
  cat(sprintf("  R%d (%s): n=%d, mean=%.2f, zeros=%.1f%%\n",
              r, restaurant_config[[r]]$name, length(y_r), mean(y_r), 100 * mean(y_r == 0)))
}

# ==============================================================================
# STEP 5: Prepare Stan Data List
# ==============================================================================

cat("\n=== STEP 5: Preparing Stan Data List ===\n\n")

# Index definitions
idx_intercept <- 1                    # Column 1 is intercept
idx_exposure <- 2:(1 + K_exposure)    # Columns 2, 3, ..., 9 are exposures

# No random/fixed beta predictors (only intercept)
K_beta_random <- 0
idx_beta_random <- integer(0)
K_beta_fixed <- 0
idx_beta_fixed <- integer(0)

# No INGARCH lags
p_effective <- 0
q_effective <- 0
effective_lags_alpha <- integer(0)
effective_lags_delta <- integer(0)
K_alpha_random <- 0
idx_alpha_random <- integer(0)
K_alpha_fixed <- 0
idx_alpha_fixed <- integer(0)
K_delta_random <- 0
idx_delta_random <- integer(0)
K_delta_fixed <- 0
idx_delta_fixed <- integer(0)

# Find zero indices for vectorized zero-inflation computation
idx_zeros <- which(y_train == 0)
N_zeros <- length(idx_zeros)

# Hyperprior scales (weakly informative)
mu_beta_scale <- 2.0
sigma_beta_scale <- 1.0
mu_gamma_scale <- 1.0
sigma_gamma_between_scale <- 0.5
sigma_gamma_within_scale <- 0.5
mu_alpha_scale <- 1.0
sigma_alpha_scale <- 1.0
mu_delta_scale <- 1.0
sigma_delta_scale <- 1.0
mu_phi_log_scale <- 2.0
sigma_phi_log_scale <- 1.0
mu_pi_logit_scale <- 2.0
sigma_pi_logit_scale <- 1.0

# Scales for non-centered deviates (set > 1 for less informative priors)
# Want restaurant-specific effects to range like mu_gamma: exp(eta) in [0.1, 7]
# Using large scale makes z_eta nearly uninformative - sigma_between controls variability
z_eta_scale <- 10.0     # Between-restaurant exposure deviates (nearly uninformative)
z_gamma_scale <- 10.0   # Within-restaurant exposure deviates (nearly uninformative)
z_beta_scale <- 10.0    # Restaurant-specific covariate deviates
z_ingarch_scale <- 10.0 # INGARCH parameter deviates
z_pi_scale <- 10.0      # Zero-inflation deviates

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
  idx_beta_random = if (K_beta_random == 0) array(integer(0), dim = 0) else idx_beta_random,
  K_beta_fixed = K_beta_fixed,
  idx_beta_fixed = if (K_beta_fixed == 0) array(integer(0), dim = 0) else idx_beta_fixed,

  # Exposure indices
  K_exposure = K_exposure,
  idx_exposure = idx_exposure,
  expo_to_rest = expo_to_rest,
  expo_to_param = expo_to_param,

  # Outcome lag indices (empty for no INGARCH)
  effective_lags_alpha = if (p_effective == 0) array(integer(0), dim = 0) else effective_lags_alpha,
  K_alpha_random = K_alpha_random,
  idx_alpha_random = if (K_alpha_random == 0) array(integer(0), dim = 0) else idx_alpha_random,
  K_alpha_fixed = K_alpha_fixed,
  idx_alpha_fixed = if (K_alpha_fixed == 0) array(integer(0), dim = 0) else idx_alpha_fixed,

  # Latent intensity indices (empty for no INGARCH)
  effective_lags_delta = if (q_effective == 0) array(integer(0), dim = 0) else effective_lags_delta,
  K_delta_random = K_delta_random,
  idx_delta_random = if (K_delta_random == 0) array(integer(0), dim = 0) else idx_delta_random,
  K_delta_fixed = K_delta_fixed,
  idx_delta_fixed = if (K_delta_fixed == 0) array(integer(0), dim = 0) else idx_delta_fixed,

  # __ Training Data __
  N_train = N_train,
  X_train = X_train,
  y_train = y_train,
  train_start_idx = train_start_idx,
  train_end_idx = train_end_idx,
  idx_to_rest_train = idx_to_rest_train,

  # __ Test Data __
  N_test = N_test,
  X_test = X_test,
  y_test = y_test,
  test_start_idx = test_start_idx,
  test_end_idx = test_end_idx,
  idx_to_rest_test = idx_to_rest_test,

  # __ Zero Indices __
  N_zeros = N_zeros,
  idx_zeros = if (N_zeros == 0) array(integer(0), dim = 0) else idx_zeros,

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
  z_ingarch_scale = z_ingarch_scale,
  z_pi_scale = z_pi_scale
)

cat("Stan data list created successfully.\n")
cat(sprintf("  R (restaurants): %d\n", R))
cat(sprintf("  J (predictors): %d\n", J))
cat(sprintf("  K_exposure: %d\n", K_exposure))
cat(sprintf("  M (transfer function params): %d\n", M))
cat(sprintf("  N_train: %d\n", N_train))
cat(sprintf("  N_test: %d\n", N_test))
cat(sprintf("  N_zeros: %d (%.1f%%)\n", N_zeros, 100 * N_zeros / N_train))

cat("\nExposure-to-restaurant mapping:\n")
for (k in 1:K_exposure) {
  cat(sprintf("  Exposure %d -> Restaurant %d (%s), param %d\n",
              k, expo_to_rest[k], restaurant_config[[expo_to_rest[k]]]$name, expo_to_param[k]))
}

# ==============================================================================
# STEP 6: Compile and Fit the Model
# ==============================================================================

cat("\n=== STEP 6: Fitting the Stan Model ===\n\n")

# Compile the model
model_path <- here::here("models", "model_multilevel_transfer_opt.stan")
cat(sprintf("Compiling model from: %s\n", model_path))

model <- cmdstan_model(model_path)

# Fit the model
cat("Starting MCMC sampling...\n")
cat("This may take a while with larger dataset...\n\n")

fit <- model$sample(
  data = data_list,
  seed = 123,
  chains = 4,
  parallel_chains = 4,
  iter_warmup = 1000,
  iter_sampling = 1000,
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
      cat(sprintf("  %-25s True: %7.3f | Est: %7.3f (median: %7.3f) | 90%% CI: [%6.3f, %6.3f] | Rhat: %.3f %s [%s]\n",
                  param_name, true_value, est_mean, est_median, est_q5, est_q95, rhat, ci_marker, transform_label))
    } else {
      cat(sprintf("  %-25s True: %7.3f | Est: %7.3f (median: %7.3f) | 90%% CI: [%6.3f, %6.3f] | Rhat: %.3f %s\n",
                  param_name, true_value, est_mean, est_median, est_q5, est_q95, rhat, ci_marker))
    }
  } else {
    cat(sprintf("  %-25s Not found in summary\n", param_name))
  }
}

# Print comparison for key parameters
cat("Parameter Recovery Results:\n")
cat(paste(rep("=", 120), collapse = ""), "\n")
cat("** indicates true value outside 90% CI\n\n")

cat("[Global Parameters - Primary Interest]\n")
cat(paste(rep("-", 80), collapse = ""), "\n")
print_comparison("mu_gamma[1]", true_params$mu_gamma, summ,
                 sprintf("rate ratio = %.3f", exp(true_params$mu_gamma)))
print_comparison("sigma_gamma_between[1]", true_params$sigma_gamma_between, summ)
print_comparison("sigma_gamma_within[1]", true_params$sigma_gamma_within, summ)

cat("\n[Global Parameters - Nuisance]\n")
cat(paste(rep("-", 80), collapse = ""), "\n")
print_comparison("mu_beta_intercept", true_params$mu_beta_intercept, summ)
print_comparison("sigma_beta_intercept", true_params$sigma_beta_intercept, summ)
print_comparison("mu_phi_log", true_params$mu_phi_log, summ,
                 sprintf("phi ~ %.1f", exp(true_params$mu_phi_log)))
print_comparison("sigma_phi_log", true_params$sigma_phi_log, summ)
print_comparison("mu_pi_logit", true_params$mu_pi_logit, summ,
                 sprintf("pi ~ %.3f", plogis(true_params$mu_pi_logit)))
print_comparison("sigma_pi_logit", true_params$sigma_pi_logit, summ)

cat("\n[Restaurant-Level Parameters (z-scores)]\n")
cat(paste(rep("-", 80), collapse = ""), "\n")
for (r in 1:R) {
  cat(sprintf("\n  Restaurant %d (%s):\n", r, restaurant_config[[r]]$name))
  print_comparison(sprintf("z_beta_intercept[%d]", r), true_z_params$z_beta_intercept[r], summ)
  print_comparison(sprintf("z_eta[1,%d]", r), true_z_params$z_eta[r], summ)
  print_comparison(sprintf("phi[%d]", r), phi[r], summ)
  print_comparison(sprintf("pi[%d]", r), pi_zi[r], summ)
}

cat("\n[Per-Exposure Gamma Values]\n")
cat(paste(rep("-", 80), collapse = ""), "\n")
for (k in 1:K_exposure) {
  r <- expo_to_rest[k]
  # Find gamma in beta matrix
  param_name <- sprintf("beta[%d,%d]", 1 + k, r)  # exposure column in beta matrix
  cat(sprintf("  Exposure %d (Rest %d - %s):\n", k, r, restaurant_config[[r]]$name))

  # Get the row from summary if it exists
  row <- summ[summ$variable == param_name, ]
  if (nrow(row) > 0) {
    in_ci <- gamma[k] >= row$q5 && gamma[k] <= row$q95
    ci_marker <- if (in_ci) "  " else "**"
    cat(sprintf("    True gamma[%d]: %.3f | Est: %.3f | 90%% CI: [%.3f, %.3f] %s\n",
                k, gamma[k], row$mean, row$q5, row$q95, ci_marker))
  }

  # Also check z_gamma for restaurants with multiple exposures
  if (restaurant_config[[r]]$n_exposures > 1) {
    print_comparison(sprintf("z_gamma[%d]", k), true_z_params$z_gamma[k], summ)
  }
}

# Model diagnostics
cat("\n[Model Diagnostics]\n")
cat(paste(rep("=", 80), collapse = ""), "\n")
diag <- fit$diagnostic_summary()
cat(sprintf("  Divergences: %d\n", sum(diag$num_divergent)))
cat(sprintf("  Max treedepth hits: %d\n", sum(diag$num_max_treedepth)))

# Check Rhat values
rhat_vals <- summ$rhat[!is.na(summ$rhat)]
cat(sprintf("  Max Rhat: %.3f\n", max(rhat_vals)))
cat(sprintf("  Parameters with Rhat > 1.01: %d\n", sum(rhat_vals > 1.01)))
cat(sprintf("  Parameters with Rhat > 1.05: %d\n", sum(rhat_vals > 1.05)))

# ESS diagnostics
ess_bulk <- summ$ess_bulk[!is.na(summ$ess_bulk)]
ess_tail <- summ$ess_tail[!is.na(summ$ess_tail)]
cat(sprintf("  Min ESS bulk: %.0f\n", min(ess_bulk)))
cat(sprintf("  Min ESS tail: %.0f\n", min(ess_tail)))

# ==============================================================================
# STEP 8: Coverage Analysis
# ==============================================================================

cat("\n=== STEP 8: Coverage Analysis ===\n\n")

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

# Check coverage for key parameters
global_params <- c("mu_gamma[1]", "sigma_gamma_between[1]", "sigma_gamma_within[1]",
                   "mu_beta_intercept", "sigma_beta_intercept",
                   "mu_phi_log", "sigma_phi_log",
                   "mu_pi_logit", "sigma_pi_logit")
global_true <- c(true_params$mu_gamma, true_params$sigma_gamma_between, true_params$sigma_gamma_within,
                 true_params$mu_beta_intercept, true_params$sigma_beta_intercept,
                 true_params$mu_phi_log, true_params$sigma_phi_log,
                 true_params$mu_pi_logit, true_params$sigma_pi_logit)

global_coverage <- check_coverage(global_params, global_true, summ)
cat(sprintf("Global parameter 90%% CI coverage: %.1f%% (expected ~90%%)\n", 100 * global_coverage))

# Restaurant-level coverage
rest_params <- c()
rest_true <- c()
for (r in 1:R) {
  rest_params <- c(rest_params, sprintf("phi[%d]", r), sprintf("pi[%d]", r))
  rest_true <- c(rest_true, phi[r], pi_zi[r])
}
rest_coverage <- check_coverage(rest_params, rest_true, summ)
cat(sprintf("Restaurant-level 90%% CI coverage: %.1f%% (expected ~90%%)\n", 100 * rest_coverage))

# ==============================================================================
# STEP 9: Save Results
# ==============================================================================

cat("\n=== STEP 9: Saving Results ===\n\n")

results <- list(
  # Configuration
  restaurant_config = restaurant_config,

  # True parameters
  true_params = true_params,
  true_z_params = true_z_params,
  true_derived = list(
    beta_intercept = beta_intercept,
    eta = eta,
    gamma = gamma,
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

  # Coverage
  coverage = list(
    global = global_coverage,
    restaurant = rest_coverage
  )
)

output_path <- here::here("model_simulations", "simulate_full_results.rds")
saveRDS(results, output_path)
cat(sprintf("Results saved to: %s\n", output_path))

cat("\n=== Simulation Complete ===\n")
cat("\nKey findings:\n")
cat(sprintf("  - mu_gamma recovery: Check if 0.2 is within 90%% CI above\n"))
cat(sprintf("  - sigma_gamma_within should be estimable since 2 restaurants have 2 exposures\n"))
cat(sprintf("  - Total data points: %d (train) + %d (test) = %d\n", N_train, N_test, N_train + N_test))

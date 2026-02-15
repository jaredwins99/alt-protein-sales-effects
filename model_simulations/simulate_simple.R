# ==============================================================================
# Simple Simulation Script for Parameter Recovery
# ==============================================================================
#
# This script generates synthetic data from the model's generative process
# (model_multilevel_transfer_opt.stan) and fits the model to recover parameters.
#
# SIMPLE VERSION:
#   - 2 restaurants (R=2)
#   - 1 outcome variable (single count outcome)
#   - Minimal covariates: intercept + 1 exposure per restaurant
#   - No INGARCH lags: p_effective=0, q_effective=0
#   - ~500 time points per restaurant for train, ~50 for test
#
# NOTE ON GAMMA INTERPRETATION:
#   gamma enters the linear predictor: nu = X * beta
#   lambda = exp(nu)
#   So gamma is on the LOG scale. exp(gamma) = rate ratio.
#   e.g., gamma = 0.2 means exp(0.2) = 1.22 = 22% increase in rate
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

# Simulation settings
R <- 2           # Number of restaurants
N_train_per_rest <- 500  # Training observations per restaurant (actual data has 335-3800+)
N_test_per_rest <- 50    # Test observations per restaurant
intervention_times <- c(200, 250)  # Different intervention times for each restaurant

# True parameter values we want to recover
true_params <- list(
  # Exposure effect (primary interest) - ON LOG SCALE
  # mu_gamma = 0.2 means rate ratio = exp(0.2) = 1.22 (22% increase)
  mu_gamma = 0.2,               # Global mean exposure effect (log scale)
  sigma_gamma_between = 0.1,    # SD across restaurants (log scale)

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
cat(sprintf("  mu_beta_intercept: %.3f\n", true_params$mu_beta_intercept))
cat(sprintf("  sigma_beta_intercept: %.3f\n", true_params$sigma_beta_intercept))
cat(sprintf("  mu_phi_log: %.3f (phi ~ %.1f)\n", true_params$mu_phi_log, exp(true_params$mu_phi_log)))
cat(sprintf("  sigma_phi_log: %.3f\n", true_params$sigma_phi_log))
cat(sprintf("  mu_pi_logit: %.3f (pi ~ %.3f)\n", true_params$mu_pi_logit, plogis(true_params$mu_pi_logit)))
cat(sprintf("  sigma_pi_logit: %.3f\n", true_params$sigma_pi_logit))

# ==============================================================================
# STEP 2: Generate Parameters Using Hierarchical Structure
# ==============================================================================

cat("\n=== STEP 2: Generating Hierarchical Parameters ===\n\n")

# Sample standard normal deviates (the "z" parameters)
z_beta_intercept <- rnorm(R)   # Per-restaurant intercept deviates
z_eta <- rnorm(R)              # Per-restaurant exposure effect deviates (M=1, so just a vector)
z_phi_log <- rnorm(R)          # Per-restaurant dispersion deviates
z_pi_logit <- rnorm(R)         # Per-restaurant zero-inflation deviates

# Compute restaurant-level parameters using non-centered parameterization
beta_intercept <- true_params$mu_beta_intercept +
                  true_params$sigma_beta_intercept * z_beta_intercept

# For exposures: Since each restaurant has only 1 exposure,
# gamma = eta (no within-restaurant level needed)
eta <- true_params$mu_gamma +
       true_params$sigma_gamma_between * z_eta
gamma <- eta  # gamma[k] = eta for single exposure per restaurant

# Dispersion and zero-inflation
phi <- exp(true_params$mu_phi_log + true_params$sigma_phi_log * z_phi_log)
pi_zi <- plogis(true_params$mu_pi_logit + true_params$sigma_pi_logit * z_pi_logit)

cat("Restaurant-level parameters:\n")
for (r in 1:R) {
  cat(sprintf("  Restaurant %d:\n", r))
  cat(sprintf("    beta_intercept: %.3f\n", beta_intercept[r]))
  cat(sprintf("    gamma (exposure effect): %.3f\n", gamma[r]))
  cat(sprintf("    phi (dispersion): %.3f\n", phi[r]))
  cat(sprintf("    pi (zero-inflation prob): %.3f\n", pi_zi[r]))
}

# Save the true z values for comparison
true_z_params <- list(
  z_beta_intercept = z_beta_intercept,
  z_eta = z_eta,
  z_phi_log = z_phi_log,
  z_pi_logit = z_pi_logit
)

# ==============================================================================
# STEP 3: Generate Predictor Data (Design Matrix)
# ==============================================================================

cat("\n=== STEP 3: Generating Design Matrix ===\n\n")

# Total observations
N_train <- R * N_train_per_rest
N_test <- R * N_test_per_rest

# Initialize matrices
# J = 3 columns: intercept (col 1), exposure_rest1 (col 2), exposure_rest2 (col 3)
J <- 1 + R  # intercept + one exposure column per restaurant

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

# Generate data for each restaurant
train_offset <- 0
test_offset <- 0

for (r in 1:R) {
  # Training data indices
  train_start_idx[r] <- train_offset + 1
  train_end_idx[r] <- train_offset + N_train_per_rest

  train_rows <- (train_start_idx[r]):(train_end_idx[r])

  # Fill in design matrix for training
  X_train[train_rows, 1] <- 1  # Intercept

  # Exposure: binary step function (0 before intervention, 1 after)
  exposure_col <- 1 + r  # Each restaurant has its own exposure column
  time_points <- 1:N_train_per_rest
  exposure_indicator <- as.integer(time_points >= intervention_times[r])
  X_train[train_rows, exposure_col] <- exposure_indicator

  idx_to_rest_train[train_rows] <- r

  # Test data indices
  test_start_idx[r] <- test_offset + 1
  test_end_idx[r] <- test_offset + N_test_per_rest

  test_rows <- (test_start_idx[r]):(test_end_idx[r])

  # Fill in design matrix for testing (all post-intervention)
  X_test[test_rows, 1] <- 1  # Intercept
  X_test[test_rows, exposure_col] <- 1  # All test data is post-intervention

  idx_to_rest_test[test_rows] <- r

  train_offset <- train_end_idx[r]
  test_offset <- test_end_idx[r]
}

cat(sprintf("Design matrix dimensions:\n"))
cat(sprintf("  J (total predictors): %d\n", J))
cat(sprintf("  N_train: %d\n", N_train))
cat(sprintf("  N_test: %d\n", N_test))
cat(sprintf("  Intervention times: Restaurant 1 at t=%d, Restaurant 2 at t=%d\n",
            intervention_times[1], intervention_times[2]))

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

  # Build beta vector for this restaurant
  beta_r <- rep(0, J)
  beta_r[1] <- beta_intercept[r]  # Intercept
  beta_r[1 + r] <- gamma[r]       # This restaurant's exposure effect

  # Compute linear predictor and lambda
  nu_r <- X_train[train_rows, , drop = FALSE] %*% beta_r
  lambda_r <- exp(as.vector(nu_r))

  # Generate outcomes
  y_train[train_rows] <- rzinb(length(train_rows), lambda_r, phi[r], pi_zi[r])
}

# Generate test outcomes
for (r in 1:R) {
  test_rows <- (test_start_idx[r]):(test_end_idx[r])

  # Build beta vector for this restaurant
  beta_r <- rep(0, J)
  beta_r[1] <- beta_intercept[r]
  beta_r[1 + r] <- gamma[r]

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

for (r in 1:R) {
  train_rows <- (train_start_idx[r]):(train_end_idx[r])
  y_r <- y_train[train_rows]
  cat(sprintf("  Restaurant %d: mean=%.2f, zeros=%.1f%%\n",
              r, mean(y_r), 100 * mean(y_r == 0)))
}

# ==============================================================================
# STEP 5: Prepare Stan Data List
# ==============================================================================

cat("\n=== STEP 5: Preparing Stan Data List ===\n\n")

# Index definitions
idx_intercept <- 1                    # Column 1 is intercept
K_exposure <- R                       # One exposure per restaurant = R total
idx_exposure <- 2:(1 + R)             # Columns 2, 3, ... are exposures
expo_to_rest <- 1:R                   # Exposure k belongs to restaurant k
expo_to_param <- rep(1, R)            # All exposures use param 1 (M=1)
M <- 1                                # Single parameter in transfer function

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
z_eta_scale <- 10.0     # Between-restaurant exposure deviates (nearly uninformative)
z_gamma_scale <- 10.0   # Within-restaurant exposure deviates (nearly uninformative)
z_beta_scale <- 10.0    # Restaurant-specific covariate deviates
z_ingarch_scale <- 10.0 # INGARCH parameter deviates
z_pi_scale <- 10.0      # Zero-inflation deviates

# Build the Stan data list
data_list <- list(
  # ── Metadata ──
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

  # ── Training Data ──
  N_train = N_train,
  X_train = X_train,
  y_train = y_train,
  train_start_idx = train_start_idx,
  train_end_idx = train_end_idx,
  idx_to_rest_train = idx_to_rest_train,

  # ── Test Data ──
  N_test = N_test,
  X_test = X_test,
  y_test = y_test,
  test_start_idx = test_start_idx,
  test_end_idx = test_end_idx,
  idx_to_rest_test = idx_to_rest_test,

  # ── Zero Indices ──
  N_zeros = N_zeros,
  idx_zeros = if (N_zeros == 0) array(integer(0), dim = 0) else idx_zeros,

  # ── Hyperprior Scales ──
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
cat(sprintf("  N_zeros: %d\n", N_zeros))

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
print_comparison <- function(param_name, true_value, summ_df) {
  row <- summ_df[summ_df$variable == param_name, ]
  if (nrow(row) > 0) {
    est_mean <- row$mean
    est_median <- row$median
    est_q5 <- row$q5
    est_q95 <- row$q95
    rhat <- row$rhat

    cat(sprintf("  %-25s True: %7.3f | Est: %7.3f (median: %7.3f) | 90%% CI: [%6.3f, %6.3f] | Rhat: %.3f\n",
                param_name, true_value, est_mean, est_median, est_q5, est_q95, rhat))
  } else {
    cat(sprintf("  %-25s Not found in summary\n", param_name))
  }
}

# Print comparison for key parameters
cat("Parameter Recovery Results:\n")
cat("─" |> rep(100) |> paste(collapse = ""), "\n")

cat("\n[Global Parameters]\n")
print_comparison("mu_gamma[1]", true_params$mu_gamma, summ)
print_comparison("sigma_gamma_between[1]", true_params$sigma_gamma_between, summ)
print_comparison("mu_beta_intercept", true_params$mu_beta_intercept, summ)
print_comparison("sigma_beta_intercept", true_params$sigma_beta_intercept, summ)
print_comparison("mu_phi_log", true_params$mu_phi_log, summ)
print_comparison("sigma_phi_log", true_params$sigma_phi_log, summ)
print_comparison("mu_pi_logit", true_params$mu_pi_logit, summ)
print_comparison("sigma_pi_logit", true_params$sigma_pi_logit, summ)

cat("\n[Restaurant-Level Parameters]\n")
for (r in 1:R) {
  cat(sprintf("\n  Restaurant %d:\n", r))
  print_comparison(sprintf("z_beta_intercept[%d]", r), true_z_params$z_beta_intercept[r], summ)
  print_comparison(sprintf("z_eta[1,%d]", r), true_z_params$z_eta[r], summ)
  print_comparison(sprintf("phi[%d]", r), phi[r], summ)
  print_comparison(sprintf("pi[%d]", r), pi_zi[r], summ)
}

# Model diagnostics
cat("\n[Model Diagnostics]\n")
cat("─" |> rep(50) |> paste(collapse = ""), "\n")
diag <- fit$diagnostic_summary()
cat(sprintf("  Divergences: %d\n", sum(diag$num_divergent)))
cat(sprintf("  Max treedepth hits: %d\n", sum(diag$num_max_treedepth)))

# Check Rhat values
rhat_vals <- summ$rhat[!is.na(summ$rhat)]
cat(sprintf("  Max Rhat: %.3f\n", max(rhat_vals)))
cat(sprintf("  Parameters with Rhat > 1.01: %d\n", sum(rhat_vals > 1.01)))

# Save results
cat("\n=== Saving Results ===\n")
results <- list(
  true_params = true_params,
  true_z_params = true_z_params,
  true_derived = list(
    beta_intercept = beta_intercept,
    gamma = gamma,
    phi = phi,
    pi = pi_zi
  ),
  data_list = data_list,
  fit = fit,
  summary = summ
)

saveRDS(results, here::here("model_simulations", "simulate_simple_results.rds"))
cat("Results saved to model_simulations/simulate_simple_results.rds\n")

cat("\n=== Simulation Complete ===\n")

# Quick test of z_eta_scale effect on mu_gamma recovery
# Uses same data generation as simulate_full.R but faster analysis

library(cmdstanr)
set.seed(42)

cat("=== Quick Test: z_eta_scale = 10 ===\n\n")

# ─── TRUE PARAMETERS ───
true_params <- list(
  mu_gamma = 0.2,
  sigma_gamma_between = 0.1,
  sigma_gamma_within = 0.05,
  mu_beta_intercept = 2.0,
  sigma_beta_intercept = 0.3,
  mu_phi_log = log(5),
  sigma_phi_log = 0.2,
  mu_pi_logit = qlogis(0.08),
  sigma_pi_logit = 0.3
)

# ─── RESTAURANT CONFIG ───
restaurant_config <- data.frame(
  name = c("VLZX7K2M9QD4T", "SRQS8F7JWA9MZ", "2HRX9P6HKXA8V", "JHDN7CF1C03X5", "L69HYJ4Y3TR91", "ED5J990H5VAZT"),
  n_train = c(332, 1520, 1615, 1615, 332, 2612),
  n_exposures = c(1, 2, 1, 2, 1, 1)
)
R <- nrow(restaurant_config)

# ─── Generate z_eta and eta ───
z_eta <- rnorm(R)
cat("True z_eta:", round(z_eta, 2), "\n")
cat("Mean of true z_eta:", round(mean(z_eta), 3), "\n\n")

eta <- true_params$mu_gamma + true_params$sigma_gamma_between * z_eta
cat("True eta:", round(eta, 3), "\n")
cat("Mean of true eta:", round(mean(eta), 3), "\n\n")

# ─── Simulate simple data for each restaurant ───
# Using simplified structure (no INGARCH) for speed

# Build design matrix
total_n <- sum(restaurant_config$n_train)
J <- 1 + sum(restaurant_config$n_exposures)  # intercept + exposures

X <- matrix(0, nrow = total_n, ncol = J)
X[, 1] <- 1  # intercept

idx_to_rest <- integer(total_n)
current_row <- 1
current_expo <- 2

for (r in 1:R) {
  n <- restaurant_config$n_train[r]
  rows <- current_row:(current_row + n - 1)
  idx_to_rest[rows] <- r

  # Add exposures for this restaurant
  for (e in 1:restaurant_config$n_exposures[r]) {
    intervention_time <- sample(floor(0.2 * n):floor(0.7 * n), 1)
    X[rows[intervention_time:n], current_expo] <- 1
    current_expo <- current_expo + 1
  }
  current_row <- current_row + n
}

# Generate outcomes
beta_intercept <- true_params$mu_beta_intercept + true_params$sigma_beta_intercept * rnorm(R)
phi <- exp(true_params$mu_phi_log + true_params$sigma_phi_log * rnorm(R))
pi_prob <- plogis(true_params$mu_pi_logit + true_params$sigma_pi_logit * rnorm(R))

# Map exposures to gamma values
K_exposure <- sum(restaurant_config$n_exposures)
gamma <- numeric(K_exposure)
expo_to_rest <- integer(K_exposure)
z_gamma <- rnorm(K_exposure)

k <- 1
for (r in 1:R) {
  for (e in 1:restaurant_config$n_exposures[r]) {
    expo_to_rest[k] <- r
    if (restaurant_config$n_exposures[r] == 1) {
      gamma[k] <- eta[r]
    } else {
      gamma[k] <- eta[r] + true_params$sigma_gamma_within * z_gamma[k]
    }
    k <- k + 1
  }
}

# Generate y
y <- integer(total_n)
for (i in 1:total_n) {
  r <- idx_to_rest[i]
  log_mu <- beta_intercept[r]
  # Add exposure effects
  for (k in 1:K_exposure) {
    if (expo_to_rest[k] == r) {
      log_mu <- log_mu + X[i, k + 1] * gamma[k]
    }
  }
  mu <- exp(log_mu)

  # Zero-inflation
  if (runif(1) < pi_prob[r]) {
    y[i] <- 0
  } else {
    y[i] <- rnbinom(1, size = phi[r], mu = mu)
  }
}

cat("Generated", total_n, "observations\n")
cat("Zeros:", sum(y == 0), "(", round(100*mean(y==0), 1), "%)\n\n")

# ─── Build Stan data ───
# Split into train/test (95/5)
train_frac <- 0.95
train_idx <- c()
test_idx <- c()
train_start <- integer(R)
train_end <- integer(R)
test_start <- integer(R)
test_end <- integer(R)

current <- 1
for (r in 1:R) {
  n <- restaurant_config$n_train[r]
  n_train <- floor(train_frac * n)
  n_test <- n - n_train

  train_start[r] <- length(train_idx) + 1
  train_idx <- c(train_idx, current:(current + n_train - 1))
  train_end[r] <- length(train_idx)

  test_start[r] <- length(test_idx) + 1
  test_idx <- c(test_idx, (current + n_train):(current + n - 1))
  test_end[r] <- length(test_idx)

  current <- current + n
}

N_train <- length(train_idx)
N_test <- length(test_idx)

idx_zeros <- which(y[train_idx] == 0)
N_zeros <- length(idx_zeros)

data_list <- list(
  R = R,
  J = J,
  p_effective = 0,
  q_effective = 0,
  M = 1,

  idx_intercept = 1,
  K_beta_random = 0,
  idx_beta_random = array(integer(0), dim = 0),
  K_beta_fixed = 0,
  idx_beta_fixed = array(integer(0), dim = 0),

  K_exposure = K_exposure,
  idx_exposure = 2:(K_exposure + 1),
  expo_to_rest = expo_to_rest,
  expo_to_param = rep(1, K_exposure),

  effective_lags_alpha = array(integer(0), dim = 0),
  K_alpha_random = 0,
  idx_alpha_random = array(integer(0), dim = 0),
  K_alpha_fixed = 0,
  idx_alpha_fixed = array(integer(0), dim = 0),

  effective_lags_delta = array(integer(0), dim = 0),
  K_delta_random = 0,
  idx_delta_random = array(integer(0), dim = 0),
  K_delta_fixed = 0,
  idx_delta_fixed = array(integer(0), dim = 0),

  N_train = N_train,
  X_train = X[train_idx, ],
  y_train = y[train_idx],
  train_start_idx = train_start,
  train_end_idx = train_end,
  idx_to_rest_train = idx_to_rest[train_idx],

  N_test = N_test,
  X_test = X[test_idx, ],
  y_test = y[test_idx],
  test_start_idx = test_start,
  test_end_idx = test_end,
  idx_to_rest_test = idx_to_rest[test_idx],

  N_zeros = N_zeros,
  idx_zeros = idx_zeros,

  # Priors
  mu_beta_scale = 2.0,
  sigma_beta_scale = 1.0,
  mu_gamma_scale = 1.0,
  sigma_gamma_between_scale = 0.5,
  sigma_gamma_within_scale = 0.5,
  mu_alpha_scale = 1.0,
  sigma_alpha_scale = 1.0,
  mu_delta_scale = 1.0,
  sigma_delta_scale = 1.0,
  mu_phi_log_scale = 2.0,
  sigma_phi_log_scale = 1.0,
  mu_pi_logit_scale = 2.0,
  sigma_pi_logit_scale = 1.0,

  # KEY CHANGE: Less informative z priors
  z_eta_scale = 10.0,
  z_gamma_scale = 10.0,
  z_beta_scale = 10.0,
  z_ingarch_scale = 10.0,
  z_pi_scale = 10.0
)

# ─── Fit model ───
cat("Compiling and fitting model...\n")
model <- cmdstan_model(here::here("models", "model_multilevel_transfer_opt.stan"))

fit <- model$sample(
  data = data_list,
  chains = 4,
  parallel_chains = 4,
  iter_warmup = 500,
  iter_sampling = 500,  # Reduced for speed
  refresh = 100
)

cat("\n=== RESULTS ===\n\n")

# Extract draws
draws <- fit$draws(format = "df")

# mu_gamma
mu_gamma_draws <- draws$`mu_gamma[1]`
cat("TRUE mu_gamma:", true_params$mu_gamma, "\n")
cat("Posterior mu_gamma:\n")
cat("  Mean:", round(mean(mu_gamma_draws), 3), "\n")
cat("  SD:", round(sd(mu_gamma_draws), 3), "\n")
cat("  90% CI:", round(quantile(mu_gamma_draws, c(0.05, 0.95)), 3), "\n")
cat("  Covers true?:", quantile(mu_gamma_draws, 0.05) < true_params$mu_gamma &
      quantile(mu_gamma_draws, 0.95) > true_params$mu_gamma, "\n\n")

# z_eta
z_eta_cols <- grep("^z_eta\\[", names(draws), value = TRUE)
z_eta_means <- sapply(z_eta_cols, function(col) mean(draws[[col]]))
cat("z_eta posterior means:", round(z_eta_means, 2), "\n")
cat("Mean of z_eta posteriors:", round(mean(z_eta_means), 3), "\n")
cat("TRUE z_eta mean:", round(mean(z_eta), 3), "\n\n")

# Diagnostics
cat("Divergences:", sum(fit$diagnostic_summary()$num_divergent), "\n")

cat("\n=== COMPARISON ===\n")
cat("With z_eta ~ N(0, 1): mu_gamma estimated ~0.34 (90% CI didn't cover 0.2)\n")
cat("With z_eta ~ N(0, 10): mu_gamma estimated", round(mean(mu_gamma_draws), 3), "\n")

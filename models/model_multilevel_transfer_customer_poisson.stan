// ══════════════════════════════════════════════════════════════════════════════
// IMPORTANT: Identification note for conditional Poisson
//
// The conditional Poisson likelihood eliminates ANY covariate that is constant
// within a customer (the customer FE absorbs it). This means:
//   - The restaurant-level INTERCEPT is NOT identified by the likelihood.
//     It is included for structural compatibility with the _opt.stan data prep
//     but its posterior = its prior. Consider dropping the intercept column
//     from X when preparing data for this model.
//   - Customer-level constants (e.g., gender main effect) are also absorbed.
//     Only TIME-VARYING covariates and INTERACTIONS contribute to identification.
//     (gender × exposure IS identified; gender alone is NOT.)
// ══════════════════════════════════════════════════════════════════════════════

data {
  // ──────────────────────────────────
  //             Metadata
  // ──────────────────────────────────

  // Size of design matrix
  int<lower=1> R;                                       // # of restaurants
  int<lower=1> J;                                       // # of predictors
  // CHANGED: Removed p_effective, q_effective (INGARCH lags dropped; AR lags now in X)
  int<lower=1> M;                                       // # of parameters in transfer function

  // Indices for pooled versus non-pooled predictors
  int<lower=1> idx_intercept;                           // The column index for the intercept
  int<lower=0> K_beta_random;                           // # of coef to have random effects
  array[K_beta_random] int idx_beta_random;             // The column indices in X for those coef
  int<lower=0> K_beta_fixed;                            // # of coef to NOT have random effects
  array[K_beta_fixed] int idx_beta_fixed;               // The column indices in X for those coef

  // Indices for exposures
  int<lower=0> K_exposure;                              // Total # of exposure *columns* across all restaurants, equals # of exposures times M
  array[K_exposure] int idx_exposure;                   // The column indices in X for these exposures
  array[K_exposure] int<lower=1,upper=R> expo_to_rest;  // Map from each exposure column to its restaurant ID
  array[K_exposure] int<lower=1,upper=M> expo_to_param; // Map from each exposure to its param in transfer func

  // CHANGED: Removed all INGARCH lag indices (effective_lags_alpha, K_alpha_*, idx_alpha_*,
  //          effective_lags_delta, K_delta_*, idx_delta_*).
  //          AR lags are now pre-computed columns in X.

  // ──────────────────────────────────
  //                Data
  // ──────────────────────────────────

  // Train data
  int<lower=1> N_train;
  matrix[N_train, J] X_train;                            // Design matrix (train)
  array[N_train] int y_train;
  array[R] int train_start_idx;                           // Restaurant start/end in concatenated data
  array[R] int train_end_idx;
  // CHANGED: Removed idx_to_rest_train (not needed; we iterate over customers instead)

  // ADDED: Customer-level indexing for conditional Poisson likelihood
  int<lower=1> C;                                         // Total # of customers across all restaurants
  array[C] int customer_start_idx;                        // Start index in concatenated data for each customer
  array[C] int customer_end_idx;                          // End index in concatenated data for each customer
  array[C] int<lower=1,upper=R> customer_to_rest;         // Map from customer to restaurant (unused in Stan; for R-side post-processing)
  array[C] int<lower=0> n_i;                              // Sufficient statistic: total count per customer (Σ_t y_{it})

  // Test data
  int<lower=1> N_test;
  matrix[N_test, J] X_test;                              // Design matrix (test)
  array[N_test] int y_test;
  array[R] int test_start_idx;
  array[R] int test_end_idx;
  // CHANGED: Removed idx_to_rest_test

  // ADDED: Customer-level indexing for test data
  int<lower=1> C_test;                                    // Total # of customers in test data
  array[C_test] int customer_start_idx_test;              // Start index in test concatenated data for each customer
  array[C_test] int customer_end_idx_test;                // End index in test concatenated data for each customer
  array[C_test] int<lower=1,upper=R> customer_to_rest_test; // Map from test customer to restaurant (unused in Stan; for R-side post-processing)
  array[C_test] int<lower=0> n_i_test;                    // Sufficient statistic for test customers

  // ──────────────────────────────────
  //         Hyperprior Scales
  // ──────────────────────────────────

  // Predictors
  real<lower=0> mu_beta_scale;
  real<lower=0> sigma_beta_scale;

  // Exposures
  real<lower=0> mu_gamma_scale;                         // Prior information about effect size
  real<lower=0> sigma_gamma_between_scale;              // Strength of pooling across restaurants (Level 2)
  real<lower=0> sigma_gamma_within_scale;               // Strength of pooling within restaurant  (Level 1)

  // CHANGED: Removed INGARCH hyperprior scales (mu_alpha_scale, sigma_alpha_scale,
  //          mu_delta_scale, sigma_delta_scale, mu_phi_log_scale, sigma_phi_log_scale)

  // Scales for non-centered deviates (default 1.0 for std_normal)
  // Set > 1 for less informative priors on restaurant-specific effects
  real<lower=0> z_eta_scale;           // Between-restaurant exposure deviates
  real<lower=0> z_gamma_scale;         // Within-restaurant exposure deviates
  real<lower=0> z_beta_scale;          // Restaurant-specific covariate deviates
  // CHANGED: Removed z_alpha_scale, z_delta_scale, z_phi_scale
}

parameters {
  // ──────────────────────────────────
  //         Global Estimates
  // ──────────────────────────────────
  // (fixed effect part of pooled or unpooled estimates)

  // Predictors
  real mu_beta_intercept;
  vector[K_beta_random] mu_beta_random;
  vector[K_beta_fixed] mu_beta_fixed;

  // Exposures
  vector[M] mu_gamma;                                   // ESTIMATE OF PRIMARY INTEREST: global mean exposure effect (center for Level 2)

  // CHANGED: Removed all INGARCH global params (mu_alpha_*, mu_delta_*, mu_phi_log)

  // ──────────────────────────────────
  //   Between Restaurant Variability
  // ──────────────────────────────────

  // Predictors
  real<lower=0> sigma_beta_intercept;
  vector<lower=0>[K_beta_random] sigma_beta_random;

  // Exposures
  vector<lower=0>[M] sigma_gamma_between;               // SD OF INTEREST: exposure effects ACROSS restaurants (scale for Level 2)

  // CHANGED: Removed sigma_alpha_random, sigma_delta_random, sigma_phi_log

  // ──────────────────────────────────
  //         Local Estimates
  // ──────────────────────────────────
  // (random effect part of pooled or unpooled estimates)

  // Predictors
  vector[R] z_beta_intercept;
  matrix[K_beta_random, R] z_beta_random;

  // Exposures
  matrix[M, R] z_eta;                                   // ESTIMATES OF SECONDARY INTEREST: uncentered per-restaurant effects (deviates for Level 2)

  // CHANGED: Removed z_alpha_random, z_delta_random, z_phi_log

  // ──────────────────────────────────
  //   Within Restaurant Variability
  // ──────────────────────────────────

  // Exposures
  vector<lower=0>[M] sigma_gamma_within;                // SD OF INTEREST: exposure effects WITHIN a restaurant (scale for Level 1)

  // ──────────────────────────────────
  //        Doubly Local Estimates
  // ──────────────────────────────────

  // Exposures
  vector[K_exposure] z_gamma;                           // ESTIMATES OF TERTIARY INTEREST: uncentered per-exposure effects (deviates for Level 1)
}

transformed parameters {
  // ──────────────────────────────────
  //       Predictors & Exposures
  // ──────────────────────────────────

  matrix[J, R] beta;
  matrix[M, R] eta;
  // Use a local scope
  {
    // --- Part 1: Predictors

    // Null initialization
    beta = rep_matrix(0.0, J, R);

    // Noncentered parametrization: instead of sampling a normal, we sample a standard normal and multiply by sd
    vector[R] beta_intercept_r = mu_beta_intercept + sigma_beta_intercept * z_beta_intercept;

    // Insert them into the respective indices of beta for matching later
    beta[idx_intercept] = beta_intercept_r';

    if (0 < K_beta_random) {
      // Same thing as intercept but multivariate
      // Diag pre multiply is more efficient due to parallelization
      matrix[K_beta_random, R] beta_random_r = diag_pre_multiply(sigma_beta_random, z_beta_random)
                                             + rep_matrix(mu_beta_random, R);
      for (r in 1:R)
        beta[idx_beta_random, r] = beta_random_r[, r];
    }
    if (0 < K_beta_fixed) {
      for (r in 1:R)
        beta[idx_beta_fixed, r] = mu_beta_fixed;  // For coef w/ no random effects, choose mean as fixed effect
    }
    if (0 < K_exposure) {
      for (r in 1:R)
        beta[idx_exposure, r] = rep_vector(0.0, K_exposure);
    }

    // --- Part 2: Exposures

    // First, figure out how many restaurants have exposures for each parameter
    if (0 < K_exposure) {
      vector[K_exposure] gamma;
      array[M, R] int rest_has_param;      // Binary: does restaurant r have param?
      array[M] int restaurants_per_param;  // Count of restaurants per parameter
      array[M, R] int exposures_per_rest;  // Count of exposures per restaurant per param

      // Initialize
      for (param in 1:M) {
        restaurants_per_param[param] = 0;
        for (r in 1:R) {
          rest_has_param[param, r] = 0;
          exposures_per_rest[param, r] = 0;
        }
      }

      // First: Mark which restaurants and exposures have each param
      for (k in 1:K_exposure) {
        int param = expo_to_param[k];
        int r = expo_to_rest[k];
        rest_has_param[param, r] = 1;
        exposures_per_rest[param, r] += 1;
      }

      // Second: Count restaurants per parameter (after marking)
      for (param in 1:M)
        for (r in 1:R)
          restaurants_per_param[param] += rest_has_param[param, r];

      // Level 2 Construct per-restaurant mean effects
      for (param in 1:M) {
        for (r in 1:R) {
          if (restaurants_per_param[param] > 1)
            eta[param, r] = mu_gamma[param] + sigma_gamma_between[param] * z_eta[param, r];
          else
            eta[param, r] = mu_gamma[param];  // Single restaurant means no between-restaurant level
        }
      }

      // Level 1 Construct per-exposure coefs (gamma)
      for (k in 1:K_exposure) {           // Remember that this is the total exposures across restaurants
        int r = expo_to_rest[k];
        int param = expo_to_param[k];

        if (exposures_per_rest[param, r] > 1)
          gamma[k] = eta[param, r] + sigma_gamma_within[param] * z_gamma[k];
        else
          gamma[k] = eta[param, r];  // Single exposure means no within-restaurant level

        beta[idx_exposure[k], r] = gamma[k];       // Insert into beta
      }
    } else {
      // No exposures - just set eta to mu_gamma
      eta = rep_matrix(mu_gamma, R);
    }
  }

  // CHANGED: Removed entire alpha (outcome lags) block — AR lags are now columns in X
  // CHANGED: Removed entire delta (latent intensity lags) block
  // CHANGED: Removed phi (dispersion) — not needed for conditional Poisson

  // ──────────────────────────────────
  //       Linear Predictor
  // ──────────────────────────────────
  // CHANGED: No sequential INGARCH lag computation — nu is purely X * beta, fully vectorized

  vector[N_train] nu;
  vector[N_train] lambda;
  // For each restaurant
  for (r in 1:R) {

    // Identify which indices in the concatenated (long-style) data are which restaurant
    int r_start = train_start_idx[r];
    int r_end = train_end_idx[r];

    // Identify the parameters for the restaurant
    vector[J] beta_r = beta[, r];

    // Vectorized predictor computation for entire restaurant at once
    nu[r_start:r_end] = X_train[r_start:r_end] * beta_r;

    // CHANGED: Removed sequential loop for outcome lags (alpha) and latent intensity lags (delta)
    //          AR structure is now absorbed into X as pre-computed covariates
  }
  lambda = exp(nu);
}

model {
  // ──────────────────────────────────
  //        Global Priors
  // ──────────────────────────────────
  // (fixed effect part of pooled or unpooled estimates)

  // Predictors
  mu_beta_intercept ~ normal(0, 5);                        // No shrinkage for the intercept, hard coded
  mu_beta_random ~ double_exponential(0, mu_beta_scale);
  mu_beta_fixed ~ double_exponential(0, mu_beta_scale);

  // Exposures
  mu_gamma ~ normal(0, mu_gamma_scale);                     // No shrinkage for the exposures

  // CHANGED: Removed INGARCH global priors (mu_alpha_*, mu_delta_*, mu_phi_log)

  // ──────────────────────────────────
  //      Between Restaurant Priors
  // ──────────────────────────────────

  // Predictors
  sigma_beta_intercept ~ student_t(3, 0, sigma_beta_scale);
  sigma_beta_random ~ student_t(3, 0, sigma_beta_scale);

  // Exposures
  sigma_gamma_between ~ student_t(3, 0, sigma_gamma_between_scale);

  // CHANGED: Removed sigma_alpha_random, sigma_delta_random, sigma_phi_log priors

  // ──────────────────────────────────
  //        Local Priors
  // ──────────────────────────────────
  // (fixed effect part of pooled or unpooled estimates)

  // Predictors
  z_beta_intercept ~ normal(0, z_beta_scale);
  to_vector(z_beta_random) ~ normal(0, z_beta_scale);

  // Exposures
  to_vector(z_eta) ~ normal(0, z_eta_scale);  // Prior for non-centered deviates

  // CHANGED: Removed z_alpha_random, z_delta_random, z_phi_log priors

  // ──────────────────────────────────
  //   Within Restaurant Variability
  // ──────────────────────────────────

  // Exposures
  sigma_gamma_within ~ student_t(3, 0, sigma_gamma_within_scale);

  // ──────────────────────────────────
  //        Doubly Local Priors
  // ──────────────────────────────────

  // Exposures
  z_gamma ~ normal(0, z_gamma_scale);  // Prior for non-centered deviates

  // ──────────────────────────────────
  //   Conditional Poisson Likelihood
  // ──────────────────────────────────
  // CHANGED: Replaced NegBin likelihood with conditional Poisson per customer.
  //
  // For customer i with T_i observations, the conditional Poisson log-likelihood is:
  //   log p(y_i | beta) = Σ_t y_{it} * nu_{it} - n_i * log(Σ_t exp(nu_{it})) + const
  // where n_i = Σ_t y_{it} is the sufficient statistic (total count).
  // The constant (involving factorials of y_{it}) does not depend on parameters and is dropped.
  // This eliminates customer fixed effects without estimating them (same as fixest::fepois).

  for (c in 1:C) {
    int c_start = customer_start_idx[c];
    int c_end = customer_end_idx[c];

    // Sum of y_it * nu_it for this customer
    real sum_y_nu = dot_product(
      to_vector(y_train[c_start:c_end]),
      nu[c_start:c_end]
    );

    // n_i * log(Σ_t exp(nu_it)) = n_i * log(Σ_t lambda_it)
    // log_sum_exp computes log(Σ exp(x)) in a numerically stable way
    target += sum_y_nu - n_i[c] * log_sum_exp(nu[c_start:c_end]);
  }
}

generated quantities {
  // ──────────────────────────────────
  //        Train Predictions
  // ──────────────────────────────────
  // CHANGED: log_lik is per CUSTOMER (not per observation) using conditional Poisson formula
  // CHANGED: y_rep uses unconditional Poisson(lambda) for posterior predictive checks

  array[N_train] int y_rep;                   // Outcome predictions (train), unconditional Poisson
  vector[C] log_lik;                          // Log-likelihood per customer (for LOO etc.)

  // Posterior predictive draws (unconditional, per observation)
  for (t in 1:N_train) {
    y_rep[t] = poisson_rng(lambda[t]);
  }

  // Conditional Poisson log-likelihood per customer
  for (c in 1:C) {
    int c_start = customer_start_idx[c];
    int c_end = customer_end_idx[c];

    real sum_y_nu = dot_product(
      to_vector(y_train[c_start:c_end]),
      nu[c_start:c_end]
    );

    log_lik[c] = sum_y_nu - n_i[c] * log_sum_exp(nu[c_start:c_end]);
  }

  // ──────────────────────────────────
  //        Test Predictions
  // ──────────────────────────────────
  // CHANGED: Fully vectorized — no sequential lag structure
  // CHANGED: Test log-likelihood is per customer using conditional Poisson
  // CHANGED: y_test_rep uses unconditional Poisson(lambda_test)

  array[N_test] int y_test_rep;               // Outcome predictions (test), unconditional Poisson
  vector[N_test] lambda_test;
  vector[N_test] nu_test;
  vector[C_test] log_lik_test;                // Log-likelihood per test customer

  // Compute nu_test and lambda_test per restaurant (vectorized, no sequential lags)
  for (r in 1:R) {
    int r_test_start_idx = test_start_idx[r];
    int r_test_end_idx = test_end_idx[r];

    vector[J] beta_r = beta[, r];

    // Fully vectorized: no INGARCH sequential computation needed
    nu_test[r_test_start_idx:r_test_end_idx] = X_test[r_test_start_idx:r_test_end_idx] * beta_r;
  }
  lambda_test = exp(nu_test);

  // Posterior predictive draws (unconditional, per observation)
  for (t in 1:N_test) {
    y_test_rep[t] = poisson_rng(lambda_test[t]);
  }

  // Conditional Poisson log-likelihood per test customer
  for (c in 1:C_test) {
    int c_start = customer_start_idx_test[c];
    int c_end = customer_end_idx_test[c];

    real sum_y_nu_test = dot_product(
      to_vector(y_test[c_start:c_end]),
      nu_test[c_start:c_end]
    );

    log_lik_test[c] = sum_y_nu_test - n_i_test[c] * log_sum_exp(nu_test[c_start:c_end]);
  }
}

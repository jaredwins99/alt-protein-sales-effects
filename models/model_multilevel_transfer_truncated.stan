data {
  // ──────────────────────────────────
  //             Metadata
  // ──────────────────────────────────

  // Size of design matrix (and higher moments, like lags)
  int<lower=1> R;                                       // # of restaurants
  int<lower=1> J;                                       // # of predictors
  int<lower=0> p_effective;                             // # of effective outcome lags
  int<lower=0> q_effective;                             // # of effective latent intensity lags
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

  // Indices for outcome lags
  array[p_effective] int effective_lags_alpha;
  int<lower=0> K_alpha_random;
  array[K_alpha_random] int idx_alpha_random;
  int<lower=0> K_alpha_fixed;
  array[K_alpha_fixed] int idx_alpha_fixed;

  // Indices for latent intensities
  array[q_effective] int effective_lags_delta;
  int<lower=0> K_delta_random;
  array[K_delta_random] int idx_delta_random;
  int<lower=0> K_delta_fixed;
  array[K_delta_fixed] int idx_delta_fixed;

  // ──────────────────────────────────
  //                Data
  // ──────────────────────────────────

  // Train data
  int<lower=1> N_train;
  matrix[N_train, J] X_train;                            // Design matrix (train)
  array[N_train] int y_train;
  array[R] int train_start_idx;
  array[R] int train_end_idx;
  array[N_train] int<lower=1,upper=R> idx_to_rest_train; // Mapping from the concatenated index to the restaurants

  // Nonzero indices for truncated/open-day likelihood
  int<lower=0,upper=1> apply_truncation;                                 // 1 = zero-truncated NB (total outcome), 0 = regular NB on open days (subset outcomes)
  int<lower=0> N_total_nonzero;                                          // # of open-day observations in training data
  array[N_total_nonzero] int<lower=1,upper=N_train> idx_total_nonzero;   // Indices of open-day observations (train)

  // Test data
  int<lower=1> N_test;
  matrix[N_test, J] X_test;                              // Design matrix (test)
  array[N_test] int y_test;
  array[R] int test_start_idx;
  array[R] int test_end_idx;
  array[N_test] int<lower=1,upper=R> idx_to_rest_test;   // Mapping from the concatenated index to the restaurants

  // Nonzero test indices
  int<lower=0> N_total_nonzero_test;                                           // # of open-day observations in test data
  array[N_total_nonzero_test] int<lower=1,upper=N_test> idx_total_nonzero_test; // Indices of open-day observations (test)

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

  // INGARCH: outcomes lags, latent intensities, and dispersion
  real<lower=0> mu_alpha_scale;
  real<lower=0> sigma_alpha_scale;
  real<lower=0> mu_delta_scale;
  real<lower=0> sigma_delta_scale;
  real<lower=0> mu_phi_log_scale;
  real<lower=0> sigma_phi_log_scale;

  // Scales for non-centered deviates (default 1.0 for std_normal)
  // Set > 1 for less informative priors on restaurant-specific effects
  real<lower=0> z_eta_scale;           // Between-restaurant exposure deviates
  real<lower=0> z_gamma_scale;         // Within-restaurant exposure deviates
  real<lower=0> z_beta_scale;          // Restaurant-specific covariate deviates
  real<lower=0> z_alpha_scale;          // Lagged outcome deviates (alpha)
  real<lower=0> z_delta_scale;          // Lagged intensity deviates (delta)
  real<lower=0> z_phi_scale;            // Dispersion deviates (phi)
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

  // INGARCH params
  vector[K_alpha_random] mu_alpha_random_raw;           // Raw will be tanh transformed
  vector[K_alpha_fixed] mu_alpha_fixed_raw;
  vector[K_delta_random] mu_delta_random_raw;
  vector[K_delta_fixed] mu_delta_fixed_raw;
  real mu_phi_log;

  // ──────────────────────────────────
  //   Between Restaurant Variability
  // ──────────────────────────────────

  // Predictors
  real<lower=0> sigma_beta_intercept;
  vector<lower=0>[K_beta_random] sigma_beta_random;

  // Exposures
  vector<lower=0>[M] sigma_gamma_between;               // SD OF INTEREST: exposure effects ACROSS restaurants (scale for Level 2)

  // INGARCH params
  vector<lower=0>[K_alpha_random] sigma_alpha_random;
  vector<lower=0>[K_delta_random] sigma_delta_random;
  real<lower=0> sigma_phi_log;

  // ──────────────────────────────────
  //         Local Estimates
  // ──────────────────────────────────
  // (random effect part of pooled or unpooled estimates)

  // Predictors
  vector[R] beta_intercept_r;
  matrix[K_beta_random, R] beta_random_r;

  // Exposures
  matrix[M, R] z_eta;                                   // ESTIMATES OF SECONDARY INTEREST: uncentered per-restaurant effects (deviates for Level 2)

  // INGARCH params
  matrix[K_alpha_random, R] alpha_random_raw_r;
  matrix[K_delta_random, R] delta_random_raw_r;
  vector[R] phi_log_r;

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

    if (R > 1) {
      // Centered parametrization: restaurant-level parameters sampled directly
      beta[idx_intercept] = beta_intercept_r';

      if (0 < K_beta_random) {
        for (r in 1:R)
          beta[idx_beta_random, r] = beta_random_r[, r];
      }
    } else {
      // Single restaurant: collapse to global mean (no between-restaurant variation)
      beta[idx_intercept, 1] = mu_beta_intercept;

      if (0 < K_beta_random) {
        beta[idx_beta_random, 1] = mu_beta_random;
      }
    }

    if (0 < K_beta_fixed) {
      for (r in 1:R)
        beta[idx_beta_fixed, r] = mu_beta_fixed;
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

  // ──────────────────────────────────
  //            Outcome Lags
  // ──────────────────────────────────

  matrix<lower=-1,upper=1>[p_effective, R] alpha;
  // Local scope
  {
    // Null initialization
    alpha = rep_matrix(0.0, p_effective, R);

    if (0 < p_effective) {
      matrix[p_effective, R] alpha_raw;

      // Null initialization
      alpha_raw = rep_matrix(0.0, p_effective, R);

      if (0 < K_alpha_random) {
        if (R > 1) {
          // CP: use directly sampled restaurant-level parameters
          for (r in 1:R)
            alpha_raw[idx_alpha_random, r] = alpha_random_raw_r[, r];
        } else {
          // Single restaurant: collapse to global mean
          alpha_raw[idx_alpha_random, 1] = mu_alpha_random_raw;
        }
      }
      if (0 < K_alpha_fixed) {
        for (r in 1:R)
          alpha_raw[idx_alpha_fixed, r] = mu_alpha_fixed_raw;
      }
      // We parametrize alpha_raw over the real line
      // But alpha itself needs to be constrained to (-1,1)
      // Divide by 2 to spread it out further (for better convergence)
      alpha = tanh(alpha_raw / 2.0);
    }
  }

  // ──────────────────────────────────
  //       Latent Intensity Lags
  // ──────────────────────────────────

  matrix<lower=-1,upper=1>[q_effective, R] delta;
  // Local scope
  {
    // Null initialization
    delta = rep_matrix(0.0, q_effective, R);

    if (0 < q_effective) {
      matrix[q_effective, R] delta_raw;

      // Null initialization
      delta_raw = rep_matrix(0.0, q_effective, R);

      if (0 < K_delta_random) {
        if (R > 1) {
          // CP: use directly sampled restaurant-level parameters
          for (r in 1:R)
            delta_raw[idx_delta_random, r] = delta_random_raw_r[, r];
        } else {
          // Single restaurant: collapse to global mean
          delta_raw[idx_delta_random, 1] = mu_delta_random_raw;
        }
      }
      if (0 < K_delta_fixed) {
        for (r in 1:R)
        delta_raw[idx_delta_fixed, r] = mu_delta_fixed_raw;
      }
    // Same thing as for alpha
    delta = tanh(delta_raw / 2.0);
    }
  }

  // ──────────────────────────────────
  //            Dispersion
  // ──────────────────────────────────

  // Dispersion: centered parametrization with R > 1 conditional
  vector<lower=0>[R] phi;
  if (R > 1) {
    phi = exp(phi_log_r);
  } else {
    phi[1] = exp(mu_phi_log);
  }

  // ──────────────────────────────────
  //      INGARCH Structural Model
  // ──────────────────────────────────

  vector[N_train] nu;
  vector[N_train] lambda;
  // For each restaurant
  for (r in 1:R) {

    // Identify which indices in the concatenated (long-style) data are which restaurant
    int r_start = train_start_idx[r];
    int r_end = train_end_idx[r];

    // Identify the parameters for the restaurant
    vector[J] beta_r = beta[, r];
    vector[p_effective] alpha_r = alpha[, r];
    vector[q_effective] delta_r = delta[, r];

    // Vectorized predictor computation for entire restaurant at once
    nu[r_start:r_end] = X_train[r_start:r_end] * beta_r;

    // Sequential part: lags (cannot be vectorized due to dependencies)
    for (t in r_start:r_end) {
      // Outcome lags
      if (0 < p_effective) {
        for (i in 1:p_effective) {
          int lag = effective_lags_alpha[i];
          if (t - lag >= r_start)                           // Log parametrization
            nu[t] += alpha_r[i] * log1p(y_train[t - lag]);  // log1p is slightly faster than log(x+1)
        }
      }

      // Latent intensity lags
      if (0 < q_effective) {
        for (j in 1:q_effective) {
          int lag = effective_lags_delta[j];
          if (t - lag >= r_start)
            nu[t] += delta_r[j] * nu[t - lag];
        }
      }
    }
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

  // INGARCH params
  mu_alpha_random_raw ~ double_exponential(0, mu_alpha_scale);
  mu_alpha_fixed_raw ~ double_exponential(0, mu_alpha_scale);
  mu_delta_random_raw ~ double_exponential(0, mu_delta_scale);
  mu_delta_fixed_raw ~ double_exponential(0, mu_delta_scale);
  mu_phi_log ~ normal(0, mu_phi_log_scale);

  // ──────────────────────────────────
  //      Between Restaurant Priors
  // ──────────────────────────────────

  // Predictors
  sigma_beta_intercept ~ student_t(3, 0, sigma_beta_scale);
  sigma_beta_random ~ student_t(3, 0, sigma_beta_scale);

  // Exposures
  sigma_gamma_between ~ student_t(3, 0, sigma_gamma_between_scale);

  // INGARCH params
  sigma_alpha_random ~ student_t(3, 0, sigma_alpha_scale);
  sigma_delta_random ~ student_t(3, 0, sigma_delta_scale);
  sigma_phi_log ~ student_t(3, 0, sigma_phi_log_scale);

  // ──────────────────────────────────
  //        Local Priors
  // ──────────────────────────────────
  // (restaurant-level effects: centered parameterization with R > 1 conditional)

  if (R > 1) {
    // Predictors: CP priors
    beta_intercept_r ~ normal(mu_beta_intercept, sigma_beta_intercept);
    if (0 < K_beta_random) {
      for (r in 1:R)
        beta_random_r[, r] ~ normal(mu_beta_random, sigma_beta_random);
    }

    // INGARCH params: CP priors
    if (0 < K_alpha_random) {
      for (r in 1:R)
        alpha_random_raw_r[, r] ~ normal(mu_alpha_random_raw, sigma_alpha_random);
    }
    if (0 < K_delta_random) {
      for (r in 1:R)
        delta_random_raw_r[, r] ~ normal(mu_delta_random_raw, sigma_delta_random);
    }
    phi_log_r ~ normal(mu_phi_log, sigma_phi_log);
  } else {
    // R=1: parameters are unused (collapsed to global mean in transformed parameters)
    // Give them independent priors so they don't create funnels with sigma
    beta_intercept_r ~ normal(0, 1);
    if (0 < K_beta_random)
      to_vector(beta_random_r) ~ normal(0, 1);
    if (0 < K_alpha_random)
      to_vector(alpha_random_raw_r) ~ normal(0, 1);
    if (0 < K_delta_random)
      to_vector(delta_random_raw_r) ~ normal(0, 1);
    phi_log_r ~ normal(0, 1);
  }

  // Exposures (gamma hierarchy: keep NCP, unchanged)
  to_vector(z_eta) ~ normal(0, z_eta_scale);  // Prior for non-centered deviates

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
  //    INGARCH Distributional Model
  // ──────────────────────────────────

  // Vectorized likelihood on open-day observations only
  {
    vector[N_total_nonzero] lambda_nz = lambda[idx_total_nonzero];
    vector[N_total_nonzero] phi_nz = phi[idx_to_rest_train[idx_total_nonzero]];
    y_train[idx_total_nonzero] ~ neg_binomial_2(lambda_nz, phi_nz);
    if (apply_truncation == 1) {
      // Zero-truncated correction: subtract log P(Y>0) for each observation
      vector[N_total_nonzero] log_nb0 = phi_nz .* (log(phi_nz) - log(phi_nz + lambda_nz));
      target += -sum(log1m_exp(log_nb0));
    }
  }
}

generated quantities {
  // ──────────────────────────────────
  //        Train Predictions
  // ──────────────────────────────────

  array[N_train] int y_rep;                   // Outcome predictions (train)
  vector[N_train] log_lik;                    // Pointwise log-likelihood

  // Initialize all to zero (excluded observations: closed days)
  for (t in 1:N_train) {
    y_rep[t] = 0;
    log_lik[t] = 0;
  }

  // Compute for included observations (open days)
  for (i in 1:N_total_nonzero) {
    int t = idx_total_nonzero[i];
    int r = idx_to_rest_train[t];
    real phi_r = phi[r];

    if (apply_truncation == 1) {
      // Truncated NB log-likelihood
      real log_nb0 = neg_binomial_2_lpmf(0 | lambda[t], phi_r);
      log_lik[t] = neg_binomial_2_lpmf(y_train[t] | lambda[t], phi_r)
                 - log1m_exp(log_nb0);
      // Truncated NB draw via rejection sampling
      while (y_rep[t] == 0)
        y_rep[t] = neg_binomial_2_rng(lambda[t], phi_r);
    } else {
      // Regular NB log-likelihood and draw
      log_lik[t] = neg_binomial_2_lpmf(y_train[t] | lambda[t], phi_r);
      y_rep[t] = neg_binomial_2_rng(lambda[t], phi_r);
    }
  }

  // ──────────────────────────────────
  //        Test Predictions
  // ──────────────────────────────────

  array[N_test] int y_test_rep;               // Outcome predictions (test)
  vector[N_test] lambda_test;
  vector[N_test] nu_test;

  // Initialize test predictions to 0 (closed days)
  for (t in 1:N_test)
    y_test_rep[t] = 0;

  // Compute nu_test and lambda_test for ALL observations (AR continuity)
  for (r in 1:R) {

    // Identify which indices in the concatenated (long-style) data are which restaurant
    int r_train_end_idx = train_end_idx[r];
    int r_test_start_idx = test_start_idx[r];
    int r_test_end_idx = test_end_idx[r];

    // Identify the parameters for the restaurant
    vector[J] beta_r = beta[, r];
    vector[p_effective] alpha_r = alpha[, r];
    vector[q_effective] delta_r = delta[, r];

    // ──────────────────────────────────
    //     INGARCH Structural Model
    // ──────────────────────────────────

    // Vectorized predictor computation
    nu_test[r_test_start_idx:r_test_end_idx] = X_test[r_test_start_idx:r_test_end_idx] * beta_r;

    for (t_test_idx in r_test_start_idx:r_test_end_idx) {
      int current_pos_in_test = t_test_idx - r_test_start_idx + 1;   // Index to restaurant mapping

      // Outcome lags
      if (0 < p_effective) {
        for (i in 1:p_effective) {
          int lag = effective_lags_alpha[i];
          int lag_source_idx_test = t_test_idx - lag;

          // IMPORTANT: we use observed y_test not y_test_rep for single-step rolling forecasting
          if (lag < current_pos_in_test)
            nu_test[t_test_idx] += alpha_r[i] * log1p(y_test[lag_source_idx_test]);

          // Use training data if we aren't far enough into the test data
          else {
            int train_lag_offset = lag - current_pos_in_test;
            int lag_source_idx_train = r_train_end_idx - train_lag_offset;
            if (lag_source_idx_train >= train_start_idx[r] && lag_source_idx_train <= r_train_end_idx)
              nu_test[t_test_idx] += alpha_r[i] * log1p(y_train[lag_source_idx_train]);
          }
        }
      }

      // Latent intensity lags
      if (0 < q_effective) {
        for (j in 1:q_effective) {
          // Identify lag and indices
          int lag = effective_lags_delta[j];
          int lag_source_idx_test = t_test_idx - lag;

          // IMPORTANT: generated, rather than observed, nu_test is used regardless
          if (lag < current_pos_in_test)
            nu_test[t_test_idx] += delta_r[j] * nu_test[lag_source_idx_test];

          // Use training estimates if we aren't far enough into the test data
          else {
            int train_lag_offset = lag - current_pos_in_test;
            int lag_source_idx_train = r_train_end_idx - train_lag_offset;
            if (lag_source_idx_train >= train_start_idx[r] && lag_source_idx_train <= r_train_end_idx)
              nu_test[t_test_idx] += delta_r[j] * nu[lag_source_idx_train];
          }
        }
      }

      lambda_test[t_test_idx] = exp(nu_test[t_test_idx]);
    }
  }

  // Draw predictions only for open-day test observations
  for (i in 1:N_total_nonzero_test) {
    int t = idx_total_nonzero_test[i];
    int r = idx_to_rest_test[t];
    real phi_r = phi[r];

    if (apply_truncation == 1) {
      // Truncated NB draw via rejection sampling
      while (y_test_rep[t] == 0)
        y_test_rep[t] = neg_binomial_2_rng(lambda_test[t], phi_r);
    } else {
      // Regular NB draw
      y_test_rep[t] = neg_binomial_2_rng(lambda_test[t], phi_r);
    }
  }
}

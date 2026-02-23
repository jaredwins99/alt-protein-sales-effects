// model_multilevel_transfer_customer_gaussian.stan
//
// Gaussian demeaning variant of the multilevel INGARCH model (_opt.stan).
//
// PURPOSE: Customer fixed-effects via demeaning for analyses A5/A6.
// After within-customer demeaning and aggregation to restaurant-day level,
// outcomes are continuous (centered ~0, can be negative).
//
// KEY CHANGES FROM _opt.stan (NegBin model):
//   1. Likelihood:    NegBin        -> Gaussian (normal)
//   2. Link function: log link      -> identity link (mu = nu, not exp(nu))
//   3. AR lags:       log1p(y)      -> y directly (outcomes can be negative)
//   4. Dispersion:    phi (NegBin)  -> sigma (Gaussian SD), same hierarchical structure
//   5. y_train/y_test: int arrays   -> real vectors (continuous demeaned values)
//   6. y_rep:         int (NegBin)  -> real (Gaussian)
//
// UNCHANGED:
//   - Entire multilevel exposure structure (gamma, eta, mu_gamma, sigma_gamma)
//   - Multilevel covariate structure (beta)
//   - All hyperprior scales for beta and gamma
//   - Sequential INGARCH loop structure (data is restaurant-day level)
//   - tanh(-1,1) constraint on alpha/delta for stationarity

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

  // CHANGED: y_train and y_test are now real vectors (continuous demeaned outcomes)
  // instead of int arrays (non-negative counts) as in _opt.stan

  // Train data
  int<lower=1> N_train;
  matrix[N_train, J] X_train;                            // Design matrix (train)
  vector[N_train] y_train;                                // CHANGED: int array -> vector (demeaned, continuous)
  array[R] int train_start_idx;
  array[R] int train_end_idx;
  array[N_train] int<lower=1,upper=R> idx_to_rest_train; // Mapping from the concatenated index to the restaurants

  // Test data
  int<lower=1> N_test;
  matrix[N_test, J] X_test;                              // Design matrix (test)
  vector[N_test] y_test;                                  // CHANGED: int array -> vector (demeaned, continuous)
  array[R] int test_start_idx;
  array[R] int test_end_idx;
  array[N_test] int<lower=1,upper=R> idx_to_rest_test;   // Mapping from the concatenated index to the restaurants

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
  // CHANGED: phi -> sigma (Gaussian SD instead of NegBin dispersion)
  real<lower=0> mu_sigma_log_scale;
  real<lower=0> sigma_sigma_log_scale;

  // Scales for non-centered deviates (default 1.0 for std_normal)
  // Set > 1 for less informative priors on restaurant-specific effects
  real<lower=0> z_eta_scale;           // Between-restaurant exposure deviates
  real<lower=0> z_gamma_scale;         // Within-restaurant exposure deviates
  real<lower=0> z_beta_scale;          // Restaurant-specific covariate deviates
  real<lower=0> z_alpha_scale;          // Lagged outcome deviates (alpha)
  real<lower=0> z_delta_scale;          // Lagged intensity deviates (delta)
  // CHANGED: z_phi_scale -> z_sigma_scale
  real<lower=0> z_sigma_scale;          // Gaussian SD deviates (was: dispersion deviates phi)
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
  // CHANGED: mu_phi_log -> mu_sigma_log (Gaussian SD)
  real mu_sigma_log;

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
  // CHANGED: sigma_phi_log -> sigma_sigma_log
  real<lower=0> sigma_sigma_log;

  // ──────────────────────────────────
  //         Local Estimates
  // ──────────────────────────────────
  // (random effect part of pooled or unpooled estimates)

  // Predictors
  vector[R] z_beta_intercept;
  matrix[K_beta_random, R] z_beta_random;

  // Exposures
  matrix[M, R] z_eta;                                   // ESTIMATES OF SECONDARY INTEREST: uncentered per-restaurant effects (deviates for Level 2)

  // INGARCH params
  matrix[K_alpha_random, R] z_alpha_random;
  matrix[K_delta_random, R] z_delta_random;
  // CHANGED: z_phi_log -> z_sigma_log
  vector[R] z_sigma_log;

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
        matrix[K_alpha_random, R] alpha_random_raw_r = diag_pre_multiply(sigma_alpha_random, z_alpha_random)
                                                    + rep_matrix(mu_alpha_random_raw, R);
        for (r in 1:R)
          alpha_raw[idx_alpha_random, r] = alpha_random_raw_r[, r];
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
        matrix[K_delta_random, R] delta_random_raw_r = diag_pre_multiply(sigma_delta_random, z_delta_random)
                                                    + rep_matrix(mu_delta_random_raw, R);
        for (r in 1:R)
          delta_raw[idx_delta_random, r] = delta_random_raw_r[, r];
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
  //       Gaussian SD (was: Dispersion)
  // ──────────────────────────────────

  // CHANGED: phi (NegBin dispersion) -> sigma (Gaussian SD)
  // Same noncentered parametrization on the log scale
  vector<lower=0>[R] sigma = exp(mu_sigma_log + sigma_sigma_log * z_sigma_log);

  // ──────────────────────────────────
  //      INGARCH Structural Model
  // ──────────────────────────────────

  vector[N_train] nu;
  // CHANGED: removed lambda = exp(nu); using identity link instead of log link
  // mu = nu directly (demeaned data is centered around 0, can be negative)
  vector[N_train] mu;

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
          if (t - lag >= r_start)
            // CHANGED: log1p(y_train[t - lag]) -> y_train[t - lag]
            // Demeaned outcomes are continuous and can be negative,
            // so log1p is inappropriate.  Use direct lagged value.
            nu[t] += alpha_r[i] * y_train[t - lag];
        }
      }

      // Latent intensity lags (unchanged)
      if (0 < q_effective) {
        for (j in 1:q_effective) {
          int lag = effective_lags_delta[j];
          if (t - lag >= r_start)
            nu[t] += delta_r[j] * nu[t - lag];
        }
      }
    }
  }
  // CHANGED: identity link instead of log link
  // In _opt.stan: lambda = exp(nu)
  // Here: mu = nu (identity link, since demeaned data is centered around 0)
  mu = nu;
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
  // CHANGED: mu_phi_log -> mu_sigma_log
  mu_sigma_log ~ normal(0, mu_sigma_log_scale);

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
  // CHANGED: sigma_phi_log -> sigma_sigma_log
  sigma_sigma_log ~ student_t(3, 0, sigma_sigma_log_scale);

  // ──────────────────────────────────
  //        Local Priors
  // ──────────────────────────────────
  // (fixed effect part of pooled or unpooled estimates)

  // Predictors
  z_beta_intercept ~ normal(0, z_beta_scale);
  to_vector(z_beta_random) ~ normal(0, z_beta_scale);

  // Exposures
  to_vector(z_eta) ~ normal(0, z_eta_scale);  // Prior for non-centered deviates

  // INGARCH params
  to_vector(z_alpha_random) ~ normal(0, z_alpha_scale);
  to_vector(z_delta_random) ~ normal(0, z_delta_scale);
  // CHANGED: z_phi_log -> z_sigma_log
  z_sigma_log ~ normal(0, z_sigma_scale);

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
  //          (Gaussian)
  // ──────────────────────────────────

  // CHANGED: NegBin -> Gaussian likelihood
  // In _opt.stan: y_train ~ neg_binomial_2(lambda, phi[idx_to_rest_train]);
  // Here: Gaussian with identity link on demeaned (continuous) outcomes
  y_train ~ normal(mu, sigma[idx_to_rest_train]);
}

generated quantities {
  // ──────────────────────────────────
  //        Train Predictions
  // ──────────────────────────────────

  // CHANGED: y_rep is now a real vector (was int array in _opt.stan)
  vector[N_train] y_rep;                     // Outcome predictions (train)
  vector[N_train] log_lik;                    // Pointwise log-likelihood

  // Pointwise log_lik and posterior predictive
  for (t in 1:N_train) {
    int r = idx_to_rest_train[t];             // Identify the restaurant
    // CHANGED: phi_r -> sigma_r
    real sigma_r = sigma[r];

    // CHANGED: neg_binomial_2_rng -> normal_rng
    y_rep[t] = normal_rng(mu[t], sigma_r);
    // CHANGED: neg_binomial_2_lpmf -> normal_lpdf
    log_lik[t] = normal_lpdf(y_train[t] | mu[t], sigma_r);
  }

  // ──────────────────────────────────
  //        Test Predictions
  // ──────────────────────────────────

  // CHANGED: y_test_rep is now a real vector (was int array)
  vector[N_test] y_test_rep;                 // Outcome predictions (test)
  // CHANGED: lambda_test -> mu_test (identity link)
  vector[N_test] mu_test;
  vector[N_test] nu_test;
  for (r in 1:R) {

    // Identify which indices in the concatenated (long-style) data are which restaurant
    int r_train_end_idx = train_end_idx[r];
    int r_test_start_idx = test_start_idx[r];
    int r_test_end_idx = test_end_idx[r];

    // Identify the parameters for the restaurant
    vector[J] beta_r = beta[, r];
    vector[p_effective] alpha_r = alpha[, r];
    vector[q_effective] delta_r = delta[, r];
    // CHANGED: phi_r -> sigma_r
    real sigma_r = sigma[r];

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
          // CHANGED: log1p(y_test[...]) -> y_test[...] (direct lagged value)
          if (lag < current_pos_in_test)
            nu_test[t_test_idx] += alpha_r[i] * y_test[lag_source_idx_test];

          // Use training data if we aren't far enough into the test data
          else {
            int train_lag_offset = lag - current_pos_in_test;
            int lag_source_idx_train = r_train_end_idx - train_lag_offset;
            // CHANGED: log1p(y_train[...]) -> y_train[...] (direct lagged value)
            if (lag_source_idx_train >= train_start_idx[r] && lag_source_idx_train <= r_train_end_idx)
              nu_test[t_test_idx] += alpha_r[i] * y_train[lag_source_idx_train];
          }
        }
      }

      // Latent intensity lags (unchanged)
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

      // ──────────────────────────────────
      //    INGARCH Distributional Model
      //          (Gaussian)
      // ──────────────────────────────────

      // CHANGED: identity link instead of log link
      // In _opt.stan: lambda_test[t_test_idx] = exp(nu_test[t_test_idx]);
      mu_test[t_test_idx] = nu_test[t_test_idx];
      // CHANGED: neg_binomial_2_rng -> normal_rng
      y_test_rep[t_test_idx] = normal_rng(mu_test[t_test_idx], sigma_r);
    }
  }
}

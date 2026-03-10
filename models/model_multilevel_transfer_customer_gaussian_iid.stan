// model_multilevel_transfer_customer_gaussian_iid.stan
//
// Transaction-level Gaussian IID variant (no INGARCH/AR/MA).
//
// PURPOSE: Customer fixed-effects via pre-period demeaning at the transaction
// level for analyses A5/A6. Each observation is one transaction (order),
// with outcome = sum of items in order, demeaned by customer's pre-exposure mean.
//
// KEY CHANGES FROM _customer_gaussian.stan (Gaussian INGARCH):
//   1. INGARCH removed: No alpha (outcome lags), delta (latent intensity lags)
//   2. Linear predictor: Fully vectorized (no sequential loop)
//   3. Data level: Transaction-level (not restaurant-day aggregate)
//
// UNCHANGED:
//   - Gaussian likelihood with identity link (mu = nu)
//   - Per-restaurant sigma (hierarchical Gaussian SD)
//   - Entire multilevel exposure structure (gamma, eta, mu_gamma, sigma_gamma)
//   - Multilevel covariate structure (beta)
//   - All hyperprior scales for beta and gamma

data {
  // ──────────────────────────────────
  //             Metadata
  // ──────────────────────────────────

  // Size of design matrix
  int<lower=1> R;                                       // # of restaurants
  int<lower=1> J;                                       // # of predictors
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

  // ──────────────────────────────────
  //                Data
  // ──────────────────────────────────

  // y_train and y_test are real vectors (continuous pre-period-demeaned outcomes)

  // Train data
  int<lower=1> N_train;
  matrix[N_train, J] X_train;                            // Design matrix (train)
  vector[N_train] y_train;                                // Pre-period demeaned, continuous
  array[R] int train_start_idx;
  array[R] int train_end_idx;
  array[N_train] int<lower=1,upper=R> idx_to_rest_train; // Mapping from the concatenated index to the restaurants

  // Test data
  int<lower=1> N_test;
  matrix[N_test, J] X_test;                              // Design matrix (test)
  vector[N_test] y_test;                                  // Pre-period demeaned, continuous
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

  // Gaussian SD
  real<lower=0> mu_sigma_log_scale;
  real<lower=0> sigma_sigma_log_scale;

  // Scales for non-centered deviates (default 1.0 for std_normal)
  real<lower=0> z_eta_scale;           // Between-restaurant exposure deviates
  real<lower=0> z_gamma_scale;         // Within-restaurant exposure deviates
  real<lower=0> z_beta_scale;          // Restaurant-specific covariate deviates
  real<lower=0> z_sigma_scale;         // Gaussian SD deviates
}

parameters {
  // ──────────────────────────────────
  //         Global Estimates
  // ──────────────────────────────────

  // Predictors
  real mu_beta_intercept;
  vector[K_beta_random] mu_beta_random;
  vector[K_beta_fixed] mu_beta_fixed;

  // Exposures
  vector[M] mu_gamma;                                   // ESTIMATE OF PRIMARY INTEREST: global mean exposure effect

  // Gaussian SD
  real mu_sigma_log;

  // ──────────────────────────────────
  //   Between Restaurant Variability
  // ──────────────────────────────────

  // Predictors
  real<lower=0> sigma_beta_intercept;
  vector<lower=0>[K_beta_random] sigma_beta_random;

  // Exposures
  vector<lower=0>[M] sigma_gamma_between;               // SD OF INTEREST: exposure effects ACROSS restaurants

  // Gaussian SD
  real<lower=0> sigma_sigma_log;

  // ──────────────────────────────────
  //         Local Estimates
  // ──────────────────────────────────

  // Predictors
  vector[R] z_beta_intercept;
  matrix[K_beta_random, R] z_beta_random;

  // Exposures
  matrix[M, R] z_eta;                                   // ESTIMATES OF SECONDARY INTEREST

  // Gaussian SD
  vector[R] z_sigma_log;

  // ──────────────────────────────────
  //   Within Restaurant Variability
  // ──────────────────────────────────

  // Exposures
  vector<lower=0>[M] sigma_gamma_within;                // SD OF INTEREST: exposure effects WITHIN a restaurant

  // ──────────────────────────────────
  //        Doubly Local Estimates
  // ──────────────────────────────────

  // Exposures
  vector[K_exposure] z_gamma;                           // ESTIMATES OF TERTIARY INTEREST
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

    // Noncentered parametrization
    vector[R] beta_intercept_r = mu_beta_intercept + sigma_beta_intercept * z_beta_intercept;

    // Insert them into the respective indices of beta
    beta[idx_intercept] = beta_intercept_r';

    if (0 < K_beta_random) {
      matrix[K_beta_random, R] beta_random_r = diag_pre_multiply(sigma_beta_random, z_beta_random)
                                             + rep_matrix(mu_beta_random, R);
      for (r in 1:R)
        beta[idx_beta_random, r] = beta_random_r[, r];
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

    if (0 < K_exposure) {
      vector[K_exposure] gamma;
      array[M, R] int rest_has_param;
      array[M] int restaurants_per_param;
      array[M, R] int exposures_per_rest;

      // Initialize
      for (param in 1:M) {
        restaurants_per_param[param] = 0;
        for (r in 1:R) {
          rest_has_param[param, r] = 0;
          exposures_per_rest[param, r] = 0;
        }
      }

      // Mark which restaurants and exposures have each param
      for (k in 1:K_exposure) {
        int param = expo_to_param[k];
        int r = expo_to_rest[k];
        rest_has_param[param, r] = 1;
        exposures_per_rest[param, r] += 1;
      }

      // Count restaurants per parameter
      for (param in 1:M)
        for (r in 1:R)
          restaurants_per_param[param] += rest_has_param[param, r];

      // Level 2: Construct per-restaurant mean effects
      for (param in 1:M) {
        for (r in 1:R) {
          if (restaurants_per_param[param] > 1)
            eta[param, r] = mu_gamma[param] + sigma_gamma_between[param] * z_eta[param, r];
          else
            eta[param, r] = mu_gamma[param];
        }
      }

      // Level 1: Construct per-exposure coefs (gamma)
      for (k in 1:K_exposure) {
        int r = expo_to_rest[k];
        int param = expo_to_param[k];

        if (exposures_per_rest[param, r] > 1)
          gamma[k] = eta[param, r] + sigma_gamma_within[param] * z_gamma[k];
        else
          gamma[k] = eta[param, r];

        beta[idx_exposure[k], r] = gamma[k];
      }
    } else {
      eta = rep_matrix(mu_gamma, R);
    }
  }

  // ──────────────────────────────────
  //       Gaussian SD
  // ──────────────────────────────────

  vector<lower=0>[R] sigma = exp(mu_sigma_log + sigma_sigma_log * z_sigma_log);

  // ──────────────────────────────────
  //       Linear Predictor (IID)
  // ──────────────────────────────────
  // Fully vectorized — no INGARCH sequential lags

  vector[N_train] nu;
  vector[N_train] mu;

  for (r in 1:R) {
    int r_start = train_start_idx[r];
    int r_end = train_end_idx[r];
    vector[J] beta_r = beta[, r];
    nu[r_start:r_end] = X_train[r_start:r_end] * beta_r;
  }
  // Identity link: mu = nu (demeaned data centered around 0)
  mu = nu;
}

model {
  // ──────────────────────────────────
  //        Global Priors
  // ──────────────────────────────────

  // Predictors
  mu_beta_intercept ~ normal(0, 5);
  mu_beta_random ~ double_exponential(0, mu_beta_scale);
  mu_beta_fixed ~ double_exponential(0, mu_beta_scale);

  // Exposures
  mu_gamma ~ normal(0, mu_gamma_scale);

  // Gaussian SD
  mu_sigma_log ~ normal(0, mu_sigma_log_scale);

  // ──────────────────────────────────
  //      Between Restaurant Priors
  // ──────────────────────────────────

  // Predictors
  sigma_beta_intercept ~ student_t(3, 0, sigma_beta_scale);
  sigma_beta_random ~ student_t(3, 0, sigma_beta_scale);

  // Exposures
  sigma_gamma_between ~ student_t(3, 0, sigma_gamma_between_scale);

  // Gaussian SD
  sigma_sigma_log ~ student_t(3, 0, sigma_sigma_log_scale);

  // ──────────────────────────────────
  //        Local Priors
  // ──────────────────────────────────

  // Predictors
  z_beta_intercept ~ normal(0, z_beta_scale);
  to_vector(z_beta_random) ~ normal(0, z_beta_scale);

  // Exposures
  to_vector(z_eta) ~ normal(0, z_eta_scale);

  // Gaussian SD
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
  z_gamma ~ normal(0, z_gamma_scale);

  // ──────────────────────────────────
  //       Gaussian Likelihood
  // ──────────────────────────────────

  y_train ~ normal(mu, sigma[idx_to_rest_train]);
}

generated quantities {
  // ──────────────────────────────────
  //        Train Predictions
  // ──────────────────────────────────

  vector[N_train] y_rep;
  vector[N_train] log_lik;

  for (t in 1:N_train) {
    int r = idx_to_rest_train[t];
    real sigma_r = sigma[r];
    y_rep[t] = normal_rng(mu[t], sigma_r);
    log_lik[t] = normal_lpdf(y_train[t] | mu[t], sigma_r);
  }

  // ──────────────────────────────────
  //        Test Predictions
  // ──────────────────────────────────

  vector[N_test] y_test_rep;
  vector[N_test] mu_test;
  vector[N_test] nu_test;

  for (r in 1:R) {
    int r_test_start_idx = test_start_idx[r];
    int r_test_end_idx = test_end_idx[r];
    vector[J] beta_r = beta[, r];
    real sigma_r = sigma[r];

    // Fully vectorized: no sequential lags
    nu_test[r_test_start_idx:r_test_end_idx] = X_test[r_test_start_idx:r_test_end_idx] * beta_r;

    // Identity link + posterior predictive
    for (t_test_idx in r_test_start_idx:r_test_end_idx) {
      mu_test[t_test_idx] = nu_test[t_test_idx];
      y_test_rep[t_test_idx] = normal_rng(mu_test[t_test_idx], sigma_r);
    }
  }
}

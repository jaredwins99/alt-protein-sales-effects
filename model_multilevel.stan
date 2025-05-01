// Bayesian Multilevel INGARCH-like Model w/ Selective Random Slopes

data {
  // Restaurant Structure
  int<lower=1> R;                 // Number of restaurants

  // Covariate Structure (Indices MUST match columns in X)
  int<lower=1> J;                 // Total number of covariates (incl. intercept)
  int<lower=1> idx_intercept;     // Index for intercept column (usually 1)
  int<lower=1> K_beta_random;     // Number of beta SLOPES with random effects (e.g., 6)
  array[K_beta_random] int idx_beta_random; // Indices for beta random slope columns
  int<lower=1> K_beta_fixed;      // Number of beta SLOPES with fixed effects
  array[K_beta_fixed] int idx_beta_fixed;   // Indices for beta fixed slope columns

  // Lag Structure (Indices based on position in effective_lags arrays)
  int<lower=1> p_effective;       // Number of effective lags for counts
  array[p_effective] int effective_lags_alpha; // List of effective lag indices
  int<lower=1> K_alpha_random;    // Number of alpha lags with random effects (e.g., 2)
  array[K_alpha_random] int idx_alpha_random; // Indices in effective_lags_alpha for random effects
  int<lower=1> K_alpha_fixed;     // Number of alpha lags with fixed effects
  array[K_alpha_fixed] int idx_alpha_fixed;  // Indices in effective_lags_alpha for fixed effects

  int<lower=1> q_effective;       // Number of effective lags for intensity
  array[q_effective] int effective_lags_delta; // List of effective lag indices
  int<lower=1> K_delta_random;    // Number of delta lags with random effects (e.g., 2)
  array[K_delta_random] int idx_delta_random; // Indices in effective_lags_delta for random effects
  int<lower=1> K_delta_fixed;     // Number of delta lags with fixed effects
  array[K_delta_fixed] int idx_delta_fixed;  // Indices in effective_lags_delta for fixed effects

  // Training Data (Long Format)
  int<lower=1> N_train;           // TOTAL number of time points across ALL restaurants
  matrix[N_train, J] X_train;     // Covariate matrix (long format, columns ordered as per indices)
  array[N_train] int y_train;     // Observed counts (long format)
  array[N_train] int<lower=1, upper=R> restaurant_id_train; // Restaurant ID for each obs
  array[R] int train_start_idx;   // Start index for each restaurant in train data
  array[R] int train_end_idx;     // End index for each restaurant in train data

  // Testing Data (Long Format)
  int<lower=1> N_test;            // TOTAL number of test time points across ALL restaurants
  matrix[N_test, J] X_test;       // Covariate matrix for test data (long format)
  array[N_test] int y_test;       // Observed counts for test data (long format)
  array[N_test] int<lower=1, upper=R> restaurant_id_test; // Restaurant ID for each obs
  array[R] int test_start_idx;    // Start index for each restaurant in test data
  array[R] int test_end_idx;      // End index for each restaurant in test data

  // Prior parameter inputs (scales for hyperpriors)
  real<lower=0> mu_beta_scale;
  real<lower=0> sigma_beta_scale; // Scale for sigma priors (e.g., exponential rate)
  real<lower=0> mu_alpha_scale;
  real<lower=0> sigma_alpha_scale;
  real<lower=0> mu_delta_scale;
  real<lower=0> sigma_delta_scale;
  real<lower=0> mu_phi_log_scale;
  real<lower=0> sigma_phi_log_scale;
}

parameters {
  // --- Population Means ---
  // Betas
  real mu_beta_intercept;           // Mean for intercept
  vector[K_beta_random] mu_beta_random; // Means for random slopes
  vector[K_beta_fixed] mu_beta_fixed;   // Values for fixed slopes (population mean = value)
  // Alphas (unconstrained scale)
  vector[K_alpha_random] mu_alpha_random_raw;
  vector[K_alpha_fixed] mu_alpha_fixed_raw;
  // Deltas (unconstrained scale)
  vector[K_delta_random] mu_delta_random_raw;
  vector[K_delta_fixed] mu_delta_fixed_raw;
  // Phi (log scale)
  real mu_phi_log;

  // --- Population Standard Deviations (only for random effects) ---
  real<lower=0> sigma_beta_intercept;
  vector<lower=0>[K_beta_random] sigma_beta_random;
  vector<lower=0>[K_alpha_random] sigma_alpha_random;
  vector<lower=0>[K_delta_random] sigma_delta_random;
  real<lower=0> sigma_phi_log;

  // --- Standardized Restaurant-Specific Deviations (only for random effects) ---
  vector[R] z_beta_intercept;          // For intercept
  matrix[K_beta_random, R] z_beta_random; // For random beta slopes
  matrix[K_alpha_random, R] z_alpha_random; // For random alpha effects
  matrix[K_delta_random, R] z_delta_random; // For random delta effects
  vector[R] z_phi_log;                // For phi
}

transformed parameters {
  // Latent log-intensity and conditional mean for training data
  vector[N_train] nu;      // nu[t] = log(lambda_t)
  vector[N_train] lambda;  // Conditional mean lambda_t = exp(nu[t])

  // --- Reconstruct Restaurant-Specific Parameters ---
  // Phi (vector[R])
  vector<lower=0>[R] phi = exp(mu_phi_log + sigma_phi_log * z_phi_log);

  // Beta (matrix[J, R])
  matrix[J, R] beta;
  { // Temporary scope for intermediate calculations
    vector[R] beta_intercept_r = mu_beta_intercept + sigma_beta_intercept * z_beta_intercept;
    matrix[K_beta_random, R] beta_random_r = diag_pre_multiply(sigma_beta_random, z_beta_random)
                                         + rep_matrix(mu_beta_random, R);

    for (r in 1:R) {
      beta[idx_intercept, r] = beta_intercept_r[r];       // Assign intercept
      beta[idx_beta_random, r] = beta_random_r[, r];    // Assign random slopes
      beta[idx_beta_fixed, r] = mu_beta_fixed;          // Assign fixed slopes (same for all r)
    }
  }

  // Alpha (matrix[p_effective, R], constrained)
  matrix<lower=-1, upper=1>[p_effective, R] alpha;
  { // Temporary scope
    matrix[p_effective, R] alpha_raw; // Unconstrained version
    matrix[K_alpha_random, R] alpha_random_raw_r = diag_pre_multiply(sigma_alpha_random, z_alpha_random)
                                                + rep_matrix(mu_alpha_random_raw, R);

    for (r in 1:R) {
      alpha_raw[idx_alpha_random, r] = alpha_random_raw_r[, r]; // Assign random components
      alpha_raw[idx_alpha_fixed, r] = mu_alpha_fixed_raw;       // Assign fixed components
    }
    alpha = tanh(alpha_raw / 2.0); // Apply constraint element-wise
  }

  // Delta (matrix[q_effective, R], constrained)
  matrix<lower=-1, upper=1>[q_effective, R] delta;
   { // Temporary scope
    matrix[q_effective, R] delta_raw; // Unconstrained version
    matrix[K_delta_random, R] delta_random_raw_r = diag_pre_multiply(sigma_delta_random, z_delta_random)
                                                + rep_matrix(mu_delta_random_raw, R);

    for (r in 1:R) {
      delta_raw[idx_delta_random, r] = delta_random_raw_r[, r]; // Assign random components
      delta_raw[idx_delta_fixed, r] = mu_delta_fixed_raw;       // Assign fixed components
    }
    delta = tanh(delta_raw / 2.0); // Apply constraint element-wise
  }


  // --- Calculate nu and lambda sequentially within each restaurant ---
  // This part is identical to the previous full multilevel model,
  // as it operates on the fully reconstructed beta, alpha, delta matrices.
  for (r in 1:R) {
    int r_start = train_start_idx[r];
    int r_end = train_end_idx[r];
    vector[J] beta_r = beta[, r];             // Params for this restaurant
    vector[p_effective] alpha_r = alpha[, r];
    vector[q_effective] delta_r = delta[, r];

    for (t in r_start:r_end) {
      // Base contribution from covariates
      nu[t] = dot_product(X_train[t], beta_r);

      // Add effect from lagged observed counts (within the same restaurant)
      for (i in 1:p_effective) {
        int lag = effective_lags_alpha[i];
        if (t - lag >= r_start) { // Check if lagged observation is within this restaurant's training period
          nu[t] += alpha_r[i] * log(y_train[t - lag] + 1);
        }
      }

      // Add effect from lagged latent values (within the same restaurant)
      for (j in 1:q_effective) {
        int lag = effective_lags_delta[j];
        if (t - lag >= r_start) { // Check if lagged nu is within this restaurant's training period
          nu[t] += delta_r[j] * nu[t - lag];
        }
      }
    } // end loop over time t for restaurant r
  } // end loop over restaurants r

  // Compute conditional mean (vectorized)
  lambda = exp(nu);
}

model {
  // --- Hyperpriors ---
  // Priors for population means (fixed effects AND means of random effects)
  mu_beta_intercept ~ normal(0, mu_beta_scale); // Adjust scale as needed
  mu_beta_random ~ normal(0, mu_beta_scale);
  mu_beta_fixed ~ normal(0, mu_beta_scale);
  mu_alpha_random_raw ~ normal(0, mu_alpha_scale); // On unconstrained scale
  mu_alpha_fixed_raw ~ normal(0, mu_alpha_scale);  // On unconstrained scale
  mu_delta_random_raw ~ normal(0, mu_delta_scale); // On unconstrained scale
  mu_delta_fixed_raw ~ normal(0, mu_delta_scale);  // On unconstrained scale
  mu_phi_log ~ normal(0, mu_phi_log_scale);

  // Priors for population standard deviations (only for random effects)
  sigma_beta_intercept ~ exponential(sigma_beta_scale); // e.g., exponential(1)
  sigma_beta_random ~ exponential(sigma_beta_scale);
  sigma_alpha_random ~ exponential(sigma_alpha_scale);
  sigma_delta_random ~ exponential(sigma_delta_scale);
  sigma_phi_log ~ exponential(sigma_phi_log_scale);

  // --- Priors for Standardized Deviations (Implied by non-centered parameterization) ---
  z_beta_intercept ~ std_normal();
  to_vector(z_beta_random) ~ std_normal();
  to_vector(z_alpha_random) ~ std_normal();
  to_vector(z_delta_random) ~ std_normal();
  z_phi_log ~ std_normal();

  // --- Likelihood ---
  // Loop through observations and apply likelihood using restaurant-specific phi
  for (t in 1:N_train) {
    int r = restaurant_id_train[t]; // Get restaurant ID for this observation
    // lambda[t] already computed in transformed parameters
    // phi[r] already computed in transformed parameters
    y_train[t] ~ neg_binomial_2(lambda[t], phi[r]);
  }
}

generated quantities {
  // In-sample posterior predictive checks:
  array[N_train] int y_rep;         // Replicated training counts
  vector[N_train] log_lik;      // Pointwise log-likelihoods

  for (t in 1:N_train) {
    int r = restaurant_id_train[t];
    // lambda[t] and phi[r] are available from transformed parameters
    y_rep[t] = neg_binomial_2_rng(lambda[t], phi[r]);
    log_lik[t] = neg_binomial_2_lpmf(y_train[t] | lambda[t], phi[r]);
  }

  // Out-of-sample predictions for test data using a rolling forecast:
  array[N_test] int y_test_rep;      // Predicted counts for test data
  vector[N_test] lambda_test;  // Predicted intensities for test data
  vector[N_test] nu_test;      // Log-scale intensities for test data

  // Note: nu from transformed parameters is needed for lags crossing train/test boundary
  // beta, alpha, delta, phi are available from transformed parameters

  // This prediction logic is identical to the previous full multilevel model,
  // as it uses the fully reconstructed parameters.
  for (t_test_idx in 1:N_test) {
    int r = restaurant_id_test[t_test_idx]; // Restaurant for this test point
    int r_train_end_idx = train_end_idx[r]; // End index of training data for this restaurant
    int r_test_start_idx = test_start_idx[r]; // Start index of test data for this restaurant

    // Get restaurant-specific parameters (already computed in transformed parameters)
    vector[J] beta_r = beta[, r];
    vector[p_effective] alpha_r = alpha[, r];
    vector[q_effective] delta_r = delta[, r];
    real phi_r = phi[r];

    // Calculate nu_test[t_test_idx]
    // Start with the covariate contribution:
    nu_test[t_test_idx] = dot_product(X_test[t_test_idx], beta_r);

    // Add effect from effective lagged observed counts:
    for (i in 1:p_effective) {
      int lag = effective_lags_alpha[i];
      int current_pos_in_test = t_test_idx - r_test_start_idx + 1; // 1-based position within this restaurant's test block
      int lag_source_idx_test = t_test_idx - lag; // Index relative to the start of the *overall* test data block

      if (lag < current_pos_in_test) {
        // Lag comes from within the test set for this restaurant
        nu_test[t_test_idx] += alpha_r[i] * log(y_test[lag_source_idx_test] + 1);
      } else {
        // Lag comes from the training set for this restaurant
        int train_lag_offset = lag - current_pos_in_test; // How many steps back from the end of training
        int lag_source_idx_train = r_train_end_idx - train_lag_offset;
        if (lag_source_idx_train >= train_start_idx[r] && lag_source_idx_train <= r_train_end_idx) { // Check index validity
             nu_test[t_test_idx] += alpha_r[i] * log(y_train[lag_source_idx_train] + 1);
        }
      }
    }

    // Add effect from effective lagged latent values:
    for (j in 1:q_effective) {
      int lag = effective_lags_delta[j];
      int current_pos_in_test = t_test_idx - r_test_start_idx + 1;
      int lag_source_idx_test = t_test_idx - lag;

      if (lag < current_pos_in_test) {
        // Lag comes from within the test set (previous nu_test)
         nu_test[t_test_idx] += delta_r[j] * nu_test[lag_source_idx_test];
      } else {
        // Lag comes from the training set (nu calculated in transformed parameters)
        int train_lag_offset = lag - current_pos_in_test;
        int lag_source_idx_train = r_train_end_idx - train_lag_offset;
         if (lag_source_idx_train >= train_start_idx[r] && lag_source_idx_train <= r_train_end_idx) { // Check index validity
            nu_test[t_test_idx] += delta_r[j] * nu[lag_source_idx_train];
         }
      }
    }

    // Compute lambda_test and generate prediction
    lambda_test[t_test_idx] = exp(nu_test[t_test_idx]);
    y_test_rep[t_test_idx] = neg_binomial_2_rng(lambda_test[t_test_idx], phi_r);
  }
}

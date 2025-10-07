data {
  // ──────────────────────────────────
  //             Metadata
  // ──────────────────────────────────
  
  // Size of design matrix (and higher moments, like lags)
  int<lower=1> R;                                       // # of restaurants
  int<lower=1> J;                                       // # of covariates
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
  
  // Indices for grouping
  array[R] int<lower=1, upper=2> restaurant_to_group;

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
  
  // Test data
  int<lower=1> N_test;
  matrix[N_test, J] X_test;                              // Design matrix (test)
  array[N_test] int y_test;
  array[R] int test_start_idx;
  array[R] int test_end_idx;
  array[N_test] int<lower=1,upper=R> idx_to_rest_test;   // Mapping from the concatenated index to the restaurants
  
  // ──────────────────────────────────
  //         Hyperprior Scales
  // ──────────────────────────────────
  
  // Predictors
  real<lower=0> mu_beta_scale;
  real<lower=0> sigma_beta_scale;
  
  // Predictors (Group 2) -- NEW
  real<lower=0> mu_beta_scale_group2;
  real<lower=0> sigma_beta_scale_group2;

  // Exposures
  real<lower=0> mu_gamma_scale;                          // Prior information about effect size
  real<lower=0> sigma_gamma_between_scale;               // Strength of pooling across restaurants (Level 2)
  real<lower=0> sigma_gamma_within_scale;                // Strength of pooling within restaurant  (Level 1)
  
  // INGARCH: outcomes lags, latent intensities, and dispersion
  real<lower=0> mu_alpha_scale;
  real<lower=0> sigma_alpha_scale;
  real<lower=0> mu_delta_scale;
  real<lower=0> sigma_delta_scale;
  real<lower=0> mu_phi_log_scale;
  real<lower=0> sigma_phi_log_scale;

  // Group 2 Hyperpriors
  real<lower=0> mu_alpha_scale_group2;
  real<lower=0> sigma_alpha_scale_group2;
  real<lower=0> mu_delta_scale_group2;
  real<lower=0> sigma_delta_scale_group2;
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

  // Predictors (Group 2) -- NEW
  real mu_beta_intercept_group2;
  vector[K_beta_random] mu_beta_random_group2;
  
  // Exposures
  vector[M] mu_gamma;                                       // ESTIMATE OF PRIMARY INTEREST: global mean exposure effect (center for Level 2)
  
  // INGARCH params
  vector[K_alpha_random] mu_alpha_random_raw;               // Raw will be tanh transformed
  vector[K_alpha_fixed] mu_alpha_fixed_raw;             
  vector[K_delta_random] mu_delta_random_raw;
  vector[K_delta_fixed] mu_delta_fixed_raw;
  real mu_phi_log;

  // Group 2 INGARCH params
  vector[K_alpha_random] mu_alpha_random_raw_group2;
  vector[K_delta_random] mu_delta_random_raw_group2;

  // ──────────────────────────────────
  //   Between Restaurant Variability
  // ──────────────────────────────────
  
  // Predictors
  real<lower=0> sigma_beta_intercept;
  vector<lower=0>[K_beta_random] sigma_beta_random;

  // Predictors (Group 2) -- NEW
  real<lower=0> sigma_beta_intercept_group2;
  vector<lower=0>[K_beta_random] sigma_beta_random_group2;
  
  // Exposures
  vector<lower=0>[M] sigma_gamma_between;                   // SD OF INTEREST: exposure effects ACROSS restaurants (scale for Level 2)
  
  // INGARCH params
  vector<lower=0>[K_alpha_random] sigma_alpha_random;
  vector<lower=0>[K_delta_random] sigma_delta_random;
  real<lower=0> sigma_phi_log;

  // Group 2 INGARCH params
  vector<lower=0>[K_alpha_random] sigma_alpha_random_group2;
  vector<lower=0>[K_delta_random] sigma_delta_random_group2;

  // ──────────────────────────────────
  //         Local Estimates  
  // ──────────────────────────────────
  // (random effect part of pooled or unpooled estimates)
  
  // Predictors
  vector[R] z_beta_intercept;
  matrix[K_beta_random, R] z_beta_random;
  
  // Exposures
  matrix[M, R] z_eta;                                     // ESTIMATES OF SECONDARY INTEREST: uncentered per-restaurant effects (deviates for Level 2)
  
  // INGARCH params
  matrix[K_alpha_random, R] z_alpha_random;
  matrix[K_delta_random, R] z_delta_random;
  vector[R] z_phi_log;
  
  // ──────────────────────────────────
  //   Within Restaurant Variability
  // ──────────────────────────────────
  
  // Exposures
  vector<lower=0>[M] sigma_gamma_within;                    // SD OF INTEREST: exposure effects WITHIN a restaurant (scale for Level 1)

  // ──────────────────────────────────
  //        Doubly Local Estimates  
  // ──────────────────────────────────
  
  // Exposures
  vector[K_exposure] z_gamma;                          // ESTIMATES OF TERTIARY INTEREST: uncentered per-exposure effects (deviates for Level 1)
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
    for (r in 1:R)
      beta[idx_intercept, r] = beta_intercept_r[r];

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
    
    // Level 2 Construct per-restaurant mean effects
    eta = rep_matrix(mu_gamma, R) + diag_pre_multiply(sigma_gamma_between, z_eta);
    
    // Level 1 Construct per-exposure coefs (gamma)
    if (0 < K_exposure) {
      vector[K_exposure] gamma;  
      for (k in 1:K_exposure) { // Remember that this is the total exposures across restaurants
      
        int r = expo_to_rest[k];
        int param = expo_to_param[k];
      
        gamma[k] = eta[param, r] + sigma_gamma_within[param] * z_gamma[k];
        beta[idx_exposure[k], r] = gamma[k]; // Insert into beta
      }
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
        matrix[K_alpha_random, R] alpha_random_raw_r;
        for (r in 1:R) {
          vector[K_alpha_random] z_r = z_alpha_random[, r];
          if (restaurant_to_group[r] == 1) {
            alpha_random_raw_r[, r] = (sigma_alpha_random .* z_r) + mu_alpha_random_raw;
          } else {
            alpha_random_raw_r[, r] = (sigma_alpha_random_group2 .* z_r) + mu_alpha_random_raw_group2;
          }
        }
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
        matrix[K_delta_random, R] delta_random_raw_r;
        for (r in 1:R) {
          vector[K_delta_random] z_r = z_delta_random[, r];
          if (restaurant_to_group[r] == 1) {
            delta_random_raw_r[, r] = (sigma_delta_random .* z_r) + mu_delta_random_raw;
          } else {
            delta_random_raw_r[, r] = (sigma_delta_random_group2 .* z_r) + mu_delta_random_raw_group2;
          }
        }
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
  //            Dispersion 
  // ──────────────────────────────────
  
  // Noncentered parametrization: instead of sampling a normal, we sample a standard normal and multiply it by sd
  vector<lower=0>[R] phi = exp(mu_phi_log + sigma_phi_log * z_phi_log);
  
  
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
    
    // For every time point within restaurant r
    for (t in r_start:r_end) {
      
      // Covariates
      nu[t] = dot_product(X_train[t], beta_r);
      
      // Outcome lags
      if (0 < p_effective) {
        for (i in 1:p_effective) {
          int lag = effective_lags_alpha[i];
          if (t - lag >= r_start)
            nu[t] += alpha_r[i] * log(y_train[t - lag] + 1);  // Log parametrization
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
  mu_beta_intercept ~ normal(0, mu_beta_scale);             // No shrinkage for the intercept
  mu_beta_random ~ double_exponential(0, mu_beta_scale);
  mu_beta_fixed ~ double_exponential(0, mu_beta_scale);
  
  // Predictors (Group 2) -- NEW
  mu_beta_intercept_group2 ~ normal(0, mu_beta_scale_group2);
  mu_beta_random_group2 ~ double_exponential(0, mu_beta_scale_group2);

  // Exposures
  mu_gamma ~ normal(0, mu_gamma_scale);                     // No shrinkage for the exposures
  
  // INGARCH params
  mu_alpha_random_raw ~ double_exponential(0, mu_alpha_scale);
  mu_alpha_fixed_raw ~ double_exponential(0, mu_alpha_scale);
  mu_delta_random_raw ~ double_exponential(0, mu_delta_scale);
  mu_delta_fixed_raw ~ double_exponential(0, mu_delta_scale);
  mu_phi_log ~ normal(0, mu_phi_log_scale);
  
  // Group 2 INGARCH Priors
  mu_alpha_random_raw_group2 ~ double_exponential(0, mu_alpha_scale_group2);
  mu_delta_random_raw_group2 ~ double_exponential(0, mu_delta_scale_group2);

  // ──────────────────────────────────
  //      Between Restaurant Priors 
  // ──────────────────────────────────
  
  // Predictors
  sigma_beta_intercept ~ exponential(sigma_beta_scale);
  sigma_beta_random ~ exponential(sigma_beta_scale);
  
  // Predictors (Group 2) -- NEW
  sigma_beta_intercept_group2 ~ exponential(sigma_beta_scale_group2);
  sigma_beta_random_group2 ~ exponential(sigma_beta_scale_group2);

  // Exposures
  sigma_gamma_between ~ normal(0, sigma_gamma_between_scale);
  
  // INGARCH params
  sigma_alpha_random ~ exponential(sigma_alpha_scale);
  sigma_delta_random ~ exponential(sigma_delta_scale);
  sigma_phi_log ~ exponential(sigma_phi_log_scale);

  // Group 2 INGARCH Priors
  sigma_alpha_random_group2 ~ exponential(sigma_alpha_scale_group2);
  sigma_delta_random_group2 ~ exponential(sigma_delta_scale_group2);
  
  // ──────────────────────────────────
  //        Local Priors  
  // ──────────────────────────────────
  // (fixed effect part of pooled or unpooled estimates)
  
  // Predictors
  z_beta_intercept ~ std_normal();
  to_vector(z_beta_random) ~ std_normal();
  
  // Exposures
  to_vector(z_eta) ~ std_normal();  // Prior for non-centered deviates
  
  // INGARCH params
  to_vector(z_alpha_random) ~ std_normal();
  to_vector(z_delta_random) ~ std_normal();
  z_phi_log ~ std_normal();
  
  // ──────────────────────────────────
  //   Within Restaurant Variability
  // ──────────────────────────────────
  
  // Exposures
  sigma_gamma_within ~ normal(0, sigma_gamma_within_scale);
  
  // ──────────────────────────────────
  //        Doubly Local Priors  
  // ──────────────────────────────────
  
  // Exposures
  z_gamma ~ std_normal();  // Prior for non-centered deviates
  
  // ──────────────────────────────────
  //    INGARCH Distributional Model  
  // ──────────────────────────────────
  
  // Back to the overall index, so we need the index to restaurant mapping
  for (t in 1:N_train) {
    int r = idx_to_rest_train[t];                   // Identify the restaurant
    y_train[t] ~ neg_binomial_2(lambda[t], phi[r]); // Emission distribution
  }
}

generated quantities {
  // ──────────────────────────────────
  //        Train Predictions  
  // ──────────────────────────────────
  
  array[N_train] int y_rep;                   // Outcome predictions (train)
  vector[N_train] log_lik;                    // Pointwise log-likelihood
  for (t in 1:N_train) {
    int r = idx_to_rest_train[t];             // Identify the restaurant
    y_rep[t] = neg_binomial_2_rng(lambda[t], phi[r]); // Random sample
    log_lik[t] = neg_binomial_2_lpmf(y_train[t] | lambda[t], phi[r]);
  }
  
  // ──────────────────────────────────
  //        Test Predictions  
  // ──────────────────────────────────
  
  array[N_test] int y_test_rep;               // Outcome predictions (test)
  vector[N_test] lambda_test;
  vector[N_test] nu_test;
  for (t_test_idx in 1:N_test) {
    
    // Identify which indices in the concatenated (long-style) data are which restaurant
    int r = idx_to_rest_test[t_test_idx];     // Identify the restaurant
    int r_train_end_idx = train_end_idx[r];
    int r_test_start_idx = test_start_idx[r];
    
    // Identify the parameters for the restaurant
    vector[J] beta_r = beta[, r];
    vector[p_effective] alpha_r = alpha[, r];
    vector[q_effective] delta_r = delta[, r];
    real phi_r = phi[r];
    
    // ──────────────────────────────────
    //     INGARCH Structural Model  
    // ──────────────────────────────────
    
    // Predictors
    nu_test[t_test_idx] = dot_product(X_test[t_test_idx], beta_r);
    
    // Outcome lags
    if (0 < p_effective) {
      for (i in 1:p_effective) {
        
        // --- Identify lag and indices
        int lag = effective_lags_alpha[i];
        int current_pos_in_test = t_test_idx - r_test_start_idx + 1; // Index to restaurant mapping
        int lag_source_idx_test = t_test_idx - lag;
        
        // --- IMPORTANT: we use observed y_test not y_test_rep for single-step rolling forecasting
        if (lag < current_pos_in_test)
          nu_test[t_test_idx] += alpha_r[i] * log(y_test[lag_source_idx_test] + 1);
        
        // --- Use training data if we aren't far enough into the test data
        else {
          int train_lag_offset = lag - current_pos_in_test;
          int lag_source_idx_train = r_train_end_idx - train_lag_offset;
          if (lag_source_idx_train >= train_start_idx[r] && lag_source_idx_train <= r_train_end_idx)
            nu_test[t_test_idx] += alpha_r[i] * log(y_train[lag_source_idx_train] + 1);
        }
      }
    }
    
    // Latent intensity lags
    if (0 < q_effective) {
      for (j in 1:q_effective) {
        
        // --- Identify lag and indices
        int lag = effective_lags_delta[j];
        int current_pos_in_test = t_test_idx - r_test_start_idx + 1;
        int lag_source_idx_test = t_test_idx - lag;
        
        // --- IMPORTANT: generated, rather than observed, nu_test is used regardless
        if (lag < current_pos_in_test)
          nu_test[t_test_idx] += delta_r[j] * nu_test[lag_source_idx_test];
        
        // --- Use training estimates if we aren't far enough into the test data
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
    // ──────────────────────────────────
    
    lambda_test[t_test_idx] = exp(nu_test[t_test_idx]);
    y_test_rep[t_test_idx] = neg_binomial_2_rng(lambda_test[t_test_idx], phi_r);
  }
}

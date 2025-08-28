data {
  int<lower=1> R;
  int<lower=1> J;
  int<lower=1> idx_intercept;
  int<lower=1> K_beta_random;
  array[K_beta_random] int idx_beta_random;
  int<lower=1> K_beta_fixed;
  array[K_beta_fixed] int idx_beta_fixed;
  int<lower=1> p_effective;
  array[p_effective] int effective_lags_alpha;
  int<lower=1> K_alpha_random;
  array[K_alpha_random] int idx_alpha_random;
  int<lower=1> K_alpha_fixed;
  array[K_alpha_fixed] int idx_alpha_fixed;
  int<lower=1> q_effective;
  array[q_effective] int effective_lags_delta;
  int<lower=1> K_delta_random;
  array[K_delta_random] int idx_delta_random;
  int<lower=1> K_delta_fixed;
  array[K_delta_fixed] int idx_delta_fixed;
  int<lower=1> N_train;
  matrix[N_train, J] X_train;
  array[N_train] int y_train;
  array[N_train] int<lower=1, upper=R> restaurant_id_train;
  array[R] int train_start_idx;
  array[R] int train_end_idx;
  int<lower=1> N_test;
  matrix[N_test, J] X_test;
  array[N_test] int y_test;
  array[N_test] int<lower=1, upper=R> restaurant_id_test;
  array[R] int test_start_idx;
  array[R] int test_end_idx;
  real<lower=0> mu_beta_scale;
  real<lower=0> sigma_beta_scale;
  real<lower=0> mu_alpha_scale;
  real<lower=0> sigma_alpha_scale;
  real<lower=0> mu_delta_scale;
  real<lower=0> sigma_delta_scale;
  real<lower=0> mu_phi_log_scale;
  real<lower=0> sigma_phi_log_scale;
}
parameters {
  real mu_beta_intercept;
  vector[K_beta_random] mu_beta_random;
  vector[K_beta_fixed] mu_beta_fixed;
  vector[K_alpha_random] mu_alpha_random_raw;
  vector[K_alpha_fixed] mu_alpha_fixed_raw;
  vector[K_delta_random] mu_delta_random_raw;
  vector[K_delta_fixed] mu_delta_fixed_raw;
  real mu_phi_log;
  real<lower=0> sigma_beta_intercept;
  vector<lower=0>[K_beta_random] sigma_beta_random;
  vector<lower=0>[K_alpha_random] sigma_alpha_random;
  vector<lower=0>[K_delta_random] sigma_delta_random;
  real<lower=0> sigma_phi_log;
  vector[R] z_beta_intercept;
  matrix[K_beta_random, R] z_beta_random;
  matrix[K_alpha_random, R] z_alpha_random;
  matrix[K_delta_random, R] z_delta_random;
  vector[R] z_phi_log;
}
transformed parameters {
  vector[N_train] nu;
  vector[N_train] lambda;
  vector<lower=0>[R] phi = exp(mu_phi_log + sigma_phi_log * z_phi_log);
  matrix[J, R] beta;
  {
    vector[R] beta_intercept_r = mu_beta_intercept + sigma_beta_intercept * z_beta_intercept;
    matrix[K_beta_random, R] beta_random_r = diag_pre_multiply(sigma_beta_random, z_beta_random)
                                             + rep_matrix(mu_beta_random, R);
    for (r in 1:R) {
      beta[idx_intercept, r] = beta_intercept_r[r];
      beta[idx_beta_random, r] = beta_random_r[, r];
      beta[idx_beta_fixed, r] = mu_beta_fixed;
    }
  }
  matrix<lower=-1, upper=1>[p_effective, R] alpha;
  {
    matrix[p_effective, R] alpha_raw;
    matrix[K_alpha_random, R] alpha_random_raw_r = diag_pre_multiply(sigma_alpha_random, z_alpha_random)
                                                 + rep_matrix(mu_alpha_random_raw, R);
    for (r in 1:R) {
      alpha_raw[idx_alpha_random, r] = alpha_random_raw_r[, r];
      alpha_raw[idx_alpha_fixed, r] = mu_alpha_fixed_raw;
    }
    alpha = tanh(alpha_raw / 2.0);
  }
  matrix<lower=-1, upper=1>[q_effective, R] delta;
  {
    matrix[q_effective, R] delta_raw;
    matrix[K_delta_random, R] delta_random_raw_r = diag_pre_multiply(sigma_delta_random, z_delta_random)
                                                 + rep_matrix(mu_delta_random_raw, R);
    for (r in 1:R) {
      delta_raw[idx_delta_random, r] = delta_random_raw_r[, r];
      delta_raw[idx_delta_fixed, r] = mu_delta_fixed_raw;
    }
    delta = tanh(delta_raw / 2.0);
  }
  for (r in 1:R) {
    int r_start = train_start_idx[r];
    int r_end = train_end_idx[r];
    vector[J] beta_r = beta[, r];
    vector[p_effective] alpha_r = alpha[, r];
    vector[q_effective] delta_r = delta[, r];
    for (t in r_start:r_end) {
      nu[t] = dot_product(X_train[t], beta_r);
      for (i in 1:p_effective) {
        int lag = effective_lags_alpha[i];
        if (t - lag >= r_start) {
          nu[t] += alpha_r[i] * log(y_train[t - lag] + 1);
        }
      }
      for (j in 1:q_effective) {
        int lag = effective_lags_delta[j];
        if (t - lag >= r_start) {
          nu[t] += delta_r[j] * nu[t - lag];
        }
      }
    }
  }
  lambda = exp(nu);
}
model {
  mu_beta_intercept ~ normal(0, mu_beta_scale);
  mu_beta_random ~ normal(0, mu_beta_scale);
  mu_beta_fixed ~ normal(0, mu_beta_scale);
  mu_alpha_random_raw ~ normal(0, mu_alpha_scale);
  mu_alpha_fixed_raw ~ normal(0, mu_alpha_scale);
  mu_delta_random_raw ~ normal(0, mu_delta_scale);
  mu_delta_fixed_raw ~ normal(0, mu_delta_scale);
  mu_phi_log ~ normal(0, mu_phi_log_scale);
  sigma_beta_intercept ~ exponential(sigma_beta_scale);
  sigma_beta_random ~ exponential(sigma_beta_scale);
  sigma_alpha_random ~ exponential(sigma_alpha_scale);
  sigma_delta_random ~ exponential(sigma_delta_scale);
  sigma_phi_log ~ exponential(sigma_phi_log_scale);
  z_beta_intercept ~ std_normal();
  to_vector(z_beta_random) ~ std_normal();
  to_vector(z_alpha_random) ~ std_normal();
  to_vector(z_delta_random) ~ std_normal();
  z_phi_log ~ std_normal();
  for (t in 1:N_train) {
    int r = restaurant_id_train[t];
    y_train[t] ~ neg_binomial_2(lambda[t], phi[r]);
  }
}
generated quantities {
  array[N_train] int y_rep;
  vector[N_train] log_lik;
  for (t in 1:N_train) {
    int r = restaurant_id_train[t];
    y_rep[t] = neg_binomial_2_rng(lambda[t], phi[r]);
    log_lik[t] = neg_binomial_2_lpmf(y_train[t] | lambda[t], phi[r]);
  }
  array[N_test] int y_test_rep;
  vector[N_test] lambda_test;
  vector[N_test] nu_test;
  for (t_test_idx in 1:N_test) {
    int r = restaurant_id_test[t_test_idx];
    int r_train_end_idx = train_end_idx[r];
    int r_test_start_idx = test_start_idx[r];
    vector[J] beta_r = beta[, r];
    vector[p_effective] alpha_r = alpha[, r];
    vector[q_effective] delta_r = delta[, r];
    real phi_r = phi[r];
    nu_test[t_test_idx] = dot_product(X_test[t_test_idx], beta_r);
    for (i in 1:p_effective) {
      int lag = effective_lags_alpha[i];
      int current_pos_in_test = t_test_idx - r_test_start_idx + 1;
      int lag_source_idx_test = t_test_idx - lag;
      if (lag < current_pos_in_test) {
        nu_test[t_test_idx] += alpha_r[i] * log(y_test[lag_source_idx_test] + 1);
      } else {
        int train_lag_offset = lag - current_pos_in_test;
        int lag_source_idx_train = r_train_end_idx - train_lag_offset;
        if (lag_source_idx_train >= train_start_idx[r] && lag_source_idx_train <= r_train_end_idx) {
              nu_test[t_test_idx] += alpha_r[i] * log(y_train[lag_source_idx_train] + 1);
        }
      }
    }
    for (j in 1:q_effective) {
      int lag = effective_lags_delta[j];
      int current_pos_in_test = t_test_idx - r_test_start_idx + 1;
      int lag_source_idx_test = t_test_idx - lag;
      if (lag < current_pos_in_test) {
          nu_test[t_test_idx] += delta_r[j] * nu_test[lag_source_idx_test];
      } else {
        int train_lag_offset = lag - current_pos_in_test;
        int lag_source_idx_train = r_train_end_idx - train_lag_offset;
          if (lag_source_idx_train >= train_start_idx[r] && lag_source_idx_train <= r_train_end_idx) {
            nu_test[t_test_idx] += delta_r[j] * nu[lag_source_idx_train];
          }
      }
    }
    lambda_test[t_test_idx] = exp(nu_test[t_test_idx]);
    y_test_rep[t_test_idx] = neg_binomial_2_rng(lambda_test[t_test_idx], phi_r);
  }
}

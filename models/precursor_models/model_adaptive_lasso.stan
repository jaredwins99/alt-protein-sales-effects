data {
  // Input data
  int<lower=1> K;                 // Number of covariates
  int<lower=1> p;                 // Number of lags for counts (y)
  int<lower=1> q;                 // Number of lags for intensity (lambda)
  
  // Effective lags for counts
  int<lower=1> p_effective;       // Number of effective lags for counts
  array[p_effective] int effective_lags_alpha;  // List of effective lag indices for counts
  
  // Effective lags for latent intensity
  int<lower=1> q_effective;       // Number of effective lags for intensity
  array[q_effective] int effective_lags_delta;  // List of effective lag indices for intensity
  
  // Training
  int<lower=1> N_train;           // Number of time points
  matrix[N_train, K] X_train;     // Covariate matrix
  array[N_train] int y_train;     // Observed counts
  
  // Testing
  int<lower=1> N_test;            // Number of test time points
  matrix[N_test, K] X_test;       // Covariate matrix for test data
  array[N_test] int y_test;
  
  // Hyperprior parameter inputs
  real<lower=0> beta_hyper;
  real<lower=0> alpha_hyper;
  real<lower=0> delta_hyper;
}

parameters {
  // Exogenous variable parameters and dispersion
  vector[K] beta;                  // Regression coefficients (K includes intercept)
  real<lower=0> phi;               // Negative binomial dispersion parameter
  
  // Autoregressive coefficients for lagged transformed counts and past linear predictor
  // For the log-linear model, we constrain these to lie in (-1, 1)
  // Only effective lags (e.g., lags 1–7 and any lag > 7 that is divisible by 7) are estimated.
  vector<lower=-1, upper=1>[p_effective] alpha;  // Effects for log(y_{t-1}+1), log(y_{t-2}+1)
  vector<lower=-1, upper=1>[q_effective] delta;  // Effects for lagged log-intensities ν_{t-1} and ν_{t-2}

  // Adaptive lasso: individual shrinkage scales
  vector<lower=0>[K] beta_scale;
  vector<lower=0>[p_effective] alpha_scale;
  vector<lower=0>[q_effective] delta_scale;
}

transformed parameters {
  // Initialize latent parameters
  vector[N_train] nu;      // nu[t] = log(λ_t)
  vector[N_train] lambda;  // Conditional mean λ_t = exp(nu[t])
  
  for (t in 1:N_train) {
    // Base contribution from covariates
    nu[t] = dot_product(X_train[t], beta);
    
    // Add effect from lagged observed counts, if available
    for (i in 1:p_effective)
      if (t > effective_lags_alpha[i])
        nu[t] += alpha[i] * log(y_train[t - effective_lags_alpha[i]] + 1);
    
    // Add effect from lagged latent values, if available
    for (j in 1:q_effective)
      if (t > effective_lags_delta[j])
        nu[t] += delta[j] * nu[t - effective_lags_delta[j]];
    
    // Compute conditional mean
    lambda[t] = exp(nu[t]);
  }
}

model {
  // Priors
  phi ~ gamma(2, 0.1);

  // Hyperpriors for the shrinkage scales (i.e., adaptive)
  for (j in 1:K) {
    beta_scale[j] ~ exponential(beta_hyper);
    beta[j] ~ double_exponential(0, beta_scale[j]);
  }
  for (k in 1:p_effective) {
    alpha_scale[k] ~ exponential(alpha_hyper * (k % 7 + k %/% 7));
    alpha[k] ~ double_exponential(0, alpha_scale[k]);
  }
  for (l in 1:q_effective) {
    delta_scale[l] ~ exponential(delta_hyper * (l % 7 + l %/% 7));
    delta[l] ~ double_exponential(0, delta_scale[l]);
  }
  
  // Likelihood: Negative binomial likelihood parametrized by mean λ and dispersion φ
  for (t in 1:N_train)
    y_train[t] ~ neg_binomial_2(lambda[t], phi);
}

generated quantities {
  // In-sample posterior predictive checks:
  array[N_train] int y_rep;         // Replicated training counts
  vector[N_train] log_lik;      // Pointwise log-likelihoods for training data
  for (t in 1:N_train) {
    y_rep[t] = neg_binomial_2_rng(lambda[t], phi);
    log_lik[t] = neg_binomial_2_lpmf(y_train[t] | lambda[t], phi);
  }

  // Out-of-sample predictions for test data using a rolling forecast:
  array[N_test] int y_test_rep;      // Predicted counts for test data
  vector[N_test] lambda_test;  // Predicted intensities for test data
  vector[N_test] nu_test;      // Log-scale intensities for test data
  for (t in 1:N_test) {
    // Start with the covariate contribution:
    nu_test[t] = dot_product(X_test[t], beta);

    // Add effect from effective lagged observed counts:
    for (i in 1:p_effective) {
        if (t - effective_lags_alpha[i] > 0)
          nu_test[t] += alpha[i] * log(y_test[t - effective_lags_alpha[i]] + 1);
        else
          nu_test[t] += alpha[i] * log(y_train[N_train - (effective_lags_alpha[i] - t)] + 1);
    }

    // Add effect from effective lagged latent values:
    for (j in 1:q_effective) {
        if (t - effective_lags_delta[j] > 0)
          nu_test[t] += delta[j] * nu_test[t - effective_lags_delta[j]];
        else
          nu_test[t] += delta[j] * nu[N_train - (effective_lags_delta[j] - t)];
    }

    lambda_test[t] = exp(nu_test[t]);
    y_test_rep[t] = neg_binomial_2_rng(lambda_test[t], phi);
  }
}

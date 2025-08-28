library(arrow)
library(fpp3)
library(tscount)
library(sandwich)
library(lmtest)
library(MASS)
library(skimr)

5+5

df_all_daily <- read_parquet("data/3_palate_data_parquet_modeling/all_locations_daily.parquet")

df_subset <- df_all_daily %>%
  mutate(
    meat_window_avg = scale(meat_window_avg),
    vegetarian_window_avg = scale(vegetarian_window_avg),
    vegan_window_avg = scale(vegan_window_avg),
    date = scale(date),
    day_of_week = as.factor(day_of_week),
  ) %>% 
  filter(location_id == "SRQS8F7JWA9MZ") %>%
  slice_sample(n=10000)

df_subset <- as.data.frame(df_subset)

predictors <- c("vegan_window_avg",
                "vegetarian_window_avg",
                "meat_window_avg",
                "day_of_week",
                #"weekend",
                "day_of_month",
                "month",
                "season",
                "date")

diagnose_poisson(df_subset, "vegan_outcome", predictors, "created_at")

diagnose_nb(df_subset, "vegan_outcome", predictors, "created_at")

diagnose_poisson <- function(data, count_var, covariates = NULL, date_var = NULL) {
  
  cat("\n=============================================\n")
  cat("       Poisson Checks                   \n")
  cat("=============================================\n")
  
  # 1. Summary stats: expectation, variance, and zero counts
  n_obs <- sum(!is.na(data[[count_var]]))
  count_mean <- mean(data[[count_var]], na.rm = TRUE)
  count_variance <- var(data[[count_var]], na.rm = TRUE)
  n_zero <- sum(data[[count_var]] == 0, na.rm = TRUE)
  prop_zero <- n_zero / n_obs
  
  cat("\n--- Descriptive Statistics ---\n")
  cat("Number of observations:", n_obs, "\n")
  cat("Mean of", count_var, ":", round(count_mean, 3), "\n")
  cat("Variance of", count_var, ":", round(count_variance, 3), "\n")
  cat("Observed proportion of zeros:", round(prop_zero, 3), "\n")
  
  # Under a Poisson distribution with mean lambda, the probability of zero is exp(-lambda)
  expected_zero <- exp(-count_mean)
  cat("Expected proportion of zeros:", round(expected_zero, 3), "\n")
  if (abs(prop_zero - expected_zero) > 0.1) {cat(">>> Information about zeros: Observed and expected proportions of zeros differ.\n")}
  
  # 2. Check for missing weeks
  if (!is.null(date_var)) {
    if (!date_var %in% names(data)) {
      stop(paste("Error: Date variable", date_var, "not found in the data."))
    }
    data[[date_var]] <- as.Date(data[[date_var]])
    
    # Create a full weekly sequence from the minimum to maximum date in the data
    full_weeks <- seq.Date(from = min(data[[date_var]], na.rm = TRUE),
                           to = max(data[[date_var]], na.rm = TRUE),
                           by = "week")
    missing_weeks <- setdiff(full_weeks, data[[date_var]])
    cat("\n--- Date/Time Series Check ---\n")
    cat("Number of weeks in full sequence:", length(full_weeks), "\n")
    cat("Number of missing weeks:", 
        length(missing_weeks), "\n")
    if (length(missing_weeks) > 0) {
      cat("Missing weeks:\n")
      print(missing_weeks)
    }
  }
  
  # 3. Fit a Poisson regression model
  cat("\n=============================================\n")
  cat("       Fitting a Poisson Regression Model     \n")
  cat("=============================================\n")
  
  if (is.null(covariates)) {
    model_formula <- as.formula(paste(count_var, "~ 1"))
  } else {
    # Ensure each specified covariate exists in the data
    missing_covs <- covariates[!covariates %in% names(data)]
    if (length(missing_covs) > 0) {
      stop(paste("Error: The following covariates were not found in the data:", 
                 paste(missing_covs, collapse = ", ")))
    }
    model_formula <- as.formula(paste(count_var, "~", paste(covariates, collapse = " + ")))
  }
  
  # Fit the Poisson GLM
  poisson_model <- glm(model_formula, family = poisson, data = data)
  cat("Poisson model fitted. Summary:\n")
  print(summary(poisson_model))
  
  # 4. Calculate the Pearson Chi2 dispersion statistic.
  #    (Sum of squared Pearson residuals divided by the model degrees of freedom.)
  pearson_resids <- residuals(poisson_model, type = "pearson")
  df_resid <- poisson_model$df.residual
  dispersion_stat <- sum(pearson_resids^2) / df_resid
  cat("\n--- Dispersion Check ---\n")
  cat("Pearson Chi-squared dispersion statistic:", round(dispersion_stat, 3), "\n")
  
  if (dispersion_stat > 1.2) {
    cat(">> Warning: Overdispersion is detected. Consider using a quasi-Poisson or negative binomial model.\n")
  } else if (dispersion_stat < 0.8) {
    cat(">> Warning: Underdispersion is detected.\n")
  } else {
    cat("Dispersion appears to be approximately 1 (i.e., as expected under Poisson assumptions).\n")
  }
  
  # 6. Compare model standard errors with robust (sandwich) standard errors.
  robust_se <- sqrt(diag(sandwich::vcovHC(poisson_model, type = "HC0")))
  model_se <- summary(poisson_model)$coefficients[, "Std. Error"]
  se_comparison <- data.frame(
    Estimate = coef(poisson_model),
    Model_SE = model_se,
    Robust_SE = robust_se
  )
  cat("\n--- Standard Errors Comparison ---\n")
  print(se_comparison)
  cat("If robust SEs differ considerably from model SEs, this suggests possible correlation / clustering issues.\n")
  
  # 5. Monte Carlo simulation of counts based on the fitted model.
  #    (This is a simple synthetic simulation using rpois for each observation.)
  fitted_lambda <- poisson_model$fitted.values
  sim_counts <- rpois(n_obs, lambda = fitted_lambda)
  sim_zero_prop <- sum(sim_counts == 0) / n_obs
  cat("\n--- Monte Carlo Poisson Simulation ---\n")
  cat("Simulated proportion of zeros:", round(sim_zero_prop, 3), "\n")
  cat("This can be compared with the observed proportion of zeros to check for model fit.\n")
  
  # 6. Compute average marginal effects for each covariate (if any)
  #    For Poisson regression, the marginal effect for a predictor is:
  #         ∂E(Y|X)/∂x = β * exp(Xβ)
  if (!is.null(covariates)) {
    cat("\n--- Average Marginal Effects ---\n")
    # Compute the linear predictor for each observation
    linear_pred <- predict(poisson_model, type = "link")
    # For each covariate, compute the marginal effect per observation and then average.
    ame_list <- sapply(covariates, function(var) {
      beta <- coef(poisson_model)[var]
      # Compute marginal effects for each observation
      effects <- beta * exp(linear_pred)
      mean(effects)
    })
    ame_df <- data.frame(Covariate = covariates,
                         Average_Marginal_Effect = round(ame_list, 3))
    print(ame_df)
  }
  
  # Return a list of important outputs
  return(list(
    model = poisson_model,
    dispersion_stat = dispersion_stat,
    se_comparison = se_comparison,
    descriptive_stats = list(
      n_obs = n_obs,
      mean = count_mean,
      variance = count_variance,
      prop_zero = prop_zero,
      expected_zero = expected_zero
    )
  ))
}

diagnose_nb <- function(data, count_var, covariates = NULL, date_var = NULL) {
  
  cat("=============================================\n")
  cat("  Negative Binomial Regression Diagnostics  \n")
  cat("=============================================\n")
  
  ### 1. Basic Data Checks and Descriptive
  
  # Check that the count variable exists and is numeric
  if (!count_var %in% names(data)) {
    stop(paste("Error: Count variable", count_var, "not found in the data."))
  }
  data[[count_var]] <- as.numeric(data[[count_var]])
  if (any(data[[count_var]] < 0, na.rm = TRUE)) {
    warning("The count variable contains negative values!")
  }
  # Check for (approximate) integer values
  if (!all(abs(data[[count_var]] - round(data[[count_var]])) < 1e-8, na.rm = TRUE)) {
    warning("The count variable contains non-integer values!")
  }
  
  # Descriptive statistics: mean, variance, and proportion of zeros
  n_obs       <- sum(!is.na(data[[count_var]]))
  count_mean  <- mean(data[[count_var]], na.rm = TRUE)
  count_var_emp <- var(data[[count_var]], na.rm = TRUE)
  n_zero      <- sum(data[[count_var]] == 0, na.rm = TRUE)
  prop_zero   <- n_zero / n_obs
  
  cat("\n--- Descriptive Statistics ---\n")
  cat("Number of observations:", n_obs, "\n")
  cat("Mean of", count_var, ":", round(count_mean, 3), "\n")
  cat("Variance of", count_var, ":", round(count_var_emp, 3), "\n")
  cat("Proportion of zeros:", round(prop_zero, 3), "\n")
  
  ### 2. Check for Missing Weeks (if a Date Variable is Provided)
  if (!is.null(date_var)) {
    if (!date_var %in% names(data)) {
      stop(paste("Error: Date variable", date_var, "not found in the data."))
    }
    data[[date_var]] <- as.Date(data[[date_var]])
    full_weeks <- seq.Date(from = min(data[[date_var]], na.rm = TRUE),
                           to   = max(data[[date_var]], na.rm = TRUE),
                           by   = "week")
    missing_weeks <- setdiff(full_weeks, data[[date_var]])
    cat("\n--- Date/Time Series Check ---\n")
    cat("Total weeks in full sequence:", length(full_weeks), "\n")
    cat("Number of missing weeks (e.g., restaurant closed):", length(missing_weeks), "\n")
    if (length(missing_weeks) > 0) {
      cat("Missing weeks:\n")
      print(missing_weeks)
    }
  }
  
  ### 3. Fit a Baseline Poisson Model
  # (This is used to assess whether the variance >> mean)
  if (is.null(covariates)) {
    formula_poisson <- as.formula(paste(count_var, "~ 1"))
  } else {
    # Ensure all specified covariates are present in the data
    missing_covs <- covariates[!covariates %in% names(data)]
    if (length(missing_covs) > 0) {
      stop(paste("Error: The following covariates were not found in the data:", 
                 paste(missing_covs, collapse = ", ")))
    }
    formula_poisson <- as.formula(paste(count_var, "~", paste(covariates, collapse = " + ")))
  }
  poisson_model <- glm(formula_poisson, family = poisson, data = data)
  cat("\n--- Poisson Model Summary ---\n")
  print(summary(poisson_model))
  
  # Calculate the Poisson dispersion statistic (Pearson Chi2 / df)
  pearson_resid <- residuals(poisson_model, type = "pearson")
  df_poisson <- poisson_model$df.residual
  dispersion_poisson <- sum(pearson_resid^2) / df_poisson
  cat("\nPoisson Dispersion Statistic (should be ~1 if well‐specified):", round(dispersion_poisson, 3), "\n")
  if (dispersion_poisson > 1.2) {
    cat(">> Overdispersion detected in Poisson model.\n")
  }
  
  ### 4. Fit a Negative Binomial Model (NB2) using MASS::glm.nb
  nb_model <- MASS::glm.nb(formula_poisson, data = data)
  cat("\n--- Negative Binomial (NB2) Model Summary ---\n")
  print(summary(nb_model))
  
  # The NB model estimates a dispersion (theta) parameter.
  theta_est <- nb_model$theta
  cat("\nEstimated Theta (dispersion parameter):", round(theta_est, 3), "\n")
  
  # Compute the NB Pearson dispersion statistic (should be close to 1 if fit is good)
  nb_pearson <- sum(residuals(nb_model, type = "pearson")^2) / nb_model$df.residual
  cat("NB Model Pearson Dispersion Statistic:", round(nb_pearson, 3), "\n")
  
  ### 5. Compare Model Fit: AIC, BIC, and Log-Likelihood
  aic_poisson <- AIC(poisson_model)
  aic_nb      <- AIC(nb_model)
  bic_poisson <- BIC(poisson_model)
  bic_nb      <- BIC(nb_model)
  ll_poisson  <- logLik(poisson_model)
  ll_nb       <- logLik(nb_model)
  
  cat("\n--- Model Fit Comparison ---\n")
  cat("Poisson Model:    AIC =", round(aic_poisson, 2), "; BIC =", round(bic_poisson, 2), "; LogLik =", round(ll_poisson, 2), "\n")
  cat("Negative Binomial: AIC =", round(aic_nb, 2), "; BIC =", round(bic_nb, 2), "; LogLik =", round(ll_nb, 2), "\n")
  
  ### 6. Likelihood Ratio Test: Poisson vs. Negative Binomial
  # Although not strictly nested, a likelihood ratio test is commonly used
  # to check whether the NB model significantly improves over the Poisson.
  lrt <- lmtest::lrtest(poisson_model, nb_model)
  cat("\n--- Likelihood Ratio Test (Poisson vs. NB) ---\n")
  print(lrt)
  
  ### 7. Robust Standard Errors for the NB Model
  robust_se_nb <- sqrt(diag(vcovHC(nb_model, type = "HC0")))
  nb_coef <- coef(nb_model)
  se_comparison <- data.frame(Estimate    = nb_coef,
                              Model_SE    = summary(nb_model)$coefficients[, "Std. Error"],
                              Robust_SE   = robust_se_nb)
  cat("\n--- NB Model Standard Errors Comparison ---\n")
  print(se_comparison)
  cat("If robust SEs differ substantially from the model SEs, heterogeneity or misspecification may be present.\n")
  
  ### 8. (Optional) Heterogeneous NB Model Using glmmTMB
  # Here we allow the dispersion (or scale) to vary with the covariates.
  # This is sometimes called a heterogeneous NB (NB-H) model.
  if (requireNamespace("glmmTMB", quietly = TRUE)) {
    cat("\n--- Heterogeneous NB Model (NB-H) via glmmTMB ---\n")
    if (is.null(covariates)) {
      formula_tmb <- as.formula(paste(count_var, "~ 1"))
      disp_formula <- ~ 1
    } else {
      formula_tmb <- as.formula(paste(count_var, "~", paste(covariates, collapse = " + ")))
      # As an example, we let the dispersion depend on the same covariates.
      disp_formula <- as.formula(paste("~", paste(covariates, collapse = " + ")))
    }
    nb_h_model <- glmmTMB::glmmTMB(formula = formula_tmb, 
                                   dispformula = disp_formula, 
                                   data = data, 
                                   family = glmmTMB::nbinom2())
    cat("Heterogeneous NB Model Summary:\n")
    print(summary(nb_h_model))
  } else {
    cat("\nPackage 'glmmTMB' is not installed; skipping heterogeneous NB model test.\n")
  }
  
  cat("\n=============================================\n")
  cat("  Negative Binomial Diagnostics Completed   \n")
  cat("=============================================\n")
  
  # Return key outputs for further inspection
  return(list(
    poisson_model       = poisson_model,
    nb_model            = nb_model,
    nb_h_model          = if (exists("nb_h_model")) nb_h_model else NULL,
    dispersion_poisson  = dispersion_poisson,
    nb_pearson_dispersion = nb_pearson,
    aic_poisson         = aic_poisson,
    aic_nb              = aic_nb,
    bic_poisson         = bic_poisson,
    bic_nb              = bic_nb,
    likelihood_ratio_test = lrt,
    se_comparison       = se_comparison
  ))
}

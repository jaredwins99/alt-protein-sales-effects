library(tidyverse)
library(dplyr)


# ──────────────────────────────────
#     Identify Column Indices 
# ──────────────────────────────────

index_data <- function(
    matrix_list,
    random_predictors,
    term_from_assign,
    effective_lags_alpha, 
    effective_lags_delta, 
    random_lags_alpha_values, 
    random_lags_delta_values) {

    tryCatch({

      # Pull the final, combined matrices and vectors from the list
      X_train <- matrix_list$X_train
      X_test  <- matrix_list$X_test
      restaurant_id_train <- matrix_list$restaurant_id_train
      
      # Get the final, correct dimensions
      R <- length(unique(restaurant_id_train))
      J <- ncol(X_train)
      model_colnames <- colnames(X_train)
      
      # ────────────────────────────
      # Predictors
      
      # Intercept index
      idx_intercept <- which(model_colnames == "(Intercept)")
      
      # Beta random slope indices
      regex_random = c(  # Exact match for non-factors
        paste0("^", random_predictors[!(random_predictors %in% c("season"))], "$"),
        paste0("^", "season")) # Starts with 'season' for factor dummies
      
      # Identify indices within design matrix
      idx_exposure     <- which(startsWith(model_colnames, "exposure_"))
      idx_beta_random  <- which(term_from_assign %in% random_predictors)
      idx_beta_fixed   <- setdiff(seq_len(J), c(idx_intercept, idx_beta_random, idx_exposure))
      
      # ────────────────────────────
      # Exposures

      # Number of exposures
      K_exposure <- length(idx_exposure)

      # Number of parameters per exposure
      M <- 2 # We have two parameter types: intercept and slope for each exposure
      
      # Create the expo_to_rest mapping
      # Tells Stan which restaurant each exposure column belongs to
      if (K_exposure > 0) {
        expo_to_rest <- integer(K_exposure)
        for (k in 1:K_exposure) {
          col_idx <- idx_exposure[k]
          active <- unique(restaurant_id_train[X_train[, col_idx] != 0])
          if (length(active) == 0) {
            stop(paste("Exposure column", model_colnames[col_idx], "is all zeros in the training data."))
          } else if (length(active) > 1) {
            stop(paste("Exposure column", model_colnames[col_idx], "is active for multiple restaurants:", paste(active, collapse=", "), ". Each exposure needs to belong to only one restaurant."))
          } else {
            expo_to_rest[k] <- active}}
        print("Successfully created `expo_to_rest` mapping.")
      } else {
        expo_to_rest <- integer(0)}
      
      # Create the expo_to_param mapping
      # Links each exposure column to a parameter type (1=intercept, 2=slope)
      if (K_exposure > 0) {
        exposure_colnames <- model_colnames[idx_exposure]
        expo_to_param <- ifelse(grepl("_slope$", exposure_colnames), 2, 1)
        print("Successfully created `expo_to_param` mapping.")
      } else {
        expo_to_param <- integer(0)}
      
      # ────────────────────────────
      # Lags
      
      # # of effective lags
      p_effective <- length(effective_lags_alpha)
      q_effective <- length(effective_lags_delta)
      # Max lags considered 
      p_max <- max(effective_lags_alpha)
      q_max <- max(effective_lags_delta)


      # Alpha & delta random/fixed indices 
      # (indices within effective_lags_alpha, and effective_lags_delta)
      idx_alpha_random <- which(effective_lags_alpha %in% random_lags_alpha_values)
      idx_alpha_fixed <- as.integer(setdiff(seq_len(p_effective), idx_alpha_random))
      idx_delta_random <- which(effective_lags_delta %in% random_lags_delta_values)
      idx_delta_fixed <- as.integer(setdiff(seq_len(q_effective), idx_delta_random))
      
      # ────────────────────────────
      # View
      
      cat("Identified ", length(idx_exposure), 
          " exposure columns in the design matrix: \n",
          paste(model_colnames[idx_exposure], collapse=", \n"), "\n", sep="")
      cat("Identified ", length(idx_beta_random), 
          " random beta columns: \n", 
          paste(model_colnames[idx_beta_random], collapse=", \n"), "\n", sep="")
      cat("Identified ", length(idx_beta_fixed), 
          " fixed beta columns: \n",
          paste(model_colnames[idx_beta_fixed], collapse=", \n"), "\n", sep="")
      cat("Identified ", length(idx_alpha_random), 
          " random alpha indices (positions): \n", 
          paste(idx_alpha_random, collapse=", "), "\n", sep="")
      cat("Identified ", length(idx_delta_random), 
          " random delta indices (positions): \n", 
          paste(idx_delta_random, collapse=", "), "\n", sep="") 

      list(K_exposure = K_exposure,
          expo_to_rest = expo_to_rest,
          expo_to_param = expo_to_param,
          idx_intercept = idx_intercept,
          idx_beta_random = idx_beta_random,
          idx_beta_fixed = idx_beta_fixed,
          idx_exposure = idx_exposure,
          idx_alpha_random = idx_alpha_random,
          idx_alpha_fixed = idx_alpha_fixed,
          idx_delta_random = idx_delta_random,
          idx_delta_fixed = idx_delta_fixed,
          p_effective = p_effective,
          q_effective = q_effective,
          p_max = p_max,
          q_max = q_max,
          R = R,
          J = J,
          M = M)

      }, error = function(e) {

      message("index_ingarch failed: ", conditionMessage(e))
      return(NULL)

    })
}
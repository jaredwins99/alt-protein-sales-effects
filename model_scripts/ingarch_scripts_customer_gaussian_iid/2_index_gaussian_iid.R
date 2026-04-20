library(tidyverse)
library(dplyr)


# ──────────────────────────────────
#     Identify Column Indices
# ──────────────────────────────────
# Same as index_data_transaction — no lag indices needed for IID model.

index_data_gaussian_iid <- function(
    matrix_list,
    random_predictors,
    term_from_assign) {

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

      # Identify indices within design matrix
      idx_exposure     <- which(startsWith(model_colnames, "exposure_"))
      idx_beta_random  <- which(term_from_assign %in% random_predictors)
      idx_beta_fixed   <- setdiff(seq_len(J), c(idx_intercept, idx_beta_random, idx_exposure))

      # ────────────────────────────
      # Exposures

      # Number of exposures
      K_exposure <- length(idx_exposure)

      # Number of parameter types per exposure (level, slope, optionally male, optionally female)
      exposure_colnames_check <- model_colnames[idx_exposure]
      has_gendermale_expo <- any(grepl("_gendermale$", exposure_colnames_check))
      has_genderfemale_expo <- any(grepl("_genderfemale$", exposure_colnames_check))
      M <- 2L + as.integer(has_gendermale_expo) + as.integer(has_genderfemale_expo)

      # Create the expo_to_rest mapping.
      # All-zero BASE-exposure or SLOPE columns are a genuine spec error (fatal, as in INGARCH).
      # All-zero gender-interaction columns happen naturally when a restaurant has no
      # male/female post-intervention observations in train; drop those columns and
      # reindex rather than failing.
      if (K_exposure > 0) {
        expo_to_rest <- integer(K_exposure)
        drop_k <- integer(0)
        for (k in 1:K_exposure) {
          col_idx <- idx_exposure[k]
          active <- unique(restaurant_id_train[X_train[, col_idx] != 0])
          colname <- model_colnames[col_idx]
          is_gender <- grepl("_gendermale$|_genderfemale$", colname)
          if (length(active) == 0) {
            if (is_gender) {
              warning(sprintf("Dropping all-zero gender-interaction column: %s", colname))
              drop_k <- c(drop_k, k)
              next
            }
            stop(paste("Exposure column", colname, "is all zeros in the training data."))
          } else if (length(active) > 1) {
            stop(paste("Exposure column", colname, "is active for multiple restaurants:",
                       paste(active, collapse=", "),
                       ". Each exposure needs to belong to only one restaurant."))
          } else {
            expo_to_rest[k] <- active
          }
        }
        if (length(drop_k) > 0) {
          keep <- setdiff(seq_len(K_exposure), drop_k)
          idx_exposure <- idx_exposure[keep]
          expo_to_rest <- expo_to_rest[keep]
          K_exposure <- length(idx_exposure)
          exposure_colnames_check <- model_colnames[idx_exposure]
          has_gendermale_expo   <- any(grepl("_gendermale$",   exposure_colnames_check))
          has_genderfemale_expo <- any(grepl("_genderfemale$", exposure_colnames_check))
          M <- 2L + as.integer(has_gendermale_expo) + as.integer(has_genderfemale_expo)
        }
        print("Successfully created `expo_to_rest` mapping.")
      } else {
        expo_to_rest <- integer(0)
      }

      # Create the expo_to_param mapping
      if (K_exposure > 0) {
        exposure_colnames <- model_colnames[idx_exposure]
        expo_to_param <- dplyr::case_when(
          grepl("_genderfemale$", exposure_colnames) ~ 4L,
          grepl("_gendermale$", exposure_colnames) ~ 3L,
          grepl("_slope$", exposure_colnames) ~ 2L,
          TRUE ~ 1L)
        print("Successfully created `expo_to_param` mapping.")
      } else {
        expo_to_param <- integer(0)}

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

      list(K_exposure = K_exposure,
          expo_to_rest = expo_to_rest,
          expo_to_param = expo_to_param,
          idx_intercept = idx_intercept,
          idx_beta_random = idx_beta_random,
          idx_beta_fixed = idx_beta_fixed,
          idx_exposure = idx_exposure,
          R = R,
          J = J,
          M = M)

      }, error = function(e) {

      message("index_gaussian_iid failed: ", conditionMessage(e))
      return(NULL)

    })
}

# ───────────────────────────────────────
#       95% Confidence Interval Helpers
# ───────────────────────────────────────
# Functions to compute q2.5 and q97.5 from posterior samples
# for use in forest plots (replacing 90% CI with 95% CI)

library(tidyverse)

#' Read Posterior Samples from a Model Directory
#' @param model_path Path to a model directory containing samples.rds
#' @return A draws_df object with posterior samples
read_samples <- function(model_path) {
  samples_file <- file.path(model_path, "samples.rds")
  if (!file.exists(samples_file)) {
    warning(paste("Samples file not found:", samples_file))
    return(NULL)
  }
  readRDS(samples_file)
}

#' Compute 95% CI for mu_gamma Parameters from Samples
#' @param model_path Path to a model directory containing samples.rds
#' @param gamma_indices Vector of gamma indices to extract (default: c(1, 2))
#' @return A tibble with variable, mean, median, sd, q2.5, q97.5, rhat, ess_bulk
compute_mu_gamma_95ci <- function(model_path, gamma_indices = c(1, 2)) {
  samples <- read_samples(model_path)
  if (is.null(samples)) return(NULL)

  # Also read summary for rhat and ess_bulk
  summ_path <- file.path(model_path, "summ.rds")
  summ <- if (file.exists(summ_path)) readRDS(summ_path) else NULL

  results <- list()

  for (idx in gamma_indices) {
    param_name <- paste0("mu_gamma[", idx, "]")

    if (!(param_name %in% names(samples))) {
      next
    }

    param_samples <- samples[[param_name]]

    # Compute statistics
    # mean_exp: posterior mean of exp(samples), i.e. mean(exp(samples))
    # mean_exp_p10: posterior mean of exp(0.1 * samples), for proportion scaling
    result <- tibble(
      variable = param_name,
      mean = mean(param_samples, na.rm = TRUE),
      mean_exp = mean(exp(param_samples), na.rm = TRUE),
      mean_exp_p10 = mean(exp(0.1 * param_samples), na.rm = TRUE),
      median = median(param_samples, na.rm = TRUE),
      sd = sd(param_samples, na.rm = TRUE),
      q2.5 = quantile(param_samples, 0.025, na.rm = TRUE),
      q97.5 = quantile(param_samples, 0.975, na.rm = TRUE)
    )

    # Add rhat and ess_bulk from summary if available
    if (!is.null(summ)) {
      summ_row <- summ[summ$variable == param_name, ]
      if (nrow(summ_row) > 0) {
        result$rhat <- summ_row$rhat[1]
        result$ess_bulk <- summ_row$ess_bulk[1]
      } else {
        result$rhat <- NA_real_
        result$ess_bulk <- NA_real_
      }
    } else {
      result$rhat <- NA_real_
      result$ess_bulk <- NA_real_
    }

    results[[length(results) + 1]] <- result
  }

  if (length(results) == 0) return(NULL)
  bind_rows(results)
}

#' Extract a Single mu_gamma with 95% CI
#' @param model_path Path to model directory
#' @param gamma_index Which gamma index (1 or 2)
#' @return A list with mean, median, sd, q2.5, q97.5, rhat, ess_bulk
extract_mu_gamma_95ci <- function(model_path, gamma_index = 1) {
  result <- compute_mu_gamma_95ci(model_path, gamma_indices = gamma_index)
  if (is.null(result) || nrow(result) == 0) return(NULL)

  row <- result[1, ]
  list(
    mean = row$mean,
    mean_exp = row$mean_exp,
    mean_exp_p10 = row$mean_exp_p10,
    median = row$median,
    sd = row$sd,
    q2.5 = row$q2.5,
    q97.5 = row$q97.5,
    rhat = row$rhat,
    ess_bulk = row$ess_bulk
  )
}

#' Compute 95% CI for Beta Parameters from Samples
#' @param model_path Path to a model directory containing samples.rds
#' @param param_pattern Regex pattern to match parameter names (default: "^beta\\[")
#' @return A tibble with variable, mean, q2.5, q97.5, rhat, ess_bulk
compute_beta_95ci <- function(model_path, param_pattern = "^beta\\[") {
  samples <- read_samples(model_path)
  if (is.null(samples)) return(NULL)

  # Also read summary for rhat and ess_bulk
  summ_path <- file.path(model_path, "summ.rds")
  summ <- if (file.exists(summ_path)) readRDS(summ_path) else NULL

  # Find matching parameter names
  all_params <- names(samples)
  matching_params <- all_params[str_detect(all_params, param_pattern)]

  if (length(matching_params) == 0) return(NULL)

  results <- map_dfr(matching_params, function(param_name) {
    param_samples <- samples[[param_name]]

    result <- tibble(
      variable = param_name,
      mean = mean(param_samples, na.rm = TRUE),
      mean_exp = mean(exp(param_samples), na.rm = TRUE),
      mean_exp_p10 = mean(exp(0.1 * param_samples), na.rm = TRUE),
      q2.5 = quantile(param_samples, 0.025, na.rm = TRUE),
      q97.5 = quantile(param_samples, 0.975, na.rm = TRUE)
    )

    # Add rhat and ess_bulk from summary if available
    if (!is.null(summ)) {
      summ_row <- summ[summ$variable == param_name, ]
      if (nrow(summ_row) > 0) {
        result$rhat <- summ_row$rhat[1]
        result$ess_bulk <- summ_row$ess_bulk[1]
      } else {
        result$rhat <- NA_real_
        result$ess_bulk <- NA_real_
      }
    } else {
      result$rhat <- NA_real_
      result$ess_bulk <- NA_real_
    }

    result
  })

  results
}

#' Find Beta Parameters with 95% CI (replacement for find_betas)
#' @param model A model object with summary and predictor_map
#' @param model_path Path to the model directory (for samples)
#' @return A tibble of named beta parameters with q2.5, q97.5
find_betas_95ci <- function(model, model_path) {
  map <- model[['predictor_map']]

  # Get 95% CI from samples
  beta_95 <- compute_beta_95ci(model_path)
  if (is.null(beta_95)) return(NULL)

  # Join with predictor map to get named columns
  beta_95 <- beta_95 %>%
    mutate(index = as.integer(str_extract(variable, "(?<=\\[)\\d+"))) %>%
    left_join(map, by = c('index' = 'col_index')) %>%
    filter(mean != 0) %>%
    select(model_col, variable, mean, mean_exp, mean_exp_p10, q2.5, q97.5, rhat, ess_bulk)

  beta_95
}

#' Exponentiate Parameters with 95% CI columns
#' @param df A tibble of parameters with q2.5, q97.5
#' @param col The column containing the parameter name
#' @param slope_id A string identifying slope parameters
#' @param unit The time unit for scaling slopes
#' @return A tibble with exponentiated numeric columns
exp_params_95ci <- function(df, col, slope_id, unit = 'year') {
  units <- list(day = 365.25, year = 1, month = 365.25 / 12)
  scale <- units[[unit]]
  df %>%
    mutate(
      is_slope = str_detect(.data[[col]], slope_id) &
        !is.infinite(ess_bulk)) %>%
    mutate(across(
      c(q2.5, q97.5),
      ~ if_else(is_slope, exp(.x / scale), exp(.x)))) %>%
    # Use pre-computed mean(exp(samples)) for correct posterior mean of rate ratio
    mutate(mean = mean_exp) %>%
    select(-is_slope, -mean_exp)
}

#' Wrapper to Exponentiate Beta Parameters with 95% CI
exp_betas_95ci <- function(df, unit = 'year') {
  df %>% exp_params_95ci('model_col', 'slope', unit)
}

#' Extract Restaurant-Level Gammas with 95% CI
#' @param model_path Path to model directory
#' @param is_its Whether this is an ITS model (has slope parameters)
#' @return A tibble with restaurant-level gamma estimates and 95% CI
extract_restaurant_gammas_95ci <- function(model_path, is_its = FALSE) {
  if (!file.exists(file.path(model_path, "summ.rds")) ||
      !file.exists(file.path(model_path, "predictor_map.rds")) ||
      !file.exists(file.path(model_path, "samples.rds"))) {
    return(NULL)
  }

  model <- list(
    summary = readRDS(file.path(model_path, "summ.rds")),
    predictor_map = readRDS(file.path(model_path, "predictor_map.rds"))
  )

  # Get betas with 95% CI
  gammas <- find_betas_95ci(model, model_path)
  if (is.null(gammas)) return(NULL)

  gammas <- gammas %>%
    filter(!is.na(model_col) & str_detect(model_col, "exposure"))

  if (nrow(gammas) == 0) return(NULL)

  if (is_its) {
    gammas <- gammas %>%
      mutate(
        is_slope = str_detect(model_col, "_slope"),
        effect_type = if_else(is_slope, "Slope Change", "Level Change")
      )
  }

  # Extract restaurant ID from model_col
  gammas <- gammas %>%
    exp_betas_95ci(unit = "year") %>%
    mutate(
      mean = round(mean, 2),
      q2.5 = round(q2.5, 2),
      q97.5 = round(q97.5, 2),
      restaurant_id = model_col %>%
        str_replace("^exposure_", "") %>%
        str_replace("_\\d+(_slope)?$", "")
    )

  return(gammas)
}

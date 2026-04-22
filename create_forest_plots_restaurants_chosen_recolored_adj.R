source("publication/forest_fallback.R")
source("publication/adj_fallback.R")
# Forest Plot Generation Script - ADJUSTED VERSION (Outcome RR / Total RR)
# Creates horizontal forest plots showing adjusted rate ratios
# Adjusted = outcome samples - total samples in log space per MCMC draw
# Based on create_forest_plots_restaurants_chosen_recolored.R

library(tidyverse)
library(ggplot2)
library(patchwork)
library(htmlwidgets)
library(plotly)

source("model_scripts/view_params_funcs.R")
source("model_scripts/ci95_helpers.R")

# ─────────────────────────────────────
#         Configuration - EDIT HERE
# ─────────────────────────────────────

DEFAULT_MODEL_PATH <- "finalized_redone_trunc"

# A1 proportion overrides
A1_OVERRIDES <- list()

# A2 a2_proportion_t overrides
A2_OVERRIDES <- list()

# A3 its overrides
A3_OVERRIDES <- list(
  "total" = "finalized_redone_trunc_cp",
  "nonvegan" = "finalized_redone_trunc_cp",
  "meat" = "finalized_redone_trunc_cp",
  "chicken_fish" = "finalized_redone_trunc_cp",
  "vegetarian" = "finalized_redone_trunc_cp",
  "vegan" = "finalized_redone_trunc_cp"
)

# A4 a4_its_t overrides
A4_OVERRIDES <- list(
  "breakfast" = "finalized_redone_trunc_cp",
  "textured" = "finalized_redone_trunc_cp",
  "untextured" = "finalized_redone_trunc_cp"
)

# A5 Gaussian IID (transaction-level, pre-period demeaned, identity link)
A5GI_MODEL_PATH <- "finalized_redone_trunc_cp"
A5GI_ANALYSIS   <- "a5_customer_day"

OUTPUT_DIR_BASE <- "forest_plots/forest_plots_restaurants_trunc_recolored_adj"

# ─────────────────────────────────────
#    Adjusted Estimate Helper Functions
# ─────────────────────────────────────

# Environment-based caches to avoid re-reading files
.samples_cache <- new.env(parent = emptyenv())
.beta_map_cache <- new.env(parent = emptyenv())

read_samples_cached <- function(model_path) {
  key <- model_path
  if (exists(key, envir = .samples_cache)) {
    return(get(key, envir = .samples_cache))
  }
  samples <- read_samples(model_path)
  if (!is.null(samples)) {
    assign(key, samples, envir = .samples_cache)
  }
  return(samples)
}

#' Compute Adjusted mu_gamma: outcome - total in log space per MCMC draw
#' @param outcome_path Path to outcome model directory
#' @param total_path Path to total model directory
#' @param gamma_index Which gamma index (1 or 2)
#' @return A list with mean, median, sd, q2.5, q97.5, rhat, ess_bulk
compute_adjusted_mu_gamma <- function(outcome_path, total_path, gamma_index = 1) {
  samples_outcome <- read_samples_cached(outcome_path)
  samples_total <- read_samples_cached(total_path)

  if (is.null(samples_outcome) || is.null(samples_total)) {
    # Fallback: use precomputed adj CSV (publication/forest_data_adj_95ci.csv)
    fb <- tryCatch(adj_mu_gamma_from_csv(outcome_path, gamma_index), error = function(e) NULL)
    if (!is.null(fb)) return(fb)
    warning(paste("Missing samples for adjusted computation and no CSV fallback:",
                  if (is.null(samples_outcome)) outcome_path else total_path))
    return(NULL)
  }

  param_name <- paste0("mu_gamma[", gamma_index, "]")

  if (!(param_name %in% names(samples_outcome))) {
    warning(paste("Parameter", param_name, "not found in outcome samples:", outcome_path))
    return(NULL)
  }
  if (!(param_name %in% names(samples_total))) {
    warning(paste("Parameter", param_name, "not found in total samples:", total_path))
    return(NULL)
  }

  outcome_draws <- samples_outcome[[param_name]]
  total_draws <- samples_total[[param_name]]

  # Truncate to min length if sample counts differ
  n <- min(length(outcome_draws), length(total_draws))
  diff_draws <- outcome_draws[1:n] - total_draws[1:n]

  # Get rhat and ess_bulk from outcome model's summ.rds
  summ_path <- file.path(outcome_path, "summ.rds")
  rhat_val <- NA_real_
  ess_val <- NA_real_
  if (file.exists(summ_path)) {
    summ <- read_summ_fallback(dirname(summ_path))
    summ_row <- summ[summ$variable == param_name, ]
    if (nrow(summ_row) > 0) {
      rhat_val <- summ_row$rhat[1]
      ess_val <- summ_row$ess_bulk[1]
    }
  }

  list(
    mean = mean(diff_draws, na.rm = TRUE),
    median = median(diff_draws, na.rm = TRUE),
    sd = sd(diff_draws, na.rm = TRUE),
    q2.5 = unname(quantile(diff_draws, 0.025, na.rm = TRUE)),
    q97.5 = unname(quantile(diff_draws, 0.975, na.rm = TRUE)),
    mean_exp = mean(exp(diff_draws), na.rm = TRUE),
    mean_exp_p10 = mean(exp(0.1 * diff_draws), na.rm = TRUE),
    rhat = rhat_val,
    ess_bulk = ess_val
  )
}

#' Build a mapping from restaurant_id to beta variable names in samples
#' Uses cached samples to avoid redundant disk reads.
#' Results are also cached per model_path.
#' @param model_path Path to model directory
#' @return A tibble with restaurant_id, variable, model_col, is_slope
build_restaurant_beta_map <- function(model_path) {
  # Check beta map cache first
  if (exists(model_path, envir = .beta_map_cache)) {
    return(get(model_path, envir = .beta_map_cache))
  }

  pred_map_file <- file.path(model_path, "predictor_map.rds")
  summ_file <- file.path(model_path, "summ.rds")

  if (!file.exists(pred_map_file) || !file.exists(summ_file)) {
    return(NULL)
  }

  # Use cached samples instead of re-reading from disk
  samples <- read_samples_cached(model_path)
  if (is.null(samples)) return(NULL)

  pred_map <- readRDS(pred_map_file)
  summ <- read_summ_fallback(outcome_dir)

  # Find beta parameters directly from cached samples (avoids find_betas_95ci re-reading)
  all_params <- names(samples)
  beta_params <- all_params[str_detect(all_params, "^beta\\[")]

  if (length(beta_params) == 0) return(NULL)

  # Compute means from cached samples to identify nonzero betas
  beta_df <- tibble(
    variable = beta_params,
    mean = map_dbl(beta_params, ~ mean(samples[[.x]], na.rm = TRUE))
  ) %>%
    filter(mean != 0) %>%
    mutate(index = as.integer(str_extract(variable, "(?<=\\[)\\d+"))) %>%
    left_join(pred_map, by = c("index" = "col_index")) %>%
    filter(!is.na(model_col) & str_detect(model_col, "exposure"))

  if (nrow(beta_df) == 0) return(NULL)

  result <- beta_df %>%
    mutate(
      is_slope = str_detect(model_col, "_slope"),
      restaurant_id = model_col %>%
        str_replace("^exposure_", "") %>%
        str_replace("_\\d+(_slope)?$", "")
    ) %>%
    select(restaurant_id, variable, model_col, is_slope)

  # Cache the result
  assign(model_path, result, envir = .beta_map_cache)
  return(result)
}

#' Compute Adjusted Restaurant-Level Gammas
#' @param outcome_path Path to outcome model directory
#' @param total_path Path to total model directory
#' @param is_its Whether this is an ITS model (has slope parameters)
#' @return A tibble with restaurant-level adjusted gamma estimates
compute_adjusted_restaurant_gammas <- function(outcome_path, total_path, is_its = FALSE) {
  outcome_map <- build_restaurant_beta_map(outcome_path)
  total_map   <- build_restaurant_beta_map(total_path)

  samples_outcome <- read_samples_cached(outcome_path)
  samples_total   <- read_samples_cached(total_path)

  if (is.null(samples_outcome) || is.null(samples_total)) {
    fb <- tryCatch(adj_restaurant_gammas_from_csv(outcome_path),
                   error = function(e) NULL)
    if (!is.null(fb) && nrow(fb) > 0) {
      fb$is_slope <- grepl("_slope$", fb$model_col)
      fb$variable <- NA_character_
      return(tibble::as_tibble(fb))
    }
    return(NULL)
  }

  if (is.null(outcome_map) || is.null(total_map)) return(NULL)

  # Inner join on (restaurant_id, is_slope) to match restaurants
  joined <- outcome_map %>%
    inner_join(total_map, by = c("restaurant_id", "is_slope"),
               suffix = c("_outcome", "_total"))

  if (nrow(joined) == 0) return(NULL)

  results <- list()

  for (i in 1:nrow(joined)) {
    row <- joined[i, ]
    var_outcome <- row$variable_outcome
    var_total <- row$variable_total

    if (!(var_outcome %in% names(samples_outcome)) ||
        !(var_total %in% names(samples_total))) {
      next
    }

    outcome_draws <- samples_outcome[[var_outcome]]
    total_draws <- samples_total[[var_total]]

    # Truncate to min length
    n <- min(length(outcome_draws), length(total_draws))
    diff_draws <- outcome_draws[1:n] - total_draws[1:n]

    results[[length(results) + 1]] <- tibble(
      restaurant_id = row$restaurant_id,
      model_col = row$model_col_outcome,
      is_slope = row$is_slope,
      variable = var_outcome,
      mean = mean(diff_draws, na.rm = TRUE),
      q2.5 = unname(quantile(diff_draws, 0.025, na.rm = TRUE)),
      q97.5 = unname(quantile(diff_draws, 0.975, na.rm = TRUE)),
      mean_exp = mean(exp(diff_draws), na.rm = TRUE),
      mean_exp_p10 = mean(exp(0.1 * diff_draws), na.rm = TRUE),
      rhat = NA_real_,
      ess_bulk = NA_real_
    )
  }

  if (length(results) == 0) return(NULL)

  gammas <- bind_rows(results)

  # Add effect_type for ITS
  if (is_its) {
    gammas <- gammas %>%
      mutate(effect_type = if_else(is_slope, "Slope Change", "Level Change"))
  }

  # Exponentiate (same as original: exp_betas_95ci with unit="year")
  gammas <- gammas %>%
    exp_betas_95ci(unit = "year") %>%
    mutate(
      mean = round(mean, 2),
      q2.5 = round(q2.5, 2),
      q97.5 = round(q97.5, 2)
    )

  return(gammas)
}

# ─────────────────────────────────────
#   A5 Gaussian IID Adjusted Helpers
#   Identity link: subtraction, no exp()
# ─────────────────────────────────────

compute_adjusted_mu_gamma_identity <- function(outcome_path, total_path, gamma_index = 1) {
  samples_outcome <- read_samples_cached(outcome_path)
  samples_total <- read_samples_cached(total_path)
  if (is.null(samples_outcome) || is.null(samples_total)) {
    fb <- tryCatch(adj_mu_gamma_from_csv(outcome_path, gamma_index), error = function(e) NULL)
    if (!is.null(fb)) {
      return(list(mean = fb$mean, q2.5 = fb$q2.5, q97.5 = fb$q97.5,
                  rhat = fb$rhat, ess_bulk = fb$ess_bulk))
    }
    return(NULL)
  }

  param_name <- paste0("mu_gamma[", gamma_index, "]")
  if (!(param_name %in% names(samples_outcome))) return(NULL)
  if (!(param_name %in% names(samples_total))) return(NULL)

  outcome_draws <- samples_outcome[[param_name]]
  total_draws <- samples_total[[param_name]]
  n <- min(length(outcome_draws), length(total_draws))
  diff_draws <- outcome_draws[1:n] - total_draws[1:n]

  summ_path <- file.path(outcome_path, "summ.rds")
  rhat_val <- NA_real_; ess_val <- NA_real_
  if (file.exists(summ_path)) {
    summ <- read_summ_fallback(dirname(summ_path))
    summ_row <- summ[summ$variable == param_name, ]
    if (nrow(summ_row) > 0) { rhat_val <- summ_row$rhat[1]; ess_val <- summ_row$ess_bulk[1] }
  }

  list(mean = mean(diff_draws, na.rm = TRUE),
       q2.5 = unname(quantile(diff_draws, 0.025, na.rm = TRUE)),
       q97.5 = unname(quantile(diff_draws, 0.975, na.rm = TRUE)),
       rhat = rhat_val, ess_bulk = ess_val)
}

compute_adjusted_restaurant_gammas_identity <- function(outcome_path, total_path) {
  pred_map_file_o <- file.path(outcome_path, "predictor_map.rds")
  pred_map_file_t <- file.path(total_path, "predictor_map.rds")
  if (!file.exists(pred_map_file_o) || !file.exists(pred_map_file_t)) return(NULL)

  samples_outcome <- read_samples_cached(outcome_path)
  samples_total <- read_samples_cached(total_path)
  if (is.null(samples_outcome) || is.null(samples_total)) {
    fb <- tryCatch(adj_restaurant_gammas_from_csv(outcome_path),
                   error = function(e) NULL)
    if (!is.null(fb) && nrow(fb) > 0) {
      fb$is_slope <- FALSE
      fb$variable <- NA_character_
      return(tibble::as_tibble(fb))
    }
    return(NULL)
  }

  pmap_o <- readRDS(pred_map_file_o)
  pmap_t <- readRDS(pred_map_file_t)

  build_map <- function(beta_vars, samples, pmap) {
    tibble(variable = beta_vars) %>%
      mutate(mean = map_dbl(variable, ~ mean(samples[[.x]], na.rm = TRUE)),
             index = as.integer(str_extract(variable, "(?<=\\[)\\d+"))) %>%
      filter(mean != 0) %>%
      left_join(pmap, by = c("index" = "col_index")) %>%
      filter(!is.na(model_col) & str_detect(model_col, "^exposure_"))
  }

  beta_o <- names(samples_outcome)[str_detect(names(samples_outcome), "^beta\\[")]
  beta_t <- names(samples_total)[str_detect(names(samples_total), "^beta\\[")]
  map_o <- build_map(beta_o, samples_outcome, pmap_o)
  map_t <- build_map(beta_t, samples_total, pmap_t)
  if (nrow(map_o) == 0 || nrow(map_t) == 0) return(NULL)

  joined <- map_o %>% inner_join(map_t, by = "model_col", suffix = c("_outcome", "_total"))
  if (nrow(joined) == 0) return(NULL)

  results <- list()
  for (i in 1:nrow(joined)) {
    row <- joined[i, ]
    var_o <- row$variable_outcome; var_t <- row$variable_total
    if (!(var_o %in% names(samples_outcome)) || !(var_t %in% names(samples_total))) next
    draws_o <- samples_outcome[[var_o]]; draws_t <- samples_total[[var_t]]
    n <- min(length(draws_o), length(draws_t))
    diff_draws <- draws_o[1:n] - draws_t[1:n]
    is_slope <- str_detect(row$model_col, "_slope")
    is_gender <- str_detect(row$model_col, "_gendermale$")
    results[[length(results) + 1]] <- tibble(
      restaurant_id = row$model_col %>% str_replace("^exposure_", "") %>% str_replace("_\\d+(_slope|_gendermale)?$", ""),
      effect_type = case_when(is_gender ~ "Gender x Level", is_slope ~ "Slope Change", TRUE ~ "Level Change"),
      mean = mean(diff_draws, na.rm = TRUE),
      q2.5 = unname(quantile(diff_draws, 0.025, na.rm = TRUE)),
      q97.5 = unname(quantile(diff_draws, 0.975, na.rm = TRUE)),
      rhat = NA_real_, ess_bulk = NA_real_)
  }
  if (length(results) == 0) return(NULL)
  bind_rows(results)
}

# compute_adjusted_gender_identity removed — Gender x Level now flows through
# the gamma hierarchy (mu_gamma[3]/gamma[3,r]) and is handled by
# compute_adjusted_mu_gamma_identity(_, _, 3) for pooled and
# compute_adjusted_restaurant_gammas_identity for restaurant-level.

# ─────────────────────────────────────
#             Helper Functions
# ─────────────────────────────────────

format_label <- function(name) {
  name %>%
    str_replace_all("_", " ") %>%
    str_to_title()}

get_model_path <- function(outcome, overrides, default = DEFAULT_MODEL_PATH) {
  if (outcome %in% names(overrides)) {
    return(overrides[[outcome]])
  }
  return(default)
}

calc_xlim_median <- function(df, multiplier = 2.5, x_max_input=3) {
  med_mean <- median(df$mean, na.rm = TRUE)
  med_q2.5 <- median(df$q2.5, na.rm = TRUE)
  med_q97.5 <- median(df$q97.5, na.rm = TRUE)

  spread_low <- med_mean - med_q2.5
  spread_high <- med_q97.5 - med_mean
  typical_spread <- max(spread_low, spread_high)

  x_min <- max(0.01, med_mean - multiplier * typical_spread)
  x_max <- med_mean + multiplier * typical_spread

  x_min <- min(x_min, 0)
  x_max <- max(x_max, x_max_input)

  c(x_min, x_max)
}

clip_to_limits <- function(df, xlim) {
  df %>%
    mutate(
      mean_orig = mean,
      q2.5_orig = q2.5,
      q97.5_orig = q97.5,
      clipped = mean < xlim[1] | mean > xlim[2],
      mean_disp = pmin(pmax(mean, xlim[1]), xlim[2]),
      q2.5_disp = q2.5,
      q97.5_disp = q97.5
    )
}

calc_xlim_identity <- function(df, multiplier = 2.5, x_max_input = 3) {
  med_mean <- median(df$mean, na.rm = TRUE)
  med_q2.5 <- median(df$q2.5, na.rm = TRUE)
  med_q97.5 <- median(df$q97.5, na.rm = TRUE)
  spread_low <- med_mean - med_q2.5
  spread_high <- med_q97.5 - med_mean
  typical_spread <- max(spread_low, spread_high)
  x_min <- med_mean - multiplier * typical_spread
  x_max <- med_mean + multiplier * typical_spread
  x_max <- max(x_max, x_max_input)
  x_min <- min(x_min, -x_max_input)
  c(x_min, x_max)
}

# ─────────────────────────────────────
# 1. PROPORTION Analysis (A1) - ADJUSTED
# ─────────────────────────────────────

create_proportion_forest_restaurants <- function(log_scale = FALSE) {
  output_dir <- if (log_scale) file.path(paste0(OUTPUT_DIR_BASE, "_log")) else file.path(OUTPUT_DIR_BASE)
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  cat("Creating ADJUSTED proportion forest plot with restaurant estimates...\n")
  cat("  Using A1 overrides:", paste(names(A1_OVERRIDES), "->", A1_OVERRIDES, collapse = ", "), "\n")

  outcomes <- c("total", "nonvegan", "meat", "chicken_fish", "vegetarian", "vegan")
  exposure_groups <- c("mpbamod", "vegan", "vegetarian")
  exposure_types <- c("count", "prop")

  pooled_list <- list()
  restaurant_list <- list()

  for (outcome in outcomes) {
    model_path_name <- get_model_path(outcome, A1_OVERRIDES)
    model_run_path <- file.path("model_fits", model_path_name)

    for (exp_group in exposure_groups) {
      for (exp_type in exposure_types) {
        exposure <- paste0(exp_group, "_dishes_", exp_type)

        if (outcome == "total") {
          # Adjusted RR for total = 1.0 exactly (diff = 0 in log space)
          pooled_list[[length(pooled_list) + 1]] <- tibble(
            outcome = outcome,
            exposure_group = exp_group,
            exposure_type = exp_type,
            mean = 0,
            q2.5 = 0,
            q97.5 = 0,
            mean_exp = 1,
            mean_exp_p10 = 1,
            rhat = NA_real_,
            estimate_type = "Pooled",
            restaurant_id = "POOLED")
          next
        }

        outcome_path <- file.path(model_run_path, "a1_proportion", outcome, exposure)

        # Total path: same exposure but under "total" outcome
        total_model_path_name <- get_model_path("total", A1_OVERRIDES)
        total_run_path <- file.path("model_fits", total_model_path_name)
        total_path <- file.path(total_run_path, "a1_proportion", "total", exposure)

        # Adjusted pooled estimate
        gamma <- compute_adjusted_mu_gamma(outcome_path, total_path, 1)
        if (!is.null(gamma)) {
          pooled_list[[length(pooled_list) + 1]] <- tibble(
            outcome = outcome,
            exposure_group = exp_group,
            exposure_type = exp_type,
            mean = gamma$mean,
            q2.5 = gamma$q2.5,
            q97.5 = gamma$q97.5,
            mean_exp = gamma$mean_exp,
            mean_exp_p10 = gamma$mean_exp_p10,
            rhat = gamma$rhat,
            estimate_type = "Pooled",
            restaurant_id = "POOLED")
        }

        # Adjusted restaurant-level estimates
        rest_gammas <- compute_adjusted_restaurant_gammas(outcome_path, total_path, is_its = FALSE)
        if (!is.null(rest_gammas) && nrow(rest_gammas) > 0) {
          for (i in 1:nrow(rest_gammas)) {
            restaurant_list[[length(restaurant_list) + 1]] <- tibble(
              outcome = outcome,
              exposure_group = exp_group,
              exposure_type = exp_type,
              mean = rest_gammas$mean[i],
              q2.5 = rest_gammas$q2.5[i],
              q97.5 = rest_gammas$q97.5[i],
              mean_exp_p10 = rest_gammas$mean_exp_p10[i],
              rhat = rest_gammas$rhat[i],
              estimate_type = "Restaurant",
              restaurant_id = rest_gammas$restaurant_id[i])
          }
        }
      }
    }
  }

  df_pooled <- bind_rows(pooled_list)
  df_restaurant <- bind_rows(restaurant_list)

  if (nrow(df_pooled) == 0) {
    cat("  No data found for proportion analysis\n")
    return(NULL)
  }

  df_all <- bind_rows(df_pooled, df_restaurant)

  df_all$outcome <- factor(df_all$outcome, levels = rev(outcomes))
  df_all$exposure_group <- factor(df_all$exposure_group, levels = exposure_groups)
  df_all$exposure_type <- factor(df_all$exposure_type, levels = c("prop", "count"),
                                  labels = c("Proportion", "Count"))

  df_all <- df_all %>%
    mutate(color_group = case_when(
      outcome == "total" ~ "Total",
      outcome %in% c("nonvegan", "meat", "chicken_fish") ~ "Animal",
      outcome %in% c("vegetarian", "vegan") ~ "Plant-based"))

  if (!log_scale) {
    df_all <- df_all %>%
      mutate(
        across(c(q2.5, q97.5), ~ case_when(
          exposure_type == "Count" & estimate_type == "Pooled" ~ exp(.x),
          exposure_type == "Count" & estimate_type == "Restaurant" ~ exp(.x),
          exposure_type == "Proportion" & estimate_type == "Pooled" ~ exp(.1 * .x),
          exposure_type == "Proportion" & estimate_type == "Restaurant" ~ exp(.1 * .x),
          TRUE ~ .x)),
        mean = case_when(
          exposure_type == "Count" & estimate_type == "Pooled" ~ mean_exp,
          exposure_type == "Count" & estimate_type == "Restaurant" ~ mean_exp,
          exposure_type == "Proportion" & estimate_type == "Pooled" ~ mean_exp_p10,
          exposure_type == "Proportion" & estimate_type == "Restaurant" ~ mean_exp_p10,
          TRUE ~ mean))
  } else {
    df_all <- df_all %>%
      mutate(
        across(c(mean, q2.5, q97.5), ~ case_when(
          estimate_type == "Restaurant" ~ log(.x),
          TRUE ~ .x)))
  }

  # Filter out pooled estimates when only 1 restaurant contributes
  n_restaurants <- df_all %>%
    filter(estimate_type == "Restaurant") %>%
    group_by(outcome, exposure_group, exposure_type) %>%
    summarise(n_rest = n_distinct(restaurant_id), .groups = "drop")
  df_all <- df_all %>%
    left_join(n_restaurants, by = c("outcome", "exposure_group", "exposure_type")) %>%
    filter(!(estimate_type == "Pooled" & !is.na(n_rest) & n_rest <= 1)) %>%
    select(-n_rest)

  df_all <- df_all %>%
    group_by(outcome, exposure_group, exposure_type) %>%
    mutate(
      n_in_group = n(),
      row_in_group = row_number(),
      y_numeric = as.numeric(outcome) +
        case_when(
          estimate_type == "Pooled" ~ 0,
          TRUE ~ -0.12 * row_in_group
        )
    ) %>%
    ungroup()

  xlim <- if (log_scale) calc_xlim_median(df_all, x_max_input = 10) else calc_xlim_median(df_all)
  df_all <- clip_to_limits(df_all, xlim)

  df_pooled <- df_all %>% filter(estimate_type == "Pooled")
  df_restaurant <- df_all %>% filter(estimate_type == "Restaurant")

  p <- ggplot() +
    geom_vline(xintercept = if (log_scale) 0 else 1, linetype = "dashed", color = "gray50") +
    {if (nrow(df_restaurant) > 0)
      geom_errorbarh(data = df_restaurant,
                     aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                     height = 0.06, alpha = 0.4, linewidth = 0.3)} +
    {if (nrow(df_restaurant) > 0)
      geom_point(data = df_restaurant,
                 aes(x = mean_disp, y = y_numeric, color = color_group,
                     shape = clipped,
                     text = paste0(
                       "Restaurant: ", restaurant_id, "<br>",
                       "Outcome: ", outcome, "<br>",
                       "Exposure: ", exposure_group, " (", exposure_type, ")<br>",
                       "Adjusted Rate Ratio: ", signif(mean_orig, 3), "<br>",
                       "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                       ifelse(clipped, "<br>(Value clipped to fit scale)", ""))),
                 size = 1.2, alpha = 0.5)} +
    scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 17), guide = "none") +
    geom_errorbarh(data = df_pooled,
                   aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                   height = 0.15, linewidth = 0.8) +
    geom_point(data = df_pooled,
               aes(x = mean_disp, y = y_numeric, color = color_group, text = paste0(
                 "POOLED<br>",
                 "Outcome: ", outcome, "<br>",
                 "Exposure: ", exposure_group, " (", exposure_type, ")<br>",
                 "Adjusted Rate Ratio: ", signif(mean_orig, 3), "<br>",
                 "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                 ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), ""))),
               size = 2.5) +
    scale_color_manual(values = c("Total" = "steelblue", "Animal" = "firebrick", "Plant-based" = "forestgreen"),
                       guide = "none") +
    facet_grid(exposure_group ~ exposure_type, scales = "free_y", space = "free_y") +
    scale_x_continuous(limits = xlim, oob = scales::squish) +
    scale_y_continuous(
      breaks = 1:length(outcomes),
      labels = format_label(rev(outcomes)),
      expand = expansion(mult = c(0.15, 0.05))) +
    labs(
      title = "A1: Proportion Analysis (Adjusted)",
      subtitle = paste0("Outcome RR / Total RR | ",
                        if (log_scale) "Log Adjusted Rate Ratios" else "Adjusted Rate Ratios",
                        " | Large points = pooled, Small = restaurants | Triangles = values beyond scale"),
      x = if (log_scale) "Log Adjusted Rate Ratio" else "Adjusted Rate Ratio",
      y = "Outcome") +
    theme_minimal(base_size = 11) +
    theme(
      panel.grid.minor = element_blank(),
      strip.background = element_rect(fill = "gray90", color = NA),
      strip.text = element_text(face = "bold"),
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 9, color = "gray40"),
      axis.text.y = element_text(size = 10))

  ggsave(file.path(output_dir, "A1_proportion_forest_restaurants.png"), p,
         width = 11, height = 12, dpi = 300)
  ggsave(file.path(output_dir, "A1_proportion_forest_restaurants.pdf"), p,
         width = 11, height = 12)

  p_plotly <- ggplotly(p, tooltip = "text")
  html_name <- if (log_scale) "A1_proportion_forest_restaurants_log.html" else "A1_proportion_forest_restaurants.html"
  try(saveWidget(p_plotly, file.path(output_dir, html_name), selfcontained = TRUE), silent = TRUE)

  df_save <- df_all %>% select(-matches("_disp|_orig|clipped|y_numeric|n_in_group|row_in_group"))
  csv_name <- if (log_scale) "A1_proportion_restaurants_data_log.csv" else "A1_proportion_restaurants_data.csv"
  write_csv(df_save, file.path(output_dir, csv_name))

  cat("  Saved: A1_proportion_forest_restaurants.png, .pdf, .html, _data.csv\n")
  return(p)
}

# ─────────────────────────────────────
# 2. PROPORTION_TARGETED Analysis (A2) - ADJUSTED
# ─────────────────────────────────────

create_proportion_targeted_forest_restaurants <- function(log_scale = FALSE) {
  output_dir <- if (log_scale) file.path(paste0(OUTPUT_DIR_BASE, "_log")) else file.path(OUTPUT_DIR_BASE)
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  cat("Creating ADJUSTED a2_proportion_t forest plot with restaurant estimates...\n")
  cat("  Using overrides:", paste(names(A2_OVERRIDES), "->", A2_OVERRIDES, collapse = ", "), "\n")

  outcomes <- c("breakfast_p", "chicken_p", "dairy_p", "egg_p", "untextured_p")
  outcome_labels <- c("Breakfast", "Chicken", "Dairy", "Egg", "Untextured")
  exposure_types <- c("count", "presence")

  pooled_list <- list()
  restaurant_list <- list()

  for (i in seq_along(outcomes)) {
    outcome <- outcomes[i]
    outcome_label <- outcome_labels[i]

    model_path_name <- get_model_path(outcome, A2_OVERRIDES)
    model_run_path <- file.path("model_fits", model_path_name)

    for (exp_type in exposure_types) {
      dish_base <- str_replace(outcome, "_p$", "")
      exposure <- paste0(dish_base, "_dishes_", exp_type)
      outcome_path <- file.path(model_run_path, "a2_proportion_t", outcome, exposure)

      # Total path: proportion/total/mpbamod_dishes_count for count,
      #             proportion/total/mpbamod_dishes_prop for presence
      total_model_path_name <- get_model_path("total", A1_OVERRIDES)
      total_run_path <- file.path("model_fits", total_model_path_name)
      total_exposure <- if (exp_type == "count") "mpbamod_dishes_count" else "mpbamod_dishes_prop"
      total_path <- file.path(total_run_path, "a1_proportion", "total", total_exposure)

      # Adjusted pooled estimate
      gamma <- compute_adjusted_mu_gamma(outcome_path, total_path, 1)
      if (!is.null(gamma)) {
        pooled_list[[length(pooled_list) + 1]] <- tibble(
          outcome = outcome_label,
          exposure_type = exp_type,
          mean = gamma$mean,
          q2.5 = gamma$q2.5,
          q97.5 = gamma$q97.5,
          mean_exp = gamma$mean_exp,
          mean_exp_p10 = gamma$mean_exp_p10,
          rhat = gamma$rhat,
          estimate_type = "Pooled",
          restaurant_id = "POOLED",
          source = model_path_name)
      }

      # Adjusted restaurant-level estimates
      rest_gammas <- compute_adjusted_restaurant_gammas(outcome_path, total_path, is_its = FALSE)
      if (!is.null(rest_gammas) && nrow(rest_gammas) > 0) {
        for (j in 1:nrow(rest_gammas)) {
          restaurant_list[[length(restaurant_list) + 1]] <- tibble(
            outcome = outcome_label,
            exposure_type = exp_type,
            mean = rest_gammas$mean[j],
            q2.5 = rest_gammas$q2.5[j],
            q97.5 = rest_gammas$q97.5[j],
            mean_exp_p10 = rest_gammas$mean_exp_p10[j],
            rhat = rest_gammas$rhat[j],
            estimate_type = "Restaurant",
            restaurant_id = rest_gammas$restaurant_id[j],
            source = model_path_name)
        }
      }
    }
  }

  # "Total (A1)" reference row: hardcode diff=0, RR=1.0
  for (exp_type in c("count", "presence")) {
    pooled_list[[length(pooled_list) + 1]] <- tibble(
      outcome = "Total (A1)",
      exposure_type = exp_type,
      mean = 0,
      q2.5 = 0,
      q97.5 = 0,
      mean_exp = 1,
      mean_exp_p10 = 1,
      rhat = NA_real_,
      estimate_type = "Pooled",
      restaurant_id = "POOLED",
      source = DEFAULT_MODEL_PATH)
  }

  df_pooled <- bind_rows(pooled_list)
  df_restaurant <- bind_rows(restaurant_list)

  if (nrow(df_pooled) == 0) {
    cat("  No data found for a2_proportion_t analysis\n")
    return(NULL)
  }

  df_all <- bind_rows(df_pooled, df_restaurant)

  all_outcomes <- c("Total (A1)", outcome_labels)
  df_all$outcome <- factor(df_all$outcome, levels = rev(all_outcomes))
  df_all$exposure_type <- factor(df_all$exposure_type, levels = c("presence", "count"),
                                  labels = c("Presence", "Count"))

  df_all <- df_all %>%
    mutate(color_group = ifelse(outcome == "Total (A1)", "Total", "Animal"))

  if (!log_scale) {
    df_all <- df_all %>%
      mutate(
        across(c(q2.5, q97.5), ~ case_when(
          exposure_type == "Count" & estimate_type == "Pooled" ~ exp(.x),
          exposure_type == "Presence" & estimate_type == "Pooled" ~ exp(.1 * .x),
          exposure_type == "Presence" & estimate_type == "Restaurant" ~ .x^0.1,
          TRUE ~ .x)),
        mean = case_when(
          exposure_type == "Count" & estimate_type == "Pooled" ~ mean_exp,
          exposure_type == "Presence" & estimate_type == "Pooled" ~ mean_exp_p10,
          exposure_type == "Presence" & estimate_type == "Restaurant" ~ mean_exp_p10,
          TRUE ~ mean))
  } else {
    df_all <- df_all %>%
      mutate(
        across(c(mean, q2.5, q97.5), ~ case_when(
          estimate_type == "Restaurant" ~ log(.x),
          TRUE ~ .x)))
  }

  # Filter out pooled estimates when only 1 restaurant contributes
  n_restaurants <- df_all %>%
    filter(estimate_type == "Restaurant") %>%
    group_by(outcome, exposure_type) %>%
    summarise(n_rest = n_distinct(restaurant_id), .groups = "drop")
  df_all <- df_all %>%
    left_join(n_restaurants, by = c("outcome", "exposure_type")) %>%
    filter(!(estimate_type == "Pooled" & !is.na(n_rest) & n_rest <= 1)) %>%
    select(-n_rest)

  df_all <- df_all %>%
    group_by(outcome, exposure_type) %>%
    mutate(
      n_in_group = n(),
      row_in_group = row_number(),
      y_numeric = as.numeric(outcome) +
        case_when(
          estimate_type == "Pooled" ~ 0,
          TRUE ~ -0.15 * row_in_group
        )
    ) %>%
    ungroup()

  xlim <- if (log_scale) calc_xlim_median(df_all, x_max_input = 10) else calc_xlim_median(df_all)
  df_all <- clip_to_limits(df_all, xlim)

  df_pooled <- df_all %>% filter(estimate_type == "Pooled")
  df_restaurant <- df_all %>% filter(estimate_type == "Restaurant")

  p <- ggplot() +
    geom_vline(xintercept = if (log_scale) 0 else 1, linetype = "dashed", color = "gray50") +
    {if (nrow(df_restaurant) > 0)
      geom_errorbarh(data = df_restaurant,
                     aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                     height = 0.08, alpha = 0.4, linewidth = 0.3)} +
    {if (nrow(df_restaurant) > 0)
      geom_point(data = df_restaurant,
                 aes(x = mean_disp, y = y_numeric, color = color_group,
                     shape = clipped,
                     text = paste0(
                       "Restaurant: ", restaurant_id, "<br>",
                       "Outcome: ", outcome, "<br>",
                       "Exposure: ", exposure_type, "<br>",
                       "Adjusted Rate Ratio: ", signif(mean_orig, 3), "<br>",
                       "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                       "<br>Source: ", source,
                       ifelse(clipped, "<br>(Value clipped to fit scale)", ""))),
                 size = 1.2, alpha = 0.5)} +
    scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 17), guide = "none") +
    geom_errorbarh(data = df_pooled,
                   aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                   height = 0.15, linewidth = 0.8) +
    geom_point(data = df_pooled,
               aes(x = mean_disp, y = y_numeric, color = color_group, text = paste0(
                 "POOLED<br>",
                 "Outcome: ", outcome, "<br>",
                 "Exposure: ", exposure_type, "<br>",
                 "Adjusted Rate Ratio: ", signif(mean_orig, 3), "<br>",
                 "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                 "<br>Source: ", source,
                 ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), ""))),
               size = 2.5) +
    scale_color_manual(values = c("Total" = "steelblue", "Animal" = "firebrick"),
                       guide = "none") +
    facet_wrap(~ exposure_type, ncol = 2) +
    scale_x_continuous(limits = xlim, oob = scales::squish) +
    scale_y_continuous(
      breaks = 1:length(all_outcomes),
      labels = rev(all_outcomes),
      expand = expansion(mult = c(0.2, 0.1))) +
    labs(
      title = "A2: Targeted Animal Product Categories Proportion Analysis (Adjusted)",
      subtitle = paste0("Outcome RR / Total RR | ",
                        if (log_scale) "Log Adjusted Rate Ratios" else "Adjusted Rate Ratios",
                        " | Large points = pooled, Small = restaurants | Triangles = values beyond scale"),
      x = if (log_scale) "Log Adjusted Rate Ratio" else "Adjusted Rate Ratio",
      y = "Outcome") +
    theme_minimal(base_size = 11) +
    theme(
      panel.grid.minor = element_blank(),
      strip.background = element_rect(fill = "gray90", color = NA),
      strip.text = element_text(face = "bold"),
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 9, color = "gray40"),
      axis.text.y = element_text(size = 10))

  ggsave(file.path(output_dir, "A2_proportion_targeted_forest_restaurants.png"), p,
         width = 10, height = 7, dpi = 300)
  ggsave(file.path(output_dir, "A2_proportion_targeted_forest_restaurants.pdf"), p,
         width = 10, height = 7)

  p_plotly <- ggplotly(p, tooltip = "text")
  html_name <- if (log_scale) "A2_proportion_targeted_forest_restaurants_log.html" else "A2_proportion_targeted_forest_restaurants.html"
  try(saveWidget(p_plotly, file.path(output_dir, html_name), selfcontained = TRUE), silent = TRUE)

  df_save <- df_all %>% select(-matches("_disp|_orig|clipped|y_numeric|n_in_group|row_in_group"))
  csv_name <- if (log_scale) "A2_proportion_targeted_restaurants_data_log.csv" else "A2_proportion_targeted_restaurants_data.csv"
  write_csv(df_save, file.path(output_dir, csv_name))

  cat("  Saved: A2_proportion_targeted_forest_restaurants.png, .pdf, .html, _data.csv\n")
  return(p)
}

# ─────────────────────────────────────
# 3. ITS Analysis (A3) - ADJUSTED
# ─────────────────────────────────────

create_its_forest_restaurants <- function(log_scale = FALSE) {
  output_dir <- if (log_scale) file.path(paste0(OUTPUT_DIR_BASE, "_log")) else file.path(OUTPUT_DIR_BASE)
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  cat("Creating ADJUSTED ITS forest plot with restaurant estimates...\n")
  cat("  Using A3 overrides:", paste(names(A3_OVERRIDES), "->", A3_OVERRIDES, collapse = ", "), "\n")

  outcomes <- c("total", "nonvegan", "meat", "chicken_fish", "vegetarian", "vegan")

  pooled_list <- list()
  restaurant_list <- list()

  # Total model path for A3
  total_model_path_name <- get_model_path("total", A3_OVERRIDES)
  total_run_path <- file.path("model_fits", total_model_path_name)
  total_path <- file.path(total_run_path, "a3_its", "total")

  for (outcome in outcomes) {
    model_path_name <- get_model_path(outcome, A3_OVERRIDES)
    model_run_path <- file.path("model_fits", model_path_name)
    outcome_path <- file.path(model_run_path, "a3_its", outcome)

    if (outcome == "total") {
      # Adjusted RR for total = 1.0 exactly (diff = 0)
      for (eff in c("Level Change", "Slope Change")) {
        pooled_list[[length(pooled_list) + 1]] <- tibble(
          outcome = outcome,
          effect_type = eff,
          mean = 0,
          q2.5 = 0,
          q97.5 = 0,
          mean_exp = 1,
          rhat = NA_real_,
          ess_bulk = NA_real_,
          estimate_type = "Pooled",
          restaurant_id = "POOLED")
      }
      next
    }

    # Adjusted gamma[1] (level change)
    gamma1 <- compute_adjusted_mu_gamma(outcome_path, total_path, 1)
    if (!is.null(gamma1)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome,
        effect_type = "Level Change",
        mean = gamma1$mean,
        q2.5 = gamma1$q2.5,
        q97.5 = gamma1$q97.5,
        mean_exp = gamma1$mean_exp,
        rhat = gamma1$rhat,
        ess_bulk = gamma1$ess_bulk,
        estimate_type = "Pooled",
        restaurant_id = "POOLED")
    }

    # Adjusted gamma[2] (slope change)
    gamma2 <- compute_adjusted_mu_gamma(outcome_path, total_path, 2)
    if (!is.null(gamma2)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome,
        effect_type = "Slope Change",
        mean = gamma2$mean,
        q2.5 = gamma2$q2.5,
        q97.5 = gamma2$q97.5,
        mean_exp = gamma2$mean_exp,
        rhat = gamma2$rhat,
        ess_bulk = gamma2$ess_bulk,
        estimate_type = "Pooled",
        restaurant_id = "POOLED")
    }

    # Adjusted restaurant-level estimates (handles both level/slope)
    rest_gammas <- compute_adjusted_restaurant_gammas(outcome_path, total_path, is_its = TRUE)
    if (!is.null(rest_gammas) && nrow(rest_gammas) > 0) {
      for (i in 1:nrow(rest_gammas)) {
        restaurant_list[[length(restaurant_list) + 1]] <- tibble(
          outcome = outcome,
          effect_type = rest_gammas$effect_type[i],
          mean = rest_gammas$mean[i],
          q2.5 = rest_gammas$q2.5[i],
          q97.5 = rest_gammas$q97.5[i],
          rhat = rest_gammas$rhat[i],
          ess_bulk = NA_real_,
          estimate_type = "Restaurant",
          restaurant_id = rest_gammas$restaurant_id[i])
      }
    }
  }

  df_pooled <- bind_rows(pooled_list)
  df_restaurant <- bind_rows(restaurant_list)

  if (nrow(df_pooled) == 0) {
    cat("  No data found for ITS analysis\n")
    return(NULL)
  }

  df_all <- bind_rows(df_pooled, df_restaurant)

  df_all$outcome <- factor(df_all$outcome, levels = rev(outcomes))
  df_all$effect_type <- factor(df_all$effect_type, levels = c("Level Change", "Slope Change"))

  df_all <- df_all %>%
    mutate(color_group = case_when(
      outcome == "total" ~ "Total",
      outcome %in% c("nonvegan", "meat", "chicken_fish") ~ "Animal",
      outcome %in% c("vegetarian", "vegan") ~ "Plant-based"))

  if (!log_scale) {
    df_pooled_part <- df_all %>%
      filter(estimate_type == "Pooled") %>%
      mutate(across(c(q2.5, q97.5), ~ exp(.x)), mean = mean_exp)
    df_restaurant_only <- df_all %>% filter(estimate_type == "Restaurant")
    df_all <- bind_rows(df_pooled_part, df_restaurant_only)
  } else {
    df_all <- df_all %>%
      mutate(
        across(c(mean, q2.5, q97.5), ~ case_when(
          estimate_type == "Restaurant" ~ log(.x),
          TRUE ~ .x)))
  }

  # Filter out pooled estimates when only 1 restaurant contributes
  n_restaurants <- df_all %>%
    filter(estimate_type == "Restaurant") %>%
    group_by(outcome, effect_type) %>%
    summarise(n_rest = n_distinct(restaurant_id), .groups = "drop")
  df_all <- df_all %>%
    left_join(n_restaurants, by = c("outcome", "effect_type")) %>%
    filter(!(estimate_type == "Pooled" & !is.na(n_rest) & n_rest <= 1)) %>%
    select(-n_rest)

  df_all <- df_all %>%
    group_by(outcome, effect_type) %>%
    mutate(
      n_in_group = n(),
      row_in_group = row_number(),
      y_numeric = as.numeric(outcome) +
        case_when(
          estimate_type == "Pooled" ~ 0,
          TRUE ~ -0.08 * row_in_group
        )
    ) %>%
    ungroup()

  xlim <- if (log_scale) calc_xlim_median(df_all, x_max_input = 10) else calc_xlim_median(df_all)
  df_all <- clip_to_limits(df_all, xlim)

  df_pooled <- df_all %>% filter(estimate_type == "Pooled")
  df_restaurant <- df_all %>% filter(estimate_type == "Restaurant")

  p <- ggplot() +
    geom_vline(xintercept = if (log_scale) 0 else 1, linetype = "dashed", color = "gray50") +
    {if (nrow(df_restaurant) > 0)
      geom_errorbarh(data = df_restaurant,
                     aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                     height = 0.05, alpha = 0.4, linewidth = 0.3)} +
    {if (nrow(df_restaurant) > 0)
      geom_point(data = df_restaurant,
                 aes(x = mean_disp, y = y_numeric, color = color_group,
                     shape = clipped,
                     text = paste0(
                       "Restaurant: ", restaurant_id, "<br>",
                       "Outcome: ", outcome, "<br>",
                       "Effect: ", effect_type, "<br>",
                       "Adjusted Rate Ratio: ", signif(mean_orig, 3), "<br>",
                       "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                       ifelse(clipped, "<br>(Value clipped to fit scale)", ""))),
                 size = 1.2, alpha = 0.5)} +
    scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 17), guide = "none") +
    geom_errorbarh(data = df_pooled,
                   aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                   height = 0.15, linewidth = 0.8) +
    geom_point(data = df_pooled,
               aes(x = mean_disp, y = y_numeric, color = color_group, text = paste0(
                 "POOLED<br>",
                 "Outcome: ", outcome, "<br>",
                 "Effect: ", effect_type, "<br>",
                 "Adjusted Rate Ratio: ", signif(mean_orig, 3), "<br>",
                 "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                 ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), ""))),
               size = 2.5) +
    scale_color_manual(values = c("Total" = "steelblue", "Animal" = "firebrick", "Plant-based" = "forestgreen"),
                       guide = "none") +
    facet_wrap(~ effect_type, ncol = 2) +
    scale_x_continuous(limits = xlim, oob = scales::squish) +
    scale_y_continuous(
      breaks = 1:length(outcomes),
      labels = format_label(rev(outcomes)),
      expand = expansion(mult = c(0.2, 0.1))) +
    labs(
      title = "A3: Interrupted Time Series Analysis (Adjusted)",
      subtitle = paste0("Outcome RR / Total RR | ",
                        if (log_scale) "Log Adjusted Rate Ratios" else "Adjusted Rate Ratios",
                        " | Large points = pooled, Small = restaurants | Triangles = values beyond scale"),
      x = if (log_scale) "Log Adjusted Rate Ratio" else "Adjusted Rate Ratio",
      y = "Outcome") +
    theme_minimal(base_size = 11) +
    theme(
      panel.grid.minor = element_blank(),
      strip.background = element_rect(fill = "gray90", color = NA),
      strip.text = element_text(face = "bold"),
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 9, color = "gray40"),
      axis.text.y = element_text(size = 10))

  ggsave(file.path(output_dir, "A3_its_forest_restaurants.png"), p,
         width = 10, height = 8, dpi = 300)
  ggsave(file.path(output_dir, "A3_its_forest_restaurants.pdf"), p,
         width = 10, height = 8)

  p_plotly <- ggplotly(p, tooltip = "text")
  html_name <- if (log_scale) "A3_its_forest_restaurants_log.html" else "A3_its_forest_restaurants.html"
  try(saveWidget(p_plotly, file.path(output_dir, html_name), selfcontained = TRUE), silent = TRUE)

  df_save <- df_all %>% select(-matches("_disp|_orig|clipped|y_numeric|n_in_group|row_in_group"))
  csv_name <- if (log_scale) "A3_its_restaurants_data_log.csv" else "A3_its_restaurants_data.csv"
  write_csv(df_save, file.path(output_dir, csv_name))

  cat("  Saved: A3_its_forest_restaurants.png, .pdf, .html, _data.csv\n")
  return(p)
}

# ─────────────────────────────────────
# 4. ITS_TARGETED Analysis (A4) - ADJUSTED
# ─────────────────────────────────────

create_its_targeted_forest_restaurants <- function(log_scale = FALSE) {
  output_dir <- if (log_scale) file.path(paste0(OUTPUT_DIR_BASE, "_log")) else file.path(OUTPUT_DIR_BASE)
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  cat("Creating ADJUSTED ITS targeted forest plot with restaurant estimates...\n")
  cat("  Using overrides:", paste(names(A4_OVERRIDES), "->", A4_OVERRIDES, collapse = ", "), "\n")

  outcomes <- c("breakfast", "textured", "untextured")

  pooled_list <- list()
  restaurant_list <- list()

  # Total model path (same as A3)
  total_model_path_name <- get_model_path("total", A3_OVERRIDES)
  total_run_path <- file.path("model_fits", total_model_path_name)
  total_path <- file.path(total_run_path, "a3_its", "total")

  for (outcome in outcomes) {
    model_path_name <- get_model_path(outcome, A4_OVERRIDES)
    model_run_path <- file.path("model_fits", model_path_name)
    outcome_path <- file.path(model_run_path, "a4_its_t", outcome)

    # Count restaurants from the outcome model's beta map (not the inner join)
    outcome_beta_map <- build_restaurant_beta_map(outcome_path)
    n_rest_in_model <- if (!is.null(outcome_beta_map)) n_distinct(outcome_beta_map$restaurant_id) else 0

    # Adjusted gamma[1] (level change)
    gamma1 <- compute_adjusted_mu_gamma(outcome_path, total_path, 1)
    if (!is.null(gamma1)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome,
        effect_type = "Level Change",
        mean = gamma1$mean,
        q2.5 = gamma1$q2.5,
        q97.5 = gamma1$q97.5,
        mean_exp = gamma1$mean_exp,
        rhat = gamma1$rhat,
        ess_bulk = gamma1$ess_bulk,
        estimate_type = "Pooled",
        restaurant_id = "POOLED",
        n_rest_model = n_rest_in_model,
        source = model_path_name)
    }

    # Adjusted gamma[2] (slope change)
    gamma2 <- compute_adjusted_mu_gamma(outcome_path, total_path, 2)
    if (!is.null(gamma2)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome,
        effect_type = "Slope Change",
        mean = gamma2$mean,
        q2.5 = gamma2$q2.5,
        q97.5 = gamma2$q97.5,
        mean_exp = gamma2$mean_exp,
        rhat = gamma2$rhat,
        ess_bulk = gamma2$ess_bulk,
        estimate_type = "Pooled",
        restaurant_id = "POOLED",
        n_rest_model = n_rest_in_model,
        source = model_path_name)
    }

    # Adjusted restaurant-level estimates
    rest_gammas <- compute_adjusted_restaurant_gammas(outcome_path, total_path, is_its = TRUE)
    if (!is.null(rest_gammas) && nrow(rest_gammas) > 0) {
      for (i in 1:nrow(rest_gammas)) {
        restaurant_list[[length(restaurant_list) + 1]] <- tibble(
          outcome = outcome,
          effect_type = rest_gammas$effect_type[i],
          mean = rest_gammas$mean[i],
          q2.5 = rest_gammas$q2.5[i],
          q97.5 = rest_gammas$q97.5[i],
          rhat = rest_gammas$rhat[i],
          ess_bulk = NA_real_,
          estimate_type = "Restaurant",
          restaurant_id = rest_gammas$restaurant_id[i],
          source = model_path_name)
      }
    }
  }

  # "Total (A3)" reference row: hardcode diff=0, RR=1.0
  for (eff in c("Level Change", "Slope Change")) {
    pooled_list[[length(pooled_list) + 1]] <- tibble(
      outcome = "Total (A3)",
      effect_type = eff,
      mean = 0,
      q2.5 = 0,
      q97.5 = 0,
      mean_exp = 1,
      rhat = NA_real_,
      ess_bulk = NA_real_,
      estimate_type = "Pooled",
      restaurant_id = "POOLED",
      source = total_model_path_name)
  }

  df_pooled <- bind_rows(pooled_list)
  df_restaurant <- bind_rows(restaurant_list)

  if (nrow(df_pooled) == 0) {
    cat("  No data found for ITS targeted analysis\n")
    return(NULL)
  }

  df_all <- bind_rows(df_pooled, df_restaurant)

  all_outcomes <- c("Total (A3)", outcomes)
  df_all$outcome <- factor(df_all$outcome, levels = rev(all_outcomes))
  df_all$effect_type <- factor(df_all$effect_type, levels = c("Level Change", "Slope Change"))

  df_all <- df_all %>%
    mutate(color_group = ifelse(outcome == "Total (A3)", "Total", "Animal"))

  if (!log_scale) {
    df_pooled_part <- df_all %>%
      filter(estimate_type == "Pooled") %>%
      mutate(across(c(q2.5, q97.5), ~ exp(.x)), mean = mean_exp)
    df_restaurant_only <- df_all %>% filter(estimate_type == "Restaurant")
    df_all <- bind_rows(df_pooled_part, df_restaurant_only)
  } else {
    df_all <- df_all %>%
      mutate(
        across(c(mean, q2.5, q97.5), ~ case_when(
          estimate_type == "Restaurant" ~ log(.x),
          TRUE ~ .x)))
  }

  # Remove pooled for textured (only 1 restaurant, so mu_gamma = that restaurant's gamma)
  df_all <- df_all %>%
    filter(!(estimate_type == "Pooled" & outcome == "textured"))

  df_all <- df_all %>%
    group_by(outcome, effect_type) %>%
    mutate(
      n_in_group = n(),
      row_in_group = row_number(),
      y_numeric = as.numeric(outcome) +
        case_when(
          estimate_type == "Pooled" ~ 0,
          TRUE ~ -0.1 * row_in_group
        )
    ) %>%
    ungroup()

  xlim <- if (log_scale) calc_xlim_median(df_all, x_max_input = 10) else calc_xlim_median(df_all)
  df_all <- clip_to_limits(df_all, xlim)

  df_pooled <- df_all %>% filter(estimate_type == "Pooled")
  df_restaurant <- df_all %>% filter(estimate_type == "Restaurant")

  p <- ggplot() +
    geom_vline(xintercept = if (log_scale) 0 else 1, linetype = "dashed", color = "gray50") +
    {if (nrow(df_restaurant) > 0)
      geom_errorbarh(data = df_restaurant,
                     aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                     height = 0.06, alpha = 0.4, linewidth = 0.3)} +
    {if (nrow(df_restaurant) > 0)
      geom_point(data = df_restaurant,
                 aes(x = mean_disp, y = y_numeric, color = color_group,
                     shape = clipped,
                     text = paste0(
                       "Restaurant: ", restaurant_id, "<br>",
                       "Outcome: ", outcome, "<br>",
                       "Effect: ", effect_type, "<br>",
                       "Adjusted Rate Ratio: ", signif(mean_orig, 3), "<br>",
                       "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                       "<br>Source: ", source,
                       ifelse(clipped, "<br>(Value clipped to fit scale)", ""))),
                 size = 1.2, alpha = 0.5)} +
    scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 17), guide = "none") +
    geom_errorbarh(data = df_pooled,
                   aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                   height = 0.15, linewidth = 0.8) +
    geom_point(data = df_pooled,
               aes(x = mean_disp, y = y_numeric, color = color_group, text = paste0(
                 "POOLED<br>",
                 "Outcome: ", outcome, "<br>",
                 "Effect: ", effect_type, "<br>",
                 "Adjusted Rate Ratio: ", signif(mean_orig, 3), "<br>",
                 "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                 "<br>Source: ", source,
                 ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), ""))),
               size = 2.5) +
    scale_color_manual(values = c("Total" = "steelblue", "Animal" = "firebrick"),
                       guide = "none") +
    facet_wrap(~ effect_type, ncol = 2) +
    scale_x_continuous(limits = xlim, oob = scales::squish) +
    scale_y_continuous(
      breaks = 1:length(all_outcomes),
      labels = format_label(rev(all_outcomes)),
      expand = expansion(mult = c(0.25, 0.15))) +
    labs(
      title = "A4: Interrupted Time Series Targeted Animal Product Categories (Adjusted)",
      subtitle = paste0("Outcome RR / Total RR | ",
                        if (log_scale) "Log Adjusted Rate Ratios" else "Adjusted Rate Ratios",
                        " | Large points = pooled, Small = restaurants | Triangles = values beyond scale"),
      x = if (log_scale) "Log Adjusted Rate Ratio" else "Adjusted Rate Ratio",
      y = "Outcome") +
    theme_minimal(base_size = 11) +
    theme(
      panel.grid.minor = element_blank(),
      strip.background = element_rect(fill = "gray90", color = NA),
      strip.text = element_text(face = "bold"),
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 9, color = "gray40"),
      axis.text.y = element_text(size = 10))

  ggsave(file.path(output_dir, "A4_its_targeted_forest_restaurants.png"), p,
         width = 10, height = 6, dpi = 300)
  ggsave(file.path(output_dir, "A4_its_targeted_forest_restaurants.pdf"), p,
         width = 10, height = 6)

  p_plotly <- ggplotly(p, tooltip = "text")
  html_name <- if (log_scale) "A4_its_targeted_forest_restaurants_log.html" else "A4_its_targeted_forest_restaurants.html"
  try(saveWidget(p_plotly, file.path(output_dir, html_name), selfcontained = TRUE), silent = TRUE)

  df_save <- df_all %>% select(-matches("_disp|_orig|clipped|y_numeric|n_in_group|row_in_group"))
  csv_name <- if (log_scale) "A4_its_targeted_restaurants_data_log.csv" else "A4_its_targeted_restaurants_data.csv"
  write_csv(df_save, file.path(output_dir, csv_name))

  cat("  Saved: A4_its_targeted_forest_restaurants.png, .pdf, .html, _data.csv\n")
  return(p)
}

# ─────────────────────────────────────
# 5. Gaussian IID Analysis (A5) - ADJUSTED
# Transaction-level, pre-period demeaned, identity link
# Adjusted = outcome effect - total effect (subtraction)
# 3 facets: Level Change, Slope Change, Gender x Level
# ─────────────────────────────────────

create_gaussian_iid_forest_restaurants_adj <- function() {
  output_dir <- OUTPUT_DIR_BASE
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  cat("Creating ADJUSTED Gaussian IID forest plot with restaurant estimates...\n")

  outcomes <- c("total", "nonvegan", "meat", "chicken_fish", "vegetarian", "vegan")
  total_path <- file.path("model_fits", A5GI_MODEL_PATH, A5GI_ANALYSIS, "total")

  pooled_list <- list()
  restaurant_list <- list()

  for (outcome in outcomes) {
    outcome_path <- file.path("model_fits", A5GI_MODEL_PATH, A5GI_ANALYSIS, outcome)
    if (!file.exists(file.path(outcome_path, "summ.rds")) &&
        is.null(adj_mu_gamma_from_csv(outcome_path, 1))) {
      cat("  Skipping", outcome, "- no summ.rds and no adj CSV fallback
")
      next
    }

    if (outcome == "total") {
      # Adjusted total = 0 by definition
      for (eff in c("Level Change", "Slope Change", "Gender x Level")) {
        pooled_list[[length(pooled_list) + 1]] <- tibble(
          outcome = outcome, effect_type = eff,
          mean = 0, q2.5 = 0, q97.5 = 0,
          rhat = NA_real_, ess_bulk = NA_real_,
          estimate_type = "Pooled", restaurant_id = "POOLED")
      }
      next
    }

    # Adjusted Level Change
    gamma1 <- compute_adjusted_mu_gamma_identity(outcome_path, total_path, 1)
    if (!is.null(gamma1)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome, effect_type = "Level Change",
        mean = gamma1$mean, q2.5 = gamma1$q2.5, q97.5 = gamma1$q97.5,
        rhat = gamma1$rhat, ess_bulk = gamma1$ess_bulk,
        estimate_type = "Pooled", restaurant_id = "POOLED")
    }

    # Adjusted Slope Change
    gamma2 <- compute_adjusted_mu_gamma_identity(outcome_path, total_path, 2)
    if (!is.null(gamma2)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome, effect_type = "Slope Change",
        mean = gamma2$mean, q2.5 = gamma2$q2.5, q97.5 = gamma2$q97.5,
        rhat = gamma2$rhat, ess_bulk = gamma2$ess_bulk,
        estimate_type = "Pooled", restaurant_id = "POOLED")
    }

    # Adjusted Restaurant-Level Gammas
    rest_adj <- compute_adjusted_restaurant_gammas_identity(outcome_path, total_path)
    if (!is.null(rest_adj) && nrow(rest_adj) > 0) {
      for (i in 1:nrow(rest_adj)) {
        restaurant_list[[length(restaurant_list) + 1]] <- tibble(
          outcome = outcome, effect_type = rest_adj$effect_type[i],
          mean = rest_adj$mean[i], q2.5 = rest_adj$q2.5[i], q97.5 = rest_adj$q97.5[i],
          rhat = rest_adj$rhat[i], ess_bulk = rest_adj$ess_bulk[i],
          estimate_type = "Restaurant", restaurant_id = rest_adj$restaurant_id[i])
      }
    }

    # Adjusted Gender x Level (pooled: mu_gamma[3])
    gamma3 <- compute_adjusted_mu_gamma_identity(outcome_path, total_path, 3)
    if (!is.null(gamma3)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome, effect_type = "Gender x Level",
        mean = gamma3$mean, q2.5 = gamma3$q2.5, q97.5 = gamma3$q97.5,
        rhat = gamma3$rhat, ess_bulk = gamma3$ess_bulk,
        estimate_type = "Pooled", restaurant_id = "POOLED")
    }
    # Restaurant-level Gender x Level already included via
    # compute_adjusted_restaurant_gammas_identity above
  }

  df_pooled <- bind_rows(pooled_list)
  df_restaurant <- bind_rows(restaurant_list)

  if (nrow(df_pooled) == 0) {
    cat("  No data found for Gaussian IID adjusted analysis\n")
    return(NULL)
  }

  df_all <- bind_rows(df_pooled, df_restaurant)

  df_all$outcome <- factor(df_all$outcome, levels = rev(outcomes))
  df_all$effect_type <- factor(df_all$effect_type,
                                levels = c("Level Change", "Slope Change", "Gender x Level"))

  df_all <- df_all %>%
    mutate(color_group = case_when(
      outcome == "total" ~ "Total",
      outcome %in% c("nonvegan", "meat", "chicken_fish") ~ "Animal",
      outcome %in% c("vegetarian", "vegan") ~ "Plant-based"))

  # Skip pooled when only 1 restaurant
  n_restaurants <- df_all %>%
    filter(estimate_type == "Restaurant") %>%
    group_by(outcome, effect_type) %>%
    summarise(n_rest = n_distinct(restaurant_id), .groups = "drop")
  df_all <- df_all %>%
    left_join(n_restaurants, by = c("outcome", "effect_type")) %>%
    filter(!(estimate_type == "Pooled" & !is.na(n_rest) & n_rest <= 1)) %>%
    select(-n_rest)

  df_all <- df_all %>%
    group_by(outcome, effect_type) %>%
    mutate(
      n_in_group = n(),
      row_in_group = row_number(),
      y_numeric = as.numeric(outcome) +
        case_when(
          estimate_type == "Pooled" ~ 0,
          TRUE ~ -0.08 * row_in_group
        )
    ) %>%
    ungroup()

  xlim <- calc_xlim_identity(df_all)
  df_all <- clip_to_limits(df_all, xlim)

  df_pooled <- df_all %>% filter(estimate_type == "Pooled")
  df_restaurant <- df_all %>% filter(estimate_type == "Restaurant")

  p <- ggplot() +
    geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
    {if (nrow(df_restaurant) > 0)
      geom_errorbarh(data = df_restaurant,
                     aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                     height = 0.05, alpha = 0.4, linewidth = 0.3)} +
    {if (nrow(df_restaurant) > 0)
      geom_point(data = df_restaurant,
                 aes(x = mean_disp, y = y_numeric, color = color_group,
                     shape = clipped,
                     text = paste0(
                       "Restaurant: ", restaurant_id, "<br>",
                       "Outcome: ", outcome, "<br>",
                       "Effect: ", effect_type, "<br>",
                       "Adjusted Estimate: ", signif(mean_orig, 3), "<br>",
                       "95% CrI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                       ifelse(clipped, "<br>(Value clipped to fit scale)", ""))),
                 size = 1.2, alpha = 0.5)} +
    scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 17), guide = "none") +
    geom_errorbarh(data = df_pooled,
                   aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                   height = 0.15, linewidth = 0.8) +
    geom_point(data = df_pooled,
               aes(x = mean_disp, y = y_numeric, color = color_group, text = paste0(
                 "POOLED<br>",
                 "Outcome: ", outcome, "<br>",
                 "Effect: ", effect_type, "<br>",
                 "Adjusted Estimate: ", signif(mean_orig, 3), "<br>",
                 "95% CrI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                 ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), ""))),
               size = 2.5) +
    scale_color_manual(values = c("Total" = "steelblue", "Animal" = "firebrick", "Plant-based" = "forestgreen"),
                       guide = "none") +
    facet_wrap(~ effect_type, ncol = 3) +
    scale_x_continuous(limits = xlim, oob = scales::squish) +
    scale_y_continuous(
      breaks = 1:length(outcomes),
      labels = format_label(rev(outcomes)),
      expand = expansion(mult = c(0.2, 0.1))) +
    labs(
      title = "A5: Gaussian IID (Transaction-Level, Pre-Period Demeaned) - Adjusted",
      subtitle = "Outcome effect - Total effect | Large points = pooled, Small = restaurants | 95% CrI",
      x = "Adjusted Effect (Outcome - Total)",
      y = "Outcome") +
    theme_minimal(base_size = 11) +
    theme(
      panel.grid.minor = element_blank(),
      strip.background = element_rect(fill = "gray90", color = NA),
      strip.text = element_text(face = "bold"),
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 9, color = "gray40"),
      axis.text.y = element_text(size = 10))

  ggsave(file.path(output_dir, "A5_gaussian_iid_forest_restaurants_adj.png"), p,
         width = 14, height = 8, dpi = 300)
  ggsave(file.path(output_dir, "A5_gaussian_iid_forest_restaurants_adj.pdf"), p,
         width = 14, height = 8)

  p_plotly <- ggplotly(p, tooltip = "text")
  try(saveWidget(p_plotly, file.path(output_dir, "A5_gaussian_iid_forest_restaurants_adj.html"),
             selfcontained = TRUE), silent = TRUE)

  df_save <- df_all %>% select(-matches("_disp|_orig|clipped|y_numeric|n_in_group|row_in_group"))
  write_csv(df_save, file.path(output_dir, "A5_gaussian_iid_restaurants_adj_data.csv"))

  cat("  Saved: A5_gaussian_iid_forest_restaurants_adj.png, .pdf, .html, _data.csv\n")
  return(p)
}

# ─────────────────────────────────────
# Execute (skipped when sourced with .forest_skip_execute option)
# ─────────────────────────────────────

if (!isTRUE(getOption(".forest_skip_execute"))) {

cat("========================================\n")
cat("Forest Plot Generation - ADJUSTED (Outcome RR / Total RR)\n")
cat("========================================\n")
cat("Default model path:", DEFAULT_MODEL_PATH, "\n")
cat("A1 overrides:", paste(names(A1_OVERRIDES), "->", A1_OVERRIDES, collapse = ", "), "\n")
cat("A2 overrides:", paste(names(A2_OVERRIDES), "->", A2_OVERRIDES, collapse = ", "), "\n")
cat("A3 overrides:", paste(names(A3_OVERRIDES), "->", A3_OVERRIDES, collapse = ", "), "\n")
cat("A4 overrides:", paste(names(A4_OVERRIDES), "->", A4_OVERRIDES, collapse = ", "), "\n")
cat("Output directory base:", OUTPUT_DIR_BASE, "\n\n")

p1 <- create_proportion_forest_restaurants()
p1_log <- create_proportion_forest_restaurants(log_scale = TRUE)
p2 <- create_proportion_targeted_forest_restaurants()
p2_log <- create_proportion_targeted_forest_restaurants(log_scale = TRUE)
p3 <- create_its_forest_restaurants()
p3_log <- create_its_forest_restaurants(log_scale = TRUE)
p4 <- create_its_targeted_forest_restaurants()
p4_log <- create_its_targeted_forest_restaurants(log_scale = TRUE)
p5 <- create_gaussian_iid_forest_restaurants_adj()

cat("\n========================================\n")
cat("All ADJUSTED forest plots generated!\n")
cat("Output directories:", OUTPUT_DIR_BASE, "and", paste0(OUTPUT_DIR_BASE, "_log"), "\n")
cat("========================================\n")

} # end if (!isTRUE(getOption(".forest_skip_execute")))

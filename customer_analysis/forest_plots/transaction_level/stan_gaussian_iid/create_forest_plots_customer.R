# Forest plots for Stan Gaussian IID results (transaction-level, demeaned)
# Reads summ.rds and predictor_map.rds from Stan model output directories.
# Identity link: no exp() transform, reference line at 0.
# Three facets:
#   1. Level Change (gamma / mu_gamma[1])
#   2. Slope Change (gamma / mu_gamma[2])
#   3. Gender x Level (beta / mu_beta_random for _gendermale columns)
# Also exports extracted results as CSVs.

library(tidyverse)
library(ggplot2)

# -----------------------------------------------
#  Paths
# -----------------------------------------------

RESULTS_DIR   <- "model_fits/finalized_redone_trunc/customer_gaussian_iid"
OUTPUT_DIR    <- "customer_analysis/forest_plots/transaction_level/stan_gaussian_iid"
CSV_DIR       <- "customer_analysis/level_transaction/stan_gaussian_iid/results_exposures"

dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(CSV_DIR, showWarnings = FALSE, recursive = TRUE)

format_label <- function(name) {
  name %>%
    str_replace_all("_", " ") %>%
    str_to_title()
}

# -----------------------------------------------
#  Extract per-restaurant exposure effects (gamma)
# -----------------------------------------------

extract_exposure_gammas <- function(outcome_dir, outcome_name) {

  summ_file <- file.path(outcome_dir, "summ.rds")
  pmap_file <- file.path(outcome_dir, "predictor_map.rds")
  rest_file <- file.path(outcome_dir, "restaurants_order.rds")

  if (!file.exists(summ_file) || !file.exists(pmap_file)) {
    warning("Missing summ.rds or predictor_map.rds in: ", outcome_dir)
    return(NULL)
  }

  summ <- readRDS(summ_file)
  pmap <- readRDS(pmap_file)
  restaurants <- if (file.exists(rest_file)) readRDS(rest_file) else NULL

  exposure_cols <- pmap %>%
    filter(type %in% c("exposure", "slope"))

  if (nrow(exposure_cols) == 0) return(NULL)

  R <- if (!is.null(restaurants)) length(restaurants) else {
    beta_vars <- summ %>% filter(str_starts(variable, "beta\\["))
    max(as.integer(str_match(beta_vars$variable, "beta\\[\\d+,(\\d+)\\]")[, 2]), na.rm = TRUE)
  }

  results <- list()
  for (i in seq_len(nrow(exposure_cols))) {
    col_idx   <- exposure_cols$col_index[i]
    model_col <- exposure_cols$model_col[i]
    col_type  <- exposure_cols$type[i]

    for (r in seq_len(R)) {
      var_name <- paste0("beta[", col_idx, ",", r, "]")
      row <- summ %>% filter(variable == var_name)
      if (nrow(row) == 0) next

      rest_id <- if (!is.null(restaurants)) restaurants[r] else paste0("rest_", r)

      exposure_period <- str_extract(model_col, "_(\\d+)(_slope)?$") %>%
        str_extract("\\d+")

      col_rest_id <- str_extract(model_col, "(?<=exposure_)[A-Z0-9]+")
      if (!is.null(restaurants) && col_rest_id != rest_id) next

      effect_type <- if (col_type == "slope") "Slope Change" else "Level Change"

      results[[length(results) + 1]] <- tibble(
        location_id     = rest_id,
        term            = model_col,
        effect_type     = effect_type,
        estimate        = row$mean,
        std_error       = row$sd,
        ci_lower        = row$q5,
        ci_upper        = row$q95,
        rhat            = row$rhat,
        ess_bulk        = row$ess_bulk,
        exposure_period = exposure_period,
        outcome_name    = outcome_name
      )
    }
  }

  if (length(results) == 0) return(NULL)
  bind_rows(results)
}

# -----------------------------------------------
#  Extract mu_gamma (global mean exposure effects)
# -----------------------------------------------

extract_mu_gamma <- function(outcome_dir, outcome_name) {

  summ_file <- file.path(outcome_dir, "summ.rds")
  if (!file.exists(summ_file)) return(NULL)
  summ <- readRDS(summ_file)

  mu_gamma_rows <- summ %>%
    filter(str_starts(variable, "mu_gamma"))

  if (nrow(mu_gamma_rows) == 0) return(NULL)

  mu_gamma_rows %>%
    mutate(
      param_index = as.integer(str_extract(variable, "\\d+")),
      effect_type = case_when(
        param_index == 1 ~ "Level Change",
        param_index == 2 ~ "Slope Change",
        TRUE ~ paste0("Param ", param_index)
      ),
      location_id     = "mu_gamma (global)",
      term            = variable,
      outcome_name    = outcome_name,
      estimate        = mean,
      std_error       = sd,
      ci_lower        = q5,
      ci_upper        = q95,
      exposure_period = NA_character_
    ) %>%
    select(location_id, term, effect_type, estimate, std_error,
           ci_lower, ci_upper, rhat, ess_bulk, exposure_period, outcome_name)
}

# -----------------------------------------------
#  Extract gender x exposure interactions
#  (per-restaurant from beta + pooled from mu_beta_random)
# -----------------------------------------------

extract_gender_interactions <- function(outcome_dir, outcome_name) {

  summ_file      <- file.path(outcome_dir, "summ.rds")
  pmap_file      <- file.path(outcome_dir, "predictor_map.rds")
  rest_file      <- file.path(outcome_dir, "restaurants_order.rds")
  data_list_file <- file.path(outcome_dir, "data_list.rds")

  if (!file.exists(summ_file) || !file.exists(pmap_file)) return(NULL)

  summ <- readRDS(summ_file)
  pmap <- readRDS(pmap_file)
  restaurants <- if (file.exists(rest_file)) readRDS(rest_file) else NULL
  data_list   <- if (file.exists(data_list_file)) readRDS(data_list_file) else NULL

  gender_cols <- pmap %>%
    filter(str_detect(model_col, "_gendermale$"))

  if (nrow(gender_cols) == 0) return(NULL)

  R <- if (!is.null(restaurants)) length(restaurants) else {
    beta_vars <- summ %>% filter(str_starts(variable, "beta\\["))
    max(as.integer(str_match(beta_vars$variable, "beta\\[\\d+,(\\d+)\\]")[, 2]), na.rm = TRUE)
  }

  idx_beta_random <- if (!is.null(data_list)) data_list$idx_beta_random else NULL

  results <- list()
  for (i in seq_len(nrow(gender_cols))) {
    col_idx   <- gender_cols$col_index[i]
    model_col <- gender_cols$model_col[i]

    exposure_period <- str_extract(model_col, "_(\\d+)(_gendermale)$") %>%
      str_extract("\\d+")

    col_rest_id <- str_extract(model_col, "(?<=exposure_)[A-Z0-9]+")

    # Per-restaurant: beta[col_idx, r]
    for (r in seq_len(R)) {
      var_name <- paste0("beta[", col_idx, ",", r, "]")
      row <- summ %>% filter(variable == var_name)
      if (nrow(row) == 0) next

      rest_id <- if (!is.null(restaurants)) restaurants[r] else paste0("rest_", r)
      if (!is.null(restaurants) && !is.null(col_rest_id) && col_rest_id != rest_id) next

      results[[length(results) + 1]] <- tibble(
        location_id     = rest_id,
        term            = model_col,
        effect_type     = "Gender x Level",
        estimate        = row$mean,
        std_error       = row$sd,
        ci_lower        = row$q5,
        ci_upper        = row$q95,
        rhat            = row$rhat,
        ess_bulk        = row$ess_bulk,
        exposure_period = exposure_period,
        outcome_name    = outcome_name
      )
    }

    # Pooled: mu_beta_random[position within idx_beta_random]
    if (!is.null(idx_beta_random)) {
      pos <- which(idx_beta_random == col_idx)
      if (length(pos) == 1) {
        var_name <- paste0("mu_beta_random[", pos, "]")
        row <- summ %>% filter(variable == var_name)
        if (nrow(row) > 0) {
          results[[length(results) + 1]] <- tibble(
            location_id     = "mu_beta (pooled)",
            term            = model_col,
            effect_type     = "Gender x Level",
            estimate        = row$mean,
            std_error       = row$sd,
            ci_lower        = row$q5,
            ci_upper        = row$q95,
            rhat            = row$rhat,
            ess_bulk        = row$ess_bulk,
            exposure_period = exposure_period,
            outcome_name    = outcome_name
          )
        }
      }
    }
  }

  if (length(results) == 0) return(NULL)
  bind_rows(results)
}

# -----------------------------------------------
#  Identity link: raw effect sizes
# -----------------------------------------------

to_effect_sizes <- function(df) {
  df %>%
    mutate(
      effect       = estimate,
      effect_lower = ci_lower,
      effect_upper = ci_upper
    )
}

# -----------------------------------------------
#  Clipping helpers
# -----------------------------------------------

clip_data <- function(df, xlim, val_col = "effect", lo_col = "effect_lower", hi_col = "effect_upper") {
  df %>%
    mutate(
      clipped  = .data[[val_col]] < xlim[1] | .data[[val_col]] > xlim[2],
      val_disp = pmin(pmax(.data[[val_col]], xlim[1]), xlim[2]),
      lo_disp  = pmax(.data[[lo_col]], xlim[1]),
      hi_disp  = pmin(.data[[hi_col]], xlim[2])
    )
}

# -----------------------------------------------
#  Common theme
# -----------------------------------------------

forest_theme <- function() {
  theme_minimal(base_size = 11) +
    theme(
      plot.background   = element_rect(fill = "white", color = NA),
      panel.background  = element_rect(fill = "white", color = NA),
      panel.grid.minor  = element_blank(),
      strip.background  = element_rect(fill = "gray90", color = NA),
      strip.text        = element_text(face = "bold"),
      plot.title        = element_text(face = "bold", size = 14),
      plot.subtitle     = element_text(size = 9, color = "gray40"),
      axis.text.y       = element_text(size = 10))
}

# -----------------------------------------------
#  Build 3-column forest plot
# -----------------------------------------------

build_forest_3col <- function(df, title, subtitle, outcome_levels, filename,
                              width = 14, height = 8) {

  facet_order <- c("Level Change", "Slope Change", "Gender x Level")
  df$effect_type  <- factor(df$effect_type, levels = facet_order)
  df$outcome_name <- factor(df$outcome_name, levels = rev(outcome_levels))

  # Color by facet type
  facet_colors <- c(
    "Level Change"   = "steelblue",
    "Slope Change"   = "steelblue",
    "Gender x Level" = "darkorange"
  )

  df <- df %>%
    mutate(
      rest_label = paste0(location_id,
                          ifelse(!is.na(exposure_period) & exposure_period != "1",
                                 paste0(" (exp ", exposure_period, ")"), "")),
      facet_color = facet_colors[as.character(effect_type)]
    )

  df <- df %>%
    group_by(outcome_name, effect_type) %>%
    mutate(
      row_in_group = row_number(),
      y_numeric    = as.numeric(outcome_name) - 0.12 * (row_in_group - 1)
    ) %>%
    ungroup()

  all_vals <- c(df$effect, df$effect_lower, df$effect_upper)
  max_abs <- max(abs(all_vals[is.finite(all_vals)]), na.rm = TRUE)
  xlim_bound <- min(max_abs * 1.2, 5)
  xlim <- c(-xlim_bound, xlim_bound)

  df <- clip_data(df, xlim, "effect", "effect_lower", "effect_upper")

  p <- ggplot(df) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
    geom_errorbarh(
      aes(xmin = lo_disp, xmax = hi_disp, y = y_numeric, color = effect_type),
      height = 0.08, alpha = 0.6, linewidth = 0.4) +
    geom_point(
      aes(x = val_disp, y = y_numeric, shape = clipped, color = effect_type),
      size = 2.2) +
    scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 17), guide = "none") +
    scale_color_manual(values = facet_colors, guide = "none") +
    facet_wrap(~ effect_type, ncol = 3) +
    scale_x_continuous(limits = xlim, oob = scales::squish) +
    scale_y_continuous(
      breaks   = seq_along(outcome_levels),
      labels   = format_label(rev(outcome_levels)),
      expand   = expansion(mult = c(0.15, 0.05))) +
    labs(
      title    = title,
      subtitle = subtitle,
      x = "Effect on Demeaned Outcome",
      y = "Outcome") +
    forest_theme()

  outpath <- file.path(OUTPUT_DIR, paste0(filename, ".png"))
  ggsave(outpath, p, width = width, height = height, dpi = 300, bg = "white")
  cat("  Saved:", outpath, "\n")
  invisible(p)
}

# -----------------------------------------------
#  Save results as CSV
# -----------------------------------------------

save_csv <- function(df, outcome_name, prefix) {
  csv_df <- df %>%
    mutate(
      model_id    = location_id,
      p_value     = NA_real_,
      n_obs       = NA_integer_,
      n_customers = NA_integer_,
      analysis    = prefix
    ) %>%
    select(model_id, term, effect_type, estimate, std_error, p_value,
           ci_lower, ci_upper, location_id, n_obs, n_customers,
           analysis, outcome_name)

  outpath <- file.path(CSV_DIR, paste0(prefix, "_", outcome_name, ".csv"))
  write_csv(csv_df, outpath)
  cat("  Saved CSV:", outpath, "\n")
}

# -----------------------------------------------
#  Load all outcomes
# -----------------------------------------------

load_all_outcomes <- function() {
  outcome_dirs <- list.dirs(RESULTS_DIR, recursive = FALSE, full.names = TRUE)

  all_gammas    <- list()
  all_mu_gammas <- list()
  all_gender    <- list()

  for (outcome_dir in outcome_dirs) {
    outcome_name <- basename(outcome_dir)
    cat("Processing outcome:", outcome_name, "\n")

    gammas <- extract_exposure_gammas(outcome_dir, outcome_name)
    if (!is.null(gammas)) {
      all_gammas[[outcome_name]] <- gammas
      save_csv(gammas, outcome_name, "gaussian_iid_exposure")
    }

    mu_gamma <- extract_mu_gamma(outcome_dir, outcome_name)
    if (!is.null(mu_gamma)) {
      all_mu_gammas[[outcome_name]] <- mu_gamma
    }

    gender <- extract_gender_interactions(outcome_dir, outcome_name)
    if (!is.null(gender)) {
      all_gender[[outcome_name]] <- gender
      save_csv(gender, outcome_name, "gaussian_iid_gender")
    }
  }

  list(
    gammas    = if (length(all_gammas) > 0) bind_rows(all_gammas) else NULL,
    mu_gammas = if (length(all_mu_gammas) > 0) bind_rows(all_mu_gammas) else NULL,
    gender    = if (length(all_gender) > 0) bind_rows(all_gender) else NULL
  )
}

# -----------------------------------------------
#  Create forest plots
# -----------------------------------------------

create_forest_plots <- function() {
  cat("Creating Gaussian IID customer forest plots...\n")

  data <- load_all_outcomes()

  if (is.null(data$gammas) || nrow(data$gammas) == 0) {
    cat("  No gamma data found. Skipping.\n")
    return(invisible(NULL))
  }

  available_outcomes <- unique(data$gammas$outcome_name)
  preferred_order <- c("total", "nonvegan", "meat", "chicken_fish", "vegan", "vegetarian")
  outcome_levels <- intersect(preferred_order, available_outcomes)
  outcome_levels <- c(outcome_levels, setdiff(available_outcomes, preferred_order))

  # Combine all three sources into one dataframe
  combined <- list()

  gamma_df <- data$gammas %>%
    filter(outcome_name %in% outcome_levels) %>%
    to_effect_sizes()
  combined[["gamma"]] <- gamma_df

  if (!is.null(data$mu_gammas) && nrow(data$mu_gammas) > 0) {
    mu_df <- data$mu_gammas %>%
      filter(outcome_name %in% outcome_levels) %>%
      to_effect_sizes()
    combined[["mu_gamma"]] <- mu_df
  }

  if (!is.null(data$gender) && nrow(data$gender) > 0) {
    gender_df <- data$gender %>%
      filter(outcome_name %in% outcome_levels) %>%
      to_effect_sizes()
    combined[["gender"]] <- gender_df
  }

  all_df <- bind_rows(combined)

  # --- Per-restaurant + pooled, 3-column plot ---
  build_forest_3col(
    all_df,
    title    = "Gaussian IID (Transaction-Level, Pre-Period Demeaned)",
    subtitle = "Per-restaurant + pooled posteriors | Points = posterior mean | Bars = 90% CrI (q5-q95)",
    outcome_levels = outcome_levels,
    filename = "customer_forest",
    width = 14, height = max(4, length(outcome_levels) * 1.8))

  # --- Global-only (mu_gamma + pooled gender) ---
  global_df <- all_df %>%
    filter(str_detect(location_id, "mu_gamma|mu_beta"))

  if (nrow(global_df) > 0) {
    build_forest_3col(
      global_df,
      title    = "Gaussian IID: Global Means (mu_gamma + mu_beta pooled gender)",
      subtitle = "Hierarchical means across restaurants | Points = posterior mean | Bars = 90% CrI",
      outcome_levels = outcome_levels,
      filename = "customer_forest_global",
      width = 14, height = max(4, length(outcome_levels) * 1.5))
  }
}

# -----------------------------------------------
#  Execute
# -----------------------------------------------

cat("========================================\n")
cat("Gaussian IID Customer Forest Plots\n")
cat("(Transaction-Level, Pre-Period Demeaned)\n")
cat("========================================\n\n")

create_forest_plots()

cat("\n========================================\n")
cat("Done!\n")
cat("  Forest plots: ", OUTPUT_DIR, "\n")
cat("  Exposure CSVs:", CSV_DIR, "\n")
cat("========================================\n")

# Forest plots for Stan conditional Poisson results (transaction-level)
# Reads summ.rds and predictor_map.rds from Stan model output directories
# and creates static forest plots showing level change and slope change
# rate ratios per restaurant (gamma) and global means (mu_gamma).
# Generates both rate-ratio scale and log-scale versions.
# Also exports extracted exposure results as CSVs for downstream comparison.

library(tidyverse)
library(ggplot2)

# -----------------------------------------------
#  Paths
# -----------------------------------------------

RESULTS_DIR   <- "customer_analysis/transaction_level/stan_poisson/results"
OUTPUT_DIR    <- "customer_analysis/forest_plots/transaction_level/stan_poisson"
CSV_DIR       <- "customer_analysis/transaction_level/stan_poisson/results_exposures"

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
#
# In the Stan model:
#   beta[col_index, rest_index] holds the full coefficient matrix.
#   The predictor_map links col_index -> model_col (e.g., "exposure_SRQS8F7JWA9MZ_1")
#   and type ("exposure" for level, "slope" for slope).
#   restaurants_order.rds gives the restaurant IDs in order (rest_index 1..R).
#
# We extract rows from the summary where variable matches beta[j,r]
# for exposure columns j, then map to restaurant IDs and effect types.

extract_exposure_gammas <- function(outcome_dir, outcome_name) {

  summ_file     <- file.path(outcome_dir, "summ.rds")
  pmap_file     <- file.path(outcome_dir, "predictor_map.rds")
  rest_file     <- file.path(outcome_dir, "restaurants_order.rds")

  if (!file.exists(summ_file) || !file.exists(pmap_file)) {
    warning("Missing summ.rds or predictor_map.rds in: ", outcome_dir)
    return(NULL)
  }

  summ <- readRDS(summ_file)
  pmap <- readRDS(pmap_file)

  # Restaurant order
  restaurants <- if (file.exists(rest_file)) readRDS(rest_file) else NULL

  # Identify exposure columns (level and slope)
  exposure_cols <- pmap %>%
    filter(type %in% c("exposure", "slope"))

  if (nrow(exposure_cols) == 0) {
    warning("No exposure columns found in predictor_map for: ", outcome_dir)
    return(NULL)
  }

  # Number of restaurants
  R <- if (!is.null(restaurants)) length(restaurants) else {
    # Infer from summary: find max rest_index in beta variables
    beta_vars <- summ %>% filter(str_starts(variable, "beta\\["))
    max(as.integer(str_match(beta_vars$variable, "beta\\[\\d+,(\\d+)\\]")[, 2]), na.rm = TRUE)
  }

  # Extract beta[col_index, rest_index] for each exposure column and restaurant
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

      # Extract the exposure period number from the model_col name
      # e.g., "exposure_SRQS8F7JWA9MZ_1" -> period "1"
      # e.g., "exposure_SRQS8F7JWA9MZ_1_slope" -> period "1"
      exposure_period <- str_extract(model_col, "_(\\d+)(_slope)?$") %>%
        str_extract("\\d+")

      # Only include gamma for the restaurant that owns this exposure column
      # The exposure column is only non-zero for its own restaurant.
      # We check: does the model_col contain the restaurant ID?
      col_rest_id <- str_extract(model_col, "(?<=exposure_)[A-Z0-9]+")
      if (!is.null(restaurants) && col_rest_id != rest_id) next

      # Determine effect type
      effect_type <- if (col_type == "slope") "Slope Change" else "Level Change"

      # Build fixest-compatible term name
      term <- if (col_type == "slope") {
        # Convert "exposure_X_1_slope" -> "exposure_X_1:date_code"
        str_replace(model_col, "_slope$", ":date_code")
      } else {
        model_col
      }

      results[[length(results) + 1]] <- tibble(
        location_id      = rest_id,
        term             = term,
        effect_type      = effect_type,
        estimate         = row$mean,
        std_error        = row$sd,
        ci_lower         = row$q5,
        ci_upper         = row$q95,
        rhat             = row$rhat,
        ess_bulk         = row$ess_bulk,
        exposure_period  = exposure_period,
        outcome_name     = outcome_name
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
      location_id  = "mu_gamma (global)",
      term         = variable,
      outcome_name = outcome_name,
      estimate     = mean,
      std_error    = sd,
      ci_lower     = q5,
      ci_upper     = q95
    ) %>%
    select(location_id, term, effect_type, estimate, std_error,
           ci_lower, ci_upper, rhat, ess_bulk, outcome_name)
}

# -----------------------------------------------
#  Convert to rate ratios
# -----------------------------------------------

to_rate_ratios_stan <- function(df) {
  df %>%
    mutate(
      # Level: exp(beta); Slope: exp(beta / 365.25) for annual rate ratio
      # Note: slope coefficients are already on the date_num scale (which is date / 365.25)
      # so slope beta is in units of "per year". exp(beta) gives annual rate ratio directly.
      # But to match the fixest convention (estimate * 365), we use:
      #   Level: exp(estimate)
      #   Slope: exp(estimate * 365.25) -- because date_num was divided by 365.25 in data prep,
      #     the slope in the design matrix is exposure * (date_num), and date_num ~ date/365.25,
      #     so the coefficient is in units per (date/365.25), i.e., per year. exp(beta) is annual RR.
      # Actually, since the slope column = exposure * date_num and date_num = date_int / 365.25,
      # the beta coefficient is the log-RR per unit of date_num, which is already per year.
      # So for slope: exp(estimate) = annual rate ratio.
      rr = exp(estimate),
      rr_lower = exp(ci_lower),
      rr_upper = exp(ci_upper),
      # Log-scale values for log plots
      log_rr       = estimate,
      log_rr_lower = ci_lower,
      log_rr_upper = ci_upper
    )
}

# -----------------------------------------------
#  Clipping helpers
# -----------------------------------------------

clip_data <- function(df, xlim, val_col = "rr", lo_col = "rr_lower", hi_col = "rr_upper") {
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
#  Build forest plot (rate ratio scale)
# -----------------------------------------------

build_forest <- function(df, title, subtitle, color, outcome_levels, filename,
                         width = 10, height = 8) {

  df$effect_type  <- factor(df$effect_type, levels = c("Level Change", "Slope Change"))
  df$outcome_name <- factor(df$outcome_name, levels = rev(outcome_levels))

  # Label for restaurants with multiple exposure periods
  df <- df %>%
    mutate(
      rest_label = paste0(location_id,
                          ifelse(!is.na(exposure_period) & exposure_period != "1",
                                 paste0(" (exp ", exposure_period, ")"), ""))
    )

  # Create y-axis positions (jitter within outcome)
  df <- df %>%
    group_by(outcome_name, effect_type) %>%
    mutate(
      row_in_group = row_number(),
      y_numeric    = as.numeric(outcome_name) - 0.12 * (row_in_group - 1)
    ) %>%
    ungroup()

  xlim <- c(0, 4)
  df <- clip_data(df, xlim, "rr", "rr_lower", "rr_upper")

  p <- ggplot(df) +
    geom_vline(xintercept = 1, linetype = "dashed", color = "gray50") +
    geom_errorbarh(
      aes(xmin = lo_disp, xmax = hi_disp, y = y_numeric),
      height = 0.08, color = color, alpha = 0.6, linewidth = 0.4) +
    geom_point(
      aes(x = val_disp, y = y_numeric, shape = clipped),
      size = 2.2, color = color) +
    scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 17), guide = "none") +
    facet_wrap(~ effect_type, ncol = 2) +
    scale_x_continuous(limits = xlim, oob = scales::squish, breaks = 0:4) +
    scale_y_continuous(
      breaks   = seq_along(outcome_levels),
      labels   = format_label(rev(outcome_levels)),
      expand   = expansion(mult = c(0.15, 0.05))) +
    labs(
      title    = title,
      subtitle = subtitle,
      x = "Rate Ratio",
      y = "Outcome") +
    forest_theme()

  outpath <- file.path(OUTPUT_DIR, paste0(filename, ".png"))
  ggsave(outpath, p, width = width, height = height, dpi = 300, bg = "white")
  cat("  Saved:", outpath, "\n")
  invisible(p)
}

# -----------------------------------------------
#  Build forest plot (log scale)
# -----------------------------------------------

build_forest_log <- function(df, title, subtitle, color, outcome_levels, filename,
                             width = 10, height = 8) {

  df$effect_type  <- factor(df$effect_type, levels = c("Level Change", "Slope Change"))
  df$outcome_name <- factor(df$outcome_name, levels = rev(outcome_levels))

  df <- df %>%
    mutate(
      rest_label = paste0(location_id,
                          ifelse(!is.na(exposure_period) & exposure_period != "1",
                                 paste0(" (exp ", exposure_period, ")"), ""))
    )

  df <- df %>%
    group_by(outcome_name, effect_type) %>%
    mutate(
      row_in_group = row_number(),
      y_numeric    = as.numeric(outcome_name) - 0.12 * (row_in_group - 1)
    ) %>%
    ungroup()

  xlim <- c(-25, 25)
  df <- clip_data(df, xlim, "log_rr", "log_rr_lower", "log_rr_upper")

  # Plausibility bounds: log(0.1) ~ -2.3, log(10) ~ 2.3
  plaus_bound <- log(10)

  p <- ggplot(df) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
    geom_vline(xintercept = c(-plaus_bound, plaus_bound),
               linetype = "dotted", color = "firebrick", alpha = 0.6) +
    annotate("rect", xmin = -plaus_bound, xmax = plaus_bound,
             ymin = -Inf, ymax = Inf, fill = "gray95", alpha = 0.4) +
    annotate("text", x = plaus_bound + 0.3, y = Inf, label = "implausible",
             color = "firebrick", size = 3, hjust = 0, vjust = 1.5, fontface = "italic") +
    annotate("text", x = -plaus_bound - 0.3, y = Inf, label = "implausible",
             color = "firebrick", size = 3, hjust = 1, vjust = 1.5, fontface = "italic") +
    geom_errorbarh(
      aes(xmin = lo_disp, xmax = hi_disp, y = y_numeric),
      height = 0.08, color = color, alpha = 0.6, linewidth = 0.4) +
    geom_point(
      aes(x = val_disp, y = y_numeric, shape = clipped),
      size = 2.2, color = color) +
    scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 17), guide = "none") +
    facet_wrap(~ effect_type, ncol = 2) +
    scale_x_continuous(limits = xlim, oob = scales::squish) +
    scale_y_continuous(
      breaks   = seq_along(outcome_levels),
      labels   = format_label(rev(outcome_levels)),
      expand   = expansion(mult = c(0.15, 0.05))) +
    labs(
      title    = title,
      subtitle = paste0(subtitle, " (log scale)"),
      x = "Log Rate Ratio",
      y = "Outcome") +
    forest_theme()

  outpath <- file.path(OUTPUT_DIR, paste0(filename, "_log.png"))
  ggsave(outpath, p, width = width, height = height, dpi = 300, bg = "white")
  cat("  Saved:", outpath, "\n")
  invisible(p)
}

# -----------------------------------------------
#  Save exposure results as CSV (fixest-compatible)
# -----------------------------------------------

save_exposure_csv <- function(df, outcome_name) {
  # Match fixest CSV columns:
  # model_id, term, estimate, std_error, p_value, ci_lower, ci_upper,
  # location_id, n_obs, n_customers, analysis, outcome_name

  csv_df <- df %>%
    mutate(
      model_id    = location_id,
      p_value     = NA_real_,   # Bayesian: no frequentist p-value
      n_obs       = NA_integer_,
      n_customers = NA_integer_,
      analysis    = "A5_stan"
    ) %>%
    select(model_id, term, estimate, std_error, p_value,
           ci_lower, ci_upper, location_id, n_obs, n_customers,
           analysis, outcome_name)

  outpath <- file.path(CSV_DIR, paste0("A5_stan_", outcome_name, ".csv"))
  write_csv(csv_df, outpath)
  cat("  Saved CSV:", outpath, "\n")
}

# -----------------------------------------------
#  Load all outcomes and build combined data
# -----------------------------------------------

load_all_outcomes <- function() {
  outcome_dirs <- list.dirs(RESULTS_DIR, recursive = FALSE, full.names = TRUE)

  all_gammas    <- list()
  all_mu_gammas <- list()

  for (outcome_dir in outcome_dirs) {
    outcome_name <- basename(outcome_dir)
    cat("Processing outcome:", outcome_name, "\n")

    # Per-restaurant gammas
    gammas <- extract_exposure_gammas(outcome_dir, outcome_name)
    if (!is.null(gammas)) {
      all_gammas[[outcome_name]] <- gammas

      # Save CSV for this outcome
      save_exposure_csv(gammas, outcome_name)
    }

    # Global mu_gamma
    mu_gamma <- extract_mu_gamma(outcome_dir, outcome_name)
    if (!is.null(mu_gamma)) {
      all_mu_gammas[[outcome_name]] <- mu_gamma
    }
  }

  list(
    gammas    = if (length(all_gammas) > 0) bind_rows(all_gammas) else NULL,
    mu_gammas = if (length(all_mu_gammas) > 0) bind_rows(all_mu_gammas) else NULL
  )
}

# -----------------------------------------------
#  Create A5 forest plots
# -----------------------------------------------

create_A5_stan_forest <- function() {
  cat("Creating A5 Stan conditional Poisson forest plots...\n")

  data <- load_all_outcomes()

  if (is.null(data$gammas) || nrow(data$gammas) == 0) {
    cat("  No gamma data found. Skipping forest plots.\n")
    return(invisible(NULL))
  }

  # Determine outcome levels from available data
  available_outcomes <- unique(data$gammas$outcome_name)
  # Preferred order (subset to what's available)
  preferred_order <- c("total", "nonvegan", "meat", "chicken_fish", "vegan", "vegetarian")
  outcome_levels <- intersect(preferred_order, available_outcomes)
  # Append any outcomes not in the preferred list
  outcome_levels <- c(outcome_levels, setdiff(available_outcomes, preferred_order))

  gamma_df <- data$gammas %>%
    filter(outcome_name %in% outcome_levels) %>%
    to_rate_ratios_stan()

  # --- Per-restaurant gamma forest plot ---
  build_forest(
    gamma_df,
    title    = "A5: Stan Conditional Poisson (Transaction-Level)",
    subtitle = "Per-restaurant posteriors | Points = posterior mean | Bars = 90% CrI (q5-q95) | Triangles = clipped",
    color    = "darkgreen",
    outcome_levels = outcome_levels,
    filename = "A5_stan_forest",
    width = 10, height = max(4, length(outcome_levels) * 1.5))

  build_forest_log(
    gamma_df,
    title    = "A5: Stan Conditional Poisson (Transaction-Level)",
    subtitle = "Per-restaurant posteriors | Points = posterior mean | Bars = 90% CrI (q5-q95) | Triangles = clipped",
    color    = "darkgreen",
    outcome_levels = outcome_levels,
    filename = "A5_stan_forest",
    width = 10, height = max(4, length(outcome_levels) * 1.5))

  # --- mu_gamma (global mean) forest plot ---
  if (!is.null(data$mu_gammas) && nrow(data$mu_gammas) > 0) {

    mu_df <- data$mu_gammas %>%
      filter(outcome_name %in% outcome_levels) %>%
      mutate(exposure_period = NA_character_) %>%
      to_rate_ratios_stan()

    build_forest(
      mu_df,
      title    = "A5: Stan Conditional Poisson - Global Mean (mu_gamma)",
      subtitle = "Hierarchical mean across restaurants | Points = posterior mean | Bars = 90% CrI",
      color    = "darkgreen",
      outcome_levels = outcome_levels,
      filename = "A5_stan_mu_gamma_forest",
      width = 10, height = max(4, length(outcome_levels) * 1.5))

    build_forest_log(
      mu_df,
      title    = "A5: Stan Conditional Poisson - Global Mean (mu_gamma)",
      subtitle = "Hierarchical mean across restaurants | Points = posterior mean | Bars = 90% CrI",
      color    = "darkgreen",
      outcome_levels = outcome_levels,
      filename = "A5_stan_mu_gamma_forest",
      width = 10, height = max(4, length(outcome_levels) * 1.5))
  }
}

# -----------------------------------------------
#  Execute
# -----------------------------------------------

cat("========================================\n")
cat("Stan Conditional Poisson Forest Plots\n")
cat("========================================\n\n")

create_A5_stan_forest()

cat("\n========================================\n")
cat("Done!\n")
cat("  Forest plots: ", OUTPUT_DIR, "\n")
cat("  Exposure CSVs:", CSV_DIR, "\n")
cat("========================================\n")

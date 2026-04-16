# Forest plots for T2 A6 Stan Gaussian IID day-level TARGETED customer results.
# Reads summ.rds and predictor_map.rds from Stan model output directories.
# Identity link: no exp() transform, reference line at 0.
#
# Expected model_fits layout (fits may not yet exist on disk -- the script
# auto-discovers whatever is present and silently skips incomplete dirs):
#   model_fits/finalized_redone_trunc_cp/t2_customer_targeted_gaussian_iid_day/<cat>_t2/
#
# Three facets:
#   1. Level Change        (gamma / mu_gamma[1])     -- base exposure cols (no gender suffix)
#   2. Slope Change        (gamma / mu_gamma[2])     -- _slope cols
#   3. Gender x Level      (beta / mu_beta_random)   -- _gendermale and _genderfemale cols
#                                                       (gender=unknown is the reference level)

library(tidyverse)
library(ggplot2)

# -----------------------------------------------
#  Paths
# -----------------------------------------------

RESULTS_DIR   <- "model_fits/finalized_redone_trunc_cp/t2_customer_targeted_gaussian_iid_day"
OUTPUT_DIR    <- "customer_analysis/forest_plots/day_level/stan_gaussian_targeted_t2"
CSV_DIR       <- "customer_analysis/level_day/stan_gaussian_targeted_t2/results_exposures"

dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(CSV_DIR, showWarnings = FALSE, recursive = TRUE)

format_label <- function(name) {
  name %>%
    str_replace_all("_", " ") %>%
    str_to_title()
}

# -----------------------------------------------
#  Extract per-restaurant exposure effects (gamma)
#  -- base exposure and slope ONLY (no gender)
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
    filter(type %in% c("exposure", "slope")) %>%
    filter(!str_detect(model_col, "_gender(male|female)$"))

  if (nrow(exposure_cols) == 0) {
    warning("No base exposure columns found in predictor_map for: ", outcome_dir)
    return(NULL)
  }

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
      if (!is.null(restaurants) && !is.null(col_rest_id) && col_rest_id != rest_id) next

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
        gender          = NA_character_,
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
      exposure_period = NA_character_,
      gender          = NA_character_
    ) %>%
    select(location_id, term, effect_type, estimate, std_error,
           ci_lower, ci_upper, rhat, ess_bulk, exposure_period, gender, outcome_name)
}

# -----------------------------------------------
#  Extract gender x exposure interactions
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
    filter(str_detect(model_col, "_gender(male|female)$"))

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

    gender <- if (str_detect(model_col, "_gendermale$")) "male" else "female"

    exposure_period <- str_extract(model_col, "_(\\d+)_gender(male|female)$") %>%
      str_extract("\\d+")

    col_rest_id <- str_extract(model_col, "(?<=exposure_)[A-Z0-9]+")

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
        gender          = gender,
        outcome_name    = outcome_name
      )
    }

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
            gender          = gender,
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

clip_data <- function(df, xlim, val_col = "effect", lo_col = "effect_lower", hi_col = "effect_upper") {
  df %>%
    mutate(
      clipped  = .data[[val_col]] < xlim[1] | .data[[val_col]] > xlim[2],
      val_disp = pmin(pmax(.data[[val_col]], xlim[1]), xlim[2]),
      lo_disp  = pmax(.data[[lo_col]], xlim[1]),
      hi_disp  = pmin(.data[[hi_col]], xlim[2])
    )
}

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
      axis.text.y       = element_text(size = 10),
      legend.position   = "bottom")
}

# -----------------------------------------------
#  Build 3-column forest plot
# -----------------------------------------------

build_forest_3col <- function(df, title, subtitle, outcome_levels, filename,
                              width = 14, height = 8) {

  facet_order <- c("Level Change", "Slope Change", "Gender x Level")
  df$effect_type  <- factor(df$effect_type, levels = facet_order)
  df$outcome_name <- factor(df$outcome_name, levels = rev(outcome_levels))

  df <- df %>%
    mutate(
      series = case_when(
        effect_type == "Gender x Level" & gender == "male"   ~ "Male",
        effect_type == "Gender x Level" & gender == "female" ~ "Female",
        TRUE                                                  ~ "Base"
      )
    )

  series_colors <- c(
    "Base"   = "darkgreen",
    "Male"   = "#1f77b4",
    "Female" = "#d62728"
  )

  df <- df %>%
    mutate(
      rest_label = paste0(location_id,
                          ifelse(!is.na(exposure_period) & exposure_period != "1",
                                 paste0(" (exp ", exposure_period, ")"), ""))
    )

  df <- df %>%
    group_by(outcome_name, effect_type, series) %>%
    mutate(row_in_series = row_number()) %>%
    ungroup() %>%
    mutate(
      series_offset = case_when(
        series == "Male"   ~ -0.18,
        series == "Female" ~  0.18,
        TRUE               ~  0.0
      ),
      y_numeric = as.numeric(outcome_name) + series_offset - 0.10 * (row_in_series - 1)
    )

  all_vals <- c(df$effect, df$effect_lower, df$effect_upper)
  max_abs <- max(abs(all_vals[is.finite(all_vals)]), na.rm = TRUE)
  if (!is.finite(max_abs) || max_abs == 0) max_abs <- 1
  xlim_bound <- min(max_abs * 1.2, 5)
  xlim <- c(-xlim_bound, xlim_bound)

  df <- clip_data(df, xlim, "effect", "effect_lower", "effect_upper")

  p <- ggplot(df) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
    geom_errorbarh(
      aes(xmin = lo_disp, xmax = hi_disp, y = y_numeric, color = series),
      height = 0.08, alpha = 0.6, linewidth = 0.4) +
    geom_point(
      aes(x = val_disp, y = y_numeric, shape = clipped, color = series),
      size = 2.2) +
    scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 17), guide = "none") +
    scale_color_manual(values = series_colors,
                       breaks = c("Male", "Female"),
                       name = "Gender (vs unknown)") +
    facet_wrap(~ effect_type, ncol = 3) +
    scale_x_continuous(limits = xlim, oob = scales::squish) +
    scale_y_continuous(
      breaks = seq_along(outcome_levels),
      labels = format_label(rev(outcome_levels)),
      expand = expansion(mult = c(0.15, 0.05))) +
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
    select(model_id, term, effect_type, gender, estimate, std_error, p_value,
           ci_lower, ci_upper, location_id, n_obs, n_customers,
           analysis, outcome_name)

  outpath <- file.path(CSV_DIR, paste0(prefix, "_", outcome_name, ".csv"))
  write_csv(csv_df, outpath)
  cat("  Saved CSV:", outpath, "\n")
}

# -----------------------------------------------
#  Load all outcomes (auto-discover; strip "_t2" suffix for display)
# -----------------------------------------------

load_all_outcomes <- function() {
  if (!dir.exists(RESULTS_DIR)) {
    cat("RESULTS_DIR does not exist yet:", RESULTS_DIR, "\n")
    return(list(gammas = NULL, mu_gammas = NULL, gender = NULL))
  }

  outcome_dirs <- list.dirs(RESULTS_DIR, recursive = FALSE, full.names = TRUE)

  all_gammas    <- list()
  all_mu_gammas <- list()
  all_gender    <- list()

  for (outcome_dir in outcome_dirs) {
    # t2 targeted convention: <cat>_t2 -> display as <cat>
    dir_name <- basename(outcome_dir)
    outcome_name <- str_remove(dir_name, "_t2$")

    if (!file.exists(file.path(outcome_dir, "summ.rds"))) {
      cat("Skipping (no summ.rds):", dir_name, "\n")
      next
    }

    cat("Processing outcome:", outcome_name, "(dir:", dir_name, ")\n")

    gammas <- extract_exposure_gammas(outcome_dir, outcome_name)
    if (!is.null(gammas)) {
      all_gammas[[outcome_name]] <- gammas
      save_csv(gammas, outcome_name, "A6_t2_targeted_gaussian_iid_day_exposure")
    }

    mu_gamma <- extract_mu_gamma(outcome_dir, outcome_name)
    if (!is.null(mu_gamma)) {
      all_mu_gammas[[outcome_name]] <- mu_gamma
    }

    gender <- extract_gender_interactions(outcome_dir, outcome_name)
    if (!is.null(gender)) {
      all_gender[[outcome_name]] <- gender
      save_csv(gender, outcome_name, "A6_t2_targeted_gaussian_iid_day_gender")
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
  cat("Creating T2 A6 Stan Gaussian IID targeted day-level forest plots...\n")

  data <- load_all_outcomes()

  if (is.null(data$gammas) || nrow(data$gammas) == 0) {
    cat("  No gamma data found. Nothing to plot.\n")
    return(invisible(NULL))
  }

  available_outcomes <- unique(data$gammas$outcome_name)
  preferred_order <- c("breakfast", "untextured", "dairy")
  outcome_levels <- intersect(preferred_order, available_outcomes)
  outcome_levels <- c(outcome_levels, sort(setdiff(available_outcomes, preferred_order)))

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

  build_forest_3col(
    all_df,
    title    = "T2 A6: Stan Gaussian IID Targeted (Day-Level, Demeaned)",
    subtitle = "Per-restaurant + pooled posteriors | Points = posterior mean | Bars = 90% CrI (q5-q95)",
    outcome_levels = outcome_levels,
    filename = "A6_t2_stan_gaussian_targeted_day_forest",
    width = 14, height = max(4, length(outcome_levels) * 1.8))

  global_df <- all_df %>%
    filter(str_detect(location_id, "mu_gamma|mu_beta"))

  if (nrow(global_df) > 0) {
    build_forest_3col(
      global_df,
      title    = "T2 A6: Targeted Day-Level Global Means (mu_gamma + mu_beta pooled gender)",
      subtitle = "Hierarchical means across restaurants | Points = posterior mean | Bars = 90% CrI",
      outcome_levels = outcome_levels,
      filename = "A6_t2_stan_gaussian_targeted_day_mu_gamma_forest",
      width = 14, height = max(4, length(outcome_levels) * 1.5))
  }
}

# -----------------------------------------------
#  Execute
# -----------------------------------------------

cat("========================================\n")
cat("T2 A6 Stan Gaussian IID Targeted Forest Plots\n")
cat("(Day-Level, Pre-Period Demeaned)\n")
cat("========================================\n\n")

create_forest_plots()

cat("\n========================================\n")
cat("Done!\n")
cat("  Forest plots: ", OUTPUT_DIR, "\n")
cat("  Exposure CSVs:", CSV_DIR, "\n")
cat("========================================\n")

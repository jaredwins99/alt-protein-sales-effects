# Forest Plot Generation Script - CHOSEN VERSION with Restaurant-Level Estimates - RECOLORED
# Creates horizontal forest plots with mixed model sources
# Uses finalized_redone for most analyses, finalized_redone2 for untextured
# RECOLORED: Uses color scheme from create_forest_plots_chosen.R and includes Total reference

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

# Default model path for most analyses
# DEFAULT_MODEL_PATH <- "finalized_redone"
DEFAULT_MODEL_PATH <- "finalized_redone_trunc"

# Override paths for specific outcomes (outcome -> model_path)
# A1 proportion overrides
A1_OVERRIDES <- list(
  # "total" = "finalized_redone2",
  # "vegan" = "finalized_redone2"
)

# A2 proportion_targeted overrides
A2_OVERRIDES <- list(
  # "breakfast_p" = "finalized_redone2",
  # "untextured_p" = "finalized_redone2"
)

# A3 its overrides
A3_OVERRIDES <- list(
  "total" = "finalized_redone_trunc_cp",
  "nonvegan" = "finalized_redone_trunc_cp",
  "meat" = "finalized_redone_trunc_cp",
  "chicken_fish" = "finalized_redone_trunc_cp",
  "vegetarian" = "finalized_redone_trunc_cp",
  "vegan" = "finalized_redone_trunc_cp"
)

# A4 its_targeted overrides
A4_OVERRIDES <- list(
  "breakfast" = "finalized_redone_trunc_cp",
  "textured" = "finalized_redone_trunc_cp",
  "untextured" = "finalized_redone_trunc_cp"
)

# OUTPUT_DIR_BASE <- "forest_plots/forest_plots_restaurants_chosen_recolored"
OUTPUT_DIR_BASE <- "forest_plots/forest_plots_restaurants_trunc_recolored"

# ─────────────────────────────────────
#             Helper Functions
# ─────────────────────────────────────

extract_mu_gamma <- function(model_path, gamma_index = 1) {
  # Use 95% CI helper function
  gamma <- extract_mu_gamma_95ci(model_path, gamma_index)
  if (is.null(gamma)) return(NULL)
  list(
    mean = gamma$mean,
    median = gamma$median,
    sd = gamma$sd,
    q2.5 = gamma$q2.5,
    q97.5 = gamma$q97.5,
    rhat = gamma$rhat,
    ess_bulk = gamma$ess_bulk)}

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

extract_restaurant_id <- function(model_col) {
  model_col %>%
    str_replace("^exposure_", "") %>%
    str_replace("_\\d+(_slope)?$", "")}

extract_restaurant_gammas <- function(model_path, is_its = FALSE) {
  # Use 95% CI helper function
  gammas <- extract_restaurant_gammas_95ci(model_path, is_its)
  return(gammas)
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

# ─────────────────────────────────────
# 1. PROPORTION Analysis (A1)
# RECOLORED: Total=steelblue, Animal=firebrick, Plant-based=forestgreen
# ─────────────────────────────────────

create_proportion_forest_restaurants <- function(log_scale = FALSE) {
  output_dir <- if (log_scale) file.path(paste0(OUTPUT_DIR_BASE, "_log")) else file.path(OUTPUT_DIR_BASE)
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  cat("Creating proportion forest plot with restaurant estimates (recolored)...\n")
  cat("  Using A1 overrides:", paste(names(A1_OVERRIDES), "->", A1_OVERRIDES, collapse = ", "), "\n")

  # RECOLORED: Same outcome order as create_forest_plots_chosen.R

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
        model_path <- file.path(model_run_path, "proportion", outcome, exposure)
        summ_path <- file.path(model_path, "summ.rds")

        gamma <- extract_mu_gamma(model_path, 1)
        if (!is.null(gamma)) {
          pooled_list[[length(pooled_list) + 1]] <- tibble(
            outcome = outcome,
            exposure_group = exp_group,
            exposure_type = exp_type,
            mean = gamma$mean,
            q2.5 = gamma$q2.5,
            q97.5 = gamma$q97.5,
            rhat = gamma$rhat,
            estimate_type = "Pooled",
            restaurant_id = "POOLED")
        }

        rest_gammas <- extract_restaurant_gammas(model_path, is_its = FALSE)
        if (!is.null(rest_gammas) && nrow(rest_gammas) > 0) {
          for (i in 1:nrow(rest_gammas)) {
            restaurant_list[[length(restaurant_list) + 1]] <- tibble(
              outcome = outcome,
              exposure_group = exp_group,
              exposure_type = exp_type,
              mean = rest_gammas$mean[i],
              q2.5 = rest_gammas$q2.5[i],
              q97.5 = rest_gammas$q97.5[i],
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

  # RECOLORED: Add color grouping based on outcome category
  df_all <- df_all %>%
    mutate(color_group = case_when(
      outcome == "total" ~ "Total",
      outcome %in% c("nonvegan", "meat", "chicken_fish") ~ "Animal",
      outcome %in% c("vegetarian", "vegan") ~ "Plant-based"))

  if (!log_scale) {
    df_all <- df_all %>%
      mutate(
        across(c(mean, q2.5, q97.5), ~ case_when(
          exposure_type == "Count" & estimate_type == "Pooled" ~ exp(.x),
          exposure_type == "Proportion" & estimate_type == "Pooled" ~ exp(.1 * .x),
          exposure_type == "Proportion" & estimate_type == "Restaurant" ~ .x^0.1,
          TRUE ~ .x)))
  } else {
    df_all <- df_all %>%
      mutate(
        across(c(mean, q2.5, q97.5), ~ case_when(
          estimate_type == "Restaurant" ~ log(.x),
          TRUE ~ .x)))
  }

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

  # RECOLORED: Use color_group for coloring
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
                       "Rate Ratio: ", signif(mean_orig, 3), "<br>",
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
                 "Rate Ratio: ", signif(mean_orig, 3), "<br>",
                 "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                 ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), ""))),
               size = 2.5) +
    # RECOLORED: Color scheme from create_forest_plots_chosen.R
    scale_color_manual(values = c("Total" = "steelblue", "Animal" = "firebrick", "Plant-based" = "forestgreen"),
                       guide = "none") +
    facet_grid(exposure_group ~ exposure_type, scales = "free_y", space = "free_y") +
    scale_x_continuous(limits = xlim, oob = scales::squish) +
    scale_y_continuous(
      breaks = 1:length(outcomes),
      labels = format_label(rev(outcomes)),
      expand = expansion(mult = c(0.15, 0.05))) +
    labs(
      title = "A1: Proportion Analysis (with Restaurant-Level Estimates)",
      subtitle = paste0(if (log_scale) "Log Rate Ratios" else "Rate Ratios", " | Large points = pooled, Small = restaurants | Triangles = values beyond scale"),
      x = if (log_scale) "Log Rate Ratio (mu_gamma[1])" else "Rate Ratio (exp(mu_gamma[1]))",
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
  saveWidget(p_plotly, file.path(output_dir, html_name), selfcontained = TRUE)

  df_save <- df_all %>% select(-matches("_disp|_orig|clipped|y_numeric|n_in_group|row_in_group"))
  csv_name <- if (log_scale) "A1_proportion_restaurants_data_log.csv" else "A1_proportion_restaurants_data.csv"
  write_csv(df_save, file.path(output_dir, csv_name))

  cat("  Saved: A1_proportion_forest_restaurants.png, .pdf, .html, _data.csv\n")
  return(p)
}

# ─────────────────────────────────────
# 2. PROPORTION_TARGETED Analysis (A2)
# Uses A2_OVERRIDES for outcome-specific model paths
# RECOLORED: Total=steelblue, Animal=firebrick + includes Total (A1)
# ─────────────────────────────────────

create_proportion_targeted_forest_restaurants <- function(log_scale = FALSE) {
  output_dir <- if (log_scale) file.path(paste0(OUTPUT_DIR_BASE, "_log")) else file.path(OUTPUT_DIR_BASE)
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  cat("Creating proportion_targeted forest plot with restaurant estimates (recolored)...\n")
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
      model_path <- file.path(model_run_path, "proportion_targeted", outcome, exposure)
      summ_path <- file.path(model_path, "summ.rds")

      gamma <- extract_mu_gamma(model_path, 1)
      if (!is.null(gamma)) {
        pooled_list[[length(pooled_list) + 1]] <- tibble(
          outcome = outcome_label,
          exposure_type = exp_type,
          mean = gamma$mean,
          q2.5 = gamma$q2.5,
          q97.5 = gamma$q97.5,
          rhat = gamma$rhat,
          estimate_type = "Pooled",
          restaurant_id = "POOLED",
          source = model_path_name)
      }

      rest_gammas <- extract_restaurant_gammas(model_path, is_its = FALSE)
      if (!is.null(rest_gammas) && nrow(rest_gammas) > 0) {
        for (j in 1:nrow(rest_gammas)) {
          restaurant_list[[length(restaurant_list) + 1]] <- tibble(
            outcome = outcome_label,
            exposure_type = exp_type,
            mean = rest_gammas$mean[j],
            q2.5 = rest_gammas$q2.5[j],
            q97.5 = rest_gammas$q97.5[j],
            rhat = rest_gammas$rhat[j],
            estimate_type = "Restaurant",
            restaurant_id = rest_gammas$restaurant_id[j],
            source = model_path_name)
        }
      }
    }
  }

  # RECOLORED: Add "Total (A1)" from A1 proportion analysis for comparison (pooled only)
  for (exp_type in c("count", "prop")) {
    model_path_a1 <- file.path("model_fits", DEFAULT_MODEL_PATH, "proportion",
                               "total", paste0("mpbamod_dishes_", exp_type))
    gamma <- extract_mu_gamma(model_path_a1, 1)
    if (!is.null(gamma)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = "Total (A1)",
        exposure_type = ifelse(exp_type == "prop", "presence", exp_type),
        mean = gamma$mean,
        q2.5 = gamma$q2.5,
        q97.5 = gamma$q97.5,
        rhat = gamma$rhat,
        estimate_type = "Pooled",
        restaurant_id = "POOLED",
        source = DEFAULT_MODEL_PATH)
    }
  }

  df_pooled <- bind_rows(pooled_list)
  df_restaurant <- bind_rows(restaurant_list)

  if (nrow(df_pooled) == 0) {
    cat("  No data found for proportion_targeted analysis\n")
    return(NULL)
  }

  df_all <- bind_rows(df_pooled, df_restaurant)

  # RECOLORED: Order with Total at top
  all_outcomes <- c("Total (A1)", outcome_labels)
  df_all$outcome <- factor(df_all$outcome, levels = rev(all_outcomes))
  df_all$exposure_type <- factor(df_all$exposure_type, levels = c("presence", "count"),
                                  labels = c("Presence", "Count"))

  # RECOLORED: Add color grouping
  df_all <- df_all %>%
    mutate(color_group = ifelse(outcome == "Total (A1)", "Total", "Animal"))

  if (!log_scale) {
    df_all <- df_all %>%
      mutate(
        across(c(mean, q2.5, q97.5), ~ case_when(
          exposure_type == "Count" & estimate_type == "Pooled" ~ exp(.x),
          exposure_type == "Presence" & estimate_type == "Pooled" ~ exp(.1 * .x),
          exposure_type == "Presence" & estimate_type == "Restaurant" ~ .x^0.1,
          TRUE ~ .x)))
  } else {
    df_all <- df_all %>%
      mutate(
        across(c(mean, q2.5, q97.5), ~ case_when(
          estimate_type == "Restaurant" ~ log(.x),
          TRUE ~ .x)))
  }

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

  # RECOLORED: Use color_group for coloring
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
                       "Rate Ratio: ", signif(mean_orig, 3), "<br>",
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
                 "Rate Ratio: ", signif(mean_orig, 3), "<br>",
                 "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                 "<br>Source: ", source,
                 ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), ""))),
               size = 2.5) +
    # RECOLORED: Color scheme from create_forest_plots_chosen.R
    scale_color_manual(values = c("Total" = "steelblue", "Animal" = "firebrick"),
                       guide = "none") +
    facet_wrap(~ exposure_type, ncol = 2) +
    scale_x_continuous(limits = xlim, oob = scales::squish) +
    scale_y_continuous(
      breaks = 1:length(all_outcomes),
      labels = rev(all_outcomes),
      expand = expansion(mult = c(0.2, 0.1))) +
    labs(
      title = "A2: Targeted Animal Product Categories Proportion Analysis",
      subtitle = paste0(if (log_scale) "Log Rate Ratios" else "Rate Ratios", " | Large points = pooled, Small = restaurants | Triangles = values beyond scale"),
      x = if (log_scale) "Log Rate Ratio (mu_gamma[1])" else "Rate Ratio (exp(mu_gamma[1]))",
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
  saveWidget(p_plotly, file.path(output_dir, html_name), selfcontained = TRUE)

  df_save <- df_all %>% select(-matches("_disp|_orig|clipped|y_numeric|n_in_group|row_in_group"))
  csv_name <- if (log_scale) "A2_proportion_targeted_restaurants_data_log.csv" else "A2_proportion_targeted_restaurants_data.csv"
  write_csv(df_save, file.path(output_dir, csv_name))

  cat("  Saved: A2_proportion_targeted_forest_restaurants.png, .pdf, .html, _data.csv\n")
  return(p)
}

# ─────────────────────────────────────
# 3. ITS Analysis (A3)
# RECOLORED: Total=steelblue, Animal=firebrick, Plant-based=forestgreen
# ─────────────────────────────────────

create_its_forest_restaurants <- function(log_scale = FALSE) {
  output_dir <- if (log_scale) file.path(paste0(OUTPUT_DIR_BASE, "_log")) else file.path(OUTPUT_DIR_BASE)
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  cat("Creating ITS forest plot with restaurant estimates (recolored)...\n")
  cat("  Using A3 overrides:", paste(names(A3_OVERRIDES), "->", A3_OVERRIDES, collapse = ", "), "\n")

  # RECOLORED: Same outcome order as create_forest_plots_chosen.R
  outcomes <- c("total", "nonvegan", "meat", "chicken_fish", "vegetarian", "vegan")

  pooled_list <- list()
  restaurant_list <- list()

  for (outcome in outcomes) {
    model_path_name <- get_model_path(outcome, A3_OVERRIDES)
    model_run_path <- file.path("model_fits", model_path_name)
    model_path <- file.path(model_run_path, "its", outcome)
    summ_path <- file.path(model_path, "summ.rds")

    gamma1 <- extract_mu_gamma(model_path, 1)
    if (!is.null(gamma1)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome,
        effect_type = "Level Change",
        mean = gamma1$mean,
        q2.5 = gamma1$q2.5,
        q97.5 = gamma1$q97.5,
        rhat = gamma1$rhat,
        ess_bulk = gamma1$ess_bulk,
        estimate_type = "Pooled",
        restaurant_id = "POOLED")
    }

    gamma2 <- extract_mu_gamma(model_path, 2)
    if (!is.null(gamma2)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome,
        effect_type = "Slope Change",
        mean = gamma2$mean,
        q2.5 = gamma2$q2.5,
        q97.5 = gamma2$q97.5,
        rhat = gamma2$rhat,
        ess_bulk = gamma2$ess_bulk,
        estimate_type = "Pooled",
        restaurant_id = "POOLED")
    }

    rest_gammas <- extract_restaurant_gammas(model_path, is_its = TRUE)
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

  # RECOLORED: Add color grouping based on outcome category
  df_all <- df_all %>%
    mutate(color_group = case_when(
      outcome == "total" ~ "Total",
      outcome %in% c("nonvegan", "meat", "chicken_fish") ~ "Animal",
      outcome %in% c("vegetarian", "vegan") ~ "Plant-based"))

  if (!log_scale) {
    df_pooled_exp <- df_all %>%
      filter(estimate_type == "Pooled") %>%
      exp_params(col = "effect_type", slope_id = "Slope", unit = "year")
    df_restaurant_only <- df_all %>% filter(estimate_type == "Restaurant")
    df_all <- bind_rows(df_pooled_exp, df_restaurant_only)
  } else {
    df_all <- df_all %>%
      mutate(
        across(c(mean, q2.5, q97.5), ~ case_when(
          estimate_type == "Restaurant" ~ log(.x),
          TRUE ~ .x)))
  }

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

  # RECOLORED: Use color_group for coloring
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
                       "Rate Ratio: ", signif(mean_orig, 3), "<br>",
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
                 "Rate Ratio: ", signif(mean_orig, 3), "<br>",
                 "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                 ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), ""))),
               size = 2.5) +
    # RECOLORED: Color scheme from create_forest_plots_chosen.R
    scale_color_manual(values = c("Total" = "steelblue", "Animal" = "firebrick", "Plant-based" = "forestgreen"),
                       guide = "none") +
    facet_wrap(~ effect_type, ncol = 2) +
    scale_x_continuous(limits = xlim, oob = scales::squish) +
    scale_y_continuous(
      breaks = 1:length(outcomes),
      labels = format_label(rev(outcomes)),
      expand = expansion(mult = c(0.2, 0.1))) +
    labs(
      title = "A3: Interrupted Time Series Analysis",
      subtitle = paste0(if (log_scale) "Log Rate Ratios" else "Rate Ratios", " | Large points = pooled, Small = restaurants | Triangles = values beyond scale"),
      x = if (log_scale) "Log Rate Ratio (mu_gamma)" else "Rate Ratio (exp(mu_gamma))",
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
  saveWidget(p_plotly, file.path(output_dir, html_name), selfcontained = TRUE)

  df_save <- df_all %>% select(-matches("_disp|_orig|clipped|y_numeric|n_in_group|row_in_group"))
  csv_name <- if (log_scale) "A3_its_restaurants_data_log.csv" else "A3_its_restaurants_data.csv"
  write_csv(df_save, file.path(output_dir, csv_name))

  cat("  Saved: A3_its_forest_restaurants.png, .pdf, .html, _data.csv\n")
  return(p)
}

# ─────────────────────────────────────
# 4. ITS_TARGETED Analysis (A4)
# Uses A4_OVERRIDES for outcome-specific model paths
# RECOLORED: Total=steelblue, Animal=firebrick + includes Total (A3)
# ─────────────────────────────────────

create_its_targeted_forest_restaurants <- function(log_scale = FALSE) {
  output_dir <- if (log_scale) file.path(paste0(OUTPUT_DIR_BASE, "_log")) else file.path(OUTPUT_DIR_BASE)
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  cat("Creating ITS targeted forest plot with restaurant estimates (recolored)...\n")
  cat("  Using overrides:", paste(names(A4_OVERRIDES), "->", A4_OVERRIDES, collapse = ", "), "\n")

  outcomes <- c("breakfast", "textured", "untextured")

  pooled_list <- list()
  restaurant_list <- list()

  for (outcome in outcomes) {
    model_path_name <- get_model_path(outcome, A4_OVERRIDES)
    model_run_path <- file.path("model_fits", model_path_name)
    model_path <- file.path(model_run_path, "its_targeted", outcome)
    summ_path <- file.path(model_path, "summ.rds")

    gamma1 <- extract_mu_gamma(model_path, 1)
    if (!is.null(gamma1)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome,
        effect_type = "Level Change",
        mean = gamma1$mean,
        q2.5 = gamma1$q2.5,
        q97.5 = gamma1$q97.5,
        rhat = gamma1$rhat,
        ess_bulk = gamma1$ess_bulk,
        estimate_type = "Pooled",
        restaurant_id = "POOLED",
        source = model_path_name)
    }

    gamma2 <- extract_mu_gamma(model_path, 2)
    if (!is.null(gamma2)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome,
        effect_type = "Slope Change",
        mean = gamma2$mean,
        q2.5 = gamma2$q2.5,
        q97.5 = gamma2$q97.5,
        rhat = gamma2$rhat,
        ess_bulk = gamma2$ess_bulk,
        estimate_type = "Pooled",
        restaurant_id = "POOLED",
        source = model_path_name)
    }

    rest_gammas <- extract_restaurant_gammas(model_path, is_its = TRUE)
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

  # RECOLORED: Add "Total (A3)" from A3 ITS analysis for comparison (pooled only)
  total_model_path_name <- get_model_path("total", A3_OVERRIDES)
  model_path_total <- file.path("model_fits", total_model_path_name, "its", "total")

  gamma1_total <- extract_mu_gamma(model_path_total, 1)
  if (!is.null(gamma1_total)) {
    pooled_list[[length(pooled_list) + 1]] <- tibble(
      outcome = "Total (A3)",
      effect_type = "Level Change",
      mean = gamma1_total$mean,
      q2.5 = gamma1_total$q2.5,
      q97.5 = gamma1_total$q97.5,
      rhat = gamma1_total$rhat,
      ess_bulk = gamma1_total$ess_bulk,
      estimate_type = "Pooled",
      restaurant_id = "POOLED",
      source = total_model_path_name)
  }

  gamma2_total <- extract_mu_gamma(model_path_total, 2)
  if (!is.null(gamma2_total)) {
    pooled_list[[length(pooled_list) + 1]] <- tibble(
      outcome = "Total (A3)",
      effect_type = "Slope Change",
      mean = gamma2_total$mean,
      q2.5 = gamma2_total$q2.5,
      q97.5 = gamma2_total$q97.5,
      rhat = gamma2_total$rhat,
      ess_bulk = gamma2_total$ess_bulk,
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

  # RECOLORED: Order with Total at top
  all_outcomes <- c("Total (A3)", outcomes)
  df_all$outcome <- factor(df_all$outcome, levels = rev(all_outcomes))
  df_all$effect_type <- factor(df_all$effect_type, levels = c("Level Change", "Slope Change"))

  # RECOLORED: Add color grouping
  df_all <- df_all %>%
    mutate(color_group = ifelse(outcome == "Total (A3)", "Total", "Animal"))

  if (!log_scale) {
    df_pooled_exp <- df_all %>%
      filter(estimate_type == "Pooled") %>%
      exp_params(col = "effect_type", slope_id = "Slope", unit = "year")
    df_restaurant_only <- df_all %>% filter(estimate_type == "Restaurant")
    df_all <- bind_rows(df_pooled_exp, df_restaurant_only)
  } else {
    df_all <- df_all %>%
      mutate(
        across(c(mean, q2.5, q97.5), ~ case_when(
          estimate_type == "Restaurant" ~ log(.x),
          TRUE ~ .x)))
  }

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

  # RECOLORED: Use color_group for coloring
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
                       "Rate Ratio: ", signif(mean_orig, 3), "<br>",
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
                 "Rate Ratio: ", signif(mean_orig, 3), "<br>",
                 "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                 "<br>Source: ", source,
                 ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), ""))),
               size = 2.5) +
    # RECOLORED: Color scheme from create_forest_plots_chosen.R
    scale_color_manual(values = c("Total" = "steelblue", "Animal" = "firebrick"),
                       guide = "none") +
    facet_wrap(~ effect_type, ncol = 2) +
    scale_x_continuous(limits = xlim, oob = scales::squish) +
    scale_y_continuous(
      breaks = 1:length(all_outcomes),
      labels = format_label(rev(all_outcomes)),
      expand = expansion(mult = c(0.25, 0.15))) +
    labs(
      title = "A4: Interrupted Time Series Targeted Animal Product Categories",
      subtitle = paste0(if (log_scale) "Log Rate Ratios" else "Rate Ratios", " | Large points = pooled, Small = restaurants | Triangles = values beyond scale"),
      x = if (log_scale) "Log Rate Ratio (mu_gamma)" else "Rate Ratio (exp(mu_gamma))",
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
  saveWidget(p_plotly, file.path(output_dir, html_name), selfcontained = TRUE)

  df_save <- df_all %>% select(-matches("_disp|_orig|clipped|y_numeric|n_in_group|row_in_group"))
  csv_name <- if (log_scale) "A4_its_targeted_restaurants_data_log.csv" else "A4_its_targeted_restaurants_data.csv"
  write_csv(df_save, file.path(output_dir, csv_name))

  cat("  Saved: A4_its_targeted_forest_restaurants.png, .pdf, .html, _data.csv\n")
  return(p)
}

# ─────────────────────────────────────
# Execute
# ─────────────────────────────────────

cat("========================================\n")
cat("Forest Plot Generation - CHOSEN VERSION (with Restaurants) - RECOLORED\n")
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

cat("\n========================================\n")
cat("All forest plots with restaurant estimates generated (RECOLORED)!\n")
cat("Output directories:", OUTPUT_DIR_BASE, "and", paste0(OUTPUT_DIR_BASE, "_log"), "\n")
cat("========================================\n")

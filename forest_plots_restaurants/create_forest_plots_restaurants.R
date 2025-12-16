# Forest Plot Generation Script - With Restaurant-Level Estimates
# Creates horizontal forest plots showing both pooled (mu_gamma) and
# individual restaurant (gamma) estimates for 4 analyses

library(tidyverse)
library(ggplot2)
library(patchwork)
library(htmlwidgets)
library(plotly)

source("model_scripts/view_params_funcs.R")

output_dir <- file.path("forest_plots_restaurants")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# ─────────────────────────────────────
#             Helper Functions
# ─────────────────────────────────────

extract_mu_gamma <- function(summ_path, gamma_index = 1) {
  if (!file.exists(summ_path)) {
    return(NULL)}
  summ <- readRDS(summ_path)
  param_name <- paste0("mu_gamma[", gamma_index, "]")
  row <- summ[summ$variable == param_name, ]
  if (nrow(row) == 0) return(NULL)
  list(
    mean = row$mean,
    median = row$median,
    sd = row$sd,
    q5 = row$q5,
    q95 = row$q95,
    rhat = row$rhat,
    ess_bulk = row$ess_bulk)}

format_label <- function(name) {
  name %>%
    str_replace_all("_", " ") %>%
    str_to_title()}

# Extract restaurant ID from model_col
extract_restaurant_id <- function(model_col) {
  model_col %>%
    str_replace("^exposure_", "") %>%
    str_replace("_\\d+(_slope)?$", "")}

# Extract restaurant-level gammas from a model using find_betas
extract_restaurant_gammas <- function(model_path, is_its = FALSE) {
  if (!file.exists(file.path(model_path, "summ.rds")) ||
      !file.exists(file.path(model_path, "predictor_map.rds"))) {
    return(NULL)
  }

  model <- list(
    summary = readRDS(file.path(model_path, "summ.rds")),
    predictor_map = readRDS(file.path(model_path, "predictor_map.rds"))
  )

  gammas <- model %>%
    find_betas() %>%
    filter(!is.na(model_col) & str_detect(model_col, "exposure"))

  if (nrow(gammas) == 0) return(NULL)

  # For ITS models, separate level and slope effects
  if (is_its) {
    gammas <- gammas %>%
      mutate(
        is_slope = str_detect(model_col, "_slope"),
        effect_type = if_else(is_slope, "Slope Change", "Level Change")
      )
  }

  gammas <- gammas %>%
    exp_betas(unit = "year") %>%
    round_params() %>%
    mutate(restaurant_id = extract_restaurant_id(model_col))

  return(gammas)
}

# ─────────────────────────────────────
# 1. PROPORTION Analysis (A1)
# 6 outcomes x 6 exposures (3 exposure groups x 2 types: count/prop)
# ─────────────────────────────────────

create_proportion_forest_restaurants <- function() {
  cat("Creating proportion forest plot with restaurant estimates...\n")

  outcomes <- c("chicken_fish", "meat", "nonvegan", "total", "vegan", "vegetarian")
  exposure_groups <- c("mpbamod", "vegan", "vegetarian")
  exposure_types <- c("count", "prop")

  pooled_list <- list()
  restaurant_list <- list()

  for (outcome in outcomes) {
    for (exp_group in exposure_groups) {
      for (exp_type in exposure_types) {
        exposure <- paste0(exp_group, "_dishes_", exp_type)
        model_path <- file.path("model_fits/finalized/proportion", outcome, exposure)
        summ_path <- file.path(model_path, "summ.rds")

        # Get pooled estimate
        gamma <- extract_mu_gamma(summ_path, 1)
        if (!is.null(gamma)) {
          pooled_list[[length(pooled_list) + 1]] <- tibble(
            outcome = outcome,
            exposure_group = exp_group,
            exposure_type = exp_type,
            mean = gamma$mean,
            q5 = gamma$q5,
            q95 = gamma$q95,
            rhat = gamma$rhat,
            estimate_type = "Pooled",
            restaurant_id = NA_character_)
        }

        # Get restaurant-level estimates
        rest_gammas <- extract_restaurant_gammas(model_path, is_its = FALSE)
        if (!is.null(rest_gammas) && nrow(rest_gammas) > 0) {
          for (i in 1:nrow(rest_gammas)) {
            restaurant_list[[length(restaurant_list) + 1]] <- tibble(
              outcome = outcome,
              exposure_group = exp_group,
              exposure_type = exp_type,
              mean = rest_gammas$mean[i],
              q5 = rest_gammas$q5[i],
              q95 = rest_gammas$q95[i],
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

  # Order factors
  df_pooled$outcome <- factor(df_pooled$outcome, levels = rev(outcomes))
  df_pooled$exposure_group <- factor(df_pooled$exposure_group, levels = exposure_groups)
  df_pooled$exposure_type <- factor(df_pooled$exposure_type, levels = c("prop", "count"),
                                     labels = c("Proportion", "Count"))

  if (nrow(df_restaurant) > 0) {
    df_restaurant$outcome <- factor(df_restaurant$outcome, levels = rev(outcomes))
    df_restaurant$exposure_group <- factor(df_restaurant$exposure_group, levels = exposure_groups)
    df_restaurant$exposure_type <- factor(df_restaurant$exposure_type, levels = c("prop", "count"),
                                           labels = c("Proportion", "Count"))
  }

  # Exponentiate pooled parameters
  df_pooled <- df_pooled %>%
    mutate(
      across(c(mean, q5, q95), ~ case_when(
        exposure_type == "Count" ~ exp(.x),
        exposure_type == "Proportion" ~ exp(.1 * .x),
        TRUE ~ .x)))

  # Restaurant estimates are already exponentiated by exp_betas
  # But need to apply same scaling for proportion type
  if (nrow(df_restaurant) > 0) {
    df_restaurant <- df_restaurant %>%
      mutate(
        across(c(mean, q5, q95), ~ case_when(
          exposure_type == "Proportion" ~ .x^0.1,
          TRUE ~ .x)))
  }

  # Add vertical offset for restaurant estimates
  df_pooled <- df_pooled %>%
    mutate(y_numeric = as.numeric(outcome))

  if (nrow(df_restaurant) > 0) {
    df_restaurant <- df_restaurant %>%
      mutate(y_numeric = as.numeric(outcome) - 0.25)
  }

  # Create plot
  p <- ggplot() +
    geom_vline(xintercept = 1, linetype = "dashed", color = "gray50") +
    # Restaurant estimates (background, de-emphasized)
    {if (nrow(df_restaurant) > 0)
      geom_errorbarh(data = df_restaurant,
                     aes(xmin = q5, xmax = q95, y = y_numeric),
                     height = 0.1, color = "steelblue", alpha = 0.35, linewidth = 0.4)} +
    {if (nrow(df_restaurant) > 0)
      geom_point(data = df_restaurant,
                 aes(x = mean, y = y_numeric, text = paste0(
                   "Restaurant: ", restaurant_id, "<br>",
                   "Outcome: ", outcome, "<br>",
                   "Exposure: ", exposure_group, " (", exposure_type, ")<br>",
                   "Rate Ratio: ", signif(mean, 3), "<br>",
                   "90% CI: [", signif(q5, 3), ", ", signif(q95, 3), "]")),
                 size = 1.3, color = "steelblue", alpha = 0.4, shape = 16)} +
    # Pooled estimates (foreground, emphasized)
    geom_errorbarh(data = df_pooled,
                   aes(xmin = q5, xmax = q95, y = y_numeric),
                   height = 0.2, color = "steelblue", linewidth = 0.7) +
    geom_point(data = df_pooled,
               aes(x = mean, y = y_numeric, text = paste0(
                 "POOLED<br>",
                 "Outcome: ", outcome, "<br>",
                 "Exposure: ", exposure_group, " (", exposure_type, ")<br>",
                 "Rate Ratio: ", signif(mean, 3), "<br>",
                 "90% CI: [", signif(q5, 3), ", ", signif(q95, 3), "]",
                 ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), ""))),
               size = 2.5, color = "steelblue") +
    facet_grid(exposure_group ~ exposure_type, scales = "free_y", space = "free_y") +
    scale_y_continuous(
      breaks = 1:length(outcomes),
      labels = format_label(rev(outcomes)),
      expand = expansion(mult = c(0.1, 0.1))) +
    labs(
      title = "A1: Proportion Analysis (with Restaurant-Level Estimates)",
      subtitle = "Effect of menu proportions on sales outcomes (Rate Ratios)\nSmall points = individual restaurants, Large points = pooled estimates",
      x = "Rate Ratio (exp(mu_gamma[1]))",
      y = "Outcome") +
    theme_minimal(base_size = 11) +
    theme(
      panel.grid.minor = element_blank(),
      strip.background = element_rect(fill = "gray90", color = NA),
      strip.text = element_text(face = "bold"),
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 9, color = "gray40"),
      axis.text.y = element_text(size = 10))

  # Save
  ggsave(file.path(output_dir, "A1_proportion_forest_restaurants.png"), p,
         width = 11, height = 11, dpi = 300)
  ggsave(file.path(output_dir, "A1_proportion_forest_restaurants.pdf"), p,
         width = 11, height = 11)

  # Save interactive HTML with hover info
  p_plotly <- ggplotly(p, tooltip = "text")
  saveWidget(p_plotly, file.path(output_dir, "A1_proportion_forest_restaurants.html"),
             selfcontained = TRUE)

  # Save extracted data
  df_combined <- bind_rows(df_pooled, df_restaurant) %>% select(-y_numeric)
  write_csv(df_combined, file.path(output_dir, "A1_proportion_restaurants_data.csv"))

  cat("  Saved: A1_proportion_forest_restaurants.png, .pdf, .html, _data.csv\n")
  return(p)
}

# ─────────────────────────────────────
# 2. PROPORTION_TARGETED Analysis (A2)
# 5 outcomes x 2 types (count/presence)
# ─────────────────────────────────────

create_proportion_targeted_forest_restaurants <- function() {
  cat("Creating proportion_targeted forest plot with restaurant estimates...\n")

  outcomes <- c("breakfast_p", "chicken_p", "dairy_p", "egg_p", "untextured_p")
  outcome_labels <- c("Breakfast", "Chicken", "Dairy", "Egg", "Untextured")
  exposure_types <- c("count", "presence")

  pooled_list <- list()
  restaurant_list <- list()

  for (i in seq_along(outcomes)) {
    outcome <- outcomes[i]
    outcome_label <- outcome_labels[i]

    for (exp_type in exposure_types) {
      dish_base <- str_replace(outcome, "_p$", "")
      exposure <- paste0(dish_base, "_dishes_", exp_type)
      model_path <- file.path("model_fits/finalized/proportion_targeted", outcome, exposure)
      summ_path <- file.path(model_path, "summ.rds")

      # Get pooled estimate
      gamma <- extract_mu_gamma(summ_path, 1)
      if (!is.null(gamma)) {
        pooled_list[[length(pooled_list) + 1]] <- tibble(
          outcome = outcome_label,
          exposure_type = exp_type,
          mean = gamma$mean,
          q5 = gamma$q5,
          q95 = gamma$q95,
          rhat = gamma$rhat,
          estimate_type = "Pooled",
          restaurant_id = NA_character_)
      }

      # Get restaurant-level estimates
      rest_gammas <- extract_restaurant_gammas(model_path, is_its = FALSE)
      if (!is.null(rest_gammas) && nrow(rest_gammas) > 0) {
        for (j in 1:nrow(rest_gammas)) {
          restaurant_list[[length(restaurant_list) + 1]] <- tibble(
            outcome = outcome_label,
            exposure_type = exp_type,
            mean = rest_gammas$mean[j],
            q5 = rest_gammas$q5[j],
            q95 = rest_gammas$q95[j],
            rhat = rest_gammas$rhat[j],
            estimate_type = "Restaurant",
            restaurant_id = rest_gammas$restaurant_id[j])
        }
      }
    }
  }

  df_pooled <- bind_rows(pooled_list)
  df_restaurant <- bind_rows(restaurant_list)

  if (nrow(df_pooled) == 0) {
    cat("  No data found for proportion_targeted analysis\n")
    return(NULL)
  }

  # Order factors
  df_pooled$outcome <- factor(df_pooled$outcome, levels = rev(outcome_labels))
  df_pooled$exposure_type <- factor(df_pooled$exposure_type, levels = c("presence", "count"),
                                     labels = c("Presence", "Count"))

  if (nrow(df_restaurant) > 0) {
    df_restaurant$outcome <- factor(df_restaurant$outcome, levels = rev(outcome_labels))
    df_restaurant$exposure_type <- factor(df_restaurant$exposure_type, levels = c("presence", "count"),
                                           labels = c("Presence", "Count"))
  }

  # Exponentiate pooled parameters
  df_pooled <- df_pooled %>%
    mutate(
      across(c(mean, q5, q95), ~ case_when(
        exposure_type == "Count" ~ exp(.x),
        exposure_type == "Proportion" ~ exp(.1 * .x),
        TRUE ~ .x)))

  # Add vertical offset for restaurant estimates
  df_pooled <- df_pooled %>%
    mutate(y_numeric = as.numeric(outcome))

  if (nrow(df_restaurant) > 0) {
    df_restaurant <- df_restaurant %>%
      mutate(y_numeric = as.numeric(outcome) - 0.25)
  }

  # Create plot
  p <- ggplot() +
    geom_vline(xintercept = 1, linetype = "dashed", color = "gray50") +
    # Restaurant estimates (background, de-emphasized)
    {if (nrow(df_restaurant) > 0)
      geom_errorbarh(data = df_restaurant,
                     aes(xmin = q5, xmax = q95, y = y_numeric),
                     height = 0.1, color = "darkgreen", alpha = 0.35, linewidth = 0.4)} +
    {if (nrow(df_restaurant) > 0)
      geom_point(data = df_restaurant,
                 aes(x = mean, y = y_numeric, text = paste0(
                   "Restaurant: ", restaurant_id, "<br>",
                   "Outcome: ", outcome, "<br>",
                   "Exposure: ", exposure_type, "<br>",
                   "Rate Ratio: ", signif(mean, 3), "<br>",
                   "90% CI: [", signif(q5, 3), ", ", signif(q95, 3), "]")),
                 size = 1.3, color = "darkgreen", alpha = 0.4, shape = 16)} +
    # Pooled estimates (foreground, emphasized)
    geom_errorbarh(data = df_pooled,
                   aes(xmin = q5, xmax = q95, y = y_numeric),
                   height = 0.2, color = "darkgreen", linewidth = 0.7) +
    geom_point(data = df_pooled,
               aes(x = mean, y = y_numeric, text = paste0(
                 "POOLED<br>",
                 "Outcome: ", outcome, "<br>",
                 "Exposure: ", exposure_type, "<br>",
                 "Rate Ratio: ", signif(mean, 3), "<br>",
                 "90% CI: [", signif(q5, 3), ", ", signif(q95, 3), "]",
                 ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), ""))),
               size = 2.5, color = "darkgreen") +
    facet_wrap(~ exposure_type, ncol = 2) +
    scale_y_continuous(
      breaks = 1:length(outcome_labels),
      labels = rev(outcome_labels),
      expand = expansion(mult = c(0.15, 0.1))) +
    labs(
      title = "A2: Targeted Animal Product Categories Proportion Analysis",
      subtitle = "Effect of targeted category menu proportions on sales (Rate Ratios)\nSmall points = individual restaurants, Large points = pooled estimates",
      x = "Rate Ratio (exp(mu_gamma[1]))",
      y = "Outcome") +
    theme_minimal(base_size = 11) +
    theme(
      panel.grid.minor = element_blank(),
      strip.background = element_rect(fill = "gray90", color = NA),
      strip.text = element_text(face = "bold"),
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 9, color = "gray40"),
      axis.text.y = element_text(size = 10))

  # Save
  ggsave(file.path(output_dir, "A2_proportion_targeted_forest_restaurants.png"), p,
         width = 10, height = 6, dpi = 300)
  ggsave(file.path(output_dir, "A2_proportion_targeted_forest_restaurants.pdf"), p,
         width = 10, height = 6)

  # Save interactive HTML
  p_plotly <- ggplotly(p, tooltip = "text")
  saveWidget(p_plotly, file.path(output_dir, "A2_proportion_targeted_forest_restaurants.html"),
             selfcontained = TRUE)

  # Save extracted data
  df_combined <- bind_rows(df_pooled, df_restaurant) %>% select(-y_numeric)
  write_csv(df_combined, file.path(output_dir, "A2_proportion_targeted_restaurants_data.csv"))

  cat("  Saved: A2_proportion_targeted_forest_restaurants.png, .pdf, .html, _data.csv\n")
  return(p)
}

# ─────────────────────────────────────
# 3. ITS Analysis (A3)
# 6 outcomes x 2 mu_gammas (level, slope)
# ─────────────────────────────────────

create_its_forest_restaurants <- function() {
  cat("Creating ITS forest plot with restaurant estimates...\n")

  outcomes <- c("chicken_fish", "meat", "nonvegan", "total", "vegan", "vegetarian")

  pooled_list <- list()
  restaurant_list <- list()

  for (outcome in outcomes) {
    model_path <- file.path("model_fits/finalized/its", outcome)
    summ_path <- file.path(model_path, "summ.rds")

    # Get pooled estimates
    gamma1 <- extract_mu_gamma(summ_path, 1)
    if (!is.null(gamma1)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome,
        effect_type = "Level Change",
        mean = gamma1$mean,
        q5 = gamma1$q5,
        q95 = gamma1$q95,
        rhat = gamma1$rhat,
        ess_bulk = gamma1$ess_bulk,
        estimate_type = "Pooled",
        restaurant_id = NA_character_)
    }

    gamma2 <- extract_mu_gamma(summ_path, 2)
    if (!is.null(gamma2)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome,
        effect_type = "Slope Change",
        mean = gamma2$mean,
        q5 = gamma2$q5,
        q95 = gamma2$q95,
        rhat = gamma2$rhat,
        ess_bulk = gamma2$ess_bulk,
        estimate_type = "Pooled",
        restaurant_id = NA_character_)
    }

    # Get restaurant-level estimates
    rest_gammas <- extract_restaurant_gammas(model_path, is_its = TRUE)
    if (!is.null(rest_gammas) && nrow(rest_gammas) > 0) {
      for (i in 1:nrow(rest_gammas)) {
        restaurant_list[[length(restaurant_list) + 1]] <- tibble(
          outcome = outcome,
          effect_type = rest_gammas$effect_type[i],
          mean = rest_gammas$mean[i],
          q5 = rest_gammas$q5[i],
          q95 = rest_gammas$q95[i],
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

  # Order factors
  df_pooled$outcome <- factor(df_pooled$outcome, levels = rev(outcomes))
  df_pooled$effect_type <- factor(df_pooled$effect_type, levels = c("Level Change", "Slope Change"))

  if (nrow(df_restaurant) > 0) {
    df_restaurant$outcome <- factor(df_restaurant$outcome, levels = rev(outcomes))
    df_restaurant$effect_type <- factor(df_restaurant$effect_type, levels = c("Level Change", "Slope Change"))
  }

  # Exponentiate pooled parameters with proper slope handling
  df_pooled <- exp_params(df_pooled, col = "effect_type", slope_id = "Slope", unit = "year")

  # Add vertical offset for restaurant estimates
  df_pooled <- df_pooled %>%
    mutate(y_numeric = as.numeric(outcome))

  if (nrow(df_restaurant) > 0) {
    df_restaurant <- df_restaurant %>%
      mutate(y_numeric = as.numeric(outcome) - 0.25)
  }

  # Create plot
  p <- ggplot() +
    geom_vline(xintercept = 1, linetype = "dashed", color = "gray50") +
    # Restaurant estimates (background, de-emphasized)
    {if (nrow(df_restaurant) > 0)
      geom_errorbarh(data = df_restaurant,
                     aes(xmin = q5, xmax = q95, y = y_numeric),
                     height = 0.1, color = "darkorange", alpha = 0.35, linewidth = 0.4)} +
    {if (nrow(df_restaurant) > 0)
      geom_point(data = df_restaurant,
                 aes(x = mean, y = y_numeric, text = paste0(
                   "Restaurant: ", restaurant_id, "<br>",
                   "Outcome: ", outcome, "<br>",
                   "Effect: ", effect_type, "<br>",
                   "Rate Ratio: ", signif(mean, 3), "<br>",
                   "90% CI: [", signif(q5, 3), ", ", signif(q95, 3), "]")),
                 size = 1.3, color = "darkorange", alpha = 0.4, shape = 16)} +
    # Pooled estimates (foreground, emphasized)
    geom_errorbarh(data = df_pooled,
                   aes(xmin = q5, xmax = q95, y = y_numeric),
                   height = 0.2, color = "darkorange", linewidth = 0.7) +
    geom_point(data = df_pooled,
               aes(x = mean, y = y_numeric, text = paste0(
                 "POOLED<br>",
                 "Outcome: ", outcome, "<br>",
                 "Effect: ", effect_type, "<br>",
                 "Rate Ratio: ", signif(mean, 3), "<br>",
                 "90% CI: [", signif(q5, 3), ", ", signif(q95, 3), "]",
                 ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), ""))),
               size = 2.5, color = "darkorange") +
    facet_wrap(~ effect_type, ncol = 2) +
    scale_y_continuous(
      breaks = 1:length(outcomes),
      labels = format_label(rev(outcomes)),
      expand = expansion(mult = c(0.15, 0.1))) +
    labs(
      title = "A3: Interrupted Time Series Analysis",
      subtitle = "Level and slope changes after MPBA introduction (Rate Ratios)\nSmall points = individual restaurants, Large points = pooled estimates",
      x = "Rate Ratio (exp(mu_gamma))",
      y = "Outcome") +
    theme_minimal(base_size = 11) +
    theme(
      panel.grid.minor = element_blank(),
      strip.background = element_rect(fill = "gray90", color = NA),
      strip.text = element_text(face = "bold"),
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 9, color = "gray40"),
      axis.text.y = element_text(size = 10))

  # Save
  ggsave(file.path(output_dir, "A3_its_forest_restaurants.png"), p,
         width = 10, height = 6, dpi = 300)
  ggsave(file.path(output_dir, "A3_its_forest_restaurants.pdf"), p,
         width = 10, height = 6)

  # Save interactive HTML
  p_plotly <- ggplotly(p, tooltip = "text")
  saveWidget(p_plotly, file.path(output_dir, "A3_its_forest_restaurants.html"),
             selfcontained = TRUE)

  # Save extracted data
  df_combined <- bind_rows(df_pooled, df_restaurant) %>% select(-y_numeric)
  write_csv(df_combined, file.path(output_dir, "A3_its_restaurants_data.csv"))

  cat("  Saved: A3_its_forest_restaurants.png, .pdf, .html, _data.csv\n")
  return(p)
}

# ─────────────────────────────────────
# 4. ITS_TARGETED Analysis (A4)
# 3 outcomes x 2 mu_gammas (level change, slope)
# ─────────────────────────────────────

create_its_targeted_forest_restaurants <- function() {
  cat("Creating ITS targeted forest plot with restaurant estimates...\n")

  outcomes <- c("breakfast", "textured", "untextured")

  pooled_list <- list()
  restaurant_list <- list()

  for (outcome in outcomes) {
    model_path <- file.path("model_fits/finalized/its_targeted", outcome)
    summ_path <- file.path(model_path, "summ.rds")

    # Get pooled estimates
    gamma1 <- extract_mu_gamma(summ_path, 1)
    if (!is.null(gamma1)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome,
        effect_type = "Level Change",
        mean = gamma1$mean,
        q5 = gamma1$q5,
        q95 = gamma1$q95,
        rhat = gamma1$rhat,
        ess_bulk = gamma1$ess_bulk,
        estimate_type = "Pooled",
        restaurant_id = NA_character_)
    }

    gamma2 <- extract_mu_gamma(summ_path, 2)
    if (!is.null(gamma2)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome,
        effect_type = "Slope Change",
        mean = gamma2$mean,
        q5 = gamma2$q5,
        q95 = gamma2$q95,
        rhat = gamma2$rhat,
        ess_bulk = gamma2$ess_bulk,
        estimate_type = "Pooled",
        restaurant_id = NA_character_)
    }

    # Get restaurant-level estimates
    rest_gammas <- extract_restaurant_gammas(model_path, is_its = TRUE)
    if (!is.null(rest_gammas) && nrow(rest_gammas) > 0) {
      for (i in 1:nrow(rest_gammas)) {
        restaurant_list[[length(restaurant_list) + 1]] <- tibble(
          outcome = outcome,
          effect_type = rest_gammas$effect_type[i],
          mean = rest_gammas$mean[i],
          q5 = rest_gammas$q5[i],
          q95 = rest_gammas$q95[i],
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
    cat("  No data found for ITS targeted analysis\n")
    return(NULL)
  }

  # Order factors
  df_pooled$outcome <- factor(df_pooled$outcome, levels = rev(outcomes))
  df_pooled$effect_type <- factor(df_pooled$effect_type, levels = c("Level Change", "Slope Change"))

  if (nrow(df_restaurant) > 0) {
    df_restaurant$outcome <- factor(df_restaurant$outcome, levels = rev(outcomes))
    df_restaurant$effect_type <- factor(df_restaurant$effect_type, levels = c("Level Change", "Slope Change"))
  }

  # Exponentiate pooled parameters with proper slope handling
  df_pooled <- exp_params(df_pooled, col = "effect_type", slope_id = "Slope", unit = "year")

  # Add vertical offset for restaurant estimates
  df_pooled <- df_pooled %>%
    mutate(y_numeric = as.numeric(outcome))

  if (nrow(df_restaurant) > 0) {
    df_restaurant <- df_restaurant %>%
      mutate(y_numeric = as.numeric(outcome) - 0.25)
  }

  # Create plot
  p <- ggplot() +
    geom_vline(xintercept = 1, linetype = "dashed", color = "gray50") +
    # Restaurant estimates (background, de-emphasized)
    {if (nrow(df_restaurant) > 0)
      geom_errorbarh(data = df_restaurant,
                     aes(xmin = q5, xmax = q95, y = y_numeric),
                     height = 0.1, color = "purple", alpha = 0.35, linewidth = 0.4)} +
    {if (nrow(df_restaurant) > 0)
      geom_point(data = df_restaurant,
                 aes(x = mean, y = y_numeric, text = paste0(
                   "Restaurant: ", restaurant_id, "<br>",
                   "Outcome: ", outcome, "<br>",
                   "Effect: ", effect_type, "<br>",
                   "Rate Ratio: ", signif(mean, 3), "<br>",
                   "90% CI: [", signif(q5, 3), ", ", signif(q95, 3), "]")),
                 size = 1.3, color = "purple", alpha = 0.4, shape = 16)} +
    # Pooled estimates (foreground, emphasized)
    geom_errorbarh(data = df_pooled,
                   aes(xmin = q5, xmax = q95, y = y_numeric),
                   height = 0.2, color = "purple", linewidth = 0.7) +
    geom_point(data = df_pooled,
               aes(x = mean, y = y_numeric, text = paste0(
                 "POOLED<br>",
                 "Outcome: ", outcome, "<br>",
                 "Effect: ", effect_type, "<br>",
                 "Rate Ratio: ", signif(mean, 3), "<br>",
                 "90% CI: [", signif(q5, 3), ", ", signif(q95, 3), "]",
                 ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), ""))),
               size = 2.5, color = "purple") +
    facet_wrap(~ effect_type, ncol = 2) +
    scale_y_continuous(
      breaks = 1:length(outcomes),
      labels = format_label(rev(outcomes)),
      expand = expansion(mult = c(0.2, 0.15))) +
    labs(
      title = "A4: Interrupted Time Series Targeted Animal Product Categories",
      subtitle = "Level and slope changes for targeted category MPBA introductions (Rate Ratios)\nSmall points = individual restaurants, Large points = pooled estimates",
      x = "Rate Ratio (exp(mu_gamma))",
      y = "Outcome") +
    theme_minimal(base_size = 11) +
    theme(
      panel.grid.minor = element_blank(),
      strip.background = element_rect(fill = "gray90", color = NA),
      strip.text = element_text(face = "bold"),
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 9, color = "gray40"),
      axis.text.y = element_text(size = 10))

  # Save
  ggsave(file.path(output_dir, "A4_its_targeted_forest_restaurants.png"), p,
         width = 10, height = 5, dpi = 300)
  ggsave(file.path(output_dir, "A4_its_targeted_forest_restaurants.pdf"), p,
         width = 10, height = 5)

  # Save interactive HTML
  p_plotly <- ggplotly(p, tooltip = "text")
  saveWidget(p_plotly, file.path(output_dir, "A4_its_targeted_forest_restaurants.html"),
             selfcontained = TRUE)

  # Save extracted data
  df_combined <- bind_rows(df_pooled, df_restaurant) %>% select(-y_numeric)
  write_csv(df_combined, file.path(output_dir, "A4_its_targeted_restaurants_data.csv"))

  cat("  Saved: A4_its_targeted_forest_restaurants.png, .pdf, .html, _data.csv\n")
  return(p)
}

# ─────────────────────────────────────
# Execute
# ─────────────────────────────────────

cat("========================================\n")
cat("Forest Plot Generation (with Restaurants)\n")
cat("========================================\n\n")

p1 <- create_proportion_forest_restaurants()
p2 <- create_proportion_targeted_forest_restaurants()
p3 <- create_its_forest_restaurants()
p4 <- create_its_targeted_forest_restaurants()

cat("\n========================================\n")
cat("All forest plots with restaurant estimates generated!\n")
cat("Output directory:", output_dir, "\n")
cat("========================================\n")

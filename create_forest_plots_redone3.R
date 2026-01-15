# Forest Plot Generation Script - finalized_redone3
# Creates horizontal forest plots
# Uses finalized_redone3 for ALL analyses (no overrides)

library(tidyverse)
library(ggplot2)
library(patchwork)
library(htmlwidgets)
library(plotly)

source("model_scripts/view_params_funcs.R")
source("model_scripts/ci95_helpers.R")

# ─────────────────────────────────────
#         Configuration
# ─────────────────────────────────────

# Model path for all analyses
DEFAULT_MODEL_PATH <- "finalized_redone3"

# No overrides - use finalized_redone3 for everything
A2_OVERRIDES <- list()
A4_OVERRIDES <- list()

OUTPUT_DIR <- "forest_plots_redone3"

# ─────────────────────────────────────
#             Helper Functions
# ─────────────────────────────────────

extract_mu_gamma <- function(model_dir, gamma_index = 1) {
  # Use 95% CI helper function (extracts from samples.rds)
  extract_mu_gamma_95ci(model_dir, gamma_index)
}

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

# ─────────────────────────────────────
# 1. PROPORTION Analysis (A1)
# 6 outcomes x 6 exposures (3 exposure groups x 2 types: count/prop)
# ─────────────────────────────────────

create_proportion_forest <- function() {
  cat("Creating proportion forest plot...\n")

  dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)

  outcomes <- c("total", "nonvegan", "meat", "chicken_fish", "vegetarian", "vegan")
  exposure_groups <- c("mpbamod", "vegan", "vegetarian")
  exposure_types <- c("count", "prop")

  data_list <- list()

  for (outcome in outcomes) {
    model_run_path <- file.path("model_fits", DEFAULT_MODEL_PATH)
    for (exp_group in exposure_groups) {
      for (exp_type in exposure_types) {
        exposure <- paste0(exp_group, "_dishes_", exp_type)
        model_dir <- file.path(model_run_path, "proportion",
                               outcome, exposure)

        gamma <- extract_mu_gamma(model_dir, 1)
        if (!is.null(gamma)) {
          data_list[[length(data_list) + 1]] <- tibble(
            outcome = outcome,
            exposure_group = exp_group,
            exposure_type = exp_type,
            mean = gamma$mean,
            q2.5 = gamma$q2.5,
            q97.5 = gamma$q97.5,
            rhat = gamma$rhat)}}}}

  df <- bind_rows(data_list)
  if (nrow(df) == 0) {
    cat("  No data found for proportion analysis\n")
    return(NULL)}

  # Order factors
  df$outcome <- factor(df$outcome, levels = rev(outcomes))
  df$exposure_group <- factor(df$exposure_group, levels = exposure_groups)
  df$exposure_type <- factor(df$exposure_type, levels = c("prop", "count"),
                              labels = c("Proportion", "Count"))

  # Add color grouping based on outcome category
  df <- df %>%
    mutate(color_group = case_when(
      outcome == "total" ~ "Total",
      outcome %in% c("nonvegan", "meat", "chicken_fish") ~ "Animal",
      outcome %in% c("vegetarian", "vegan") ~ "Plant-based"))

  # Exponentiate parameters
  df <- df %>%
    mutate(
      across(c(mean, q2.5, q97.5), ~ case_when(
        exposure_type == "Count" ~ exp(.x),
        exposure_type == "Proportion" ~ exp(.1 * .x),
        TRUE ~ .x)))

  # Create plot
  p <- ggplot(df, aes(x = mean, y = outcome, color = color_group, text = paste0(
    "Outcome: ", outcome, "<br>",
    "Exposure: ", exposure_group, " (", exposure_type, ")<br>",
    "Rate Ratio: ", signif(mean, 3), "<br>",
    "95% CI: [", signif(q2.5, 3), ", ", signif(q97.5, 3), "]",
    ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), "")))) +
    geom_vline(xintercept = 1, linetype = "dashed", color = "gray50") +
    geom_errorbarh(aes(xmin = q2.5, xmax = q97.5), height = 0.2) +
    geom_point(size = 2.5) +
    scale_color_manual(values = c("Total" = "steelblue", "Animal" = "firebrick", "Plant-based" = "forestgreen"),
                       guide = "none") +
    scale_x_continuous(limits = c(0, NA), breaks = scales::pretty_breaks()) +
    facet_grid(exposure_group ~ exposure_type, scales = "free_y", space = "free_y") +
    labs(
      title = "A1: Proportion Analysis",
      subtitle = "Effect of menu proportions on sales outcomes (Rate Ratios)",
      x = "Rate Ratio (exp(mu_gamma[1]))",
      y = "Outcome") +
    scale_y_discrete(labels = function(x) format_label(x)) +
    theme_minimal(base_size = 11) +
    theme(
      panel.grid.minor = element_blank(),
      strip.background = element_rect(fill = "gray90", color = NA),
      strip.text = element_text(face = "bold"),
      plot.title = element_text(face = "bold", size = 14),
      axis.text.y = element_text(size = 10))

  # Save
  ggsave(file.path(OUTPUT_DIR, "A1_proportion_forest.png"), p,
         width = 10, height = 10, dpi = 300)
  ggsave(file.path(OUTPUT_DIR, "A1_proportion_forest.pdf"), p,
         width = 10, height = 10)

  p_plotly <- ggplotly(p, tooltip = "text")
  saveWidget(p_plotly, file.path(OUTPUT_DIR, "A1_proportion_forest.html"),
             selfcontained = TRUE)

  write_csv(df, file.path(OUTPUT_DIR, "A1_proportion_mu_gamma.csv"))

  cat("  Saved: A1_proportion_forest.png, .pdf, .html, _mu_gamma.csv\n")
  return(p)
}

# ─────────────────────────────────────
# 2. PROPORTION_TARGETED Analysis (A2)
# 5 outcomes x 2 types (count/presence)
# ─────────────────────────────────────

create_proportion_targeted_forest <- function() {
  cat("Creating proportion_targeted forest plot...\n")
  cat("  Using overrides:", if(length(A2_OVERRIDES) == 0) "NONE" else paste(names(A2_OVERRIDES), "->", A2_OVERRIDES, collapse = ", "), "\n")

  dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)

  outcomes <- c("breakfast_p", "chicken_p", "dairy_p", "egg_p", "untextured_p")
  outcome_labels <- c("Breakfast", "Chicken", "Dairy", "Egg", "Untextured")
  exposure_types <- c("count", "presence")

  data_list <- list()

  for (i in seq_along(outcomes)) {
    outcome <- outcomes[i]
    outcome_label <- outcome_labels[i]

    # Get the appropriate model path for this outcome
    model_path <- get_model_path(outcome, A2_OVERRIDES)
    model_run_path <- file.path("model_fits", model_path)

    for (exp_type in exposure_types) {
      dish_base <- str_replace(outcome, "_p$", "")
      exposure <- paste0(dish_base, "_dishes_", exp_type)
      model_dir <- file.path(model_run_path, "proportion_targeted",
                             outcome, exposure)

      gamma <- extract_mu_gamma(model_dir, 1)
      if (!is.null(gamma)) {
        data_list[[length(data_list) + 1]] <- tibble(
          outcome = outcome_label,
          exposure_type = exp_type,
          mean = gamma$mean,
          q2.5 = gamma$q2.5,
          q97.5 = gamma$q97.5,
          rhat = gamma$rhat,
          source = model_path)}}}

  # Add "Total" from A1 proportion analysis for comparison
  for (exp_type in c("count", "prop")) {
    model_dir <- file.path("model_fits", DEFAULT_MODEL_PATH, "proportion",
                           "total", paste0("mpbamod_dishes_", exp_type))
    gamma <- extract_mu_gamma(model_dir, 1)
    if (!is.null(gamma)) {
      data_list[[length(data_list) + 1]] <- tibble(
        outcome = "Total (A1)",
        exposure_type = ifelse(exp_type == "prop", "presence", exp_type),
        mean = gamma$mean,
        q2.5 = gamma$q2.5,
        q97.5 = gamma$q97.5,
        rhat = gamma$rhat,
        source = DEFAULT_MODEL_PATH)}}

  df <- bind_rows(data_list)

  if (nrow(df) == 0) {
    cat("  No data found for proportion_targeted analysis\n")
    return(NULL)}

  # Order factors with Total at top
  all_outcomes <- c("Total (A1)", outcome_labels)
  df$outcome <- factor(df$outcome, levels = rev(all_outcomes))
  df$exposure_type <- factor(df$exposure_type, levels = c("presence", "count"),
                              labels = c("Presence", "Count"))

  # Add color grouping
  df <- df %>%
    mutate(color_group = ifelse(outcome == "Total (A1)", "Total", "Animal"))

  # Exponentiate parameters
  df <- df %>%
    mutate(
      across(c(mean, q2.5, q97.5), ~ case_when(
        exposure_type == "Count" ~ exp(.x),
        exposure_type == "Presence" ~ exp(.1 * .x),
        TRUE ~ .x)))

  # Create plot
  p <- ggplot(df, aes(x = mean, y = outcome, color = color_group, text = paste0(
    "Outcome: ", outcome, "<br>",
    "Exposure: ", exposure_type, "<br>",
    "Rate Ratio: ", signif(mean, 3), "<br>",
    "95% CI: [", signif(q2.5, 3), ", ", signif(q97.5, 3), "]",
    ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), ""),
    "<br>Source: ", source))) +
    geom_vline(xintercept = 1, linetype = "dashed", color = "gray50") +
    geom_errorbarh(aes(xmin = q2.5, xmax = q97.5), height = 0.2) +
    geom_point(size = 2.5) +
    scale_color_manual(values = c("Total" = "steelblue", "Animal" = "firebrick"),
                       guide = "none") +
    scale_x_continuous(limits = c(0, NA), breaks = scales::pretty_breaks()) +
    facet_wrap(~ exposure_type, ncol = 2) +
    labs(
      title = "A2: Targeted Animal Product Categories Proportion Analysis",
      subtitle = "Effect of targeted category menu proportions on sales outcomes (Rate Ratios)",
      x = "Rate Ratio (exp(mu_gamma[1]))",
      y = "Outcome") +
    theme_minimal(base_size = 11) +
    theme(
      panel.grid.minor = element_blank(),
      strip.background = element_rect(fill = "gray90", color = NA),
      strip.text = element_text(face = "bold"),
      plot.title = element_text(face = "bold", size = 14),
      axis.text.y = element_text(size = 10))

  # Save
  ggsave(file.path(OUTPUT_DIR, "A2_proportion_targeted_forest.png"), p,
         width = 9, height = 5, dpi = 300)
  ggsave(file.path(OUTPUT_DIR, "A2_proportion_targeted_forest.pdf"), p,
         width = 9, height = 5)

  p_plotly <- ggplotly(p, tooltip = "text")
  saveWidget(p_plotly, file.path(OUTPUT_DIR, "A2_proportion_targeted_forest.html"),
             selfcontained = TRUE)

  write_csv(df, file.path(OUTPUT_DIR, "A2_proportion_targeted_mu_gamma.csv"))

  cat("  Saved: A2_proportion_targeted_forest.png, .pdf, .html, _mu_gamma.csv\n")
  return(p)
}

# ─────────────────────────────────────
# 3. ITS Analysis (A3)
# 6 outcomes x 2 mu_gammas (level, slope)
# ─────────────────────────────────────

create_its_forest <- function() {
  cat("Creating ITS forest plot...\n")

  dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)
  model_run_path <- file.path("model_fits", DEFAULT_MODEL_PATH)

  outcomes <- c("total", "nonvegan", "meat", "chicken_fish", "vegetarian", "vegan")

  data_list <- list()

  for (outcome in outcomes) {
    model_dir <- file.path(model_run_path, "its", outcome)

    gamma1 <- extract_mu_gamma(model_dir, 1)
    if (!is.null(gamma1)) {
      data_list[[length(data_list) + 1]] <- tibble(
        outcome = outcome,
        effect_type = "Level Change",
        mean = gamma1$mean,
        q2.5 = gamma1$q2.5,
        q97.5 = gamma1$q97.5,
        rhat = gamma1$rhat,
        ess_bulk = gamma1$ess_bulk)}

    gamma2 <- extract_mu_gamma(model_dir, 2)
    if (!is.null(gamma2)) {
      data_list[[length(data_list) + 1]] <- tibble(
        outcome = outcome,
        effect_type = "Slope Change",
        mean = gamma2$mean,
        q2.5 = gamma2$q2.5,
        q97.5 = gamma2$q97.5,
        rhat = gamma2$rhat,
        ess_bulk = gamma2$ess_bulk)}}

  df <- bind_rows(data_list)

  if (nrow(df) == 0) {
    cat("  No data found for ITS analysis\n")
    return(NULL)}

  df$outcome <- factor(df$outcome, levels = rev(outcomes))
  df$effect_type <- factor(df$effect_type, levels = c("Level Change", "Slope Change"))

  df <- df %>%
    mutate(color_group = case_when(
      outcome == "total" ~ "Total",
      outcome %in% c("nonvegan", "meat", "chicken_fish") ~ "Animal",
      outcome %in% c("vegetarian", "vegan") ~ "Plant-based"))

  df <- exp_params_95ci(df, col = "effect_type", slope_id = "Slope", unit = "year")

  p <- ggplot(df, aes(x = mean, y = outcome, color = color_group, text = paste0(
    "Outcome: ", outcome, "<br>",
    "Effect: ", effect_type, "<br>",
    "Rate Ratio: ", signif(mean, 3), "<br>",
    "95% CI: [", signif(q2.5, 3), ", ", signif(q97.5, 3), "]",
    ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), "")))) +
    geom_vline(xintercept = 1, linetype = "dashed", color = "gray50") +
    geom_errorbarh(aes(xmin = q2.5, xmax = q97.5), height = 0.2) +
    geom_point(size = 2.5) +
    scale_color_manual(values = c("Total" = "steelblue", "Animal" = "firebrick", "Plant-based" = "forestgreen"),
                       guide = "none") +
    scale_x_continuous(limits = c(0, NA), breaks = scales::pretty_breaks()) +
    facet_wrap(~ effect_type, ncol = 2) +
    labs(
      title = "A3: Interrupted Time Series Analysis",
      subtitle = "Level and slope changes after MPBA introduction (Rate Ratios)",
      x = "Rate Ratio (exp(mu_gamma))",
      y = "Outcome") +
    scale_y_discrete(labels = function(x) format_label(x)) +
    theme_minimal(base_size = 11) +
    theme(
      panel.grid.minor = element_blank(),
      strip.background = element_rect(fill = "gray90", color = NA),
      strip.text = element_text(face = "bold"),
      plot.title = element_text(face = "bold", size = 14),
      axis.text.y = element_text(size = 10))

  ggsave(file.path(OUTPUT_DIR, "A3_its_forest.png"), p,
         width = 9, height = 5, dpi = 300)
  ggsave(file.path(OUTPUT_DIR, "A3_its_forest.pdf"), p,
         width = 9, height = 5)

  p_plotly <- ggplotly(p, tooltip = "text")
  saveWidget(p_plotly, file.path(OUTPUT_DIR, "A3_its_forest.html"),
             selfcontained = TRUE)

  write_csv(df, file.path(OUTPUT_DIR, "A3_its_mu_gamma.csv"))

  cat("  Saved: A3_its_forest.png, .pdf, .html, _mu_gamma.csv\n")
  return(p)
}

# ─────────────────────────────────────
# 4. ITS_TARGETED Analysis (A4)
# 3 outcomes x 2 mu_gammas (level change, slope)
# ─────────────────────────────────────

create_its_targeted_forest <- function() {
  cat("Creating ITS targeted forest plot...\n")
  cat("  Using overrides:", if(length(A4_OVERRIDES) == 0) "NONE" else paste(names(A4_OVERRIDES), "->", A4_OVERRIDES, collapse = ", "), "\n")

  dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)

  outcomes <- c("breakfast", "textured", "untextured")

  data_list <- list()

  for (outcome in outcomes) {
    # Get the appropriate model path for this outcome
    model_path <- get_model_path(outcome, A4_OVERRIDES)
    model_run_path <- file.path("model_fits", model_path)

    model_dir <- file.path(model_run_path, "its_targeted", outcome)

    gamma1 <- extract_mu_gamma(model_dir, 1)
    if (!is.null(gamma1)) {
      data_list[[length(data_list) + 1]] <- tibble(
        outcome = outcome,
        effect_type = "Level Change",
        mean = gamma1$mean,
        q2.5 = gamma1$q2.5,
        q97.5 = gamma1$q97.5,
        rhat = gamma1$rhat,
        ess_bulk = gamma1$ess_bulk,
        source = model_path)}

    gamma2 <- extract_mu_gamma(model_dir, 2)
    if (!is.null(gamma2)) {
      data_list[[length(data_list) + 1]] <- tibble(
        outcome = outcome,
        effect_type = "Slope Change",
        mean = gamma2$mean,
        q2.5 = gamma2$q2.5,
        q97.5 = gamma2$q97.5,
        rhat = gamma2$rhat,
        ess_bulk = gamma2$ess_bulk,
        source = model_path)}}

  # Add "Total" from A3 ITS analysis for comparison
  model_dir_total <- file.path("model_fits", DEFAULT_MODEL_PATH, "its", "total")

  gamma1_total <- extract_mu_gamma(model_dir_total, 1)
  if (!is.null(gamma1_total)) {
    data_list[[length(data_list) + 1]] <- tibble(
      outcome = "Total (A3)",
      effect_type = "Level Change",
      mean = gamma1_total$mean,
      q2.5 = gamma1_total$q2.5,
      q97.5 = gamma1_total$q97.5,
      rhat = gamma1_total$rhat,
      ess_bulk = gamma1_total$ess_bulk,
      source = DEFAULT_MODEL_PATH)}

  gamma2_total <- extract_mu_gamma(model_dir_total, 2)
  if (!is.null(gamma2_total)) {
    data_list[[length(data_list) + 1]] <- tibble(
      outcome = "Total (A3)",
      effect_type = "Slope Change",
      mean = gamma2_total$mean,
      q2.5 = gamma2_total$q2.5,
      q97.5 = gamma2_total$q97.5,
      rhat = gamma2_total$rhat,
      ess_bulk = gamma2_total$ess_bulk,
      source = DEFAULT_MODEL_PATH)}

  df <- bind_rows(data_list)

  if (nrow(df) == 0) {
    cat("  No data found for ITS targeted analysis\n")
    return(NULL)}

  all_outcomes <- c("Total (A3)", outcomes)
  df$outcome <- factor(df$outcome, levels = rev(all_outcomes))
  df$effect_type <- factor(df$effect_type, levels = c("Level Change", "Slope Change"))

  df <- df %>%
    mutate(color_group = ifelse(outcome == "Total (A3)", "Total", "Animal"))

  df <- exp_params_95ci(df, col = "effect_type", slope_id = "Slope", unit = "year")

  p <- ggplot(df, aes(x = mean, y = outcome, color = color_group, text = paste0(
    "Outcome: ", outcome, "<br>",
    "Effect: ", effect_type, "<br>",
    "Rate Ratio: ", signif(mean, 3), "<br>",
    "95% CI: [", signif(q2.5, 3), ", ", signif(q97.5, 3), "]",
    ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), ""),
    "<br>Source: ", source))) +
    geom_vline(xintercept = 1, linetype = "dashed", color = "gray50") +
    geom_errorbarh(aes(xmin = q2.5, xmax = q97.5), height = 0.2) +
    geom_point(size = 2.5) +
    scale_color_manual(values = c("Total" = "steelblue", "Animal" = "firebrick"),
                       guide = "none") +
    scale_x_continuous(limits = c(0, NA), breaks = scales::pretty_breaks()) +
    facet_wrap(~ effect_type, ncol = 2) +
    labs(
      title = "A4: Interrupted Time Series Targeted Animal Product Categories Analysis",
      subtitle = "Level and slope changes for targeted category MPBA introductions (Rate Ratios)",
      x = "Rate Ratio (exp(mu_gamma))",
      y = "Outcome") +
    scale_y_discrete(labels = function(x) format_label(x)) +
    theme_minimal(base_size = 11) +
    theme(
      panel.grid.minor = element_blank(),
      strip.background = element_rect(fill = "gray90", color = NA),
      strip.text = element_text(face = "bold"),
      plot.title = element_text(face = "bold", size = 14),
      axis.text.y = element_text(size = 10))

  ggsave(file.path(OUTPUT_DIR, "A4_its_targeted_forest.png"), p,
         width = 9, height = 4, dpi = 300)
  ggsave(file.path(OUTPUT_DIR, "A4_its_targeted_forest.pdf"), p,
         width = 9, height = 4)

  p_plotly <- ggplotly(p, tooltip = "text")
  saveWidget(p_plotly, file.path(OUTPUT_DIR, "A4_its_targeted_forest.html"),
             selfcontained = TRUE)

  write_csv(df, file.path(OUTPUT_DIR, "A4_its_targeted_mu_gamma.csv"))

  cat("  Saved: A4_its_targeted_forest.png, .pdf, .html, _mu_gamma.csv\n")
  return(p)
}

# ─────────────────────────────────────
# Execute
# ─────────────────────────────────────

cat("========================================\n")
cat("Forest Plot Generation - finalized_redone3\n")
cat("========================================\n")
cat("Model path:", DEFAULT_MODEL_PATH, "\n")
cat("A2 overrides:", if(length(A2_OVERRIDES) == 0) "NONE" else paste(names(A2_OVERRIDES), "->", A2_OVERRIDES, collapse = ", "), "\n")
cat("A4 overrides:", if(length(A4_OVERRIDES) == 0) "NONE" else paste(names(A4_OVERRIDES), "->", A4_OVERRIDES, collapse = ", "), "\n")
cat("Output directory:", OUTPUT_DIR, "\n\n")

p1 <- create_proportion_forest()
p2 <- create_proportion_targeted_forest()
p3 <- create_its_forest()
p4 <- create_its_targeted_forest()

cat("\n========================================\n")
cat("All forest plots generated!\n")
cat("Output directory:", OUTPUT_DIR, "\n")
cat("========================================\n")

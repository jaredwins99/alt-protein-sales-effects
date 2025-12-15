# Forest Plot Generation Script
# Creates horizontal forest plots for 4 analyses: proportion, proportion_targeted, its, its_targeted

library(tidyverse)
library(ggplot2)
library(patchwork)
library(htmlwidgets)
library(plotly)


source("model_scripts/view_params_funcs.R")

output_dir <- file.path("forest_plots")
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
    ess_bulk = row$ess_bulk
  )
}

format_label <- function(name) {
  name %>%
    str_replace_all("_", " ") %>%
    str_to_title()}

# ─────────────────────────────────────
# 1. PROPORTION Analysis (A1)
# 6 outcomes x 6 exposures (3 exposure groups x 2 types: count/prop)
# ─────────────────────────────────────

create_proportion_forest <- function() {
  cat("Creating proportion forest plot...\n")
  
  outcomes <- c("chicken_fish", "meat", "nonvegan", "total", "vegan", "vegetarian")
  exposure_groups <- c("mpbamod", "vegan", "vegetarian")
  exposure_types <- c("count", "prop")

  data_list <- list()
  
  for (outcome in outcomes) {
    for (exp_group in exposure_groups) {
      for (exp_type in exposure_types) {
        exposure <- paste0(exp_group, "_dishes_", exp_type)
        summ_path <- file.path("model_fits/finalized/proportion", 
                               outcome, exposure, "summ.rds")
        
        gamma <- extract_mu_gamma(summ_path, 1)
        if (!is.null(gamma)) {
          data_list[[length(data_list) + 1]] <- tibble(
            outcome = outcome,
            exposure_group = exp_group,
            exposure_type = exp_type,
            mean = gamma$mean,
            q5 = gamma$q5,
            q95 = gamma$q95,
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

  # Exponentiate parameters (no slopes in proportion analysis - only mu_gamma[1])
  # Simple exp() transformation for level change parameters
  df <- df %>%
    mutate(across(c(mean, q5, q95), ~ exp(.x)))

  # Create plot with facets for exposure type (columns) and exposure group (rows with separators)
  p <- ggplot(df, aes(x = mean, y = outcome, text = paste0(
    "Outcome: ", outcome, "<br>",
    "Exposure: ", exposure_group, " (", exposure_type, ")<br>",
    "Rate Ratio: ", signif(mean, 3), "<br>",
    "90% CI: [", signif(q5, 3), ", ", signif(q95, 3), "]",
    ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), "")))) +
    geom_vline(xintercept = 1, linetype = "dashed", color = "gray50") +
    geom_errorbarh(aes(xmin = q5, xmax = q95), height = 0.2, color = "steelblue") +
    geom_point(size = 2.5, color = "steelblue") +
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
  ggsave(file.path(output_dir, "A1_proportion_forest.png"), p, 
         width = 10, height = 10, dpi = 300)
  ggsave(file.path(output_dir, "A1_proportion_forest.pdf"), p, 
         width = 10, height = 10)

  # Save interactive HTML with rhat in hover
  p_plotly <- ggplotly(p, tooltip = "text")
  saveWidget(p_plotly, file.path(output_dir, "A1_proportion_forest.html"), 
             selfcontained = TRUE)

  # Save extracted data
  write_csv(df, file.path(output_dir, "A1_proportion_mu_gamma.csv"))

  cat("  Saved: A1_proportion_forest.png, .pdf, .html, _mu_gamma.csv\n")
  return(p)
}

# ─────────────────────────────────────
# 2. PROPORTION_TARGETED Analysis (A2)
# 5 outcomes x 2 types (count/presence)
# ─────────────────────────────────────

create_proportion_targeted_forest <- function() {
  cat("Creating proportion_targeted forest plot...\n")
  
  outcomes <- c("breakfast_p", "chicken_p", "dairy_p", "egg_p", "untextured_p")
  outcome_labels <- c("Breakfast", "Chicken", "Dairy", "Egg", "Untextured")
  exposure_types <- c("count", "presence")
  
  # Collect data
  data_list <- list()
  
  for (i in seq_along(outcomes)) {
    outcome <- outcomes[i]
    outcome_label <- outcome_labels[i]
    
    for (exp_type in exposure_types) {
      # Derive the dish name from outcome (remove _p suffix)
      dish_base <- str_replace(outcome, "_p$", "")
      exposure <- paste0(dish_base, "_dishes_", exp_type)
      summ_path <- file.path("model_fits/finalized/proportion_targeted", 
                             outcome, exposure, "summ.rds")
      
      gamma <- extract_mu_gamma(summ_path, 1)
      if (!is.null(gamma)) {
        data_list[[length(data_list) + 1]] <- tibble(
          outcome = outcome_label,
          exposure_type = exp_type,
          mean = gamma$mean,
          q5 = gamma$q5,
          q95 = gamma$q95,
          rhat = gamma$rhat)}}}
  
  df <- bind_rows(data_list)
  
  if (nrow(df) == 0) {
    cat("  No data found for proportion_targeted analysis\n")
    return(NULL)}
  
  # Order factors
  df$outcome <- factor(df$outcome, levels = rev(outcome_labels))
  df$exposure_type <- factor(df$exposure_type, levels = c("presence", "count"),
                              labels = c("Presence", "Count"))

  # Exponentiate parameters (no slopes in proportion analysis - only mu_gamma[1])
  # Simple exp() transformation for level change parameters
  df <- df %>%
    mutate(across(c(mean, q5, q95), ~ exp(.x)))

  # Create plot
  p <- ggplot(df, aes(x = mean, y = outcome, text = paste0(
    "Outcome: ", outcome, "<br>",
    "Exposure: ", exposure_type, "<br>",
    "Rate Ratio: ", signif(mean, 3), "<br>",
    "90% CI: [", signif(q5, 3), ", ", signif(q95, 3), "]",
    ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), "")
  ))) +
    geom_vline(xintercept = 1, linetype = "dashed", color = "gray50") +
    geom_errorbarh(aes(xmin = q5, xmax = q95), height = 0.2, color = "darkgreen") +
    geom_point(size = 2.5, color = "darkgreen") +
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
  ggsave(file.path(output_dir, "A2_proportion_targeted_forest.png"), p, 
         width = 9, height = 5, dpi = 300)
  ggsave(file.path(output_dir, "A2_proportion_targeted_forest.pdf"), p, 
         width = 9, height = 5)

  # Save interactive HTML with rhat in hover
  p_plotly <- ggplotly(p, tooltip = "text")
  saveWidget(p_plotly, file.path(output_dir, "A2_proportion_targeted_forest.html"), 
             selfcontained = TRUE)

  # Save extracted data
  write_csv(df, file.path(output_dir, "A2_proportion_targeted_mu_gamma.csv"))

  cat("  Saved: A2_proportion_targeted_forest.png, .pdf, .html, _mu_gamma.csv\n")
  return(p)
}

# ─────────────────────────────────────
# 3. ITS Analysis (A3)
# 6 outcomes x 2 mu_gammas (level change, slope)
# ─────────────────────────────────────

create_its_forest <- function() {
  cat("Creating ITS forest plot...\n")
  
  outcomes <- c("chicken_fish", "meat", "nonvegan", "total", "vegan", "vegetarian")
  
  # Collect data for both mu_gamma[1] (level) and mu_gamma[2] (slope)
  data_list <- list()
  
  for (outcome in outcomes) {
    summ_path <- file.path("model_fits/finalized/its", outcome, "summ.rds")
    
    # Level change (mu_gamma[1])
    gamma1 <- extract_mu_gamma(summ_path, 1)
    if (!is.null(gamma1)) {
      data_list[[length(data_list) + 1]] <- tibble(
        outcome = outcome,
        effect_type = "Level Change",
        mean = gamma1$mean,
        q5 = gamma1$q5,
        q95 = gamma1$q95,
        rhat = gamma1$rhat,
        ess_bulk = gamma1$ess_bulk)}
    
    # Slope change (mu_gamma[2])
    gamma2 <- extract_mu_gamma(summ_path, 2)
    if (!is.null(gamma2)) {
      data_list[[length(data_list) + 1]] <- tibble(
        outcome = outcome,
        effect_type = "Slope Change",
        mean = gamma2$mean,
        q5 = gamma2$q5,
        q95 = gamma2$q95,
        rhat = gamma2$rhat,
        ess_bulk = gamma2$ess_bulk)}}
  
  df <- bind_rows(data_list)
  
  if (nrow(df) == 0) {
    cat("  No data found for ITS analysis\n")
    return(NULL)}
  
  # Order factors
  df$outcome <- factor(df$outcome, levels = rev(outcomes))
  df$effect_type <- factor(df$effect_type, levels = c("Level Change", "Slope Change"))

  # Exponentiate parameters with proper slope handling
  # For ITS: mu_gamma[1] = level change (exp directly), mu_gamma[2] = slope (exp with annualization)
  df <- exp_params(df, col = "effect_type", slope_id = "Slope", unit = "year")

  # Create plot
  p <- ggplot(df, aes(x = mean, y = outcome, text = paste0(
    "Outcome: ", outcome, "<br>",
    "Effect: ", effect_type, "<br>",
    "Rate Ratio: ", signif(mean, 3), "<br>",
    "90% CI: [", signif(q5, 3), ", ", signif(q95, 3), "]",
    ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), "")
  ))) +
    geom_vline(xintercept = 1, linetype = "dashed", color = "gray50") +
    geom_errorbarh(aes(xmin = q5, xmax = q95), height = 0.2, color = "darkorange") +
    geom_point(size = 2.5, color = "darkorange") +
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

  # Save
  ggsave(file.path(output_dir, "A3_its_forest.png"), p, 
         width = 9, height = 5, dpi = 300)
  ggsave(file.path(output_dir, "A3_its_forest.pdf"), p, 
         width = 9, height = 5)

  # Save interactive HTML with rhat in hover
  p_plotly <- ggplotly(p, tooltip = "text")
  saveWidget(p_plotly, file.path(output_dir, "A3_its_forest.html"), 
             selfcontained = TRUE)

  # Save extracted data
  write_csv(df, file.path(output_dir, "A3_its_mu_gamma.csv"))

  cat("  Saved: A3_its_forest.png, .pdf, .html, _mu_gamma.csv\n")
  return(p)
}

# ─────────────────────────────────────
# 4. ITS_TARGETED Analysis (A4)
# 3 outcomes x 2 mu_gammas (level change, slope)
# ─────────────────────────────────────

create_its_targeted_forest <- function() {
  cat("Creating ITS targeted forest plot...\n")
  
  outcomes <- c("breakfast", "textured", "untextured")
  
  # Collect data for both mu_gamma[1] (level) and mu_gamma[2] (slope)
  data_list <- list()
  
  for (outcome in outcomes) {
    summ_path <- file.path("model_fits/finalized/its_targeted", outcome, "summ.rds")
    
    # Level change (mu_gamma[1])
    gamma1 <- extract_mu_gamma(summ_path, 1)
    if (!is.null(gamma1)) {
      data_list[[length(data_list) + 1]] <- tibble(
        outcome = outcome,
        effect_type = "Level Change",
        mean = gamma1$mean,
        q5 = gamma1$q5,
        q95 = gamma1$q95,
        rhat = gamma1$rhat,
        ess_bulk = gamma1$ess_bulk)}
    
    # Slope change (mu_gamma[2])
    gamma2 <- extract_mu_gamma(summ_path, 2)
    if (!is.null(gamma2)) {
      data_list[[length(data_list) + 1]] <- tibble(
        outcome = outcome,
        effect_type = "Slope Change",
        mean = gamma2$mean,
        q5 = gamma2$q5,
        q95 = gamma2$q95,
        rhat = gamma2$rhat,
        ess_bulk = gamma2$ess_bulk)}}
  
  df <- bind_rows(data_list)
  
  if (nrow(df) == 0) {
    cat("  No data found for ITS targeted analysis\n")
    return(NULL)}
  
  # Order factors
  df$outcome <- factor(df$outcome, levels = rev(outcomes))
  df$effect_type <- factor(df$effect_type, levels = c("Level Change", "Slope Change"))

  # Exponentiate parameters with proper slope handling
  # For ITS: mu_gamma[1] = level change (exp directly), mu_gamma[2] = slope (exp with annualization)
  df <- exp_params(df, col = "effect_type", slope_id = "Slope", unit = "year")

  # Create plot
  p <- ggplot(df, aes(x = mean, y = outcome, text = paste0(
    "Outcome: ", outcome, "<br>",
    "Effect: ", effect_type, "<br>",
    "Rate Ratio: ", signif(mean, 3), "<br>",
    "90% CI: [", signif(q5, 3), ", ", signif(q95, 3), "]",
    ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), "")
  ))) +
    geom_vline(xintercept = 1, linetype = "dashed", color = "gray50") +
    geom_errorbarh(aes(xmin = q5, xmax = q95), height = 0.2, color = "purple") +
    geom_point(size = 2.5, color = "purple") +
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

  # Save
  ggsave(file.path(output_dir, "A4_its_targeted_forest.png"), p, 
         width = 9, height = 4, dpi = 300)
  ggsave(file.path(output_dir, "A4_its_targeted_forest.pdf"), p, 
         width = 9, height = 4)

  # Save interactive HTML with rhat in hover
  p_plotly <- ggplotly(p, tooltip = "text")
  saveWidget(p_plotly, file.path(output_dir, "A4_its_targeted_forest.html"), 
             selfcontained = TRUE)

  # Save extracted data
  write_csv(df, file.path(output_dir, "A4_its_targeted_mu_gamma.csv"))

  cat("  Saved: A4_its_targeted_forest.png, .pdf, .html, _mu_gamma.csv\n")
  return(p)
}

# ─────────────────────────────────────
# Execute
# ─────────────────────────────────────

cat("========================================\n")
cat("Forest Plot Generation\n")
cat("========================================\n\n")

p1 <- create_proportion_forest()
p2 <- create_proportion_targeted_forest()
p3 <- create_its_forest()
p4 <- create_its_targeted_forest()

cat("\n========================================\n")
cat("All forest plots generated!\n")
cat("Output directory:", output_dir, "\n")
cat("========================================\n")

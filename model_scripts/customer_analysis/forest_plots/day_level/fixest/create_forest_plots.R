# Forest plots for day-level customer conditional Poisson analyses (A5, A6)
# Reads exposure results CSVs and creates static forest plots
# Same format as transaction-level but with different color to distinguish

library(tidyverse)
library(ggplot2)

OUTPUT_DIR <- "customer_analysis/forest_plots/day_level/fixest"
dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)

format_label <- function(name) {
  name %>%
    str_replace_all("_", " ") %>%
    str_to_title()
}

load_exposure_data <- function(files) {
  all <- bind_rows(lapply(files, read_csv, show_col_types = FALSE))

  all <- all %>%
    filter(grepl("^exposure_", term)) %>%
    mutate(
      effect_type = case_when(
        grepl(":date_code", term) ~ "Slope Change",
        grepl(":gender", term) ~ "Gender Interaction",
        TRUE ~ "Level Change"
      ),
      exposure_period = str_extract(term, "_(\\d+)($|:)") %>% str_extract("\\d+")
    )

  all
}

to_rate_ratios <- function(df) {
  df %>%
    mutate(
      rr = case_when(
        effect_type == "Level Change" ~ exp(estimate),
        effect_type == "Slope Change" ~ exp(estimate * 365),
        TRUE ~ exp(estimate)
      ),
      rr_lower = case_when(
        effect_type == "Level Change" ~ exp(ci_lower),
        effect_type == "Slope Change" ~ exp(ci_lower * 365),
        TRUE ~ exp(ci_lower)
      ),
      rr_upper = case_when(
        effect_type == "Level Change" ~ exp(ci_upper),
        effect_type == "Slope Change" ~ exp(ci_upper * 365),
        TRUE ~ exp(ci_upper)
      ),
      log_rr = case_when(
        effect_type == "Level Change" ~ estimate,
        effect_type == "Slope Change" ~ estimate * 365,
        TRUE ~ estimate
      ),
      log_rr_lower = case_when(
        effect_type == "Level Change" ~ ci_lower,
        effect_type == "Slope Change" ~ ci_lower * 365,
        TRUE ~ ci_lower
      ),
      log_rr_upper = case_when(
        effect_type == "Level Change" ~ ci_upper,
        effect_type == "Slope Change" ~ ci_upper * 365,
        TRUE ~ ci_upper
      ),
      sig = p_value < 0.05
    )
}

clip_data <- function(df, xlim, val_col = "rr", lo_col = "rr_lower", hi_col = "rr_upper") {
  df %>%
    mutate(
      clipped = .data[[val_col]] < xlim[1] | .data[[val_col]] > xlim[2],
      val_disp = pmin(pmax(.data[[val_col]], xlim[1]), xlim[2]),
      lo_disp = pmax(.data[[lo_col]], xlim[1]),
      hi_disp = pmin(.data[[hi_col]], xlim[2])
    )
}

forest_theme <- function() {
  theme_minimal(base_size = 11) +
    theme(
      plot.background = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA),
      panel.grid.minor = element_blank(),
      strip.background = element_rect(fill = "gray90", color = NA),
      strip.text = element_text(face = "bold"),
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 9, color = "gray40"),
      axis.text.y = element_text(size = 10))
}

build_forest <- function(df, title, subtitle, color, outcome_levels, filename,
                         width = 10, height = 8) {

  df <- df %>% filter(effect_type != "Gender Interaction")
  df$effect_type <- factor(df$effect_type, levels = c("Level Change", "Slope Change"))
  df$outcome_name <- factor(df$outcome_name, levels = rev(outcome_levels))

  df <- df %>%
    mutate(
      rest_label = paste0(location_id, ifelse(!is.na(exposure_period) & exposure_period != "1",
                                               paste0(" (exp ", exposure_period, ")"), ""))
    )

  df <- df %>%
    group_by(outcome_name, effect_type) %>%
    mutate(
      row_in_group = row_number(),
      y_numeric = as.numeric(outcome_name) - 0.12 * (row_in_group - 1)
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
      breaks = seq_along(outcome_levels),
      labels = format_label(rev(outcome_levels)),
      expand = expansion(mult = c(0.15, 0.05))) +
    labs(
      title = title,
      subtitle = subtitle,
      x = "Rate Ratio",
      y = "Outcome") +
    forest_theme()

  ggsave(file.path(OUTPUT_DIR, paste0(filename, ".png")), p,
         width = width, height = height, dpi = 300, bg = "white")

  cat("  Saved:", file.path(OUTPUT_DIR, paste0(filename, ".png")), "\n")
  invisible(p)
}

build_forest_log <- function(df, title, subtitle, color, outcome_levels, filename,
                             width = 10, height = 8) {

  df <- df %>% filter(effect_type != "Gender Interaction")
  df$effect_type <- factor(df$effect_type, levels = c("Level Change", "Slope Change"))
  df$outcome_name <- factor(df$outcome_name, levels = rev(outcome_levels))

  df <- df %>%
    mutate(
      rest_label = paste0(location_id, ifelse(!is.na(exposure_period) & exposure_period != "1",
                                               paste0(" (exp ", exposure_period, ")"), ""))
    )

  df <- df %>%
    group_by(outcome_name, effect_type) %>%
    mutate(
      row_in_group = row_number(),
      y_numeric = as.numeric(outcome_name) - 0.12 * (row_in_group - 1)
    ) %>%
    ungroup()

  xlim <- c(-25, 25)
  df <- clip_data(df, xlim, "log_rr", "log_rr_lower", "log_rr_upper")

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
      breaks = seq_along(outcome_levels),
      labels = format_label(rev(outcome_levels)),
      expand = expansion(mult = c(0.15, 0.05))) +
    labs(
      title = title,
      subtitle = paste0(subtitle, " (log scale)"),
      x = "Log Rate Ratio",
      y = "Outcome") +
    forest_theme()

  ggsave(file.path(OUTPUT_DIR, paste0(filename, "_log.png")), p,
         width = width, height = height, dpi = 300, bg = "white")

  cat("  Saved:", file.path(OUTPUT_DIR, paste0(filename, "_log.png")), "\n")
  invisible(p)
}

# ─────────────────────────────────────
#  A5: Day-level customer analysis (6 outcomes)
# ─────────────────────────────────────

create_A5_forest <- function() {
  cat("Creating A5 day-level customer analysis forest plots...\n")

  files <- list.files("customer_analysis/level_day/fixest/results_exposures", pattern = "^A5_", full.names = TRUE)
  if (length(files) == 0) {
    cat("  No A5 results found. Skipping.\n")
    return(invisible(NULL))}

  df <- load_exposure_data(files) %>% to_rate_ratios()

  a5_outcomes <- unique(df$outcome_name)
  a5_outcomes_ordered <- intersect(c("total", "nonvegan", "meat", "chicken_fish", "vegan", "vegetarian"), a5_outcomes)

  if (nrow(df) == 0) {
    cat("  No exposure data found. Skipping.\n")
    return(invisible(NULL))}

  build_forest(
    df,
    title = "A5: Day-Level Customer Conditional Poisson Analysis",
    subtitle = "Rate ratios per restaurant | Level = immediate shift | Slope = annual trend change | Triangles = clipped",
    color = "forestgreen",
    outcome_levels = a5_outcomes_ordered,
    filename = "A5_day_level_customer_forest",
    width = 10, height = 8)

  build_forest_log(
    df,
    title = "A5: Day-Level Customer Conditional Poisson Analysis",
    subtitle = "Per restaurant | Level = immediate shift | Slope = annual trend change | Triangles = clipped",
    color = "forestgreen",
    outcome_levels = a5_outcomes_ordered,
    filename = "A5_day_level_customer_forest",
    width = 10, height = 8)
}

# ─────────────────────────────────────
#  A6: Day-level targeted analysis
# ─────────────────────────────────────

create_A6_forest <- function() {
  cat("Creating A6 day-level customer targeted analysis forest plots...\n")

  files <- list.files("customer_analysis/level_day/fixest/results_exposures", pattern = "^A6_", full.names = TRUE)
  if (length(files) == 0) {
    cat("  No A6 results found. Skipping.\n")
    return(invisible(NULL))}

  df <- load_exposure_data(files) %>% to_rate_ratios()

  a6_outcomes <- c("breakfast", "untextured")
  df <- df %>% filter(outcome_name %in% a6_outcomes)

  if (nrow(df) == 0) {
    cat("  No exposure data found. Skipping.\n")
    return(invisible(NULL))}

  build_forest(
    df,
    title = "A6: Day-Level Customer Targeted Categories Analysis",
    subtitle = "Rate ratios per restaurant | Level = immediate shift | Slope = annual trend change | Triangles = clipped",
    color = "darkorange",
    outcome_levels = a6_outcomes,
    filename = "A6_day_level_customer_targeted_forest",
    width = 10, height = 5)

  build_forest_log(
    df,
    title = "A6: Day-Level Customer Targeted Categories Analysis",
    subtitle = "Per restaurant | Level = immediate shift | Slope = annual trend change | Triangles = clipped",
    color = "darkorange",
    outcome_levels = a6_outcomes,
    filename = "A6_day_level_customer_targeted_forest",
    width = 10, height = 5)
}

# ─────────────────────────────────────
#  Execute
# ─────────────────────────────────────

cat("========================================\n")
cat("Day-Level Customer Analysis Forest Plots\n")
cat("========================================\n\n")

create_A5_forest()
create_A6_forest()

cat("\n========================================\n")
cat("Done!\n")
cat("  Output:", OUTPUT_DIR, "\n")
cat("========================================\n")

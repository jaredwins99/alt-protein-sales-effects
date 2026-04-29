# Forest plots for top-25% customer conditional Poisson analyses (A5)
# Reads exposure results CSVs from results_exposures_top25/ and creates
# forest plots on both rate-ratio and log scales.
# Distinguishes from full-sample plots with "darkorchid" colour.

library(tidyverse)
library(ggplot2)

OUTPUT_DIR     <- "customer_analysis/forest_plots/transaction_level/fixest_top_customers"
OUTPUT_DIR_LOG <- "customer_analysis/forest_plots/transaction_level/fixest_top_customers"
dir.create(OUTPUT_DIR,     showWarnings = FALSE, recursive = TRUE)
dir.create(OUTPUT_DIR_LOG, showWarnings = FALSE, recursive = TRUE)

format_label <- function(name) {
  name %>%
    str_replace_all("_", " ") %>%
    str_to_title()
}

# ─────────────────────────────────────
#  Load and prepare exposure data
# ─────────────────────────────────────

load_exposure_data <- function(files) {
  all <- bind_rows(lapply(files, read_csv, show_col_types = FALSE))

  all <- all %>%
    filter(grepl("^exposure_", term)) %>%
    mutate(
      effect_type = case_when(
        grepl(":date_code", term) ~ "Slope Change",
        grepl(":gender", term)    ~ "Gender Interaction",
        TRUE                      ~ "Level Change"
      ),
      exposure_period = str_extract(term, "_(\\d+)($|:)") %>% str_extract("\\d+")
    )

  all
}

# ─────────────────────────────────────
#  Convert to rate ratios
# ─────────────────────────────────────

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

# ─────────────────────────────────────
#  Clipping helpers
# ─────────────────────────────────────

clip_data <- function(df, xlim, val_col = "rr", lo_col = "rr_lower", hi_col = "rr_upper") {
  df %>%
    mutate(
      clipped  = .data[[val_col]] < xlim[1] | .data[[val_col]] > xlim[2],
      val_disp = pmin(pmax(.data[[val_col]], xlim[1]), xlim[2]),
      lo_disp  = pmax(.data[[lo_col]], xlim[1]),
      hi_disp  = pmin(.data[[hi_col]], xlim[2])
    )
}

# ─────────────────────────────────────
#  Common theme
# ─────────────────────────────────────

forest_theme <- function() {
  theme_minimal(base_size = 11) +
    theme(
      plot.background   = element_rect(fill = "white", color = NA),
      panel.background  = element_rect(fill = "white", color = NA),
      panel.grid.minor  = element_blank(),
      strip.background  = element_rect(fill = "gray90", color = NA),
      strip.text        = element_text(face = "bold"),
      plot.title         = element_text(face = "bold", size = 14),
      plot.subtitle      = element_text(size = 9, color = "gray40"),
      axis.text.y        = element_text(size = 10))
}

# ─────────────────────────────────────
#  Build forest plot (rate ratio scale)
# ─────────────────────────────────────

build_forest <- function(df, title, subtitle, color, outcome_levels, filename,
                         width = 10, height = 8) {

  df <- df %>% filter(effect_type != "Gender Interaction")
  df$effect_type   <- factor(df$effect_type, levels = c("Level Change", "Slope Change"))
  df$outcome_name  <- factor(df$outcome_name, levels = rev(outcome_levels))

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

  xlim <- c(0, 4)
  df   <- clip_data(df, xlim, "rr", "rr_lower", "rr_upper")

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
      title    = title,
      subtitle = subtitle,
      x = "Rate Ratio",
      y = "Outcome") +
    forest_theme()

  ggsave(file.path(OUTPUT_DIR, paste0(filename, ".png")), p,
         width = width, height = height, dpi = 300, bg = "white")

  cat("  Saved:", file.path(OUTPUT_DIR, paste0(filename, ".png")), "\n")
  invisible(p)
}

# ─────────────────────────────────────
#  Build forest plot (log scale)
# ─────────────────────────────────────

build_forest_log <- function(df, title, subtitle, color, outcome_levels, filename,
                             width = 10, height = 8) {

  df <- df %>% filter(effect_type != "Gender Interaction")
  df$effect_type   <- factor(df$effect_type, levels = c("Level Change", "Slope Change"))
  df$outcome_name  <- factor(df$outcome_name, levels = rev(outcome_levels))

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
  df   <- clip_data(df, xlim, "log_rr", "log_rr_lower", "log_rr_upper")

  plaus_bound <- log(10)  # ~2.3

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
      title    = title,
      subtitle = paste0(subtitle, " (log scale)"),
      x = "Log Rate Ratio",
      y = "Outcome") +
    forest_theme()

  ggsave(file.path(OUTPUT_DIR_LOG, paste0(filename, "_log.png")), p,
         width = width, height = height, dpi = 300, bg = "white")

  cat("  Saved:", file.path(OUTPUT_DIR_LOG, paste0(filename, "_log.png")), "\n")
  invisible(p)
}

# ─────────────────────────────────────
#  A5 Top 25% forest plots
# ─────────────────────────────────────

create_A5_top_forest <- function() {
  cat("Creating A5 Top 25% customer forest plots...\n")

  files <- list.files(
    "customer_analysis/transaction_level/fixest/results_exposures_top25",
    pattern = "^A5_", full.names = TRUE)

  if (length(files) == 0) {
    cat("  No A5 result files found in results_exposures_top25/\n")
    return(invisible(NULL))
  }

  df <- load_exposure_data(files) %>% to_rate_ratios()

  a5_outcomes <- c("nonvegan", "meat", "chicken_fish", "vegan", "vegetarian", "total")
  df <- df %>% filter(outcome_name %in% a5_outcomes)

  # Drop outcomes that have no data (in case some didn't converge)
  a5_outcomes <- a5_outcomes[a5_outcomes %in% unique(df$outcome_name)]

  if (nrow(df) == 0) {
    cat("  No exposure data after filtering, skipping.\n")
    return(invisible(NULL))
  }

  build_forest(
    df,
    title    = "A5: Top 25% Customers - Conditional Poisson (fixest)",
    subtitle = "Rate ratios per restaurant | Level = immediate shift | Slope = annual trend change | Triangles = clipped",
    color    = "darkorchid",
    outcome_levels = a5_outcomes,
    filename = "A5_top25_customer_forest",
    width = 10, height = 8)

  build_forest_log(
    df,
    title    = "A5: Top 25% Customers - Conditional Poisson (fixest)",
    subtitle = "Per restaurant | Level = immediate shift | Slope = annual trend change | Triangles = clipped",
    color    = "darkorchid",
    outcome_levels = a5_outcomes,
    filename = "A5_top25_customer_forest",
    width = 10, height = 8)
}

# ─────────────────────────────────────
#  Execute
# ─────────────────────────────────────

cat("========================================\n")
cat("Top 25% Customer Forest Plots\n")
cat("========================================\n\n")

create_A5_top_forest()

cat("\n========================================\n")
cat("Done!\n")
cat("  Rate ratio:", OUTPUT_DIR, "\n")
cat("  Log scale: ", OUTPUT_DIR_LOG, "\n")
cat("========================================\n")

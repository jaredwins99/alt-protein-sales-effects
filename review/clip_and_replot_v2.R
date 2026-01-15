# Clip Data and Regenerate Overlap Plots - V2
# Handles ONLY tier1 proportion (A1) and proportion_targeted (A2)
#
# Usage: Rscript review/clip_and_replot_v2.R

library(arrow)
library(ggplot2)
library(dplyr)
library(patchwork)

# ─────────────────────────────────────────────────────────────
# Define Tier 1 Restaurants
# ─────────────────────────────────────────────────────────────

tier1_proportion <- c("SRQS8F7JWA9MZ", "2HRX9P6HKXA8V", "JHDN7CF1C03X5",
                      "L69HYJ4Y3TR91", "ED5J990H5VAZT", "W8T41JZK0ZMEP")

# ─────────────────────────────────────────────────────────────
# Define Clipping Dates for Proportion (A1) - Tier 1 Only
# ─────────────────────────────────────────────────────────────

# Default clips for proportion (A1)
# Dates are set to day BEFORE first non-zero mpbamod_dishes_count (filter uses >)
clip_dates_proportion <- list(
  "2HRX9P6HKXA8V" = list(start = "2018-12-31", end = NULL),  # Outcome ramps from 0, then jumps 2019-01-01
  "ED5J990H5VAZT" = list(start = "2016-04-20", end = NULL),  # Outcome starts 2016-04-21
  "JHDN7CF1C03X5" = list(start = "2019-01-04", end = NULL),  # Exposure never 0, no clip needed but harmless
  "L69HYJ4Y3TR91" = list(start = "2022-08-29", end = NULL),  # Outcome starts 2022-08-30 with real data
  "SRQS8F7JWA9MZ" = list(start = "2019-04-29", end = NULL),  # Outcome starts meaningful 2019-04-30
  "W8T41JZK0ZMEP" = list(start = "2020-02-12", end = NULL)   # Data starts 2020-02-13 with real values
)

# Outcome-specific overrides for proportion (A1) - none needed with precise dates
clip_dates_proportion_outcome <- list()

# ─────────────────────────────────────────────────────────────
# Define Clipping Dates for Proportion Targeted (A2) - Tier 1 Only
# ─────────────────────────────────────────────────────────────

# Clips for proportion_targeted (A2) - using same precise dates as proportion
# Note: these are day BEFORE first non-zero exposure (filter uses >)
clip_dates_proportion_targeted <- list(
  "breakfast_p" = list(
    "2HRX9P6HKXA8V" = list(start = "2018-12-31", end = NULL),
    "ED5J990H5VAZT" = list(start = "2016-12-23", end = NULL),  # Outcome starts 2016-12-24
    "L69HYJ4Y3TR91" = list(start = "2022-09-07", end = NULL)   # Outcome starts 2022-09-08
  ),
  "chicken_p" = list(
    "JHDN7CF1C03X5" = list(start = "2019-01-04", end = NULL),
    "W8T41JZK0ZMEP" = list(start = "2020-02-12", end = NULL)
  ),
  "dairy_p" = list(
    "ED5J990H5VAZT" = list(start = "2016-03-22", end = NULL),  # Outcome starts 2016-03-23
    "JHDN7CF1C03X5" = list(start = "2019-01-04", end = NULL),
    "W8T41JZK0ZMEP" = list(start = "2020-02-12", end = NULL)
  ),
  "egg_p" = list(
    "ED5J990H5VAZT" = list(start = "2016-03-22", end = NULL),  # Outcome starts 2016-03-23
    "W8T41JZK0ZMEP" = list(start = "2020-02-12", end = NULL)
  ),
  "textured_p" = list(
    "W8T41JZK0ZMEP" = list(start = "2020-02-12", end = NULL)
  ),
  "untextured_p" = list(
    "SRQS8F7JWA9MZ" = list(start = "2019-04-29", end = NULL)   # Outcome starts meaningful 2019-04-30
  )
)

# ─────────────────────────────────────────────────────────────
# Functions to Get Clip Dates
# ─────────────────────────────────────────────────────────────

# Get clip dates for proportion (A1)
get_clip_dates_proportion <- function(restaurant, exposure_type = NULL) {
  # Check for exposure-type-specific override first
  if (!is.null(exposure_type) && exposure_type %in% names(clip_dates_proportion_outcome)) {
    if (restaurant %in% names(clip_dates_proportion_outcome[[exposure_type]])) {
      return(clip_dates_proportion_outcome[[exposure_type]][[restaurant]])
    }
  }
  # Fall back to default proportion clips
  if (restaurant %in% names(clip_dates_proportion)) {
    return(clip_dates_proportion[[restaurant]])
  }
  return(list(start = NULL, end = NULL))
}

# Get clip dates for proportion_targeted (A2)
get_clip_dates_proportion_targeted <- function(restaurant, category) {
  if (category %in% names(clip_dates_proportion_targeted)) {
    if (restaurant %in% names(clip_dates_proportion_targeted[[category]])) {
      return(clip_dates_proportion_targeted[[category]][[restaurant]])
    }
  }
  return(list(start = NULL, end = NULL))
}

# ─────────────────────────────────────────────────────────────
# Apply Clipping Function
# ─────────────────────────────────────────────────────────────

clip_restaurant_data <- function(rest_df, clips) {
  if (!is.null(clips$start)) {
    rest_df <- rest_df %>% filter(date > as.Date(clips$start))
  }
  if (!is.null(clips$end)) {
    rest_df <- rest_df %>% filter(date < as.Date(clips$end))
  }
  return(rest_df)
}

# ─────────────────────────────────────────────────────────────
# Generate Overlap Plot Function
# ─────────────────────────────────────────────────────────────

generate_plot <- function(rest_df, rest_id, analysis, category, outcome_col, exp_col, output_dir) {

  if (nrow(rest_df) == 0) return(NULL)
  if (!outcome_col %in% names(rest_df)) return(NULL)
  if (all(is.na(rest_df[[outcome_col]]))) return(NULL)

  # Scale outcome to match exposure range for visibility
  outcome_vals <- rest_df[[outcome_col]]
  exposure_vals <- rest_df[[exp_col]]
  outcome_max <- max(outcome_vals, na.rm = TRUE)
  exposure_max <- max(exposure_vals, na.rm = TRUE)
  if (outcome_max == 0) outcome_max <- 1
  if (exposure_max == 0) exposure_max <- 1
  outcome_scaled <- (outcome_vals / outcome_max) * exposure_max

  plot_df <- rest_df %>%
    mutate(
      exposure = .data[[exp_col]],
      outcome = .data[[outcome_col]],
      outcome_scaled = outcome_scaled
    )

  # Left panel - time series
  p1 <- ggplot(plot_df, aes(x = date)) +
    geom_line(aes(y = exposure, color = "Exposure")) +
    geom_line(aes(y = outcome_scaled, color = "Outcome (scaled)")) +
    scale_color_manual(values = c("Exposure" = "blue", "Outcome (scaled)" = "red")) +
    labs(
      title = paste0(rest_id, " - ", category, " - ", gsub("_", " ", analysis)),
      x = "Date",
      y = "Value"
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")

  # Right panel - boxplot
  p2 <- ggplot(plot_df, aes(x = factor(exposure), y = outcome)) +
    geom_boxplot(fill = "lightblue") +
    labs(x = "Exposure Level", y = "Outcome") +
    theme_minimal()

  combined <- p1 + p2 + plot_layout(widths = c(2, 1))

  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
  ggsave(file.path(output_dir, paste0(rest_id, ".png")), combined, width = 12, height = 5, dpi = 150)

  return(TRUE)
}

# ─────────────────────────────────────────────────────────────
# A1 - Proportion Outcomes and Exposures
# ─────────────────────────────────────────────────────────────

proportion_outcomes <- list(
  meat = "meat_outcome",
  vegan = "vegan_outcome",
  vegetarian = "vegetarian_outcome",
  nonvegan = "nonvegan_outcome",
  total = "total_outcome",
  chicken_fish = "chicken_fish_outcome"
)

proportion_exposures <- c(
  "mpbamod_dishes_count", "mpbamod_dishes_prop",
  "vegan_dishes_count", "vegan_dishes_prop",
  "vegetarian_dishes_count", "vegetarian_dishes_prop"
)

# ─────────────────────────────────────────────────────────────
# A2 - Proportion Targeted Configuration
# ─────────────────────────────────────────────────────────────

proportion_targeted_config <- list(
  breakfast_p = list(
    outcome = "breakfast_outcome",
    exposures = c("breakfast_dishes_count", "breakfast_dishes_presence")
  ),
  chicken_p = list(
    outcome = "chicken_outcome_p",
    exposures = c("chicken_dishes_count", "chicken_dishes_presence")
  ),
  dairy_p = list(
    outcome = "dairy_outcome_p",
    exposures = c("dairy_dishes_count", "dairy_dishes_presence")
  ),
  egg_p = list(
    outcome = "egg_outcome_p",
    exposures = c("egg_dishes_count", "egg_dishes_presence")
  ),
  textured_p = list(
    outcome = "textured_outcome",
    exposures = c("textured_dishes_count", "textured_dishes_presence")
  ),
  untextured_p = list(
    outcome = "untextured_outcome",
    exposures = c("untextured_dishes_count", "untextured_dishes_presence")
  )
)

# ─────────────────────────────────────────────────────────────
# Main: Process Proportion Data (A1) - Tier 1 Only
# ─────────────────────────────────────────────────────────────

cat("\n=== A1 - Proportion (Tier 1 Only) ===\n")
for (exp_type in proportion_exposures) {
  cat(paste0("Loading: ", exp_type, "\n"))

  data_file <- paste0("data/4_data_parquet_modeling/proportion/finalized_", exp_type, ".parquet")
  if (!file.exists(data_file)) {
    cat(paste0("  File not found: ", data_file, "\n"))
    next
  }

  df_prop <- read_parquet(data_file)

  for (cat_name in names(proportion_outcomes)) {
    outcome_col <- proportion_outcomes[[cat_name]]

    for (rest in tier1_proportion) {
      rest_df <- df_prop %>% filter(location_id == rest) %>% arrange(date)

      if (nrow(rest_df) == 0) next
      if (!exp_type %in% names(rest_df)) next

      # Get clips for this restaurant and exposure type
      clips <- get_clip_dates_proportion(rest, exp_type)
      rest_df <- clip_restaurant_data(rest_df, clips)

      if (nrow(rest_df) == 0) next

      output_dir <- file.path("review/overlap_plots_clipped/proportion", cat_name, exp_type, "tier1")

      result <- generate_plot(rest_df, rest, "proportion", cat_name, outcome_col, exp_type, output_dir)
    }
  }
}

# ─────────────────────────────────────────────────────────────
# Main: Process Proportion Targeted Data (A2) - Tier 1 Only
# ─────────────────────────────────────────────────────────────

cat("\n=== A2 - Proportion Targeted (Tier 1 Only) ===\n")
for (cat_name in names(proportion_targeted_config)) {
  config <- proportion_targeted_config[[cat_name]]
  outcome_col <- config$outcome

  for (exp_type in config$exposures) {
    cat(paste0("Processing: ", cat_name, " / ", exp_type, "\n"))

    data_file <- paste0("data/4_data_parquet_modeling/proportion_targeted/finalized_", exp_type, ".parquet")
    if (!file.exists(data_file)) {
      cat(paste0("  File not found: ", data_file, "\n"))
      next
    }

    df_prop_t <- read_parquet(data_file)

    for (rest in tier1_proportion) {
      rest_df <- df_prop_t %>% filter(location_id == rest) %>% arrange(date)

      if (nrow(rest_df) == 0) next
      if (!exp_type %in% names(rest_df)) next

      # Get clips for this restaurant and category
      clips <- get_clip_dates_proportion_targeted(rest, cat_name)
      rest_df <- clip_restaurant_data(rest_df, clips)

      if (nrow(rest_df) == 0) next

      output_dir <- file.path("review/overlap_plots_clipped/proportion_targeted", cat_name, exp_type, "tier1")

      result <- generate_plot(rest_df, rest, "proportion_targeted", cat_name, outcome_col, exp_type, output_dir)
    }
  }
}

cat("\nDone! Clipped plots saved to review/overlap_plots_clipped/\n")

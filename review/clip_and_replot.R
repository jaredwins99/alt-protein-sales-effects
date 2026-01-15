# Clip Data and Regenerate Overlap Plots
# Creates overlap_plots_clipped/ folder with clipped data plots
#
# Usage: Rscript review/clip_and_replot.R

library(arrow)
library(ggplot2)
library(dplyr)
library(patchwork)

# ─────────────────────────────────────────────────────────────
# Define Clipping Dates for All Restaurants
# ─────────────────────────────────────────────────────────────

# Format: list(start = "YYYY-MM-DD", end = "YYYY-MM-DD")
# NULL means no clip on that end

# Default clips (apply to all outcomes unless overridden)
clip_dates_default <- list(
  # Tier 1
  "VLZX7K2M9QD4T" = list(start = "2021-10-01", end = NULL),
  "SRQS8F7JWA9MZ" = list(start = "2020-06-01", end = NULL),
  "2HRX9P6HKXA8V" = list(start = "2019-01-01", end = "2023-08-01"),
  "JHDN7CF1C03X5" = list(start = "2019-04-01", end = "2023-06-01"),
  "L69HYJ4Y3TR91" = list(start = NULL, end = NULL),  # OK
  "ED5J990H5VAZT" = list(start = "2021-06-01", end = NULL),
  "W8T41JZK0ZMEP" = list(start = NULL, end = NULL),  # OK

  # Tier 2
  "EMBVNVD207CC6" = list(start = "2016-06-01", end = "2022-09-01"),
  "C0BE4NDSW26QN" = list(start = NULL, end = NULL),
  "75WYSXR9QBK5M" = list(start = "2022-05-01", end = "2023-07-01"),
  "V3Q26BHF3SE2H" = list(start = NULL, end = NULL),
  "LBZEEFSBJNB3Z" = list(start = "2021-09-01", end = "2023-07-01"),
  "SAFK7ND1HR6XS" = list(start = "2019-04-18", end = "2020-03-25"),
  "CB2KHY1C2G9PT" = list(start = "2020-06-01", end = "2023-04-01"),
  "S8MT0YGD2KTN9" = list(start = NULL, end = NULL),
  "LFZFT3VASXPED" = list(start = "2021-10-01", end = "2022-11-01"),
  "1SQPTEGYPH0GA" = list(start = NULL, end = NULL),
  "9XKJD8DQTH559" = list(start = NULL, end = NULL),
  "LQ5EH4BKGV61T" = list(start = NULL, end = NULL),
  "78AY09MVJVTYE" = list(start = NULL, end = NULL)
)

# Outcome-specific overrides: clip_dates_outcome[[outcome]][[restaurant]]
clip_dates_outcome <- list(
  # 2HRX egg needs earlier end clip
  "egg" = list(
    "2HRX9P6HKXA8V" = list(start = "2019-01-01", end = "2021-06-01")
  )
)

# Function to get clip dates for a specific restaurant and outcome
get_clip_dates <- function(restaurant, outcome = NULL) {
  # Check for outcome-specific override first
  if (!is.null(outcome) && outcome %in% names(clip_dates_outcome)) {
    if (restaurant %in% names(clip_dates_outcome[[outcome]])) {
      return(clip_dates_outcome[[outcome]][[restaurant]])
    }
  }
  # Fall back to default
  if (restaurant %in% names(clip_dates_default)) {
    return(clip_dates_default[[restaurant]])
  }
  return(list(start = NULL, end = NULL))
}

tier1 <- c("VLZX7K2M9QD4T", "SRQS8F7JWA9MZ", "2HRX9P6HKXA8V", "JHDN7CF1C03X5",
           "L69HYJ4Y3TR91", "ED5J990H5VAZT", "W8T41JZK0ZMEP")

# ─────────────────────────────────────────────────────────────
# Apply Clipping Function (per-restaurant, outcome-aware)
# ─────────────────────────────────────────────────────────────

clip_restaurant_data <- function(rest_df, restaurant, outcome = NULL) {
  clips <- get_clip_dates(restaurant, outcome)
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
# Main: Process ITS Data (A3, A4)
# ─────────────────────────────────────────────────────────────

cat("Loading ITS data...\n")
df_its <- read_parquet("data/4_data_parquet_modeling/its/finalized.parquet")
cat("Total rows:", nrow(df_its), "\n")

restaurants <- unique(df_its$location_id)

# A3 - ITS outcomes
its_outcomes <- list(
  meat = "meat_outcome",
  vegan = "vegan_outcome",
  vegetarian = "vegetarian_outcome",
  nonvegan = "nonvegan_outcome",
  total = "total_outcome",
  chicken_fish = "chicken_fish_outcome"
)

cat("\n=== A3 - ITS ===\n")
for (cat_name in names(its_outcomes)) {
  cat(paste0("Processing: ", cat_name, "\n"))
  outcome_col <- its_outcomes[[cat_name]]

  for (rest in restaurants) {
    rest_df <- df_its %>% filter(location_id == rest) %>% arrange(date)

    # Apply outcome-specific clipping
    rest_df <- clip_restaurant_data(rest_df, rest, cat_name)

    # Find exposure column
    exp_cols <- names(rest_df)[grepl(paste0("^exposure_", rest), names(rest_df))]
    if (length(exp_cols) == 0) next
    exp_col <- exp_cols[1]

    tier <- if (rest %in% tier1) "tier1" else "tier2"
    output_dir <- file.path("review/overlap_plots_clipped/its", cat_name, tier)

    result <- generate_plot(rest_df, rest, "its", cat_name, outcome_col, exp_col, output_dir)
  }
}

# A4 - ITS Targeted outcomes
its_targeted_outcomes <- list(
  breakfast = "breakfast_outcome",
  dairy = "dairy_outcome_p",
  chicken = "chicken_outcome_p",
  egg = "egg_outcome_p",
  textured = "textured_outcome",
  untextured = "untextured_outcome"
)

cat("\n=== A4 - ITS Targeted ===\n")
for (cat_name in names(its_targeted_outcomes)) {
  cat(paste0("Processing: ", cat_name, "\n"))
  outcome_col <- its_targeted_outcomes[[cat_name]]

  for (rest in restaurants) {
    rest_df <- df_its %>% filter(location_id == rest) %>% arrange(date)

    # Apply outcome-specific clipping
    rest_df <- clip_restaurant_data(rest_df, rest, cat_name)

    exp_cols <- names(rest_df)[grepl(paste0("^exposure_", rest), names(rest_df))]
    if (length(exp_cols) == 0) next
    exp_col <- exp_cols[1]

    tier <- if (rest %in% tier1) "tier1" else "tier2"
    output_dir <- file.path("review/overlap_plots_clipped/its_targeted", cat_name, tier)

    result <- generate_plot(rest_df, rest, "its_targeted", cat_name, outcome_col, exp_col, output_dir)
  }
}

# ─────────────────────────────────────────────────────────────
# Main: Process Proportion Data (A1)
# ─────────────────────────────────────────────────────────────

# tier1 for proportion (no VLZX7K2M9QD4T - only in ITS data)
tier1_proportion <- c("SRQS8F7JWA9MZ", "2HRX9P6HKXA8V", "JHDN7CF1C03X5",
                      "L69HYJ4Y3TR91", "ED5J990H5VAZT", "W8T41JZK0ZMEP")

# A1 - Proportion outcomes
proportion_outcomes <- list(
  meat = "meat_outcome",
  vegan = "vegan_outcome",
  vegetarian = "vegetarian_outcome",
  nonvegan = "nonvegan_outcome",
  total = "total_outcome",
  chicken_fish = "chicken_fish_outcome"
)

# A1 - Proportion exposure types
proportion_exposures <- c(
  "mpbamod_dishes_count", "mpbamod_dishes_prop",
  "vegan_dishes_count", "vegan_dishes_prop",
  "vegetarian_dishes_count", "vegetarian_dishes_prop"
)

cat("\n=== A1 - Proportion ===\n")
for (exp_type in proportion_exposures) {
  cat(paste0("Loading: ", exp_type, "\n"))

  data_file <- paste0("data/4_data_parquet_modeling/proportion/finalized_", exp_type, ".parquet")
  if (!file.exists(data_file)) {
    cat(paste0("  File not found: ", data_file, "\n"))
    next
  }

  df_prop <- read_parquet(data_file)
  restaurants_prop <- unique(df_prop$location_id)

  for (cat_name in names(proportion_outcomes)) {
    outcome_col <- proportion_outcomes[[cat_name]]

    for (rest in restaurants_prop) {
      rest_df <- df_prop %>% filter(location_id == rest) %>% arrange(date)

      # Apply clipping (using cat_name for outcome-specific overrides)
      rest_df <- clip_restaurant_data(rest_df, rest, cat_name)

      if (nrow(rest_df) == 0) next
      if (!exp_type %in% names(rest_df)) next

      tier <- if (rest %in% tier1_proportion) "tier1" else "tier2"
      output_dir <- file.path("review/overlap_plots_clipped/proportion", cat_name, exp_type, tier)

      result <- generate_plot(rest_df, rest, "proportion", cat_name, outcome_col, exp_type, output_dir)
    }
  }
}

# ─────────────────────────────────────────────────────────────
# Main: Process Proportion Targeted Data (A2)
# ─────────────────────────────────────────────────────────────

# A2 - Proportion Targeted: category -> (outcome, exposure types)
proportion_targeted_config <- list(
  breakfast = list(
    outcome = "breakfast_outcome",
    exposures = c("breakfast_dishes_count", "breakfast_dishes_presence")
  ),
  chicken = list(
    outcome = "chicken_outcome_p",
    exposures = c("chicken_dishes_count", "chicken_dishes_presence")
  ),
  dairy = list(
    outcome = "dairy_outcome_p",
    exposures = c("dairy_dishes_count", "dairy_dishes_presence")
  ),
  egg = list(
    outcome = "egg_outcome_p",
    exposures = c("egg_dishes_count", "egg_dishes_presence")
  ),
  textured = list(
    outcome = "textured_outcome",
    exposures = c("textured_dishes_count", "textured_dishes_presence")
  ),
  untextured = list(
    outcome = "untextured_outcome",
    exposures = c("untextured_dishes_count", "untextured_dishes_presence")
  )
)

cat("\n=== A2 - Proportion Targeted ===\n")
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
    restaurants_prop_t <- unique(df_prop_t$location_id)

    for (rest in restaurants_prop_t) {
      rest_df <- df_prop_t %>% filter(location_id == rest) %>% arrange(date)

      # Apply clipping (using cat_name for outcome-specific overrides like egg/2HRX)
      rest_df <- clip_restaurant_data(rest_df, rest, cat_name)

      if (nrow(rest_df) == 0) next
      if (!exp_type %in% names(rest_df)) next

      tier <- if (rest %in% tier1_proportion) "tier1" else "tier2"
      output_dir <- file.path("review/overlap_plots_clipped/proportion_targeted", paste0(cat_name, "_p"), exp_type, tier)

      result <- generate_plot(rest_df, rest, "proportion_targeted", cat_name, outcome_col, exp_type, output_dir)
    }
  }
}

cat("\nDone! Clipped plots saved to review/overlap_plots_clipped/\n")

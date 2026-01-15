# Generate Overlap Plots
# Usage: Rscript review/generate_overlap_plots.R <analysis> <category> [restaurant]
#
# Arguments:
#   analysis   - One of: proportion, proportion_targeted, its, its_targeted
#   category   - The outcome category (e.g., meat, vegan, breakfast, dairy, chicken, egg)
#   restaurant - (Optional) Specific restaurant ID, or "all" for all restaurants (default: all)
#
# Examples:
#   Rscript review/generate_overlap_plots.R its_targeted dairy
#   Rscript review/generate_overlap_plots.R its_targeted chicken 2HRX9P6HKXA8V
#   Rscript review/generate_overlap_plots.R proportion meat all

library(arrow)
library(ggplot2)
library(dplyr)
library(patchwork)

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 2) {
  stop("Usage: Rscript generate_overlap_plots.R <analysis> <category> [restaurant]\n",
       "  analysis: proportion, proportion_targeted, its, its_targeted\n",
       "  category: meat, vegan, vegetarian, breakfast, dairy, chicken, egg, textured, untextured, etc.\n",
       "  restaurant: specific ID or 'all' (default: all)")
}

analysis <- args[1]
category <- args[2]
restaurant_filter <- if (length(args) >= 3) args[3] else "all"

# Define data paths and outcome columns based on analysis type
get_config <- function(analysis, category) {
  config <- list()

  if (analysis == "proportion") {
    config$data_file <- paste0("data/4_data_parquet_modeling/proportion/finalized_", category, ".parquet")
    config$exposure_col <- category
    # Map category to outcome
    outcome_map <- list(
      mpbamod_dishes_prop = "meat_outcome",
      vegan_dishes_prop = "vegan_outcome",
      vegetarian_dishes_prop = "vegetarian_outcome"
    )
    config$outcome_col <- outcome_map[[category]]

  } else if (analysis == "proportion_targeted") {
    config$data_file <- paste0("data/4_data_parquet_modeling/proportion_targeted/finalized_", category, "_dishes_presence.parquet")
    config$exposure_col <- paste0(category, "_dishes_presence")
    config$outcome_col <- paste0(category, "_outcome_p")

  } else if (analysis == "its") {
    config$data_file <- "data/4_data_parquet_modeling/its/finalized.parquet"
    config$exposure_col <- "exposure"  # Will be per-restaurant
    # Map category to outcome for ITS
    outcome_map <- list(
      meat = "meat_outcome",
      vegan = "vegan_outcome",
      vegetarian = "vegetarian_outcome",
      nonvegan = "nonvegan_outcome",
      total = "total_outcome",
      chicken_fish = "chicken_fish_outcome"
    )
    config$outcome_col <- outcome_map[[category]]

  } else if (analysis == "its_targeted") {
    config$data_file <- "data/4_data_parquet_modeling/its/finalized.parquet"
    config$exposure_col <- "exposure"  # Will be per-restaurant
    # Map category to outcome for ITS targeted
    outcome_map <- list(
      breakfast = "breakfast_outcome",
      textured = "textured_outcome",
      untextured = "untextured_outcome",
      dairy = "dairy_outcome_p",
      chicken = "chicken_outcome_p",
      egg = "egg_outcome_p"
    )
    config$outcome_col <- outcome_map[[category]]

  } else {
    stop("Unknown analysis type: ", analysis)
  }

  return(config)
}

# Generate plot for a single restaurant
generate_plot <- function(rest_df, rest_id, analysis, category, outcome_col, output_dir) {

  if (nrow(rest_df) == 0) return(NULL)

  # Find exposure column
  if (analysis %in% c("its", "its_targeted")) {
    exp_cols <- names(rest_df)[grepl(paste0("^exposure_", rest_id), names(rest_df))]
    if (length(exp_cols) == 0) return(NULL)
    exp_col <- exp_cols[1]
  } else {
    exp_col <- config$exposure_col
  }

  if (!outcome_col %in% names(rest_df)) {
    warning("Outcome column ", outcome_col, " not found for ", rest_id)
    return(NULL)
  }
  if (all(is.na(rest_df[[outcome_col]]))) return(NULL)

  # Scale outcome to 0-1 for overlay
  outcome_vals <- rest_df[[outcome_col]]
  outcome_range <- max(outcome_vals, na.rm = TRUE) - min(outcome_vals, na.rm = TRUE)
  if (outcome_range == 0) outcome_range <- 1
  outcome_scaled <- (outcome_vals - min(outcome_vals, na.rm = TRUE)) / (outcome_range + 0.001)

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
  ggsave(file.path(output_dir, paste0(rest_id, ".png")), combined, width = 12, height = 5)

  return(TRUE)
}

# Main execution
config <- get_config(analysis, category)

cat("Analysis:", analysis, "\n")
cat("Category:", category, "\n")
cat("Data file:", config$data_file, "\n")
cat("Outcome column:", config$outcome_col, "\n")

# Read data
df <- read_parquet(config$data_file)

# Get restaurants
if (restaurant_filter == "all") {
  restaurants <- unique(df$location_id)
} else {
  restaurants <- restaurant_filter
}

cat("Restaurants:", length(restaurants), "\n\n")

# Output directory
output_dir <- file.path("review/overlap_plots", analysis, category)

# Generate plots
for (rest in restaurants) {
  rest_df <- df %>% filter(location_id == rest)
  result <- generate_plot(rest_df, rest, analysis, category, config$outcome_col, output_dir)
  if (!is.null(result)) {
    cat("Created:", rest, "\n")
  }
}

cat("\nDone! Plots saved to:", output_dir, "\n")

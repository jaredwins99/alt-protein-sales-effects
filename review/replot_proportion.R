#!/usr/bin/env Rscript
# Replot Proportion (A1) with correct scaling

library(arrow)
library(ggplot2)
library(dplyr)
library(patchwork)

generate_plot <- function(rest_df, rest_id, analysis, category, outcome_col, exp_col, output_dir) {
  if (nrow(rest_df) == 0) return(NULL)
  if (!outcome_col %in% names(rest_df)) return(NULL)
  if (all(is.na(rest_df[[outcome_col]]))) return(NULL)

  outcome_vals <- rest_df[[outcome_col]]
  exposure_vals <- rest_df[[exp_col]]
  outcome_max <- max(outcome_vals, na.rm = TRUE)
  exposure_max <- max(exposure_vals, na.rm = TRUE)
  if (outcome_max == 0) outcome_max <- 1
  if (exposure_max == 0) exposure_max <- 1
  outcome_scaled <- (outcome_vals / outcome_max) * exposure_max

  plot_df <- rest_df %>%
    mutate(exposure = .data[[exp_col]], outcome = .data[[outcome_col]], outcome_scaled = outcome_scaled)

  p1 <- ggplot(plot_df, aes(x = date)) +
    geom_line(aes(y = exposure, color = "Exposure")) +
    geom_line(aes(y = outcome_scaled, color = "Outcome (scaled)")) +
    scale_color_manual(values = c("Exposure" = "blue", "Outcome (scaled)" = "red")) +
    labs(title = paste0(rest_id, " - ", category, " - ", exp_col), x = "Date", y = "Value") +
    theme_minimal() + theme(legend.position = "bottom")

  p2 <- ggplot(plot_df, aes(x = factor(exposure), y = outcome)) +
    geom_boxplot(fill = "lightblue") +
    labs(x = "Exposure Level", y = "Outcome") +
    theme_minimal()

  combined <- p1 + p2 + plot_layout(widths = c(2, 1))
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
  ggsave(file.path(output_dir, paste0(rest_id, ".png")), combined, width = 12, height = 5, dpi = 150)
  return(TRUE)
}

tier1_proportion <- c("SRQS8F7JWA9MZ", "2HRX9P6HKXA8V", "JHDN7CF1C03X5", "L69HYJ4Y3TR91", "ED5J990H5VAZT", "W8T41JZK0ZMEP")

proportion_outcomes <- list(meat = "meat_outcome", vegan = "vegan_outcome", vegetarian = "vegetarian_outcome",
                            nonvegan = "nonvegan_outcome", total = "total_outcome", chicken_fish = "chicken_fish_outcome")
proportion_exposures <- c("mpbamod_dishes_count", "mpbamod_dishes_prop", "vegan_dishes_count", "vegan_dishes_prop",
                          "vegetarian_dishes_count", "vegetarian_dishes_prop")

for (exp_type in proportion_exposures) {
  cat(paste0("Loading: ", exp_type, "\n"))
  data_file <- paste0("data/4_data_parquet_modeling/proportion/finalized_", exp_type, ".parquet")
  if (!file.exists(data_file)) next
  df_prop <- read_parquet(data_file)
  restaurants_prop <- unique(df_prop$location_id)

  for (cat_name in names(proportion_outcomes)) {
    outcome_col <- proportion_outcomes[[cat_name]]
    for (rest in restaurants_prop) {
      rest_df <- df_prop %>% filter(location_id == rest) %>% arrange(date)
      if (nrow(rest_df) == 0 || !exp_type %in% names(rest_df)) next
      tier <- if (rest %in% tier1_proportion) "tier1" else "tier2"
      output_dir <- file.path("review/overlap_plots_clipped/proportion", cat_name, exp_type, tier)
      generate_plot(rest_df, rest, "proportion", cat_name, outcome_col, exp_type, output_dir)
    }
  }
}
cat("Proportion done!\n")

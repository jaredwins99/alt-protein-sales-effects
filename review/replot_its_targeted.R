#!/usr/bin/env Rscript
# Replot ITS Targeted (A4) with correct scaling

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
    labs(title = paste0(rest_id, " - ", category, " - ", gsub("_", " ", analysis)), x = "Date", y = "Value") +
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

tier1 <- c("VLZX7K2M9QD4T", "SRQS8F7JWA9MZ", "2HRX9P6HKXA8V", "JHDN7CF1C03X5", "L69HYJ4Y3TR91", "ED5J990H5VAZT", "W8T41JZK0ZMEP")

cat("Loading ITS data...\n")
df_its <- read_parquet("data/4_data_parquet_modeling/its/finalized.parquet")
restaurants <- unique(df_its$location_id)

its_targeted_outcomes <- list(breakfast = "breakfast_outcome", dairy = "dairy_outcome_p", chicken = "chicken_outcome_p",
                               egg = "egg_outcome_p", textured = "textured_outcome", untextured = "untextured_outcome")

for (cat_name in names(its_targeted_outcomes)) {
  cat(paste0("Processing ITS Targeted: ", cat_name, "\n"))
  outcome_col <- its_targeted_outcomes[[cat_name]]
  for (rest in restaurants) {
    rest_df <- df_its %>% filter(location_id == rest) %>% arrange(date)
    exp_cols <- names(rest_df)[grepl(paste0("^exposure_", rest), names(rest_df))]
    if (length(exp_cols) == 0) next
    exp_col <- exp_cols[1]
    tier <- if (rest %in% tier1) "tier1" else "tier2"
    output_dir <- file.path("review/overlap_plots_clipped/its_targeted", cat_name, tier)
    generate_plot(rest_df, rest, "its_targeted", cat_name, outcome_col, exp_col, output_dir)
  }
}
cat("ITS Targeted done!\n")

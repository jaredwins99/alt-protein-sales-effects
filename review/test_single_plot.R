#!/usr/bin/env Rscript
# Test W8 - chicken_fish - mpbamod_dishes_count with matched styling

library(arrow)
library(ggplot2)
library(dplyr)
library(patchwork)

df <- read_parquet("data/4_data_parquet_modeling/proportion/finalized_mpbamod_dishes_count.parquet")

rest_id <- "W8T41JZK0ZMEP"
outcome_col <- "chicken_fish_outcome"
exp_col <- "mpbamod_dishes_count"

rest_df <- df %>% filter(location_id == rest_id) %>% arrange(date)

outcome_max <- max(rest_df[[outcome_col]], na.rm = TRUE)
exposure_max <- max(rest_df[[exp_col]], na.rm = TRUE)
if (outcome_max == 0) outcome_max <- 1
if (exposure_max == 0) exposure_max <- 1
outcome_scaled <- (rest_df[[outcome_col]] / outcome_max) * exposure_max

plot_df <- rest_df %>%
  mutate(exposure = .data[[exp_col]], outcome = .data[[outcome_col]], outcome_scaled = outcome_scaled)

p1 <- ggplot(plot_df, aes(x = date)) +
  geom_line(aes(y = exposure, color = "Exposure")) +
  geom_line(aes(y = outcome_scaled, color = "Outcome (scaled)")) +
  scale_color_manual(values = c("Exposure" = "blue", "Outcome (scaled)" = "red")) +
  labs(title = paste0(rest_id, " - chicken_fish - mpbamod_dishes_count"), x = "Date", y = "Value") +
  theme_minimal() +
  theme(legend.position = "bottom")

p2 <- ggplot(plot_df, aes(x = factor(exposure), y = outcome)) +
  geom_boxplot(fill = "lightblue") +
  labs(x = "Exposure Level", y = "Outcome") +
  theme_minimal()

combined <- p1 + p2 + plot_layout(widths = c(2, 1))

ggsave("review/overlap_plots_clipped/proportion/chicken_fish/mpbamod_dishes_count/tier1/W8T41JZK0ZMEP.png",
       combined, width = 12, height = 5, dpi = 150)

cat("Done! Check the output.\n")

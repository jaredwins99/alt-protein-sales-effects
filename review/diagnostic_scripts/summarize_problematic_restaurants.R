library(tidyverse)

# Read the restaurant-specific problematic file
prob <- read_csv("data_diagnostics/restaurant_specific_problematic.csv", show_col_types = FALSE)

cat("========================================\n")
cat("RESTAURANTS TO CONSIDER REMOVING\n")
cat("========================================\n\n")

# Group by restaurant and count issues
restaurant_summary <- prob %>%
  group_by(restaurant_id) %>%
  summarise(
    n_problematic_cases = n(),
    n_complete_separation = sum(complete_separation),
    n_quasi_separation = sum(quasi_separation),
    n_very_sparse = sum(very_sparse),
    analyses = paste(unique(analysis), collapse = ", "),
    .groups = "drop"
  ) %>%
  arrange(desc(n_complete_separation), desc(n_problematic_cases))

cat("Summary by restaurant:\n\n")
print(as.data.frame(restaurant_summary), row.names = FALSE)

cat("\n\n========================================\n")
cat("RECOMMENDATION\n")
cat("========================================\n\n")

cat("Restaurants with complete separation issues:\n")
sep_restaurants <- restaurant_summary %>%
  filter(n_complete_separation > 0) %>%
  pull(restaurant_id)

for (rest in sep_restaurants) {
  rest_data <- prob %>% filter(restaurant_id == rest, complete_separation == TRUE)
  cat("\n", rest, ":\n", sep = "")
  cat("  - Complete separation in", nrow(rest_data), "cases\n")
  cat("  - Analyses:", paste(unique(rest_data$analysis), collapse = ", "), "\n")
  cat("  - Exposures:", paste(unique(rest_data$exposure), collapse = ", "), "\n")
}

cat("\n\n========================================\n")
cat("DETAILED BREAKDOWN\n")
cat("========================================\n\n")

# Show all problematic cases grouped by restaurant
for (rest in sep_restaurants) {
  rest_data <- prob %>%
    filter(restaurant_id == rest) %>%
    select(analysis, outcome, exposure, n_obs, distinct_values,
           prop_outcome_zero_when_exp_zero, complete_separation, warning)

  cat("\n", rest, " (", nrow(rest_data), " problematic cases):\n", sep = "")
  print(as.data.frame(rest_data), row.names = FALSE)
}

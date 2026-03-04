library(tidyverse)

# Read the high cardinality results
high_card <- read_csv("exposure_distinct_values_high_cardinality.csv", show_col_types = FALSE)

# Summary by exposure column
cat("=== Summary by Exposure Column ===\n")
exposure_summary <- high_card %>%
  group_by(exposure_column) %>%
  summarise(
    max_distinct = max(distinct_values),
    min_distinct = min(distinct_values),
    n_occurrences = n(),
    .groups = "drop"
  ) %>%
  arrange(desc(max_distinct))

print(exposure_summary, n = Inf)

# Summary by analysis
cat("\n\n=== Summary by Analysis Type ===\n")
analysis_summary <- high_card %>%
  group_by(analysis) %>%
  summarise(
    n_problematic = n(),
    unique_exposures = n_distinct(exposure),
    unique_columns = n_distinct(exposure_column),
    .groups = "drop"
  )

print(analysis_summary, n = Inf)

# Summary by exposure (middle level)
cat("\n\n=== Summary by Exposure (Middle Level) ===\n")
exposure_level_summary <- high_card %>%
  group_by(analysis, exposure) %>%
  summarise(
    n_columns = n_distinct(exposure_column),
    max_distinct = max(distinct_values),
    .groups = "drop"
  ) %>%
  arrange(desc(max_distinct))

print(exposure_level_summary, n = Inf)

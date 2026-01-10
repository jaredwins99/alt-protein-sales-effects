library(tidyverse)

prob <- read_csv("data_diagnostics/restaurant_specific_problematic.csv", show_col_types = FALSE)

cat("Distribution of n_outcome_nonzero_when_exp_zero for complete separation cases:\n\n")

sep_cases <- prob %>%
  filter(complete_separation == TRUE) %>%
  arrange(n_outcome_nonzero_when_exp_zero)

count_distribution <- sep_cases %>%
  group_by(n_outcome_nonzero_when_exp_zero) %>%
  summarise(n_cases = n(), .groups = "drop")

print(count_distribution)

cat("\n\nCases with exactly 3 non-zero (boundary case):\n")
boundary_cases <- sep_cases %>%
  filter(n_outcome_nonzero_when_exp_zero == 3) %>%
  select(restaurant_id, outcome, exposure, prop_outcome_zero_when_exp_zero, n_outcome_nonzero_when_exp_zero)

print(boundary_cases, n = Inf)

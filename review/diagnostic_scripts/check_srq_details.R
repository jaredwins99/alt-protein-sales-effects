library(tidyverse)

# Load restaurant-specific data
rest_data <- read_csv("data_diagnostics/restaurant_specific_all.csv", show_col_types = FALSE)

# Get SRQ vegan case
srq_vegan <- rest_data %>%
  filter(restaurant_id == "SRQS8F7JWA9MZ",
         exposure == "vegan_dishes_count")

cat("SRQ vegan_dishes_count details:\n\n")

for (i in 1:nrow(srq_vegan)) {
  row <- srq_vegan[i,]
  
  cat("Outcome:", row$outcome, "\n")
  cat("  Total observations:", row$n_obs, "\n")
  cat("  Unexposed (exposure=0):", row$n_unexposed, "\n")
  cat("  Exposed (exposure>0):", row$n_exposed, "\n")
  
  # Calculate number with outcome=0 when exposure=0
  n_outcome_zero_when_exp_zero <- round(row$n_unexposed * row$prop_outcome_zero_when_exp_zero)
  n_outcome_nonzero_when_exp_zero <- row$n_unexposed - n_outcome_zero_when_exp_zero
  
  cat("  When exposure=0:\n")
  cat("    - outcome=0:", n_outcome_zero_when_exp_zero, "\n")
  cat("    - outcome>0:", n_outcome_nonzero_when_exp_zero, "*** THIS IS KEY ***\n")
  cat("  Separation %:", round(row$prop_outcome_zero_when_exp_zero * 100, 1), "%\n")
  cat("  Mean outcome when unexposed:", round(row$mean_outcome_when_unexposed, 2), "\n")
  cat("  Mean outcome when exposed:", round(row$mean_outcome_when_exposed, 2), "\n")
  cat("\n")
}

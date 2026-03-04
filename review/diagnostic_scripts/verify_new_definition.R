library(tidyverse)

rest_data <- read_csv("data_diagnostics/restaurant_specific_all.csv", show_col_types = FALSE)

cat("=== W8 breakfast count ===\n")
w8 <- rest_data %>%
  filter(restaurant_id == "W8T41JZK0ZMEP", exposure == "breakfast_dishes_count")

cat("Separation %:", round(w8$prop_outcome_zero_when_exp_zero * 100, 1), "%\n")
cat("n_outcome_nonzero_when_exp_zero:", w8$n_outcome_nonzero_when_exp_zero, "\n")
cat("Complete separation:", w8$complete_separation, "\n")
cat("Warning:", w8$warning, "\n\n")

cat("=== SRQ vegan count (vegan outcome) ===\n")
srq <- rest_data %>%
  filter(restaurant_id == "SRQS8F7JWA9MZ", 
         exposure == "vegan_dishes_count",
         outcome == "vegan")

cat("Separation %:", round(srq$prop_outcome_zero_when_exp_zero * 100, 1), "%\n")
cat("n_outcome_nonzero_when_exp_zero:", srq$n_outcome_nonzero_when_exp_zero, "\n")
cat("Complete separation:", srq$complete_separation, "\n")
cat("Warning:", srq$warning, "\n")

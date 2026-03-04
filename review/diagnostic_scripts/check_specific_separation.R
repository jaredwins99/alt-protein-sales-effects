library(tidyverse)

prob <- read_csv("data_diagnostics/restaurant_specific_problematic.csv", show_col_types = FALSE)

cat("W8 breakfast cases:\n")
w8_breakfast <- prob %>%
  filter(restaurant_id == "W8T41JZK0ZMEP", 
         str_detect(exposure, "breakfast"))

print(w8_breakfast %>% 
  select(exposure, prop_outcome_zero_when_exp_zero, complete_separation, 
         mean_outcome_when_unexposed, mean_outcome_when_exposed, n_obs, n_unexposed, n_exposed))

cat("\n\nSRQ vegan count case:\n")
srq_vegan <- prob %>%
  filter(restaurant_id == "SRQS8F7JWA9MZ",
         exposure == "vegan_dishes_count")

print(srq_vegan %>% 
  select(analysis, outcome, exposure, prop_outcome_zero_when_exp_zero, 
         complete_separation, mean_outcome_when_unexposed, mean_outcome_when_exposed,
         n_obs, n_unexposed, n_exposed))

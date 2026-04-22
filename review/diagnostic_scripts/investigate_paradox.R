library(tidyverse)

cat("=== Investigating the W8 Breakfast Paradox ===\n\n")

data_list <- readRDS("model_fits/finalized/a2_proportion_t/breakfast_p/breakfast_dishes_count/data_list.rds")

# Get W8 column
X_train <- data_list$X_train
col_names <- colnames(X_train)
w8_col <- grep("W8T41JZK0ZMEP", col_names, value = TRUE)[1]
w8_idx <- which(col_names == w8_col)
w8_values <- X_train[, w8_idx]

y_train <- data_list$y_train

# Check if this is restaurant-specific data
cat("Total observations:", length(y_train), "\n")
cat("Number of restaurants:", data_list$R, "\n")

# Get restaurant ID mapping
idx_to_rest <- data_list$idx_to_rest_train

# Find which restaurant index W8 is
cat("\nRestaurant indices:\n")
cat("  Data has idx_to_rest_train mapping\n")

# Check which rows belong to W8
# Need to figure out which restaurant ID corresponds to W8
# Let's check if the exposure column gives us a clue

# When W8 exposure > 0, which restaurant should it be?
w8_exposed_rows <- which(w8_values > 0)
cat("\nRows where W8 exposure > 0:", length(w8_exposed_rows), "\n")
cat("  Example row indices:", paste(head(w8_exposed_rows, 10), collapse=", "), "\n")
cat("  Restaurant IDs for those rows:", paste(head(idx_to_rest[w8_exposed_rows], 10), collapse=", "), "\n")

# Check what restaurant ID has the non-zero W8 exposures
w8_restaurant_id <- unique(idx_to_rest[w8_exposed_rows])
cat("  W8 appears to be restaurant ID:", w8_restaurant_id, "\n")

# Now let's look at W8's data specifically
w8_rows <- which(idx_to_rest == w8_restaurant_id)
cat("\nW8 restaurant (ID", w8_restaurant_id, ") has", length(w8_rows), "observations\n")

# Subset to just W8's data
w8_exposure <- w8_values[w8_rows]
w8_outcome <- y_train[w8_rows]

cat("\nW8-SPECIFIC data:\n")
cat("  Exposure values:", paste(sort(unique(w8_exposure)), collapse=", "), "\n")
cat("  When W8 exposure = 0: mean outcome =", mean(w8_outcome[w8_exposure == 0]), 
    ", n =", sum(w8_exposure == 0), "\n")
cat("  When W8 exposure = 2: mean outcome =", mean(w8_outcome[w8_exposure == 2]), 
    ", n =", sum(w8_exposure == 2), "\n")
cat("  Correlation (W8 only):", cor(w8_exposure, w8_outcome), "\n")

# Simple linear regression on W8 data only
lm_w8 <- lm(w8_outcome ~ w8_exposure)
cat("\nSimple regression (W8 only): outcome ~ exposure\n")
print(summary(lm_w8)$coefficients)

# Poisson regression
pois_w8 <- glm(w8_outcome ~ w8_exposure, family = poisson())
cat("\nPoisson regression (W8 only):\n")
print(summary(pois_w8)$coefficients)
cat("  Rate ratio for exposure:", exp(coef(pois_w8)[2]), "\n")

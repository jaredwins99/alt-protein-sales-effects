library(tidyverse)

cat("=== SRQ Vegan Separation Check ===\n\n")

data_list <- readRDS("model_fits/finalized/a1_proportion/vegan/vegan_dishes_count/data_list.rds")

X_train <- data_list$X_train
col_names <- colnames(X_train)
srq_col <- grep("SRQS8F7JWA9MZ", col_names, value = TRUE)[1]
srq_idx <- which(col_names == srq_col)
srq_values <- X_train[, srq_idx]

y_train <- data_list$y_train
idx_to_rest <- data_list$idx_to_rest_train

# Find SRQ restaurant ID
srq_exposed_rows <- which(srq_values > 0)
srq_restaurant_id <- unique(idx_to_rest[srq_exposed_rows])

# Subset to SRQ's data
srq_rows <- which(idx_to_rest == srq_restaurant_id)
srq_exposure <- srq_values[srq_rows]
srq_outcome <- y_train[srq_rows]

cat("SRQ-SPECIFIC data:\n")
cat("  Total observations:", length(srq_rows), "\n")
cat("  Exposure values:", paste(sort(unique(srq_exposure)), collapse=", "), "\n")
cat("  When SRQ exposure = 0: mean outcome =", mean(srq_outcome[srq_exposure == 0]), 
    ", n =", sum(srq_exposure == 0), "\n")
cat("  When SRQ exposure = 1: mean outcome =", mean(srq_outcome[srq_exposure == 1]), 
    ", n =", sum(srq_exposure == 1), "\n")
cat("  Correlation (SRQ only):", cor(srq_exposure, srq_outcome), "\n")

# Check if there's separation
cat("\n  Outcome = 0 when exposure = 0:", sum(srq_outcome[srq_exposure == 0] == 0), 
    "out of", sum(srq_exposure == 0), "\n")
cat("  Outcome = 0 when exposure = 1:", sum(srq_outcome[srq_exposure == 1] == 0), 
    "out of", sum(srq_exposure == 1), "\n")

# Poisson regression
pois_srq <- glm(srq_outcome ~ srq_exposure, family = poisson())
cat("\nPoisson regression (SRQ only):\n")
cat("  Rate ratio for exposure:", exp(coef(pois_srq)[2]), "\n")

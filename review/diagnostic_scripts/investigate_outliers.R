library(tidyverse)

cat("=== W8 in Breakfast Count ===\n")
data_list <- readRDS("model_fits/finalized/a2_proportion_t/breakfast_p/breakfast_dishes_count/data_list.rds")
X_train <- data_list$X_train
col_names <- colnames(X_train)
w8_col <- grep("W8T41JZK0ZMEP", col_names, value = TRUE)[1]
w8_idx <- which(col_names == w8_col)
w8_values <- X_train[, w8_idx]

cat("\nW8 breakfast exposure values:\n")
cat("  Unique values:", paste(sort(unique(w8_values)), collapse=", "), "\n")
cat("  Value counts:\n")
print(table(w8_values))
cat("  Total observations:", length(w8_values), "\n")
cat("  Proportion with value > 0:", mean(w8_values > 0), "\n")

# Check outcome (y_train) pattern when exposure changes
y_train <- data_list$y_train
cat("\n  Outcome when exposure = 0: mean =", mean(y_train[w8_values == 0]), 
    ", n =", sum(w8_values == 0), "\n")
cat("  Outcome when exposure = 2: mean =", mean(y_train[w8_values == 2]), 
    ", n =", sum(w8_values == 2), "\n")
cat("  Ratio of means:", mean(y_train[w8_values == 2]) / mean(y_train[w8_values == 0]), "\n")

cat("\n\n=== SRQ (SRQS8F7JWA9MZ) in Vegan Count ===\n")
data_list <- readRDS("model_fits/finalized/a1_proportion/vegan/vegan_dishes_count/data_list.rds")
X_train <- data_list$X_train
col_names <- colnames(X_train)
srq_col <- grep("SRQS8F7JWA9MZ", col_names, value = TRUE)[1]
srq_idx <- which(col_names == srq_col)
srq_values <- X_train[, srq_idx]

cat("\nSRQ vegan exposure values:\n")
cat("  Unique values:", paste(sort(unique(srq_values)), collapse=", "), "\n")
cat("  Value counts:\n")
print(table(srq_values))
cat("  Total observations:", length(srq_values), "\n")
cat("  Proportion with value > 0:", mean(srq_values > 0), "\n")

# Check outcome pattern
y_train <- data_list$y_train
cat("\n  Outcome when exposure = 0: mean =", mean(y_train[srq_values == 0]), 
    ", n =", sum(srq_values == 0), "\n")

# Get mean for max value
max_val <- max(srq_values)
cat("  Outcome when exposure =", max_val, ": mean =", mean(y_train[srq_values == max_val]), 
    ", n =", sum(srq_values == max_val), "\n")

# Overall correlation
cat("  Correlation between exposure and outcome:", cor(srq_values, y_train), "\n")

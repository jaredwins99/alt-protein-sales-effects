library(tidyverse)

cat("=== Checking if exposures are actually standardized ===\n\n")

# W8 Breakfast Count
cat("W8 Breakfast Count:\n")
data_list <- readRDS("model_fits/finalized/a2_proportion_t/breakfast_p/breakfast_dishes_count/data_list.rds")
X_train <- data_list$X_train
col_names <- colnames(X_train)
w8_col <- grep("W8T41JZK0ZMEP", col_names, value = TRUE)[1]
w8_values <- X_train[, which(col_names == w8_col)]

cat("  First 20 values:", paste(head(w8_values, 20), collapse=", "), "\n")
cat("  All unique values:", paste(sort(unique(w8_values)), collapse=", "), "\n")
cat("  Are all values integers?", all(w8_values == floor(w8_values)), "\n")
cat("  Min:", min(w8_values), "Max:", max(w8_values), "\n")
cat("  Mean:", mean(w8_values), "SD:", sd(w8_values), "\n\n")

# SRQ Vegan Count
cat("SRQ Vegan Count:\n")
data_list <- readRDS("model_fits/finalized/a1_proportion/vegan/vegan_dishes_count/data_list.rds")
X_train <- data_list$X_train
col_names <- colnames(X_train)
srq_col <- grep("SRQS8F7JWA9MZ", col_names, value = TRUE)[1]
srq_values <- X_train[, which(col_names == srq_col)]

cat("  First 20 values:", paste(head(srq_values, 20), collapse=", "), "\n")
cat("  All unique values:", paste(sort(unique(srq_values)), collapse=", "), "\n")
cat("  Are all values integers?", all(srq_values == floor(srq_values)), "\n")
cat("  Min:", min(srq_values), "Max:", max(srq_values), "\n")
cat("  Mean:", mean(srq_values), "SD:", sd(srq_values), "\n")

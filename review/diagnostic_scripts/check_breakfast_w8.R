library(tidyverse)

# Load the breakfast presence and count data_lists
presence_file <- "model_fits/finalized/proportion_targeted/breakfast_p/breakfast_dishes_presence/data_list.rds"
count_file <- "model_fits/finalized/proportion_targeted/breakfast_p/breakfast_dishes_count/data_list.rds"

if (file.exists(presence_file)) {
  cat("=== Breakfast Presence - W8 Restaurant ===\n")
  data_list_presence <- readRDS(presence_file)
  X_train <- data_list_presence$X_train
  col_names <- colnames(X_train)
  
  # Find W8 column
  w8_col <- grep("W8T41JZK0ZMEP", col_names, value = TRUE)
  if (length(w8_col) > 0) {
    w8_idx <- which(col_names == w8_col[1])
    w8_values <- X_train[, w8_idx]
    
    cat("W8 Column:", w8_col[1], "\n")
    cat("Unique values:", paste(sort(unique(w8_values)), collapse=", "), "\n")
    cat("Min:", min(w8_values, na.rm=TRUE), "Max:", max(w8_values, na.rm=TRUE), "\n")
    cat("Mean:", mean(w8_values, na.rm=TRUE), "SD:", sd(w8_values, na.rm=TRUE), "\n")
    cat("Summary:\n")
    print(summary(w8_values))
  } else {
    cat("W8 column not found in breakfast_dishes_presence\n")
  }
}

cat("\n")

if (file.exists(count_file)) {
  cat("=== Breakfast Count - W8 Restaurant ===\n")
  data_list_count <- readRDS(count_file)
  X_train <- data_list_count$X_train
  col_names <- colnames(X_train)
  
  # Find W8 column
  w8_col <- grep("W8T41JZK0ZMEP", col_names, value = TRUE)
  if (length(w8_col) > 0) {
    w8_idx <- which(col_names == w8_col[1])
    w8_values <- X_train[, w8_idx]
    
    cat("W8 Column:", w8_col[1], "\n")
    cat("Unique values:", paste(sort(unique(w8_values)), collapse=", "), "\n")
    cat("Min:", min(w8_values, na.rm=TRUE), "Max:", max(w8_values, na.rm=TRUE), "\n")
    cat("Mean:", mean(w8_values, na.rm=TRUE), "SD:", sd(w8_values, na.rm=TRUE), "\n")
    cat("Summary:\n")
    print(summary(w8_values))
  } else {
    cat("W8 column not found in breakfast_dishes_count\n")
  }
}

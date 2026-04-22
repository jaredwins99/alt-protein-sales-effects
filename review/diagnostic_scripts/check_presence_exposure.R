library(tidyverse)

cat("========================================\n")
cat("PRESENCE EXPOSURE VALIDATION\n")
cat("Checking for restaurants with presence exposures that lack unexposed periods\n")
cat("========================================\n\n")

# Find all data_list.rds files in proportion and a2_proportion_t directories
data_list_files <- c(
  list.files("model_fits/finalized/a1_proportion", pattern = "data_list\\.rds$",
             recursive = TRUE, full.names = TRUE),
  list.files("model_fits/finalized/a2_proportion_t", pattern = "data_list\\.rds$",
             recursive = TRUE, full.names = TRUE)
)

cat("Found", length(data_list_files), "data_list.rds files\n\n")

# Initialize results list
results <- list()

# Process each data_list file
for (file_path in data_list_files) {

  # Extract analysis info from path
  path_parts <- str_split(file_path, "/")[[1]]
  analysis <- path_parts[3]
  outcome <- path_parts[4]
  exposure <- path_parts[5]

  # Only check presence exposures
  if (!grepl("presence", exposure, ignore.case = TRUE)) {
    next
  }

  # Load the data_list
  data_list <- readRDS(file_path)

  # Get data
  X_train <- data_list$X_train
  y_train <- data_list$y_train
  idx_to_rest <- data_list$idx_to_rest_train
  col_names <- colnames(X_train)

  if (is.null(col_names)) next

  # Find exposure columns
  exposure_cols <- grep("^exposure_", col_names, value = TRUE)

  # For each exposure column (each restaurant)
  for (expo_col in exposure_cols) {
    col_idx <- which(col_names == expo_col)
    col_values <- X_train[, col_idx]

    # Extract restaurant ID from column name
    restaurant_id <- str_replace(expo_col, "^exposure_", "") %>%
                     str_replace("_\\d+$", "")

    # Find which restaurant index this corresponds to
    exposed_rows <- which(col_values > 0)
    if (length(exposed_rows) == 0) {
      next
    }

    # Get the restaurant index
    restaurant_idx <- unique(idx_to_rest[exposed_rows])

    if (length(restaurant_idx) != 1) {
      next
    }

    # Get data for THIS restaurant only
    restaurant_rows <- which(idx_to_rest == restaurant_idx)

    # Restaurant-specific data
    rest_exposure <- col_values[restaurant_rows]
    rest_outcome <- y_train[restaurant_rows]

    # Check exposure values
    n_obs <- length(rest_exposure)
    n_exposed <- sum(rest_exposure > 0)
    n_unexposed <- sum(rest_exposure == 0)
    distinct_exposure <- length(unique(rest_exposure))

    # Flag if no unexposed period
    missing_unexposed <- (n_unexposed == 0)
    missing_exposed <- (n_exposed == 0)

    # Also check if exposure is truly binary
    is_binary <- (distinct_exposure == 2 && all(rest_exposure %in% c(0, 1)))
    only_one_value <- (distinct_exposure == 1)

    # Save result
    results[[length(results) + 1]] <- data.frame(
      restaurant_id = restaurant_id,
      analysis = analysis,
      outcome = outcome,
      exposure = exposure,
      n_obs = n_obs,
      n_exposed = n_exposed,
      n_unexposed = n_unexposed,
      distinct_exposure = distinct_exposure,
      is_binary = is_binary,
      missing_unexposed = missing_unexposed,
      missing_exposed = missing_exposed,
      only_one_value = only_one_value,
      exposure_values = paste(sort(unique(rest_exposure)), collapse = ", "),
      stringsAsFactors = FALSE
    )
  }
}

# Combine results
results_df <- bind_rows(results)

cat("Analyzed", nrow(results_df), "restaurant-presence combinations\n\n")

# ===== SUMMARY =====
cat("========================================\n")
cat("SUMMARY\n")
cat("========================================\n\n")

cat("Total presence analyses:", nrow(results_df), "\n")
cat("  Missing unexposed period (n_unexposed=0):", sum(results_df$missing_unexposed), "\n")
cat("  Missing exposed period (n_exposed=0):", sum(results_df$missing_exposed), "\n")
cat("  Only one exposure value:", sum(results_df$only_one_value), "\n")
cat("  Truly binary (0,1):", sum(results_df$is_binary), "\n\n")

# Show problematic cases
cat("========================================\n")
cat("PROBLEMATIC: MISSING UNEXPOSED PERIOD\n")
cat("========================================\n\n")

missing_unexposed <- results_df %>%
  filter(missing_unexposed == TRUE) %>%
  arrange(restaurant_id, analysis, outcome) %>%
  select(restaurant_id, analysis, outcome, exposure, n_obs, n_exposed, exposure_values)

if (nrow(missing_unexposed) > 0) {
  print(as.data.frame(missing_unexposed), row.names = FALSE)

  # Count by restaurant
  cat("\n\nRestaurants with missing unexposed periods:\n")
  missing_by_rest <- missing_unexposed %>%
    group_by(restaurant_id) %>%
    summarize(n_cases = n(), .groups = "drop") %>%
    arrange(desc(n_cases))
  print(as.data.frame(missing_by_rest), row.names = FALSE)
} else {
  cat("None found!\n")
}

# ===== SAVE FILES =====
cat("\n\n========================================\n")
cat("SAVING FILES\n")
cat("========================================\n\n")

# Create output directory if needed
dir.create("data_diagnostics", showWarnings = FALSE, recursive = TRUE)

# Save all results
write_csv(results_df, "data_diagnostics/presence_exposure_check.csv")
cat("✓ Saved: data_diagnostics/presence_exposure_check.csv (", nrow(results_df), "rows)\n")

# Save only missing unexposed cases
if (nrow(missing_unexposed) > 0) {
  write_csv(missing_unexposed, "data_diagnostics/presence_missing_unexposed.csv")
  cat("✓ Saved: data_diagnostics/presence_missing_unexposed.csv (", nrow(missing_unexposed), "rows)\n")
}

cat("\nDone!\n")

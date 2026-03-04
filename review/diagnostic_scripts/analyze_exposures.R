library(tidyverse)

# Find all data_list.rds files in proportion and proportion_targeted directories
data_list_files <- c(
  list.files("model_fits/finalized/proportion", pattern = "data_list\\.rds$",
             recursive = TRUE, full.names = TRUE),
  list.files("model_fits/finalized/proportion_targeted", pattern = "data_list\\.rds$",
             recursive = TRUE, full.names = TRUE)
)

cat("Found", length(data_list_files), "data_list.rds files\n\n")

# Initialize results list
results <- list()

# Process each data_list file
for (file_path in data_list_files) {

  # Extract analysis info from path
  # Path format: model_fits/finalized/{analysis}/{outcome}/{exposure}/data_list.rds
  path_parts <- str_split(file_path, "/")[[1]]
  analysis <- path_parts[3]  # proportion or proportion_targeted
  outcome <- path_parts[4]
  exposure <- path_parts[5]

  # Load the data_list
  data_list <- readRDS(file_path)

  # Get X_train matrix
  X_train <- data_list$X_train

  # Get column names (if they exist as attributes or separate element)
  # If X_train is a matrix without column names, we may need to check if column names are stored elsewhere
  col_names <- colnames(X_train)

  # If no column names, skip this file
  if (is.null(col_names)) {
    cat("Warning: No column names found for", file_path, "\n")
    next
  }

  # Find columns containing "exposure_"
  exposure_cols <- grep("^exposure_", col_names, value = TRUE)

  # For each exposure column, count distinct values and check standardization
  for (expo_col in exposure_cols) {
    col_idx <- which(col_names == expo_col)
    col_values <- X_train[, col_idx]
    distinct_count <- length(unique(col_values))

    # Check if exposure variable is a count or proportion based on the exposure name
    is_count <- grepl("count", exposure, ignore.case = TRUE)
    is_prop <- grepl("prop|presence", exposure, ignore.case = TRUE)

    # Check for incorrect standardization
    incorrectly_standardized <- FALSE
    standardization_issue <- "OK"

    if (is_count) {
      # For counts, check if any values are non-integer (decimal)
      has_decimals <- any(col_values != floor(col_values), na.rm = TRUE)
      if (has_decimals) {
        incorrectly_standardized <- TRUE
        standardization_issue <- "Has decimals (should be integers)"
      }
    } else if (is_prop) {
      # For proportions/presence, check if any values are outside [0, 1]
      has_values_outside_range <- any(col_values < 0 | col_values > 1, na.rm = TRUE)
      if (has_values_outside_range) {
        incorrectly_standardized <- TRUE
        min_val <- min(col_values, na.rm = TRUE)
        max_val <- max(col_values, na.rm = TRUE)
        standardization_issue <- sprintf("Values outside [0,1]: min=%.2f, max=%.2f", min_val, max_val)
      }
    }

    # ===== DATA QUALITY / SEPARATION CHECKS =====

    # 1. Very sparse: only 2 distinct values (binary-like)
    very_sparse <- distinct_count <= 2

    # 2. High proportion of zeros (suggests structural zeros / sparse exposure)
    prop_zero <- mean(col_values == 0, na.rm = TRUE)
    high_zero_prop <- prop_zero > 0.90

    # 3. Low variation relative to range (all values clustered)
    val_range <- max(col_values, na.rm = TRUE) - min(col_values, na.rm = TRUE)
    val_sd <- sd(col_values, na.rm = TRUE)
    low_variation <- (val_range > 0 && val_sd / val_range < 0.1)

    # 4. Potential separation: Check if outcome=0 when exposure=0
    # Get outcome (y_train)
    y_train <- data_list$y_train

    # Among observations where exposure=0, what % have outcome=0?
    zero_exposure_idx <- which(col_values == 0)
    if (length(zero_exposure_idx) > 0) {
      prop_outcome_zero_when_exp_zero <- mean(y_train[zero_exposure_idx] == 0, na.rm = TRUE)
    } else {
      prop_outcome_zero_when_exp_zero <- NA
    }

    # Flag potential separation if >90% of outcome=0 when exposure=0
    potential_separation <- !is.na(prop_outcome_zero_when_exp_zero) &&
                           prop_outcome_zero_when_exp_zero > 0.90 &&
                           prop_zero > 0.10  # and there are some zeros in exposure

    # Overall data quality flag
    data_quality_issue <- very_sparse || high_zero_prop || potential_separation

    # Create warning message
    warnings <- c()
    if (very_sparse) warnings <- c(warnings, "Very sparse (≤2 values)")
    if (high_zero_prop) warnings <- c(warnings, sprintf("High zeros (%.1f%%)", prop_zero * 100))
    if (potential_separation) warnings <- c(warnings, sprintf("Potential separation (%.1f%% outcome=0 when exp=0)", prop_outcome_zero_when_exp_zero * 100))
    if (low_variation) warnings <- c(warnings, "Low variation")

    data_quality_warning <- if (length(warnings) > 0) paste(warnings, collapse="; ") else "OK"

    results[[length(results) + 1]] <- data.frame(
      analysis = analysis,
      outcome = outcome,
      exposure = exposure,
      exposure_column = expo_col,
      distinct_values = distinct_count,
      incorrectly_standardized = incorrectly_standardized,
      standardization_issue = standardization_issue,
      very_sparse = very_sparse,
      high_zero_prop = high_zero_prop,
      prop_exposure_zero = prop_zero,
      potential_separation = potential_separation,
      prop_outcome_zero_when_exp_zero = prop_outcome_zero_when_exp_zero,
      data_quality_issue = data_quality_issue,
      data_quality_warning = data_quality_warning,
      stringsAsFactors = FALSE
    )
  }
}

# Combine all results into a single data frame
results_df <- bind_rows(results)

# Create summary table
cat("\n=== All Exposure Columns ===\n")
results_sorted <- results_df %>% arrange(analysis, outcome, exposure, exposure_column)
print(as.data.frame(results_sorted), row.names = FALSE)

# Filter for columns with more than 12 distinct values
cat("\n\n=== Exposure Columns with MORE than 12 Distinct Values ===\n")
high_cardinality <- results_df %>%
  filter(distinct_values > 12) %>%
  arrange(desc(distinct_values), analysis, outcome, exposure)

if (nrow(high_cardinality) > 0) {
  print(as.data.frame(high_cardinality), row.names = FALSE)
} else {
  cat("None found.\n")
}

# Save results to CSV for easy viewing
write_csv(results_df, "exposure_distinct_values_all.csv")
write_csv(high_cardinality, "exposure_distinct_values_high_cardinality.csv")

cat("\n\nResults saved to:\n")
cat("  - exposure_distinct_values_all.csv\n")
cat("  - exposure_distinct_values_high_cardinality.csv\n")

# ===== STANDARDIZATION ISSUES =====
cat("\n\n========================================\n")
cat("STANDARDIZATION ISSUES\n")
cat("========================================\n")

standardization_issues <- results_df %>%
  filter(incorrectly_standardized == TRUE)

if (nrow(standardization_issues) > 0) {
  cat("\nFound", nrow(standardization_issues), "exposure columns with standardization issues!\n\n")
  print(as.data.frame(standardization_issues %>%
    select(analysis, outcome, exposure, exposure_column, distinct_values, standardization_issue) %>%
    arrange(analysis, outcome, exposure)), row.names = FALSE)

  # Save to separate CSV
  write_csv(standardization_issues, "exposure_standardization_issues.csv")
  cat("\nStandardization issues saved to: exposure_standardization_issues.csv\n")
} else {
  cat("\nNo standardization issues found - all exposure columns look correct!\n")
}

# ===== DATA QUALITY ISSUES (Separation, Sparsity) =====
cat("\n\n========================================\n")
cat("DATA QUALITY ISSUES\n")
cat("(Potential separation, sparsity, low variation)\n")
cat("========================================\n")

data_quality_issues <- results_df %>%
  filter(data_quality_issue == TRUE)

if (nrow(data_quality_issues) > 0) {
  cat("\nFound", nrow(data_quality_issues), "exposure columns with data quality issues!\n\n")

  # Show summary by issue type
  cat("Summary by issue type:\n")
  cat("  Very sparse (≤2 values):", sum(data_quality_issues$very_sparse), "\n")
  cat("  High zero proportion (>90%):", sum(data_quality_issues$high_zero_prop), "\n")
  cat("  Potential separation:", sum(data_quality_issues$potential_separation), "\n\n")

  # Show top issues (most severe separation cases)
  cat("Top 20 most severe cases (by separation indicator):\n")
  top_issues <- data_quality_issues %>%
    arrange(desc(prop_outcome_zero_when_exp_zero), desc(prop_exposure_zero)) %>%
    select(analysis, outcome, exposure, exposure_column, distinct_values,
           prop_exposure_zero, prop_outcome_zero_when_exp_zero, data_quality_warning) %>%
    head(20)

  print(as.data.frame(top_issues), row.names = FALSE)

  # Save to separate CSV
  write_csv(data_quality_issues, "exposure_data_quality_issues.csv")
  cat("\n\nData quality issues saved to: exposure_data_quality_issues.csv\n")
} else {
  cat("\nNo data quality issues found!\n")
}

# ===== SUMMARY STATISTICS =====
cat("\n\n========================================\n")
cat("SUMMARY STATISTICS\n")
cat("========================================\n")

# Summary by exposure column
cat("\n=== By Exposure Column (Restaurant) ===\n")
exposure_summary <- high_cardinality %>%
  group_by(exposure_column) %>%
  summarise(
    max_distinct = max(distinct_values),
    min_distinct = min(distinct_values),
    n_occurrences = n(),
    .groups = "drop"
  ) %>%
  arrange(desc(max_distinct))

print(as.data.frame(exposure_summary), row.names = FALSE)

# Summary by analysis type
cat("\n=== By Analysis Type ===\n")
analysis_summary <- high_cardinality %>%
  group_by(analysis) %>%
  summarise(
    n_problematic = n(),
    unique_exposures = n_distinct(exposure),
    unique_columns = n_distinct(exposure_column),
    .groups = "drop"
  )

print(as.data.frame(analysis_summary), row.names = FALSE)

# Summary by exposure (middle level)
cat("\n=== By Exposure Variable (within analysis) ===\n")
exposure_level_summary <- high_cardinality %>%
  group_by(analysis, exposure) %>%
  summarise(
    n_exposure_columns = n_distinct(exposure_column),
    max_distinct_values = max(distinct_values),
    .groups = "drop"
  ) %>%
  arrange(desc(max_distinct_values))

print(as.data.frame(exposure_level_summary), row.names = FALSE)

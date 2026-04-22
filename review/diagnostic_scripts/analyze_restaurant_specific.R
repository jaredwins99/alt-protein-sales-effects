library(tidyverse)

cat("========================================\n")
cat("RESTAURANT-SPECIFIC DATA QUALITY ANALYSIS\n")
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

  # For each exposure column
  for (expo_col in exposure_cols) {
    col_idx <- which(col_names == expo_col)
    col_values <- X_train[, col_idx]

    # Extract restaurant ID from column name (e.g., "exposure_W8T41JZK0ZMEP_1" -> "W8T41JZK0ZMEP")
    restaurant_id <- str_replace(expo_col, "^exposure_", "") %>%
                     str_replace("_\\d+$", "")

    # Find which restaurant index this corresponds to
    # Observations where this exposure > 0 should belong to this restaurant
    exposed_rows <- which(col_values > 0)
    if (length(exposed_rows) == 0) {
      # No exposure for this restaurant, skip
      next
    }

    # Get the restaurant index from idx_to_rest for exposed rows
    restaurant_idx <- unique(idx_to_rest[exposed_rows])

    # Should only be one restaurant
    if (length(restaurant_idx) != 1) {
      cat("Warning: Multiple restaurant indices for", expo_col, "in", file_path, "\n")
      next
    }

    # Get data for THIS restaurant only
    restaurant_rows <- which(idx_to_rest == restaurant_idx)

    # Restaurant-specific data
    rest_exposure <- col_values[restaurant_rows]
    rest_outcome <- y_train[restaurant_rows]

    # Sample size
    n_obs <- length(rest_exposure)
    n_exposed <- sum(rest_exposure > 0)
    n_unexposed <- sum(rest_exposure == 0)

    # ===== EXPOSURE CHARACTERISTICS =====
    distinct_values_exposure <- length(unique(rest_exposure))
    prop_zero_exposure <- mean(rest_exposure == 0, na.rm = TRUE)

    # ===== OUTCOME CHARACTERISTICS =====
    distinct_values_outcome <- length(unique(rest_outcome))
    prop_zero_outcome <- mean(rest_outcome == 0, na.rm = TRUE)

    # ===== OUTCOME SEPARATION CHECKS =====
    # Among restaurant's obs where exposure=0, what % have outcome=0?
    zero_exp_idx <- which(rest_exposure == 0)
    if (length(zero_exp_idx) > 0) {
      prop_outcome_zero_when_exp_zero <- mean(rest_outcome[zero_exp_idx] == 0, na.rm = TRUE)
      n_outcome_nonzero_when_exp_zero <- sum(rest_outcome[zero_exp_idx] != 0)
    } else {
      prop_outcome_zero_when_exp_zero <- NA
      n_outcome_nonzero_when_exp_zero <- NA
    }

    # Among restaurant's obs where exposure>0, what % have outcome=0?
    pos_exp_idx <- which(rest_exposure > 0)
    if (length(pos_exp_idx) > 0) {
      prop_outcome_zero_when_exp_pos <- mean(rest_outcome[pos_exp_idx] == 0, na.rm = TRUE)
      mean_outcome_when_exposed <- mean(rest_outcome[pos_exp_idx], na.rm = TRUE)
    } else {
      prop_outcome_zero_when_exp_pos <- NA
      mean_outcome_when_exposed <- NA
    }

    # Mean outcomes
    if (length(zero_exp_idx) > 0) {
      mean_outcome_when_unexposed <- mean(rest_outcome[zero_exp_idx], na.rm = TRUE)
    } else {
      mean_outcome_when_unexposed <- NA
    }

    # ===== EXPOSURE SEPARATION CHECKS =====
    # Among restaurant's obs where outcome=0, what % have exposure=0?
    zero_outcome_idx <- which(rest_outcome == 0)
    if (length(zero_outcome_idx) > 0) {
      prop_exposure_zero_when_outcome_zero <- mean(rest_exposure[zero_outcome_idx] == 0, na.rm = TRUE)
      n_exposure_nonzero_when_outcome_zero <- sum(rest_exposure[zero_outcome_idx] != 0)
    } else {
      prop_exposure_zero_when_outcome_zero <- NA
      n_exposure_nonzero_when_outcome_zero <- NA
    }

    # Correlation (restaurant-specific)
    if (sd(rest_exposure) > 0 && sd(rest_outcome) > 0) {
      correlation <- cor(rest_exposure, rest_outcome)
    } else {
      correlation <- NA
    }

    # ===== FLAGS =====

    # 1. Very sparse data (≤2 distinct values)
    very_sparse_exposure <- distinct_values_exposure <= 2
    very_sparse_outcome <- distinct_values_outcome <= 2

    # 2. Small sample size
    small_sample <- n_obs < 100
    very_small_sample <- n_obs < 50

    # 3. Imbalanced exposure (one group < 10% of total)
    imbalanced <- min(n_exposed, n_unexposed) / n_obs < 0.10

    # 4. High structural zeros (>90% zeros)
    high_zero_exposure <- prop_zero_exposure > 0.90
    high_zero_outcome <- prop_zero_outcome > 0.90

    # 5. SEPARATION CHECK
    # True separation: outcome doesn't vary within an exposure level
    # Check if outcome has no variation when unexposed (exposure=0)
    if (length(zero_exp_idx) > 0) {
      distinct_outcome_when_unexposed <- length(unique(rest_outcome[zero_exp_idx]))
    } else {
      distinct_outcome_when_unexposed <- NA
    }

    # Check if outcome has no variation when exposed (exposure>0)
    if (length(pos_exp_idx) > 0) {
      distinct_outcome_when_exposed <- length(unique(rest_outcome[pos_exp_idx]))
    } else {
      distinct_outcome_when_exposed <- NA
    }

    # Complete separation: outcome is constant (1 value) within at least one exposure level
    # AND there's substantial sample size in that level (≥50 obs)
    separation <- FALSE
    separation_type <- NA

    if (!is.na(distinct_outcome_when_unexposed) &&
        distinct_outcome_when_unexposed == 1 &&
        length(zero_exp_idx) >= 50) {
      separation <- TRUE
      separation_type <- sprintf("No variation in outcome when unexposed (n=%d, outcome always %.0f)",
                                 length(zero_exp_idx),
                                 unique(rest_outcome[zero_exp_idx])[1])
    }

    if (!is.na(distinct_outcome_when_exposed) &&
        distinct_outcome_when_exposed == 1 &&
        length(pos_exp_idx) >= 50) {
      if (separation) {
        separation_type <- "No variation in outcome for either exposure level (perfect separation)"
      } else {
        separation <- TRUE
        separation_type <- sprintf("No variation in outcome when exposed (n=%d, outcome always %.0f)",
                                   length(pos_exp_idx),
                                   unique(rest_outcome[pos_exp_idx])[1])
      }
    }

    # Quasi-separation: very limited variation (≤3 distinct values and ≥98% are one value)
    quasi_separation <- FALSE
    if (!separation && length(zero_exp_idx) >= 50) {
      if (!is.na(distinct_outcome_when_unexposed) &&
          distinct_outcome_when_unexposed <= 3 &&
          prop_outcome_zero_when_exp_zero >= 0.98) {
        quasi_separation <- TRUE
        separation_type <- sprintf("Quasi-separation when unexposed (%.0f%% zeros, n=%d)",
                                   prop_outcome_zero_when_exp_zero * 100,
                                   n_outcome_nonzero_when_exp_zero)
      }
    }

    # Overall problematic flag
    problematic <- very_sparse_exposure || very_sparse_outcome ||
                   separation || quasi_separation ||
                   (imbalanced && small_sample)

    # Create concise summary
    issue_summary <- c()
    if (separation) {
      issue_summary <- c(issue_summary, "SEPARATION")
    }
    if (quasi_separation) {
      issue_summary <- c(issue_summary, "QUASI_SEP")
    }
    if (very_sparse_exposure) issue_summary <- c(issue_summary, sprintf("Exp_sparse(%d)", distinct_values_exposure))
    if (very_sparse_outcome) issue_summary <- c(issue_summary, sprintf("Out_sparse(%d)", distinct_values_outcome))
    if (imbalanced) issue_summary <- c(issue_summary, sprintf("Imbal(%.0f%%)", n_exposed/n_obs * 100))

    issue_summary_text <- if (length(issue_summary) > 0) paste(issue_summary, collapse=" | ") else "OK"

    # Save result with reorganized columns (most important first)
    results[[length(results) + 1]] <- data.frame(
      # Key identifiers
      restaurant_id = restaurant_id,
      analysis = analysis,
      outcome = outcome,
      exposure = exposure,

      # Summary
      issue_summary = issue_summary_text,

      # Separation flags (most important)
      separation = separation,
      quasi_separation = quasi_separation,
      separation_type = ifelse(is.na(separation_type), "OK", separation_type),

      # Basic sample info
      n_obs = n_obs,
      n_exposed = n_exposed,
      n_unexposed = n_unexposed,

      # Variation within exposure levels
      distinct_outcome_unexposed = ifelse(is.na(distinct_outcome_when_unexposed), 0, distinct_outcome_when_unexposed),
      distinct_outcome_exposed = ifelse(is.na(distinct_outcome_when_exposed), 0, distinct_outcome_when_exposed),

      # Sparsity flags
      very_sparse_exposure = very_sparse_exposure,
      very_sparse_outcome = very_sparse_outcome,
      distinct_values_exposure = distinct_values_exposure,
      distinct_values_outcome = distinct_values_outcome,

      # Less important details
      correlation = round(correlation, 3),
      mean_outcome_unexposed = round(mean_outcome_when_unexposed, 2),
      mean_outcome_exposed = round(mean_outcome_when_exposed, 2),
      outcome_pct_zero_when_exp0 = round(prop_outcome_zero_when_exp_zero * 100, 1),
      prop_zero_exposure = round(prop_zero_exposure, 3),
      prop_zero_outcome = round(prop_zero_outcome, 3),
      high_zero_exposure = high_zero_exposure,
      high_zero_outcome = high_zero_outcome,
      imbalanced = imbalanced,
      small_sample = small_sample,
      problematic = problematic,

      # Technical details (least important)
      exposure_column = expo_col,

      stringsAsFactors = FALSE
    )
  }
}

# Combine results
results_df <- bind_rows(results)

cat("Analyzed", nrow(results_df), "restaurant-exposure combinations\n\n")

# ===== SUMMARY =====
cat("========================================\n")
cat("SUMMARY\n")
cat("========================================\n\n")

cat("Total problematic cases:", sum(results_df$problematic), "\n")
cat("  Separation (no variation in outcome):", sum(results_df$separation), "\n")
cat("  Quasi-separation (very limited variation):", sum(results_df$quasi_separation), "\n")
cat("  Very sparse exposure (≤2 values):", sum(results_df$very_sparse_exposure), "\n")
cat("  Very sparse outcome (≤2 values):", sum(results_df$very_sparse_outcome), "\n")
cat("  Small sample (<100 obs):", sum(results_df$small_sample), "\n")
cat("  Imbalanced exposure:", sum(results_df$imbalanced), "\n\n")

# Show most problematic cases
cat("========================================\n")
cat("SEPARATION CASES\n")
cat("========================================\n\n")

separation_cases_summary <- results_df %>%
  filter(separation == TRUE | quasi_separation == TRUE) %>%
  arrange(desc(separation), desc(quasi_separation)) %>%
  select(restaurant_id, analysis, outcome, exposure, separation_type,
         n_unexposed, distinct_outcome_unexposed, n_exposed, distinct_outcome_exposed)

if (nrow(separation_cases_summary) > 0) {
  print(as.data.frame(separation_cases_summary), row.names = FALSE)
} else {
  cat("No separation cases found!\n")
}

# ===== SAVE FILES =====
cat("\n\n========================================\n")
cat("SAVING FILES\n")
cat("========================================\n\n")

# Create output directory if needed
dir.create("data_diagnostics", showWarnings = FALSE, recursive = TRUE)

# Save all results
write_csv(results_df, "data_diagnostics/restaurant_specific_all.csv")
cat("✓ Saved: data_diagnostics/restaurant_specific_all.csv (", nrow(results_df), "rows)\n")

# Save only problematic cases
problematic_all <- results_df %>%
  filter(problematic == TRUE) %>%
  arrange(desc(separation), desc(quasi_separation))

write_csv(problematic_all, "data_diagnostics/restaurant_specific_problematic.csv")
cat("✓ Saved: data_diagnostics/restaurant_specific_problematic.csv (", nrow(problematic_all), "rows)\n")

# Save separation cases specifically
separation_cases <- results_df %>%
  filter(separation == TRUE | quasi_separation == TRUE) %>%
  arrange(desc(separation), desc(quasi_separation))

write_csv(separation_cases, "data_diagnostics/restaurant_specific_separation.csv")
cat("✓ Saved: data_diagnostics/restaurant_specific_separation.csv (", nrow(separation_cases), "rows)\n")

cat("\nDone!\n")

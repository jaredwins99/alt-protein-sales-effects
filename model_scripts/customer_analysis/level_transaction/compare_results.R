# compare_results.R
# Compare fixest conditional Poisson vs Stan conditional Poisson results
# for the "total" outcome across 4 restaurants.
#
# Usage: Rscript customer_analysis/transaction_level/compare_results.R

library(tidyverse)

# ──────────────────────────────────────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────────────────────────────────────

RESTAURANTS <- c('SRQS8F7JWA9MZ', '2HRX9P6HKXA8V', 'L69HYJ4Y3TR91', 'ED5J990H5VAZT')
OUTCOME <- "total_outcome"
STAN_DIR <- "customer_analysis/transaction_level/stan_poisson/results/total"
OUTPUT_CSV <- "customer_analysis/transaction_level/comparison_total.csv"

# ──────────────────────────────────────────────────────────────────────────────
# 1. Run fixest models
# ──────────────────────────────────────────────────────────────────────────────

cat("\n================================================================\n")
cat("  Fixest vs Stan Comparison: total outcome\n")
cat("================================================================\n\n")

source("customer_analysis/transaction_level/fixest/model_functions.R")

cat("Loading customer transaction data...\n")
data <- load_customer_data()
data <- data %>% filter(location_id %in% RESTAURANTS)
cat(sprintf("Filtered to %d observations across %d restaurants\n\n", nrow(data), length(RESTAURANTS)))

# Fit fixest for each restaurant and collect exposure results
fixest_results <- list()
for (rest in RESTAURANTS) {
  cat(sprintf("Fitting fixest model for restaurant: %s\n", rest))
  result <- fit_restaurant_model(data, OUTCOME, rest, include_gender = TRUE)

  if (!is.null(result)) {
    results_df <- extract_results(result)

    # Filter to exposure terms only (level shifts and slopes)
    exposure_df <- results_df %>%
      filter(grepl("^exposure_", term))

    fixest_results[[rest]] <- exposure_df
    cat(sprintf("  -> %d exposure terms extracted\n", nrow(exposure_df)))
  } else {
    cat(sprintf("  -> Model fitting FAILED for %s\n", rest))
  }
}

fixest_all <- bind_rows(fixest_results)
cat(sprintf("\nTotal fixest exposure estimates: %d\n\n", nrow(fixest_all)))

# ──────────────────────────────────────────────────────────────────────────────
# 2. Load Stan results
# ──────────────────────────────────────────────────────────────────────────────

cat("Loading Stan results...\n")
summ <- readRDS(file.path(STAN_DIR, "summ.rds"))
predictor_map <- readRDS(file.path(STAN_DIR, "predictor_map.rds"))
restaurants_order <- readRDS(file.path(STAN_DIR, "restaurants_order.rds"))

cat(sprintf("  Restaurants order: %s\n", paste(restaurants_order, collapse = ", ")))
cat(sprintf("  Summary has %d parameters\n", nrow(summ)))
cat(sprintf("  Predictor map has %d columns\n\n", nrow(predictor_map)))

# ──────────────────────────────────────────────────────────────────────────────
# 3. Extract Stan gamma (exposure) parameters
# ──────────────────────────────────────────────────────────────────────────────

# Identify exposure columns in predictor_map (both level shifts and slopes)
exposure_map <- predictor_map %>%
  filter(type %in% c("exposure", "slope")) %>%
  filter(grepl("^exposure_", model_col))

cat(sprintf("Exposure columns in predictor map: %d\n", nrow(exposure_map)))

# For each exposure column, extract beta[col_index, rest_index] from summ
# The model_col tells us which restaurant the exposure belongs to
# e.g., "exposure_SRQS8F7JWA9MZ_1" -> restaurant SRQS8F7JWA9MZ
# e.g., "exposure_SRQS8F7JWA9MZ_1_slope" -> restaurant SRQS8F7JWA9MZ (slope)

stan_results <- list()

for (i in seq_len(nrow(exposure_map))) {
  col_idx <- exposure_map$col_index[i]
  model_col <- exposure_map$model_col[i]

  # Determine which restaurant this exposure belongs to
  # Extract restaurant ID from model_col
  # Pattern: exposure_{REST_ID}_{number} or exposure_{REST_ID}_{number}_slope
  rest_id <- model_col %>%
    str_remove("^exposure_") %>%
    str_remove("_\\d+(_slope)?$")

  # Determine if this is a slope term
  is_slope <- grepl("_slope$", model_col)

  # Find rest_index from restaurants_order
  rest_idx <- which(restaurants_order == rest_id)

  if (length(rest_idx) == 0) {
    cat(sprintf("  WARNING: Restaurant %s not found in restaurants_order, skipping\n", rest_id))
    next
  }

  # Extract beta[col_idx, rest_idx] from summ
  param_name <- sprintf("beta[%d,%d]", col_idx, rest_idx)
  param_row <- summ %>% filter(variable == param_name)

  if (nrow(param_row) == 0) {
    cat(sprintf("  WARNING: Parameter %s not found in summ, skipping\n", param_name))
    next
  }

  # Build a matching fixest term name
  # Stan model_col: "exposure_SRQS8F7JWA9MZ_1" -> fixest term: "exposure_SRQS8F7JWA9MZ_1"
  # Stan model_col: "exposure_SRQS8F7JWA9MZ_1_slope" -> fixest term: "exposure_SRQS8F7JWA9MZ_1:date_code"
  if (is_slope) {
    fixest_term <- paste0(str_remove(model_col, "_slope$"), ":date_code")
  } else {
    fixest_term <- model_col
  }

  stan_results[[length(stan_results) + 1]] <- tibble(
    restaurant = rest_id,
    rest_index = rest_idx,
    col_index = col_idx,
    stan_model_col = model_col,
    fixest_term = fixest_term,
    is_slope = is_slope,
    stan_mean = param_row$mean,
    stan_sd = param_row$sd,
    stan_q5 = param_row$q5,
    stan_q95 = param_row$q95,
    stan_rhat = param_row$rhat,
    stan_ess_bulk = param_row$ess_bulk
  )
}

stan_all <- bind_rows(stan_results)
cat(sprintf("Total Stan exposure estimates: %d\n\n", nrow(stan_all)))

# ──────────────────────────────────────────────────────────────────────────────
# 4. Also extract mu_gamma (global mean exposure effects)
# ──────────────────────────────────────────────────────────────────────────────

mu_gamma_rows <- summ %>% filter(grepl("^mu_gamma", variable))
cat("Stan mu_gamma (global exposure effects):\n")
for (j in seq_len(nrow(mu_gamma_rows))) {
  row <- mu_gamma_rows[j, ]
  label <- ifelse(j == 1, "level shift", ifelse(j == 2, "slope", paste0("param ", j)))
  cat(sprintf("  mu_gamma[%d] (%s): mean = %.4f, sd = %.4f, 90%% CrI = [%.4f, %.4f], rhat = %.3f\n",
              j, label, row$mean, row$sd, row$q5, row$q95, row$rhat))
}
cat("\n")

# ──────────────────────────────────────────────────────────────────────────────
# 5. Merge and compare
# ──────────────────────────────────────────────────────────────────────────────

# Prepare fixest side for joining
fixest_for_join <- fixest_all %>%
  select(
    restaurant = location_id,
    fixest_term = term,
    fixest_estimate = estimate,
    fixest_se = std_error,
    fixest_ci_lower = ci_lower,
    fixest_ci_upper = ci_upper,
    fixest_t_value = t_value,
    fixest_p_value = p_value,
    fixest_n_obs = n_obs,
    fixest_n_customers = n_customers
  )

# Prepare stan side for joining
stan_for_join <- stan_all %>%
  select(
    restaurant,
    fixest_term,
    stan_model_col,
    is_slope,
    stan_mean,
    stan_sd,
    stan_q5,
    stan_q95,
    stan_rhat,
    stan_ess_bulk
  )

# Join on restaurant + term
comparison <- fixest_for_join %>%
  full_join(stan_for_join, by = c("restaurant", "fixest_term"))

cat(sprintf("Comparison rows: %d (matched: %d, fixest-only: %d, stan-only: %d)\n\n",
            nrow(comparison),
            sum(!is.na(comparison$fixest_estimate) & !is.na(comparison$stan_mean)),
            sum(!is.na(comparison$fixest_estimate) & is.na(comparison$stan_mean)),
            sum(is.na(comparison$fixest_estimate) & !is.na(comparison$stan_mean))))

# ──────────────────────────────────────────────────────────────────────────────
# 6. Print detailed comparison
# ──────────────────────────────────────────────────────────────────────────────

matched <- comparison %>%
  filter(!is.na(fixest_estimate) & !is.na(stan_mean))

cat("================================================================\n")
cat("  DETAILED COMPARISON: Fixest vs Stan\n")
cat("================================================================\n\n")

for (rest in RESTAURANTS) {
  rest_rows <- matched %>% filter(restaurant == rest)
  if (nrow(rest_rows) == 0) {
    cat(sprintf("Restaurant %s: No matched terms\n\n", rest))
    next
  }

  cat(sprintf("Restaurant: %s\n", rest))
  cat(sprintf("%s\n", strrep("-", 70)))

  for (j in seq_len(nrow(rest_rows))) {
    row <- rest_rows[j, ]
    term_label <- row$fixest_term

    cat(sprintf("\n  Term: %s\n", term_label))
    cat(sprintf("    Fixest:  estimate = %8.5f, SE = %.5f, 95%% CI = [%8.5f, %8.5f], p = %.4f\n",
                row$fixest_estimate, row$fixest_se, row$fixest_ci_lower, row$fixest_ci_upper, row$fixest_p_value))
    cat(sprintf("    Stan:    mean     = %8.5f, SD = %.5f, 90%% CrI = [%8.5f, %8.5f], rhat = %.3f\n",
                row$stan_mean, row$stan_sd, row$stan_q5, row$stan_q95, row$stan_rhat))

    diff <- row$fixest_estimate - row$stan_mean
    cat(sprintf("    Difference (fixest - stan): %+.5f\n", diff))

    # Check interval overlap
    # The fixest 95% CI and Stan 90% CrI overlap if intervals intersect
    fixest_lo <- row$fixest_ci_lower
    fixest_hi <- row$fixest_ci_upper
    stan_lo <- row$stan_q5
    stan_hi <- row$stan_q95
    overlap <- (fixest_lo <= stan_hi) & (stan_lo <= fixest_hi)
    cat(sprintf("    Intervals overlap: %s\n", ifelse(overlap, "YES", "NO")))

    # Direction agreement
    same_sign <- sign(row$fixest_estimate) == sign(row$stan_mean)
    cat(sprintf("    Same sign: %s (fixest: %s, stan: %s)\n",
                ifelse(same_sign, "YES", "NO"),
                ifelse(row$fixest_estimate > 0, "+", "-"),
                ifelse(row$stan_mean > 0, "+", "-")))
  }
  cat("\n")
}

# ──────────────────────────────────────────────────────────────────────────────
# 7. Unmatched terms
# ──────────────────────────────────────────────────────────────────────────────

fixest_only <- comparison %>% filter(!is.na(fixest_estimate) & is.na(stan_mean))
stan_only <- comparison %>% filter(is.na(fixest_estimate) & !is.na(stan_mean))

if (nrow(fixest_only) > 0) {
  cat("================================================================\n")
  cat("  Terms in FIXEST only (no Stan match):\n")
  cat("================================================================\n")
  for (j in seq_len(nrow(fixest_only))) {
    row <- fixest_only[j, ]
    cat(sprintf("  %s | %s | estimate = %.5f\n", row$restaurant, row$fixest_term, row$fixest_estimate))
  }
  cat("\n")
}

if (nrow(stan_only) > 0) {
  cat("================================================================\n")
  cat("  Terms in STAN only (no fixest match):\n")
  cat("================================================================\n")
  for (j in seq_len(nrow(stan_only))) {
    row <- stan_only[j, ]
    cat(sprintf("  %s | %s | mean = %.5f\n", row$restaurant, row$stan_model_col, row$stan_mean))
  }
  cat("\n")
}

# ──────────────────────────────────────────────────────────────────────────────
# 8. Save comparison CSV
# ──────────────────────────────────────────────────────────────────────────────

output_df <- comparison %>%
  transmute(
    restaurant,
    term = fixest_term,
    fixest_estimate,
    fixest_se,
    fixest_ci_lower,
    fixest_ci_upper,
    stan_mean,
    stan_sd,
    stan_q5,
    stan_q95
  )

write_csv(output_df, OUTPUT_CSV)
cat(sprintf("Comparison CSV saved to: %s\n\n", OUTPUT_CSV))

# ──────────────────────────────────────────────────────────────────────────────
# 9. Summary assessment
# ──────────────────────────────────────────────────────────────────────────────

cat("================================================================\n")
cat("  SUMMARY: Do the two models broadly agree?\n")
cat("================================================================\n\n")

if (nrow(matched) > 0) {
  n_same_sign <- sum(sign(matched$fixest_estimate) == sign(matched$stan_mean))
  n_overlap <- sum(
    (matched$fixest_ci_lower <= matched$stan_q95) &
    (matched$stan_q5 <= matched$fixest_ci_upper))
  mean_abs_diff <- mean(abs(matched$fixest_estimate - matched$stan_mean))
  median_abs_diff <- median(abs(matched$fixest_estimate - matched$stan_mean))

  # Check if Stan estimates fall within fixest 95% CI
  n_stan_in_fixest_ci <- sum(
    matched$stan_mean >= matched$fixest_ci_lower &
    matched$stan_mean <= matched$fixest_ci_upper)

  # Check if fixest estimates fall within Stan 90% CrI
  n_fixest_in_stan_cri <- sum(
    matched$fixest_estimate >= matched$stan_q5 &
    matched$fixest_estimate <= matched$stan_q95)

  cat(sprintf("  Matched terms:                     %d\n", nrow(matched)))
  cat(sprintf("  Same sign:                         %d / %d (%.0f%%)\n",
              n_same_sign, nrow(matched), 100 * n_same_sign / nrow(matched)))
  cat(sprintf("  Overlapping intervals:             %d / %d (%.0f%%)\n",
              n_overlap, nrow(matched), 100 * n_overlap / nrow(matched)))
  cat(sprintf("  Stan mean in fixest 95%% CI:        %d / %d (%.0f%%)\n",
              n_stan_in_fixest_ci, nrow(matched), 100 * n_stan_in_fixest_ci / nrow(matched)))
  cat(sprintf("  Fixest est in Stan 90%% CrI:        %d / %d (%.0f%%)\n",
              n_fixest_in_stan_cri, nrow(matched), 100 * n_fixest_in_stan_cri / nrow(matched)))
  cat(sprintf("  Mean |difference|:                 %.5f\n", mean_abs_diff))
  cat(sprintf("  Median |difference|:               %.5f\n", median_abs_diff))

  # Overall verdict
  cat("\n  VERDICT: ")
  if (n_overlap == nrow(matched) && n_same_sign == nrow(matched)) {
    cat("STRONG AGREEMENT -- All intervals overlap and all signs match.\n")
  } else if (n_overlap >= 0.8 * nrow(matched) && n_same_sign >= 0.8 * nrow(matched)) {
    cat("BROAD AGREEMENT -- Most intervals overlap and most signs match.\n")
  } else if (n_overlap >= 0.5 * nrow(matched)) {
    cat("PARTIAL AGREEMENT -- Some intervals overlap, but notable differences exist.\n")
  } else {
    cat("DISAGREEMENT -- Models produce substantially different estimates.\n")
  }

  # Note about expected differences
  cat("\n  NOTE: Differences are expected because:\n")
  cat("    - Fixest uses 90/10 train/test split; Stan uses 95/5\n")
  cat("    - Fixest is frequentist (MLE); Stan is Bayesian (hierarchical prior)\n")
  cat("    - Stan applies partial pooling via mu_gamma -> eta -> gamma hierarchy\n")
  cat("    - Fixest uses clustered SEs; Stan reports posterior SDs\n")
  cat("    - Fixest CIs are 95%%; Stan CrIs are 90%%\n")
} else {
  cat("  No matched terms to compare.\n")
}

cat("\n================================================================\n")
cat("  Done.\n")
cat("================================================================\n")

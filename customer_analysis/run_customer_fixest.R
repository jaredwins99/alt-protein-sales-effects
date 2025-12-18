# run_customer_fixest.R
# Main script for running conditional Poisson customer FE analysis (A5)
#
# This implements ITS analysis with customer fixed effects using conditional
# Poisson regression via fixest. The conditional Poisson approach conditions
# on the sufficient statistic (customer's total count sum), effectively
# absorbing customer FEs without explicit dummy variables.
# Robust/clustered SEs handle overdispersion.

source("customer_analysis/model_functions.R")

OUTCOMES <- c("nonvegan_outcome", "meat_outcome", "chicken_fish_outcome")
INCLUDE_GENDER <- TRUE

RESTAURANTS_T1 <- c(
  'SRQS8F7JWA9MZ',
  '2HRX9P6HKXA8V',
  'L69HYJ4Y3TR91',
  'ED5J990H5VAZT')

RESTAURANTS_T2 <- c(
  'SRQS8F7JWA9MZ', '2HRX9P6HKXA8V', 'L69HYJ4Y3TR91', 'ED5J990H5VAZT', 'W8T41JZK0ZMEP',
  'EMBVNVD207CC6', 'C0BE4NDSW26QN', 'V3Q26BHF3SE2H', 'LBZEEFSBJNB3Z', 'SAFK7ND1HR6XS',
  'S8MT0YGD2KTN9', '1SQPTEGYPH0GA', '9XKJD8DQTH559', 'LQ5EH4BKGV61T', '78AY09MVJVTYE')

#' Run conditional Poisson analysis for a single outcome
#'
#' @param data The loaded customer transaction data
#' @param outcome The outcome variable name
#' @param restaurants Vector of restaurant IDs to analyze
#' @param include_gender Whether to include gender interactions
#' @param run_pooled Whether to also run the pooled model
#' @return List with per-restaurant and pooled results
run_outcome_analysis <- function(data, outcome, restaurants, include_gender = TRUE, run_pooled = TRUE) {
  message("\n========================================")
  message(paste("Running analysis for outcome:", outcome))
  message("========================================\n")

  # Per-restaurant models
  restaurant_results <- list()
  for (rest in restaurants) {
    message(paste("\nFitting model for restaurant:", rest))
    result <- fit_restaurant_model(data, outcome, rest, include_gender)
    if (!is.null(result)) {
      print_model_summary(result)
      restaurant_results[[rest]] <- extract_results(result, "restaurant")}}

  # Pooled model
  pooled_result <- NULL
  if (run_pooled) {
    message("\nFitting pooled model...")

    pooled_data <- data %>%
      filter(location_id %in% restaurants)

    pooled <- fit_pooled_model(pooled_data, outcome, include_gender)
    if (!is.null(pooled)) {
      print_model_summary(pooled)
      pooled_result <- extract_results(pooled, "pooled")}}

  # Combine results
  all_results <- bind_rows(restaurant_results)
  if (!is.null(pooled_result)) {
    all_results <- bind_rows(all_results, pooled_result)}

  # Add outcome name
  all_results$outcome <- outcome

  all_results
}

#' Run full analysis for all outcomes
#'
#' @param tier Either "T1" or "T2" for restaurant tier
#' @param include_gender Whether to include gender interactions
#' @return Combined results data frame
run_full_analysis <- function(tier = "T1", include_gender = TRUE) {
  # Load data
  message("Loading customer transaction data...")
  data <- load_customer_data()
  message(paste("Loaded", nrow(data), "observations"))

  # Select restaurants
  restaurants <- if (tier == "T1") RESTAURANTS_T1 else RESTAURANTS_T2
  message(paste("Analyzing", length(restaurants), "restaurants for Tier", tier))

  # Filter data to selected restaurants
  data <- data %>%
    filter(location_id %in% restaurants)
  message(paste("Filtered to", nrow(data), "observations"))

  # Run analysis for each outcome
  all_results <- list()
  for (outcome in OUTCOMES) {
    results <- run_outcome_analysis(data, outcome, restaurants, include_gender)
    all_results[[outcome]] <- results}

  # Combine all results
  combined <- bind_rows(all_results)

  # Save results
  output_file <- paste0("customer_analysis/results/conditional_poisson_", tier, ".csv")
  write_csv(combined, output_file)
  message(paste("\nAll results saved to:", output_file))

  combined
}

#' Quick test function for a single restaurant and outcome
test_single_model <- function(location_id = "SRQS8F7JWA9MZ", outcome = "nonvegan_outcome") {
  message("Loading data for test...")
  data <- load_customer_data()

  message(paste("\nTesting model for", location_id, "-", outcome))
  result <- fit_restaurant_model(data, outcome, location_id, include_gender = TRUE)

  if (!is.null(result)) {
    print_model_summary(result)
    extract_results(result, "restaurant")
  } else {
    message("Model fitting failed")
    NULL}
}

# Main execution
if (sys.nframe() == 0) {
  message("\n##################################################")
  message("# Running Tier 1 Conditional Poisson Analysis")
  message("##################################################\n")
  results_t1 <- run_full_analysis(tier = "T1", include_gender = TRUE)

  # message("\n##################################################")
  # message("# Running Tier 2 Conditional Poisson Analysis")
  # message("##################################################\n")
  # results_t2 <- run_full_analysis(tier = "T2", include_gender = TRUE)
}

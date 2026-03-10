source("customer_analysis/level_day/fixest/model_functions_day.R")

A5_OUTCOMES <- c("nonvegan", "meat", "chicken_fish", "vegan", "vegetarian", "total")
A5_RESTAURANTS <- c('SRQS8F7JWA9MZ', '2HRX9P6HKXA8V', 'L69HYJ4Y3TR91', 'ED5J990H5VAZT')

A6_CONFIG <- list(
  breakfast = list(
    restaurants = c('2HRX9P6HKXA8V', 'L69HYJ4Y3TR91', 'ED5J990H5VAZT'),
    extra_price = "breakfast_price_real"),
  untextured = list(
    restaurants = c('SRQS8F7JWA9MZ'),
    extra_price = "untextured_price_real"))

run_single_outcome <- function(outcome, restaurants, analysis_type = "A5", extra_price_predictor = NULL) {

  outcome_var <- paste0(outcome, "_outcome")
  message(sprintf("\n========================================"))
  message(sprintf("Running %s (day-level): %s", analysis_type, outcome))
  message(sprintf("Restaurants: %s", paste(restaurants, collapse = ", ")))
  message(sprintf("========================================\n"))

  data <- load_customer_data()
  data_filtered <- data %>% filter(location_id %in% restaurants)

  if (!is.null(extra_price_predictor)) {
    message(sprintf("Using extra price predictor: %s", extra_price_predictor))}

  all_restaurant_results <- list()
  exposure_summary <- list()

  for (rest in restaurants) {
    message(sprintf("\n--- Fitting day-level model for %s ---", rest))

    result <- fit_restaurant_model(
      data = data_filtered,
      outcome = outcome_var,
      location_id = rest,
      include_gender = TRUE,
      extra_price_predictor = extra_price_predictor)

    if (!is.null(result)) {
      print_model_summary(result)

      results_df <- extract_results(result)
      results_df$analysis <- analysis_type
      results_df$outcome_name <- outcome

      restaurant_file <- file.path(
        "customer_analysis/level_day/fixest/results_other",
        sprintf("%s_%s_%s.csv", analysis_type, outcome, rest))
      write_csv(results_df, restaurant_file)
      message(sprintf("Saved: %s", restaurant_file))

      all_restaurant_results[[rest]] <- results_df

      exposure_rows <- results_df %>%
        filter(grepl("^exposure_", term) | grepl("^exposure_.*:date_code", term) | grepl("^exposure_.*:gender", term)) %>%
        select(term, estimate, std_error, p_value, ci_lower, ci_upper, location_id, n_obs, n_customers)

      if (nrow(exposure_rows) > 0) {
        exposure_summary[[rest]] <- exposure_rows}

      if (!is.null(result$predictions)) {
        plot_predictions(result, outcome)}
    } else {
      message(sprintf("Model failed for %s", rest))}}

  combined_exposure <- NULL
  if (length(exposure_summary) > 0) {
    combined_exposure <- bind_rows(exposure_summary, .id = "model_id")
    combined_exposure$analysis <- analysis_type
    combined_exposure$outcome_name <- outcome

    summary_file <- file.path(
      "customer_analysis/level_day/fixest/results_exposures",
      sprintf("%s_%s.csv", analysis_type, outcome))
    write_csv(combined_exposure, summary_file)
    message(sprintf("\nSaved exposure summary: %s", summary_file))
  } else {
    message("\nNo valid model results for exposure summary")}

  all_results <- bind_rows(all_restaurant_results)

  invisible(list(
    all_results = all_results,
    exposure_summary = combined_exposure))
}

run_all_A5 <- function() {
  message("\n##################################################")
  message("# Running All A5 Day-Level Analyses (6 outcomes)")
  message("##################################################\n")
  results <- list()
  for (outcome in A5_OUTCOMES) {
    results[[outcome]] <- run_single_outcome(
      outcome = outcome,
      restaurants = A5_RESTAURANTS,
      analysis_type = "A5")}
  invisible(results)}

run_all_A6 <- function() {
  message("\n##################################################")
  message("# Running All A6 Day-Level Analyses (2 outcomes)")
  message("##################################################\n")
  results <- list()
  for (outcome in names(A6_CONFIG)) {
    config <- A6_CONFIG[[outcome]]
    results[[outcome]] <- run_single_outcome(
      outcome = outcome,
      restaurants = config$restaurants,
      analysis_type = "A6",
      extra_price_predictor = config$extra_price)}
  invisible(results)}

run_all <- function() {
  message("=================================================")
  message("  Day-Level Conditional Poisson Customer FE Analysis")
  message("  A5: 6 outcomes x 4 restaurants")
  message("  A6: 2 outcomes (breakfast: 3 rest, untextured: 1 rest)")
  message("=================================================\n")

  start_time <- Sys.time()

  a5_results <- run_all_A5()
  a6_results <- run_all_A6()

  end_time <- Sys.time()
  elapsed <- difftime(end_time, start_time, units = "mins")

  message("\n=================================================")
  message(sprintf("  All day-level analyses completed in %.1f minutes", as.numeric(elapsed)))
  message("  Exposures: customer_analysis/level_day/fixest/results_exposures/")
  message("  Full results: customer_analysis/level_day/fixest/results_other/")
  message("=================================================\n")

  invisible(list(A5 = a5_results, A6 = a6_results))}

# Main execution
if (sys.nframe() == 0) {
  results <- run_all()}

# run_top_customers.R
# Conditional Poisson (fixest) analysis restricted to the top 25% most
# frequent customers per restaurant.  Mirrors run_all_analyses.R but adds a
# frequency-based customer filter after the pre/post filter.

source("customer_analysis/transaction_level/fixest/model_functions.R")

# ─────────────────────────────────────
#  Configuration
# ─────────────────────────────────────

A5_OUTCOMES <- c("nonvegan", "meat", "chicken_fish", "vegan", "vegetarian", "total")

RESTAURANTS <- c(
  'SRQS8F7JWA9MZ',
  '2HRX9P6HKXA8V',
  'L69HYJ4Y3TR91',
  'ED5J990H5VAZT')

RESULTS_DIR <- "customer_analysis/transaction_level/fixest/results_exposures_top25"
PRED_DIR    <- "customer_analysis/transaction_level/fixest/pred_plots_top25"

dir.create(RESULTS_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(PRED_DIR, showWarnings = FALSE, recursive = TRUE)

# ─────────────────────────────────────
#  Helper: summary statistics collector
# ─────────────────────────────────────

summary_stats <- list()

# ─────────────────────────────────────
#  Main analysis loop
# ─────────────────────────────────────

run_top_customer_analysis <- function() {
  message("Loading customer transaction data...")
  data <- load_customer_data()
  message(sprintf("Loaded %d observations", nrow(data)))

  for (outcome in A5_OUTCOMES) {
    outcome_var <- paste0(outcome, "_outcome")

    message(sprintf("\n========================================"))
    message(sprintf("A5 Top-25%%: %s", outcome))
    message(sprintf("========================================\n"))

    exposure_summary <- list()

    for (rest in RESTAURANTS) {
      message(sprintf("\n--- Restaurant: %s ---", rest))

      # Step a: filter to this restaurant
      rest_data <- filter_restaurant(data, rest)

      # Step b: get exposure columns
      exposure_cols <- get_exposure_cols(rest_data, rest)
      if (length(exposure_cols) == 0) {
        message(sprintf("  No exposure columns for %s, skipping", rest))
        next
      }

      # Step c: filter to customers with both pre and post observations
      rest_data <- filter_customers_pre_post(rest_data, exposure_cols)
      if (nrow(rest_data) == 0) {
        message(sprintf("  No valid pre/post customers for %s, skipping", rest))
        next
      }
      n_full <- length(unique(rest_data$customer_id))

      # Step d: count transactions per customer
      customer_counts <- rest_data %>%
        count(customer_id) %>%
        arrange(desc(n))

      # Step e: take top 25%
      top_customers <- customer_counts %>%
        slice_head(prop = 0.25) %>%
        pull(customer_id)
      n_top <- length(top_customers)

      # Step f: filter data to only those customers
      rest_data <- rest_data %>%
        filter(customer_id %in% top_customers)

      # Collect summary stats
      mean_txn_top  <- mean(customer_counts %>%
                              filter(customer_id %in% top_customers) %>%
                              pull(n))
      mean_txn_full <- mean(customer_counts$n)
      summary_stats[[paste(rest, outcome, sep = "_")]] <<- list(
        restaurant   = rest,
        outcome      = outcome,
        n_full       = n_full,
        n_top25      = n_top,
        pct          = round(n_top / n_full * 100, 1),
        mean_txn_top = round(mean_txn_top, 1),
        mean_txn_all = round(mean_txn_full, 1),
        n_obs_top    = nrow(rest_data)
      )

      message(sprintf("  Full set: %d customers | Top 25%%: %d customers (%d obs)",
                       n_full, n_top, nrow(rest_data)))
      message(sprintf("  Mean transactions -- top25: %.1f | all: %.1f",
                       mean_txn_top, mean_txn_full))

      # Step g: fit the model
      rest_data <- rest_data %>% arrange(date)
      split_idx  <- floor(nrow(rest_data) * 0.9)
      train_data <- rest_data[1:split_idx, ]
      test_data  <- rest_data[(split_idx + 1):nrow(rest_data), ]

      has_gender <- sum(!is.na(train_data$gender)) > 0 &&
                    length(unique(na.omit(train_data$gender))) > 1

      form <- build_formula(outcome_var, exposure_cols, include_gender = has_gender)

      # Exposure dates (for prediction plots)
      exposure_dates <- rest_data %>%
        select(date, all_of(exposure_cols)) %>%
        pivot_longer(cols = all_of(exposure_cols),
                     names_to = "exposure_col", values_to = "value") %>%
        filter(value == 1) %>%
        group_by(exposure_col) %>%
        summarize(date = min(date), .groups = "drop") %>%
        pull(date)

      model <- tryCatch({
        fepois(form, data = train_data, vcov = ~customer_id)
      }, error = function(e) {
        message(sprintf("  Error fitting model: %s", e$message))
        NULL
      })

      if (is.null(model)) next

      # Wrap into the same list structure that extract_results / plot_predictions expect
      model_result <- list(
        model         = model,
        location_id   = rest,
        n_obs         = nrow(rest_data),
        n_train       = nrow(train_data),
        n_test        = nrow(test_data),
        n_customers   = n_top,
        exposure_cols = exposure_cols,
        exposure_dates = exposure_dates,
        has_gender    = has_gender
      )

      # Predictions for plotting
      train_data$pred <- predict(model, newdata = train_data, type = "response")
      test_data$pred  <- predict(model, newdata = test_data,  type = "response")
      train_data$split <- "train"
      test_data$split  <- "test"

      model_result$predictions <- bind_rows(train_data, test_data) %>%
        select(date,
               outcome_col = all_of(outcome_var),
               pred, split, customer_id, date_code,
               all_of(exposure_cols))

      print_model_summary(model_result)

      # Extract results (same format as full-sample analysis)
      results_df <- extract_results(model_result)
      results_df$analysis     <- "A5"
      results_df$outcome_name <- outcome

      # Exposure rows for the summary CSV
      exposure_rows <- results_df %>%
        filter(grepl("^exposure_", term)) %>%
        select(term, estimate, std_error, p_value, ci_lower, ci_upper,
               location_id, n_obs, n_customers)

      if (nrow(exposure_rows) > 0) {
        exposure_summary[[rest]] <- exposure_rows
      }

      # Prediction plot
      tryCatch(
        plot_predictions(model_result, outcome, output_dir = PRED_DIR),
        error = function(e) message(sprintf("  Plot error: %s", e$message))
      )
    }

    # Step h: save exposure results CSV
    if (length(exposure_summary) > 0) {
      combined_exposure <- bind_rows(exposure_summary, .id = "model_id")
      combined_exposure$analysis     <- "A5"
      combined_exposure$outcome_name <- outcome

      out_file <- file.path(RESULTS_DIR, sprintf("A5_%s.csv", outcome))
      write_csv(combined_exposure, out_file)
      message(sprintf("\nSaved exposure summary: %s", out_file))
    } else {
      message("\nNo valid model results for exposure summary")
    }
  }
}

# ─────────────────────────────────────
#  Step 4: Print summary statistics
# ─────────────────────────────────────

print_summary_stats <- function() {
  cat("\n========================================\n")
  cat("  Top 25% Customer Summary Statistics\n")
  cat("========================================\n\n")

  stats_df <- bind_rows(lapply(summary_stats, as.data.frame))

  if (nrow(stats_df) == 0) {
    cat("  No summary statistics collected.\n")
    return()
  }

  # Print per-restaurant aggregated stats (unique restaurant rows)
  per_rest <- stats_df %>%
    group_by(restaurant) %>%
    summarize(
      n_full_customers = first(n_full),
      n_top25_customers = first(n_top25),
      mean_txn_top25 = first(mean_txn_top),
      mean_txn_all   = first(mean_txn_all),
      total_obs_top25 = first(n_obs_top),
      .groups = "drop"
    )

  for (i in seq_len(nrow(per_rest))) {
    r <- per_rest[i, ]
    cat(sprintf("  Restaurant: %s\n", r$restaurant))
    cat(sprintf("    Full set:  %d customers (mean %.1f txn/customer)\n",
                r$n_full_customers, r$mean_txn_all))
    cat(sprintf("    Top 25%%:   %d customers (mean %.1f txn/customer)\n",
                r$n_top25_customers, r$mean_txn_top25))
    cat(sprintf("    Top-25%% obs: %d\n\n", r$total_obs_top25))
  }
}

# ─────────────────────────────────────
#  Execute
# ─────────────────────────────────────

if (sys.nframe() == 0) {
  message("=================================================")
  message("  Conditional Poisson -- Top 25% Customers")
  message("  A5: 6 outcomes x 4 restaurants")
  message("=================================================\n")

  start_time <- Sys.time()

  run_top_customer_analysis()

  end_time <- Sys.time()
  elapsed  <- difftime(end_time, start_time, units = "mins")

  print_summary_stats()

  message(sprintf("\nCompleted in %.1f minutes", as.numeric(elapsed)))
  message(sprintf("  Exposures:  %s/", RESULTS_DIR))
  message(sprintf("  Pred plots: %s/", PRED_DIR))
}

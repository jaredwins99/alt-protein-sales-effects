library(tidyverse)
library(arrow)
library(patchwork)
library(fixest)

load_customer_data <- function(data_path = "data/4_data_parquet_modeling/customer/finalized_transactions_customers.parquet") {
  read_parquet(data_path)}

get_exposure_cols <- function(data, location_id) {
  pattern <- paste0("^exposure_", location_id, "_")
  colnames(data) %>% str_subset(pattern)}

get_restaurants <- function(data) {
  unique(data$location_id)}

filter_restaurant <- function(data, loc_id) {
  data %>% filter(location_id == loc_id)}

filter_customers_pre_post <- function(data, exposure_cols) {
  if (length(exposure_cols) == 0) {
    return(data %>% filter(FALSE))}
  data <- data %>%
    mutate(any_exposure = rowSums(select(., all_of(exposure_cols))) > 0)
  valid_customers <- data %>%
    group_by(customer_id) %>%
    summarize(
      has_pre = any(!any_exposure),
      has_post = any(any_exposure),
      .groups = "drop") %>%
    filter(has_pre & has_post) %>%
    pull(customer_id)
  data %>%
    filter(customer_id %in% valid_customers)
}



build_formula <- function(outcome, exposure_cols, include_gender = TRUE, extra_price_predictor = NULL) {
  covariates <- c(
    "vegan_price_real", 
    "vegetarian_price_real", 
    "meat_price_real",
    "weekend", 
    "holiday_window",
    "month_cat", 
    "season", 
    "year_cat", 
    "date_code",
    "day_of_week_cat", 
    "inflation",
    "precip",
    "temp"
    )

  if (!is.null(extra_price_predictor)) {
    covariates <- c(covariates, extra_price_predictor)}

  exposure_terms <- exposure_cols
  slope_terms <- paste0(exposure_cols, ":date_code")

  if (include_gender && length(exposure_cols) > 0) {
    gender_interactions <- paste0(exposure_cols, ":gender")
    rhs_terms <- c(exposure_terms, slope_terms, "gender", gender_interactions, covariates)
  } else {
    rhs_terms <- c(exposure_terms, slope_terms, covariates)}

  formula_str <- paste0(outcome, " ~ ", paste(rhs_terms, collapse = " + "), " | customer_id")
  as.formula(formula_str)
}



fit_restaurant_model <- function(data, outcome, location_id, include_gender = TRUE, extra_price_predictor = NULL, train_frac = 0.9) {
  exposure_cols <- get_exposure_cols(data, location_id)

  if (length(exposure_cols) == 0) {
    message(paste("No exposure columns found for restaurant:", location_id))
    return(NULL)}

  rest_data <- filter_restaurant(data, location_id)
  rest_data <- filter_customers_pre_post(rest_data, exposure_cols)

  if (nrow(rest_data) == 0) {
    message(paste("No valid customers with pre/post observations for:", location_id))
    return(NULL)}

  # Split by date
  rest_data <- rest_data %>% arrange(date)
  split_idx <- floor(nrow(rest_data) * train_frac)
  train_data <- rest_data[1:split_idx, ]
  test_data <- rest_data[(split_idx + 1):nrow(rest_data), ]

  has_gender <- include_gender && sum(!is.na(train_data$gender)) > 0 &&
                length(unique(na.omit(train_data$gender))) > 1

  form <- build_formula(outcome, exposure_cols, include_gender = has_gender, extra_price_predictor = extra_price_predictor)

  # Extract exposure dates
  exposure_dates <- rest_data %>%
    select(date, all_of(exposure_cols)) %>%
    pivot_longer(cols = all_of(exposure_cols), names_to = "exposure_col", values_to = "value") %>%
    filter(value == 1) %>%
    group_by(exposure_col) %>%
    summarize(date = min(date), .groups = "drop") %>%
    pull(date)

  tryCatch({
    model <- fepois(
      form,
      data = train_data,
      vcov = ~customer_id)

    train_data$pred <- predict(model, newdata = train_data, type = "response")
    test_data$pred <- predict(model, newdata = test_data, type = "response")

    train_data$split <- "train"
    test_data$split <- "test"

    pred_data <- bind_rows(train_data, test_data) %>%
      select(date, outcome_col = all_of(outcome), pred, split, customer_id, date_code, all_of(exposure_cols))

    list(
      model = model,
      location_id = location_id,
      n_obs = nrow(rest_data),
      n_train = nrow(train_data),
      n_test = nrow(test_data),
      n_customers = length(unique(rest_data$customer_id)),
      exposure_cols = exposure_cols,
      exposure_dates = exposure_dates,
      has_gender = has_gender,
      predictions = pred_data)
  }, error = function(e) {
    message(paste("Error fitting model for", location_id, ":", e$message))
    NULL})
}



extract_results <- function(model_result) {
  if (is.null(model_result)) return(NULL)

  model <- model_result$model
  coef_table <- summary(model)$coeftable

  results <- as.data.frame(coef_table)
  results$term <- rownames(results)
  rownames(results) <- NULL
  colnames(results) <- c("estimate", "std_error", "t_value", "p_value", "term")

  # Add confidence intervals
  results <- results %>%
    mutate(
      ci_lower = estimate - 1.96 * std_error,
      ci_upper = estimate + 1.96 * std_error)

  # Add metadata
  results$location_id <- model_result$location_id
  results$n_obs <- model_result$n_obs
  results$n_customers <- model_result$n_customers

  results
}



save_results <- function(results, outcome, output_dir = "customer_analysis/transaction_level/fixest/results") {
  filename <- file.path(output_dir, paste0("conditional_poisson_", outcome, ".csv"))
  write_csv(results, filename)
  message(paste("Results saved to:", filename))}



print_model_summary <- function(model_result) {
  if (is.null(model_result)) {
    message("Model is NULL")
    return()}
  cat("\n========================================\n")
  cat("Restaurant:", model_result$location_id, "\n")
  cat("N observations:", model_result$n_obs, "\n")
  if (!is.null(model_result$n_train)) {
    cat("N train:", model_result$n_train, "\n")
    cat("N test:", model_result$n_test, "\n")}
  cat("N customers:", model_result$n_customers, "\n")
  cat("Has gender interactions:", model_result$has_gender, "\n")
  cat("========================================\n\n")
  print(summary(model_result$model))}



plot_predictions <- function(model_result, outcome_name, output_dir = "customer_analysis/transaction_level/fixest/pred_plots") {
  pred_data <- model_result$predictions
  model_id <- model_result$location_id
  exposure_dates <- model_result$exposure_dates
  model_obj <- model_result$model
  exposure_cols <- model_result$exposure_cols
  has_gender <- model_result$has_gender

  if (is.null(pred_data) || nrow(pred_data) == 0) {
    message("No prediction data to plot")
    return(NULL)}

  coefs <- coef(model_obj)

  # Separate train and test data
  train_data <- pred_data %>% filter(split == "train")
  test_data <- pred_data %>% filter(split == "test")

  # Aggregate by week, keeping date_code and exposure info
  agg_weekly <- function(df) {
    df %>%
      filter(!is.na(date)) %>%
      group_by(week = floor_date(date, "week")) %>%
      summarize(
        obs = sum(outcome_col, na.rm = TRUE),
        pred = sum(pred, na.rm = TRUE),
        avg_date_code = mean(date_code, na.rm = TRUE),
        across(all_of(exposure_cols), ~max(., na.rm = TRUE)),
        .groups = "drop")
  }

  train_weekly <- agg_weekly(train_data)
  test_weekly <- agg_weekly(test_data)

  if (nrow(train_weekly) == 0 || nrow(test_weekly) == 0) {
    message("Insufficient data for plotting")
    return(NULL)}

  # Pre-exposure weekly mean (weeks where no exposure is active)
  all_weekly <- bind_rows(train_weekly, test_weekly)
  pre_weeks <- all_weekly %>%
    filter(if_all(all_of(exposure_cols), ~. == 0))
  pre_mean <- mean(pre_weeks$obs, na.rm = TRUE)

  color_vals <- c("Observed" = "black", "Predicted" = "red")

  # Build plot helper
  build_panel <- function(wk_df, panel_title) {
    p <- ggplot(wk_df, aes(x = week)) +
      geom_line(aes(y = obs, color = "Observed")) +
      geom_line(aes(y = pred, color = "Predicted")) +
      geom_hline(yintercept = pre_mean, linetype = "dotted", color = "grey50", alpha = 0.7) +
      labs(title = panel_title, y = "Weekly Count", x = "Week") +
      scale_color_manual(values = color_vals) +
      theme_minimal() +
      theme(legend.position = "bottom")

    # Add exposure date vertical lines
    if (!is.null(exposure_dates) && length(exposure_dates) > 0) {
      p <- p + geom_vline(xintercept = exposure_dates, linetype = "dashed", color = "purple", alpha = 0.5)
    }
    p
  }

  p_train <- build_panel(train_weekly, paste(model_id, "- Training Data"))
  p_test <- build_panel(test_weekly, paste(model_id, "- Test Data"))

  combined_plot <- p_train + p_test + plot_layout(guides = "collect") & theme(legend.position = 'bottom')

  filename <- file.path(output_dir, paste0(outcome_name, "_", model_id, ".png"))
  ggsave(filename, combined_plot, width = 10, height = 5, dpi = 300)
  message(paste("Saved plot:", filename))

  invisible(combined_plot)
}


plot_predictions_counterfactual <- function(model_result, outcome_name, output_dir = "customer_analysis/transaction_level/fixest/pred_plots_cf") {
  pred_data <- model_result$predictions
  model_id <- model_result$location_id
  exposure_dates <- model_result$exposure_dates
  model_obj <- model_result$model
  exposure_cols <- model_result$exposure_cols
  has_gender <- model_result$has_gender

  if (is.null(pred_data) || nrow(pred_data) == 0) {
    message("No prediction data to plot")
    return(NULL)
  }

  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

  coefs <- coef(model_obj)

  # Compute per-observation exposure log-effect, then divide it out of pred
  # For Poisson: pred = base * exp(exposure_effect), so base = pred / exp(exposure_effect)
  compute_exposure_effect <- function(row) {
    log_eff <- 0
    for (ec in exposure_cols) {
      if (!(ec %in% names(coefs))) next
      beta_level <- coefs[ec]
      beta_slope <- if (paste0(ec, ":date_code") %in% names(coefs)) coefs[paste0(ec, ":date_code")] else 0
      active <- row[[ec]]
      log_eff <- log_eff + active * (beta_level + beta_slope * row[["date_code"]])
    }
    log_eff
  }

  pred_data$log_exposure_eff <- sapply(seq_len(nrow(pred_data)), function(i) compute_exposure_effect(pred_data[i, ]))
  pred_data$pred_cf <- pred_data$pred / exp(pred_data$log_exposure_eff)

  # Separate train and test
  train_data <- pred_data %>% filter(split == "train")
  test_data <- pred_data %>% filter(split == "test")

  # Aggregate by week
  agg_weekly <- function(df) {
    df %>%
      filter(!is.na(date)) %>%
      group_by(week = floor_date(date, "week")) %>%
      summarize(
        obs = sum(outcome_col, na.rm = TRUE),
        pred = sum(pred, na.rm = TRUE),
        pred_cf = sum(pred_cf, na.rm = TRUE),
        .groups = "drop")
  }

  train_weekly <- agg_weekly(train_data)
  test_weekly <- agg_weekly(test_data)

  if (nrow(train_weekly) == 0 || nrow(test_weekly) == 0) {
    message("Insufficient data for plotting")
    return(NULL)
  }

  color_vals <- c("Observed" = "black", "Predicted" = "red", "Counterfactual (no exposure)" = "steelblue")

  build_panel <- function(wk_df, panel_title) {
    p <- ggplot(wk_df, aes(x = week)) +
      geom_line(aes(y = obs, color = "Observed")) +
      geom_line(aes(y = pred, color = "Predicted")) +
      geom_line(aes(y = pred_cf, color = "Counterfactual (no exposure)"), linetype = "dashed", linewidth = 0.7) +
      labs(title = panel_title, y = "Weekly Count", x = "Week") +
      scale_color_manual(values = color_vals) +
      theme_minimal() +
      theme(legend.position = "bottom")

    if (!is.null(exposure_dates) && length(exposure_dates) > 0) {
      p <- p + geom_vline(xintercept = exposure_dates, linetype = "dashed", color = "purple", alpha = 0.5)
    }
    p
  }

  p_train <- build_panel(train_weekly, paste(model_id, "- Training Data"))
  p_test <- build_panel(test_weekly, paste(model_id, "- Test Data"))

  combined_plot <- p_train + p_test + plot_layout(guides = "collect") & theme(legend.position = "bottom")

  filename <- file.path(output_dir, paste0(outcome_name, "_", model_id, ".png"))
  ggsave(filename, combined_plot, width = 10, height = 5, dpi = 300)
  message(paste("Saved counterfactual plot:", filename))

  invisible(combined_plot)
}

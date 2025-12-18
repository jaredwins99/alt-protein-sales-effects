library(tidyverse)
library(arrow)
library(fixest)
library(patchwork)

load_customer_data <- function(data_path = "data/4_data_parquet_modeling/customer/finalized_transactions_customers.parquet") {
  read_parquet(data_path)
}

get_exposure_cols <- function(data, location_id) {
  exp_pattern <- paste0("^exposure_", location_id, "_")
  grep(exp_pattern, colnames(data), value = TRUE)
}

get_restaurants <- function(data) {
  unique(data$location_id)
}

filter_restaurant <- function(data, location_id) {
  data %>% filter(location_id == !!location_id)
}

filter_customers_pre_post <- function(data, exposure_cols) {
  if (length(exposure_cols) == 0) {
    return(data %>% filter(FALSE))
  }

  data <- data %>%
    mutate(any_exposure = rowSums(select(., all_of(exposure_cols))) > 0)

  valid_customers <- data %>%
    group_by(customer_id) %>%
    summarise(
      has_pre = any(!any_exposure),
      has_post = any(any_exposure),
      .groups = "drop"
    ) %>%
    filter(has_pre & has_post) %>%
    pull(customer_id)

  data %>%
    filter(customer_id %in% valid_customers)
}

build_formula <- function(outcome, exposure_cols, include_gender = TRUE, extra_price_predictor = NULL) {
  covariates <- c(
    "vegan_price_real", "vegetarian_price_real", "meat_price_real",
    "weekend", "holiday_window",
    "month_cat", "season", "year_cat", "date_code",
    "day_of_week_cat", "inflation"
  )

  if (!is.null(extra_price_predictor)) {
    covariates <- c(covariates, extra_price_predictor)
  }

  exposure_terms <- exposure_cols
  slope_terms <- paste0(exposure_cols, ":date_code")

  if (include_gender && length(exposure_cols) > 0) {
    gender_interactions <- paste0(exposure_cols, ":gender")
    rhs_terms <- c(exposure_terms, slope_terms, "gender", gender_interactions, covariates)
  } else {
    rhs_terms <- c(exposure_terms, slope_terms, covariates)
  }

  formula_str <- paste0(outcome, " ~ ", paste(rhs_terms, collapse = " + "), " | customer_id")
  as.formula(formula_str)
}

build_formula_pooled <- function(outcome, include_gender = TRUE) {
  covariates <- c(
    "vegan_price_real", "vegetarian_price_real", "meat_price_real",
    "weekend", "holiday_window",
    "month_cat", "season", "year_cat", "date_code",
    "day_of_week_cat", "inflation"
  )

  if (include_gender) {
    rhs_terms <- c("any_exposure", "any_exposure:date_code", "gender", "any_exposure:gender", covariates)
  } else {
    rhs_terms <- c("any_exposure", "any_exposure:date_code", covariates)
  }

  formula_str <- paste0(outcome, " ~ ", paste(rhs_terms, collapse = " + "), " | customer_id + location_id")
  as.formula(formula_str)
}

fit_restaurant_model <- function(data, outcome, location_id, include_gender = TRUE, extra_price_predictor = NULL, train_frac = 0.9) {
  exposure_cols <- get_exposure_cols(data, location_id)

  if (length(exposure_cols) == 0) {
    message(paste("No exposure columns found for restaurant:", location_id))
    return(NULL)
  }

  rest_data <- filter_restaurant(data, location_id)
  rest_data <- filter_customers_pre_post(rest_data, exposure_cols)

  if (nrow(rest_data) == 0) {
    message(paste("No valid customers with pre/post observations for:", location_id))
    return(NULL)
  }

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
    summarise(date = min(date), .groups = "drop") %>%
    pull(date)

  tryCatch({
    model <- fepois(
      form,
      data = train_data,
      vcov = ~customer_id
    )

    # Generate predictions
    train_data$pred <- predict(model, newdata = train_data, type = "response")
    test_data$pred <- predict(model, newdata = test_data, type = "response")

    train_data$split <- "train"
    test_data$split <- "test"

    pred_data <- bind_rows(train_data, test_data) %>%
      select(date, outcome_col = all_of(outcome), pred, split, customer_id)

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
      predictions = pred_data
    )
  }, error = function(e) {
    message(paste("Error fitting model for", location_id, ":", e$message))
    NULL
  })
}

fit_pooled_model <- function(data, outcome, include_gender = TRUE, train_frac = 0.9) {
  all_exp_cols <- grep("^exposure_", colnames(data), value = TRUE)

  data <- data %>%
    mutate(any_exposure = rowSums(select(., all_of(all_exp_cols))) > 0)

  valid_customers <- data %>%
    group_by(customer_id) %>%
    summarise(
      has_pre = any(!any_exposure),
      has_post = any(any_exposure),
      .groups = "drop"
    ) %>%
    filter(has_pre & has_post) %>%
    pull(customer_id)

  data <- data %>%
    filter(customer_id %in% valid_customers)

  if (nrow(data) == 0) {
    message("No valid customers with pre/post observations for pooled model")
    return(NULL)
  }

  # Split by date
  data <- data %>% arrange(date)
  split_idx <- floor(nrow(data) * train_frac)
  train_data <- data[1:split_idx, ]
  test_data <- data[(split_idx + 1):nrow(data), ]

  has_gender <- include_gender && sum(!is.na(train_data$gender)) > 0 &&
                length(unique(na.omit(train_data$gender))) > 1

  # Extract exposure dates across all restaurants
  exposure_dates <- data %>%
    select(location_id, date, all_of(all_exp_cols)) %>%
    pivot_longer(cols = all_of(all_exp_cols), names_to = "exposure_col", values_to = "value") %>%
    filter(value == 1) %>%
    group_by(location_id, exposure_col) %>%
    summarise(date = min(date), .groups = "drop") %>%
    pull(date) %>%
    unique()

  form <- build_formula_pooled(outcome, include_gender = has_gender)

  tryCatch({
    model <- fepois(
      form,
      data = train_data,
      vcov = ~customer_id + location_id
    )

    train_data$pred <- predict(model, newdata = train_data, type = "response")
    test_data$pred <- predict(model, newdata = test_data, type = "response")

    train_data$split <- "train"
    test_data$split <- "test"

    pred_data <- bind_rows(train_data, test_data) %>%
      select(date, outcome_col = all_of(outcome), pred, split, customer_id, location_id)

    list(
      model = model,
      n_obs = nrow(data),
      n_train = nrow(train_data),
      n_test = nrow(test_data),
      n_customers = length(unique(data$customer_id)),
      n_restaurants = length(unique(data$location_id)),
      exposure_dates = exposure_dates,
      has_gender = has_gender,
      predictions = pred_data
    )
  }, error = function(e) {
    message(paste("Error fitting pooled model:", e$message))
    NULL
  })
}

extract_results <- function(model_result, model_type = "restaurant") {
  if (is.null(model_result)) return(NULL)

  model <- model_result$model
  coef_table <- summary(model)$coeftable

  # Convert to data frame
  results <- as.data.frame(coef_table)
  results$term <- rownames(results)
  rownames(results) <- NULL

  # Rename columns
  colnames(results) <- c("estimate", "std_error", "t_value", "p_value", "term")

  # Add confidence intervals
  results <- results %>%
    mutate(
      ci_lower = estimate - 1.96 * std_error,
      ci_upper = estimate + 1.96 * std_error
    )

  # Add metadata
  if (model_type == "restaurant") {
    results$location_id <- model_result$location_id
    results$n_obs <- model_result$n_obs
    results$n_customers <- model_result$n_customers
  } else {
    results$location_id <- "pooled"
    results$n_obs <- model_result$n_obs
    results$n_customers <- model_result$n_customers
    results$n_restaurants <- model_result$n_restaurants
  }

  results
}

save_results <- function(results, outcome, output_dir = "customer_analysis/results") {
  filename <- file.path(output_dir, paste0("conditional_poisson_", outcome, ".csv"))
  write_csv(results, filename)
  message(paste("Results saved to:", filename))
}

print_model_summary <- function(model_result) {
  if (is.null(model_result)) {
    message("Model is NULL")
    return()
  }

  cat("\n========================================\n")
  if (!is.null(model_result$location_id)) {
    cat("Restaurant:", model_result$location_id, "\n")
  } else {
    cat("Pooled Model\n")
  }
  cat("N observations:", model_result$n_obs, "\n")
  if (!is.null(model_result$n_train)) {
    cat("N train:", model_result$n_train, "\n")
    cat("N test:", model_result$n_test, "\n")
  }
  cat("N customers:", model_result$n_customers, "\n")
  if (!is.null(model_result$n_restaurants)) {
    cat("N restaurants:", model_result$n_restaurants, "\n")
  }
  cat("Has gender interactions:", model_result$has_gender, "\n")
  cat("========================================\n\n")

  print(summary(model_result$model))
}

plot_predictions <- function(pred_data, outcome_name, model_id, exposure_dates = NULL, output_dir = "customer_analysis/pred_plots") {
  if (is.null(pred_data) || nrow(pred_data) == 0) {
    message("No prediction data to plot")
    return(NULL)
  }

  # Separate train and test data
  train_data <- pred_data %>% filter(split == "train")
  test_data <- pred_data %>% filter(split == "test")

  # Aggregate by week for train data
  train_weekly <- train_data %>%
    filter(!is.na(date)) %>%
    group_by(week = floor_date(date, "week")) %>%
    summarise(
      obs = sum(outcome_col, na.rm = TRUE),
      pred = sum(pred, na.rm = TRUE),
      .groups = "drop"
    )

  # Aggregate by week for test data
  test_weekly <- test_data %>%
    filter(!is.na(date)) %>%
    group_by(week = floor_date(date, "week")) %>%
    summarise(
      obs = sum(outcome_col, na.rm = TRUE),
      pred = sum(pred, na.rm = TRUE),
      .groups = "drop"
    )

  if (nrow(train_weekly) == 0 || nrow(test_weekly) == 0) {
    message("Insufficient data for plotting")
    return(NULL)
  }

  # Create training plot
  p_train <- ggplot(train_weekly, aes(x = week)) +
    geom_line(aes(y = obs, color = "Observed")) +
    geom_line(aes(y = pred, color = "Predicted")) +
    labs(title = paste(model_id, "- Training Data"), y = "Weekly Count", x = "Week") +
    scale_color_manual(values = c("Observed" = "black", "Predicted" = "red")) +
    theme_minimal() +
    theme(legend.position = "bottom")

  # Create test plot
  p_test <- ggplot(test_weekly, aes(x = week)) +
    geom_line(aes(y = obs, color = "Observed")) +
    geom_line(aes(y = pred, color = "Predicted")) +
    labs(title = paste(model_id, "- Test Data"), y = "Weekly Count", x = "Week") +
    scale_color_manual(values = c("Observed" = "black", "Predicted" = "red")) +
    theme_minimal() +
    theme(legend.position = "bottom")

  # Add exposure dates as vertical lines if provided
  if (!is.null(exposure_dates) && length(exposure_dates) > 0) {
    p_train <- p_train + geom_vline(xintercept = exposure_dates, linetype = "dashed", color = "blue", alpha = 0.7)
    p_test <- p_test + geom_vline(xintercept = exposure_dates, linetype = "dashed", color = "blue", alpha = 0.7)
  }

  # Combine plots side by side
  combined_plot <- p_train + p_test + plot_layout(guides = "collect") & theme(legend.position = 'bottom')

  filename <- file.path(output_dir, paste0(outcome_name, "_", model_id, ".png"))
  ggsave(filename, combined_plot, width = 8, height = 4, dpi = 300)
  message(paste("Saved plot:", filename))

  invisible(combined_plot)
}


library(tidyverse)
library(dplyr)
library(grid)
library(patchwork) 


# ──────────────────────────────────
#           Plot Results
# ──────────────────────────────────

plot_ingarch <- function(
    df,
    restaurants_to_model,
    data_list,
    y_rep_mean,
    y_test_rep_mean,
    plot_dir,
    plot_daily = FALSE,
    structural_zero_prob = NULL,
    structural_zero_prob_test = NULL,
    structural_zero_threshold = 0.5) {

  print("Generating plots...")

  exposure_indicators <- df %>% ungroup %>% select(starts_with("exposure_")) %>% select(-contains("slope")) %>% colnames()
  print(exposure_indicators)
  print(data_list$R)

  exposure_dates_df <- df %>%
    select(location_id, date, any_of(exposure_indicators)) %>%
    pivot_longer(
      cols = any_of(exposure_indicators),
      names_to = "exposure_col",
      values_to = "value"
      ) %>%
      filter(value == 1) %>%
      group_by(location_id, exposure_col) %>%
      summarize(date = min(date), .groups = "drop")

  plot_data_train <- tibble(
    pred = y_rep_mean,
    obs = data_list$y_train,
    restaurant_idx = data_list$idx_to_rest_train) %>%
    mutate(time_idx = 1:n())

  # Add structural zero probabilities if provided
  if (!is.null(structural_zero_prob)) {
    plot_data_train <- plot_data_train %>%
      mutate(sz_prob = structural_zero_prob)
  }

  plot_data_test <- tibble(
    pred = y_test_rep_mean,
    obs = data_list$y_test,
    restaurant_idx = data_list$idx_to_rest_test) %>%
    mutate(time_idx = 1:n())

  # Add structural zero probabilities if provided
  if (!is.null(structural_zero_prob_test)) {
    plot_data_test <- plot_data_test %>%
      mutate(sz_prob = structural_zero_prob_test)
  }
  
  # We need the original dates back, and easiest way is to rebuild the date sequence
  # Helper df with original dates and restaurant index
  original_dates_df <- df %>%
    mutate(restaurant_idx = as.integer(location_id)) %>%
    arrange(restaurant_idx, date) %>%
    group_by(restaurant_idx) %>%
    mutate(row_in_restaurant = row_number()) %>%
    ungroup() %>%
    dplyr::select(restaurant_idx, date, row_in_restaurant)
  
  N_train_vec <- data_list$train_end_idx - data_list$train_start_idx + 1

  # Add train/test identifier and overall row index within train/test sets
  train_indices_df <- tibble(restaurant_idx = data_list$idx_to_rest_train, 
  overall_train_idx = 1:(data_list$N_train)) %>%
    group_by(restaurant_idx) %>%
    mutate(row_in_restaurant = row_number()) %>%
    ungroup()
    
  test_indices_df <- tibble(
    restaurant_idx = data_list$idx_to_rest_test,
    overall_test_idx = 1:data_list$N_test) %>%
    group_by(restaurant_idx) %>%
    # The test rows continue numbering from where train left off for that restaurant
    mutate(row_in_restaurant = row_number() + N_train_vec[first(restaurant_idx)]) %>%
    ungroup()

  # Add predictions back
  plot_data_train <- plot_data_train %>%
    left_join(train_indices_df, by = c("restaurant_idx", "time_idx" = "overall_train_idx"))
  plot_data_test <- plot_data_test %>%
    left_join(test_indices_df, by = c("restaurant_idx", "time_idx" = "overall_test_idx"))
  
  # Join with original dates
  plot_data_train <- plot_data_train %>%
    left_join(original_dates_df, by = c("restaurant_idx", "row_in_restaurant"))
  plot_data_test <- plot_data_test %>%
    left_join(original_dates_df, by = c("restaurant_idx", "row_in_restaurant"))
  
  # Generate weekly plots per restaurant
  for(i in 1:(data_list$R)) {
    loc_id <- restaurants_to_model[i]
    
    loc_exposure_dates <- exposure_dates_df %>%
      filter(location_id == loc_id) %>%
      pull(date)

    # Filter data for the current restaurant
    train_data_loc <- plot_data_train %>% filter(restaurant_idx == i)
    test_data_loc <- plot_data_test %>% filter(restaurant_idx == i)

    # Extract structural zero dates (where probability > threshold)
    train_sz_dates <- c()
    test_sz_dates <- c()
    if ("sz_prob" %in% colnames(train_data_loc)) {
      train_sz_dates <- train_data_loc %>%
        filter(!is.na(date), sz_prob > structural_zero_threshold) %>%
        pull(date)
    }
    if ("sz_prob" %in% colnames(test_data_loc)) {
      test_sz_dates <- test_data_loc %>%
        filter(!is.na(date), sz_prob > structural_zero_threshold) %>%
        pull(date)
    }

    # Aggregate weekly
    train_weekly_data <- train_data_loc %>%
      filter(!is.na(date)) %>%
      group_by(week = floor_date(date, "week")) %>%
      summarize(obs = sum(obs), pred = sum(pred), .groups = "drop")

    test_weekly_data <- test_data_loc %>%
      filter(!is.na(date)) %>%
      group_by(week = floor_date(date, "week")) %>%
      summarize(obs = sum(obs), pred = sum(pred), .groups = "drop")
    
    if (nrow(train_weekly_data) > 0 && nrow(test_weekly_data) > 0) {

      p_train <- ggplot(train_weekly_data, aes(x = week)) +
        geom_line(aes(y = obs, color = "Observed")) +
        geom_line(aes(y = pred, color = "Predicted")) +
        geom_vline(xintercept = loc_exposure_dates, linetype = "dashed", color = "blue", alpha = 0.7) +
        geom_vline(xintercept = train_sz_dates, linetype = "dashed", color = "green", alpha = 0.7) +
        labs(title = paste(loc_id, "- Training Data"), y = "Weekly Count", x = "Week") +
        scale_color_manual(values = c("Observed" = "black", "Predicted" = "red")) +
        theme_minimal() + theme(legend.position = "bottom")

      p_test <- ggplot(test_weekly_data, aes(x = week)) +
        geom_line(aes(y = obs, color = "Observed")) +
        geom_line(aes(y = pred, color = "Predicted")) +
        geom_vline(xintercept = loc_exposure_dates, linetype = "dashed", color = "blue", alpha = 0.7) +
        geom_vline(xintercept = test_sz_dates, linetype = "dashed", color = "green", alpha = 0.7) +
        labs(title = paste(loc_id, "- Test Data"), y = "Weekly Count", x = "Week") +
        scale_color_manual(values = c("Observed" = "black", "Predicted" = "red")) +
        theme_minimal() + theme(legend.position = "bottom")
      
      combined_plot <- p_train + p_test + plot_layout(guides = "collect") & theme(legend.position = 'bottom')
      
      ggsave(
        filename = file.path(plot_dir, paste0(loc_id, ".png")),
        plot     = combined_plot,
        width    = 8,         # inches
        height   = 4,         # inches
        dpi      = 300
      )

    } else {
      print(paste("Skipping plot for", loc_id, "due to missing weekly data."))
    }

    if (plot_daily && nrow(train_data_loc) > 0 && nrow(test_data_loc) > 0) {

      p_daily_train <- ggplot(train_data_loc, aes(x = date)) +
          geom_line(aes(y = obs, color = "Observed")) +
          geom_line(aes(y = pred, color = "Predicted")) +
          geom_vline(xintercept = loc_exposure_dates, linetype = "dashed", color = "blue", alpha = 0.7) +
          geom_vline(xintercept = train_sz_dates, linetype = "dashed", color = "green", alpha = 0.7) +
          labs(title = paste(loc_id, "- Training Data (Daily)"), y = "Daily Count", x = "Date") +
          scale_color_manual(values = c("Observed" = "black", "Predicted" = "red")) +
          theme_minimal() + theme(legend.position = "bottom")

      p_daily_test <- ggplot(test_data_loc, aes(x = date)) +
          geom_line(aes(y = obs, color = "Observed")) +
          geom_line(aes(y = pred, color = "Predicted")) +
          geom_vline(xintercept = loc_exposure_dates, linetype = "dashed", color = "blue", alpha = 0.7) +
          geom_vline(xintercept = test_sz_dates, linetype = "dashed", color = "green", alpha = 0.7) +
          labs(title = paste(loc_id, "- Test Data (Daily)"), y = "Daily Count", x = "Date") +
          scale_color_manual(values = c("Observed" = "black", "Predicted" = "red")) +
          theme_minimal() + theme(legend.position = "bottom")

      combined_daily_plot <- p_daily_train + p_daily_test + plot_layout(guides = "collect") & theme(legend.position = 'bottom')

      if (!dir.exists(file.path(plot_dir, 'daily'))) {
        dir.create(file.path(plot_dir, 'daily'), recursive = TRUE)}

      ggsave(
        filename = file.path(plot_dir, 'daily', paste0(loc_id, "_daily.png")),
        plot     = combined_daily_plot,
        width    = 8,         # inches
        height   = 4,         # inches
        dpi      = 300
      )
    } else {
      print(paste("Skipping daily plot for", loc_id, "due to missing daily data."))
    }
  }
}
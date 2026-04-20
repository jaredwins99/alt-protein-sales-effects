
library(tidyverse)
library(dplyr)
library(grid)
library(patchwork)


# ──────────────────────────────────
#        Professional Theme
# ──────────────────────────────────

theme_professional <- function(base_size = 14) {
  theme_bw(base_size = base_size) %+replace%
    theme(
      plot.title = element_text(size = rel(1.0), face = "bold", hjust = 0.5,
                                margin = margin(b = 4)),
      plot.subtitle = element_text(size = rel(0.9), hjust = 0.5,
                                   margin = margin(b = 10)),
      axis.title = element_text(size = rel(1.0), face = "bold"),
      axis.text = element_text(size = rel(0.85)),
      axis.title.x = element_text(margin = margin(t = 10)),
      axis.title.y = element_text(angle = 90, margin = margin(r = 10)),
      panel.border = element_rect(color = "black", fill = NA, linewidth = 0.7),
      panel.grid.major = element_line(color = "grey90", linewidth = 0.3),
      panel.grid.minor = element_blank(),
      panel.background = element_rect(fill = "white"),
      legend.title = element_blank(),
      legend.text = element_text(size = rel(0.9)),
      legend.background = element_rect(fill = alpha("white", 0.8), color = "grey80",
                                       linewidth = 0.3),
      legend.key = element_rect(fill = "white", color = NA),
      legend.margin = margin(4, 6, 4, 6),
      plot.margin = margin(10, 15, 10, 10),
      strip.background = element_rect(fill = "grey95", color = "black"),
      strip.text = element_text(face = "bold", size = rel(0.9))
    )
}


# ──────────────────────────────────
#           Plot Results
# ──────────────────────────────────
# Adapted for transaction-level Gaussian IID model.
# Predictions are per-transaction (order-level), so we aggregate to
# restaurant-week for weekly comparison plots.

plot_gaussian_iid <- function(
    df,
    restaurants_to_model,
    data_list,
    y_rep_mean,
    y_test_rep_mean,
    plot_dir,
    outcome_label = NULL) {

  print("Generating plots...")

  exposure_indicators <- df %>% ungroup %>% select(starts_with("exposure_")) %>% select(-contains("slope")) %>% colnames()
  print(exposure_indicators)

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

  # Build plot data: each row is one transaction with prediction
  plot_data_train <- tibble(
    pred = y_rep_mean,
    obs = data_list$y_train,
    restaurant_idx = data_list$idx_to_rest_train) %>%
    mutate(time_idx = 1:n())

  plot_data_test <- tibble(
    pred = y_test_rep_mean,
    obs = data_list$y_test,
    restaurant_idx = data_list$idx_to_rest_test) %>%
    mutate(time_idx = 1:n())

  # Map concatenated indices back to original dates.
  # Transaction-level: sort by (restaurant_idx, customer_id, date).
  # Day-level (no customer_id column): sort by (restaurant_idx, date).
  sort_cols <- if ("customer_id" %in% colnames(df)) {
    c("restaurant_idx", "customer_id", "date")
  } else {
    c("restaurant_idx", "date")
  }
  original_dates_df <- df %>%
    mutate(restaurant_idx = as.integer(location_id)) %>%
    arrange(across(all_of(sort_cols))) %>%
    group_by(restaurant_idx) %>%
    mutate(row_in_restaurant = row_number()) %>%
    ungroup() %>%
    dplyr::select(restaurant_idx, date, row_in_restaurant)

  N_train_vec <- data_list$train_end_idx - data_list$train_start_idx + 1

  train_indices_df <- tibble(restaurant_idx = data_list$idx_to_rest_train,
  overall_train_idx = 1:(data_list$N_train)) %>%
    group_by(restaurant_idx) %>%
    mutate(row_in_restaurant = row_number()) %>%
    ungroup()

  test_indices_df <- tibble(
    restaurant_idx = data_list$idx_to_rest_test,
    overall_test_idx = 1:data_list$N_test) %>%
    group_by(restaurant_idx) %>%
    mutate(row_in_restaurant = row_number() + N_train_vec[first(restaurant_idx)]) %>%
    ungroup()

  # Join with indices and dates
  plot_data_train <- plot_data_train %>%
    left_join(train_indices_df, by = c("restaurant_idx", "time_idx" = "overall_train_idx")) %>%
    left_join(original_dates_df, by = c("restaurant_idx", "row_in_restaurant"))

  plot_data_test <- plot_data_test %>%
    left_join(test_indices_df, by = c("restaurant_idx", "time_idx" = "overall_test_idx")) %>%
    left_join(original_dates_df, by = c("restaurant_idx", "row_in_restaurant"))

  # ──────────────────────────────────
  #   Per-Restaurant Weekly Plots
  # ──────────────────────────────────
  # Aggregate transaction-level predictions to weekly sums per restaurant

  for(i in 1:(data_list$R)) {
    loc_id <- restaurants_to_model[i]

    loc_exposure_dates <- exposure_dates_df %>%
      filter(location_id == loc_id) %>%
      pull(date)

    train_data_loc <- plot_data_train %>% filter(restaurant_idx == i)
    test_data_loc <- plot_data_test %>% filter(restaurant_idx == i)

    # Aggregate to weekly sums
    train_weekly_data <- train_data_loc %>%
      filter(!is.na(date)) %>%
      group_by(week = floor_date(date, "week")) %>%
      summarize(obs = sum(obs), pred = sum(pred), n_transactions = n(), .groups = "drop")

    test_weekly_data <- test_data_loc %>%
      filter(!is.na(date)) %>%
      group_by(week = floor_date(date, "week")) %>%
      summarize(obs = sum(obs), pred = sum(pred), n_transactions = n(), .groups = "drop")

    if (nrow(train_weekly_data) > 0 && nrow(test_weekly_data) > 0) {

      p_train <- ggplot(train_weekly_data, aes(x = week)) +
        geom_line(aes(y = obs, color = "Observed"), linewidth = 0.7) +
        geom_line(aes(y = pred, color = "Predicted"), linewidth = 0.7) +
        geom_vline(xintercept = loc_exposure_dates, linetype = "dashed", color = "steelblue3", alpha = 0.8, linewidth = 1.2) +
        labs(title = "Training Data", y = "Weekly Demeaned Sum", x = "Week") +
        scale_color_manual(values = c("Observed" = "grey30", "Predicted" = "coral2")) +
        theme_professional()

      p_test <- ggplot(test_weekly_data, aes(x = week)) +
        geom_line(aes(y = obs, color = "Observed"), linewidth = 0.7) +
        geom_line(aes(y = pred, color = "Predicted"), linewidth = 0.7) +
        geom_vline(xintercept = loc_exposure_dates, linetype = "dashed", color = "steelblue3", alpha = 0.8, linewidth = 1.2) +
        labs(title = "Test Data", y = "Weekly Demeaned Sum", x = "Week") +
        scale_color_manual(values = c("Observed" = "grey30", "Predicted" = "coral2")) +
        theme_professional()

      weekly_subtitle <- if (!is.null(outcome_label)) paste0(outcome_label, " (Pre-Period Demeaned) — Observed vs. Predicted") else "Pre-Period Demeaned — Observed vs. Predicted"
      combined_plot <- p_train + p_test +
        plot_annotation(title = loc_id, subtitle = weekly_subtitle,
                        theme = theme(
                          plot.title = element_text(size = 18, face = "bold", hjust = 0.5),
                          plot.subtitle = element_text(size = 13, hjust = 0.5))) +
        plot_layout(guides = "collect") &
        theme(legend.position = "bottom")

      ggsave(
        filename = file.path(plot_dir, paste0(loc_id, ".png")),
        plot     = combined_plot,
        width    = 10,
        height   = 5,
        dpi      = 300
      )

    } else {
      print(paste("Skipping plot for", loc_id, "due to missing weekly data."))
    }
  }

  # ──────────────────────────────────
  #   All Restaurants Weekly Combined
  # ──────────────────────────────────

  n_restaurants <- length(restaurants_to_model)
  plot_list <- list()

  for (i in 1:n_restaurants) {
    loc_id <- restaurants_to_model[i]

    loc_exposure_dates <- exposure_dates_df %>%
      filter(location_id == loc_id) %>%
      pull(date)

    train_loc <- plot_data_train %>% filter(restaurant_idx == i, !is.na(date))
    test_loc <- plot_data_test %>% filter(restaurant_idx == i, !is.na(date))

    train_weekly <- train_loc %>%
      group_by(week = floor_date(date, "week")) %>%
      summarize(obs = sum(obs), pred = sum(pred), .groups = "drop")

    test_weekly <- test_loc %>%
      group_by(week = floor_date(date, "week")) %>%
      summarize(obs = sum(obs), pred = sum(pred), .groups = "drop")

    combined_weekly <- bind_rows(train_weekly, test_weekly)

    if (nrow(combined_weekly) == 0) next

    train_test_boundary <- max(train_loc$date, na.rm = TRUE)

    p <- ggplot(combined_weekly, aes(x = week)) +
      geom_line(aes(y = obs, color = "Observed"), linewidth = 0.5) +
      geom_line(aes(y = pred, color = "Predicted"), linewidth = 0.5) +
      geom_vline(xintercept = loc_exposure_dates, linetype = "dashed", color = "steelblue3", alpha = 0.8, linewidth = 1.0) +
      geom_vline(xintercept = train_test_boundary, linetype = "dotted", color = "grey50", linewidth = 0.8) +
      scale_color_manual(values = c("Observed" = "grey30", "Predicted" = "coral2")) +
      labs(title = loc_id, y = "Weekly Demeaned Sum", x = NULL) +
      theme_professional(base_size = 11) +
      theme(
        plot.title = element_text(size = 11, face = "bold", hjust = 0),
        legend.position = "none"
      )

    plot_list[[i]] <- p
  }

  if (length(plot_list) > 0) {

    all_title <- if (!is.null(outcome_label)) paste0(outcome_label, " (Pre-Period Demeaned) — All Restaurants") else "All Restaurants (Pre-Period Demeaned)"
    all_subtitle <- "Weekly Observed vs. Predicted (Training + Test)"
    plot_height <- max(6, n_restaurants * 2.5)

    combined_all <- wrap_plots(plot_list, ncol = 1) +
      plot_annotation(
        title = all_title,
        subtitle = all_subtitle,
        theme = theme(
          plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
          plot.subtitle = element_text(size = 12, hjust = 0.5)
        )
      ) &
      theme(legend.position = "bottom")

    ggsave(
      filename = file.path(plot_dir, "all_restaurants_weekly.png"),
      plot     = combined_all,
      width    = 10,
      height   = plot_height,
      dpi      = 300
    )

    # Date-aligned version
    all_weekly_data <- bind_rows(
      plot_data_train %>% filter(!is.na(date)) %>%
        mutate(loc_id = restaurants_to_model[restaurant_idx]) %>%
        group_by(loc_id, week = floor_date(date, "week")) %>%
        summarize(obs = sum(obs), pred = sum(pred), .groups = "drop"),
      plot_data_test %>% filter(!is.na(date)) %>%
        mutate(loc_id = restaurants_to_model[restaurant_idx]) %>%
        group_by(loc_id, week = floor_date(date, "week")) %>%
        summarize(obs = sum(obs), pred = sum(pred), .groups = "drop")
    )

    if (nrow(all_weekly_data) > 0) {
      p_aligned <- ggplot(all_weekly_data, aes(x = week)) +
        geom_line(aes(y = obs, color = "Observed"), linewidth = 0.5) +
        geom_line(aes(y = pred, color = "Predicted"), linewidth = 0.5) +
        facet_wrap(~ loc_id, scales = "free_y", ncol = 2) +
        scale_color_manual(values = c("Observed" = "grey30", "Predicted" = "coral2")) +
        labs(
          title = all_title,
          subtitle = "Date-Aligned",
          y = "Weekly Demeaned Sum", x = "Week"
        ) +
        theme_professional(base_size = 11) +
        theme(legend.position = "bottom")

      ggsave(
        filename = file.path(plot_dir, "all_restaurants_weekly_aligned.png"),
        plot     = p_aligned,
        width    = 12,
        height   = max(5, ceiling(n_restaurants / 2) * 3),
        dpi      = 300
      )
    }
  }
}

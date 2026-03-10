
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
# Adapted from plot_ingarch for Gaussian demeaned customer model.
# Key differences:
#   - Y-axis labels use "Demeaned Sum" (values can be negative)
#   - Closed-day rug ticks use idx_total_nonzero if available

plot_customer_gaussian <- function(
    df,
    restaurants_to_model,
    data_list,
    y_rep_mean,
    y_test_rep_mean,
    plot_dir,
    outcome_label = NULL,
    plot_daily = TRUE) {

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

  # Identify closed days if idx_total_nonzero is available
  has_closed_idx <- !is.null(data_list$idx_total_nonzero)
  if (has_closed_idx) {
    is_closed_train <- !(1:length(y_rep_mean) %in% data_list$idx_total_nonzero)
    is_closed_test  <- !(1:length(y_test_rep_mean) %in% data_list$idx_total_nonzero_test)
  } else {
    is_closed_train <- rep(FALSE, length(y_rep_mean))
    is_closed_test  <- rep(FALSE, length(y_test_rep_mean))
  }

  plot_data_train <- tibble(
    pred = y_rep_mean,
    obs = data_list$y_train,
    restaurant_idx = data_list$idx_to_rest_train,
    closed = is_closed_train) %>%
    mutate(time_idx = 1:n())

  plot_data_test <- tibble(
    pred = y_test_rep_mean,
    obs = data_list$y_test,
    restaurant_idx = data_list$idx_to_rest_test,
    closed = is_closed_test) %>%
    mutate(time_idx = 1:n())

  # We need the original dates back
  original_dates_df <- df %>%
    mutate(restaurant_idx = as.integer(location_id)) %>%
    arrange(restaurant_idx, date) %>%
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

  # ──────────────────────────────────
  #   Per-Restaurant Weekly Plots
  # ──────────────────────────────────

  for(i in 1:(data_list$R)) {
    loc_id <- restaurants_to_model[i]

    loc_exposure_dates <- exposure_dates_df %>%
      filter(location_id == loc_id) %>%
      pull(date)

    train_data_loc <- plot_data_train %>% filter(restaurant_idx == i)
    test_data_loc <- plot_data_test %>% filter(restaurant_idx == i)

    # Closed-day dates for rug ticks
    train_closed_dates <- train_data_loc %>% filter(!is.na(date), closed == TRUE) %>% pull(date)
    test_closed_dates <- test_data_loc %>% filter(!is.na(date), closed == TRUE) %>% pull(date)

    # Aggregate weekly (sum all days)
    train_weekly_data <- train_data_loc %>%
      filter(!is.na(date)) %>%
      group_by(week = floor_date(date, "week")) %>%
      summarize(obs = sum(obs), pred = sum(pred), .groups = "drop")

    test_weekly_data <- test_data_loc %>%
      filter(!is.na(date)) %>%
      group_by(week = floor_date(date, "week")) %>%
      summarize(obs = sum(obs), pred = sum(pred), .groups = "drop")

    train_closed_weeks <- if (length(train_closed_dates) > 0) tibble(x = unique(floor_date(train_closed_dates, "week"))) else tibble(x = as.Date(character(0)))
    test_closed_weeks  <- if (length(test_closed_dates) > 0) tibble(x = unique(floor_date(test_closed_dates, "week"))) else tibble(x = as.Date(character(0)))

    if (nrow(train_weekly_data) > 0 && nrow(test_weekly_data) > 0) {

      p_train <- ggplot(train_weekly_data, aes(x = week)) +
        geom_line(aes(y = obs, color = "Observed"), linewidth = 0.7) +
        geom_line(aes(y = pred, color = "Predicted"), linewidth = 0.7) +
        geom_vline(xintercept = loc_exposure_dates, linetype = "dashed", color = "steelblue3", alpha = 0.8, linewidth = 1.2) +
        { if (nrow(train_closed_weeks) > 0) geom_rug(data = train_closed_weeks, aes(x = x), sides = "b", color = "seagreen3", alpha = 0.6, length = unit(0.03, "npc"), linewidth = 0.4) } +
        labs(title = "Training Data", y = "Weekly Demeaned Sum", x = "Week") +
        scale_color_manual(values = c("Observed" = "grey30", "Predicted" = "coral2")) +
        theme_professional()

      p_test <- ggplot(test_weekly_data, aes(x = week)) +
        geom_line(aes(y = obs, color = "Observed"), linewidth = 0.7) +
        geom_line(aes(y = pred, color = "Predicted"), linewidth = 0.7) +
        geom_vline(xintercept = loc_exposure_dates, linetype = "dashed", color = "steelblue3", alpha = 0.8, linewidth = 1.2) +
        { if (nrow(test_closed_weeks) > 0) geom_rug(data = test_closed_weeks, aes(x = x), sides = "b", color = "seagreen3", alpha = 0.6, length = unit(0.03, "npc"), linewidth = 0.4) } +
        labs(title = "Test Data", y = "Weekly Demeaned Sum", x = "Week") +
        scale_color_manual(values = c("Observed" = "grey30", "Predicted" = "coral2")) +
        theme_professional()

      weekly_subtitle <- if (!is.null(outcome_label)) paste0(outcome_label, " (Demeaned) — Observed vs. Predicted") else "Demeaned — Observed vs. Predicted"
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

    # ──────────────────────────────────
    #   Per-Restaurant Daily Plots
    # ──────────────────────────────────

    if (plot_daily && nrow(train_data_loc) > 0 && nrow(test_data_loc) > 0) {

      train_closed_rug <- if (length(train_closed_dates) > 0) tibble(x = train_closed_dates) else tibble(x = as.Date(character(0)))
      test_closed_rug  <- if (length(test_closed_dates) > 0) tibble(x = test_closed_dates) else tibble(x = as.Date(character(0)))

      p_daily_train <- ggplot(train_data_loc, aes(x = date)) +
          geom_line(aes(y = obs, color = "Observed"), linewidth = 0.7) +
          geom_line(aes(y = pred, color = "Predicted"), linewidth = 0.7) +
          geom_vline(xintercept = loc_exposure_dates, linetype = "dashed", color = "steelblue3", alpha = 0.8, linewidth = 1.2) +
          { if (nrow(train_closed_rug) > 0) geom_rug(data = train_closed_rug, aes(x = x), sides = "b", color = "seagreen3", alpha = 0.6, length = unit(0.03, "npc"), linewidth = 0.4) } +
          labs(title = "Training Data (Daily)", y = "Daily Demeaned Sum", x = "Date") +
          scale_color_manual(values = c("Observed" = "grey30", "Predicted" = "coral2")) +
          theme_professional()

      p_daily_test <- ggplot(test_data_loc, aes(x = date)) +
          geom_line(aes(y = obs, color = "Observed"), linewidth = 0.7) +
          geom_line(aes(y = pred, color = "Predicted"), linewidth = 0.7) +
          geom_vline(xintercept = loc_exposure_dates, linetype = "dashed", color = "steelblue3", alpha = 0.8, linewidth = 1.2) +
          { if (nrow(test_closed_rug) > 0) geom_rug(data = test_closed_rug, aes(x = x), sides = "b", color = "seagreen3", alpha = 0.6, length = unit(0.03, "npc"), linewidth = 0.4) } +
          labs(title = "Test Data (Daily)", y = "Daily Demeaned Sum", x = "Date") +
          scale_color_manual(values = c("Observed" = "grey30", "Predicted" = "coral2")) +
          theme_professional()

      daily_subtitle <- if (!is.null(outcome_label)) paste0(outcome_label, " (Demeaned) — Daily") else "Demeaned — Daily"
      combined_daily_plot <- p_daily_train + p_daily_test +
        plot_annotation(title = loc_id, subtitle = daily_subtitle,
                        theme = theme(
                          plot.title = element_text(size = 18, face = "bold", hjust = 0.5),
                          plot.subtitle = element_text(size = 13, hjust = 0.5))) +
        plot_layout(guides = "collect") &
        theme(legend.position = "bottom")

      if (!dir.exists(file.path(plot_dir, 'daily'))) {
        dir.create(file.path(plot_dir, 'daily'), recursive = TRUE)}

      ggsave(
        filename = file.path(plot_dir, 'daily', paste0(loc_id, "_daily.png")),
        plot     = combined_daily_plot,
        width    = 10,
        height   = 5,
        dpi      = 300
      )
    } else {
      print(paste("Skipping daily plot for", loc_id, "due to missing daily data."))
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

    closed_dates <- c(
      train_loc %>% filter(closed == TRUE) %>% pull(date),
      test_loc %>% filter(closed == TRUE) %>% pull(date)
    )
    closed_rug <- if (length(closed_dates) > 0) tibble(x = unique(floor_date(closed_dates, "week"))) else tibble(x = as.Date(character(0)))

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
      { if (nrow(closed_rug) > 0) geom_rug(data = closed_rug, aes(x = x), sides = "b", color = "seagreen3", alpha = 0.6, length = unit(0.03, "npc"), linewidth = 0.4) } +
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

    all_title <- if (!is.null(outcome_label)) paste0(outcome_label, " (Demeaned) — All Restaurants") else "All Restaurants (Demeaned)"
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

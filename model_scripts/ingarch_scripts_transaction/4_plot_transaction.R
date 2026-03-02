
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

plot_transaction <- function(
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

  # ────────────────────────────
  # Build per-transaction prediction data with dates and restaurant mapping
  # Transactions are mapped back to dates via df (which preserves the row order)

  # Reconstruct date and restaurant for train/test from the scaled df
  train_df <- df %>%
    filter(train_test == "train") %>%
    ungroup() %>%
    select(date, location_id, location_id_num)

  test_df <- df %>%
    filter(train_test == "test") %>%
    ungroup() %>%
    select(date, location_id, location_id_num)

  plot_data_train <- tibble(
    pred = y_rep_mean,
    obs = data_list$y_train,
    date = train_df$date,
    restaurant_idx = train_df$location_id_num)

  plot_data_test <- tibble(
    pred = y_test_rep_mean,
    obs = data_list$y_test,
    date = test_df$date,
    restaurant_idx = test_df$location_id_num)

  # Generate weekly plots per restaurant
  for(i in 1:(data_list$R)) {
    loc_id <- restaurants_to_model[i]

    loc_exposure_dates <- exposure_dates_df %>%
      filter(location_id == loc_id) %>%
      pull(date)

    # Filter data for the current restaurant
    train_data_loc <- plot_data_train %>% filter(restaurant_idx == i)
    test_data_loc <- plot_data_test %>% filter(restaurant_idx == i)

    # Aggregate to weekly (sum transactions per week)
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
        geom_line(aes(y = obs, color = "Observed"), linewidth = 0.7) +
        geom_line(aes(y = pred, color = "Predicted"), linewidth = 0.7) +
        geom_vline(xintercept = loc_exposure_dates, linetype = "dashed", color = "steelblue3", alpha = 0.8, linewidth = 1.2) +
        labs(title = "Training Data", y = "Weekly Count", x = "Week") +
        scale_color_manual(values = c("Observed" = "grey30", "Predicted" = "coral2")) +
        theme_professional()

      p_test <- ggplot(test_weekly_data, aes(x = week)) +
        geom_line(aes(y = obs, color = "Observed"), linewidth = 0.7) +
        geom_line(aes(y = pred, color = "Predicted"), linewidth = 0.7) +
        geom_vline(xintercept = loc_exposure_dates, linetype = "dashed", color = "steelblue3", alpha = 0.8, linewidth = 1.2) +
        labs(title = "Test Data", y = "Weekly Count", x = "Week") +
        scale_color_manual(values = c("Observed" = "grey30", "Predicted" = "coral2")) +
        theme_professional()

      weekly_subtitle <- if (!is.null(outcome_label)) paste0(outcome_label, " — Observed vs. Predicted (Transaction)") else "Observed vs. Predicted (Transaction)"
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
}

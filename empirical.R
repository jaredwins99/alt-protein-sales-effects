library(cmdstanr)
library(posterior)
library(tidyverse)
library(arrow)

print(5)

source("tools/modeling_functions.R")

set.seed(123)

df_all_daily <- read_parquet("data/all_locations_daily_weather_inflation.parquet")

bad_restaurants <- c(
  "AQD04SM0J92WA", "LBMCPAYT7W36V", "L3XS7WSJ4AJA3", "1G5AJ17XCH2A8",
  "3AXDVZJYN9DRS", "MS8R16DY0JQAM", "N0PC58FB2XAZ3", "ADPFRN3QZRCXK",
  "WJA3YCD4QBWRX", "0RJH3FFPYBPEY", "LZ5MR1TS37E7W"
)



restaurants_by_coverage <- read.csv("data/restaurants_by_4m_coverage.csv") %>%
  filter(!(location_id %in% bad_restaurants)) %>%
  filter(!(location_id %in% c("75WYSXR9QBK5M",
                              "CB2KHY1C2G9PT",
                              "V3Q26BHF3SE2H", # missing weather data
                              "LFZFT3VASXPED", # missing weather data
                              "LQ5EH4BKGV61T", # failing to fit
                              "LBZEEFSBJNB3Z"))) %>% # failing to fit
  pull(location_id)

restaurants_by_coverage

for (loc_id in restaurants_by_coverage) {

  df_loc <- df_all_daily %>% filter(location_id == loc_id)
    # 1. Randomly split into train/test (75% train)
  n <- nrow(df_loc)
  df_loc_train <- df_loc[1:floor(0.75 * n), ]
  df_loc_test  <- df_loc[(floor(0.75 * n)+1):n, ]

  # 1. Get names of numeric columns (excluding outcome and date)
  numeric_cols <- df_loc_train %>%
    dplyr::select(-date, -location_id, -contains("cat"), -season, -weekend, -nonvegan_outcome, -vegan_outcome) %>%
    dplyr::select(where(is.numeric)) %>%
    colnames()

  # 2. Define a function to scale using training mean and sd
  scale_with_train_stats <- function(train_df, test_df, cols) {
    means <- map_dbl(train_df[cols], mean, na.rm = TRUE)
    sds   <- map_dbl(train_df[cols], sd, na.rm = TRUE)
    
    scale_fn <- function(df) {
      df[cols] <- map2_dfc(df[cols], cols, ~ (.x - means[.y]) / sds[.y])
      df
    }
    
    list(
      train = scale_fn(train_df),
      test  = scale_fn(test_df)
    )
  }

  # 3. Apply scaling
  scaled_data <- scale_with_train_stats(df_loc_train, df_loc_test, numeric_cols)
  df_loc_train <- scaled_data$train
  df_loc_test  <- scaled_data$test

  outcome <- "vegan_outcome"

  predictors <- c(
    "vegan_price_real",
    "meat_price_real",
    "day_of_week_cat",
    "weekend",
    "month_cat",
    "season",
    "year",
    "inflation",
    "temp",
    "precip"
  )

  formula_var <- ~ 1 + vegan_price_real + meat_price_real +
    day_of_week_cat + weekend +
    month_cat + season + year +
    inflation + temp + precip

  X_train <- model.matrix(formula_var, data = df_loc_train)
  X_test  <- model.matrix(formula_var, data = df_loc_test)
  y_train <- df_loc_train[[outcome]]
  y_test  <- df_loc_test[[outcome]]

  # Compile the Stan model using cmdstanr
  mod <- cmdstan_model("model.stan")

  # Define dimensions and lag orders
  N_train <- X_train %>% nrow()
  N_test  <- X_test %>% nrow()
  K       <- X_train %>% ncol()
  p <- 56   # lag order for counts
  q <- 56   # lag order for intensities
  p_effective <- 14
  q_effective <- 14
  effective_lags_alpha <- c(1,2,3,4,5,6,7,14,21,28,35,42,49,56)
  effective_lags_delta <- c(1,2,3,4,5,6,7,14,21,28,35,42,49,56)

  # Hyperprior parameter inputs
  beta_scale_input <- rep(1, K)
  alpha_scale_input <- seq(0.03,0.03,length.out=p)
  delta_scale_input <- seq(0.03,0.03,length.out=q)

  # Prepare data list for Stan
  data_list <- list(
    K = K,
    p = p,
    q = q,
    p_effective = p_effective,
    q_effective = q_effective,
    effective_lags_alpha = effective_lags_alpha,
    effective_lags_delta = effective_lags_delta,
    N_train = N_train,
    X_train = X_train,
    y_train = y_train,
    N_test = N_test,
    X_test = X_test,
    y_test = y_test,
    # beta_scale = ,
    # alpha_scale = ,
    # delta_scale = ,
    beta_hyper = 10,
    alpha_hyper = 10,
    delta_hyper = 10
  )

  alpha_init <- rep(0, p_effective)
  if (p_effective >= 1) alpha_init[1] <- 0.1
  if (p_effective >= 2) alpha_init[2] <- 0
  if (p_effective >= 3) alpha_init[3] <- 0
  if (p_effective >= 4) alpha_init[4] <- 0
  if (p_effective >= 5) alpha_init[5] <- 0
  if (p_effective >= 6) alpha_init[6] <- 0
  if (p_effective >= 7) alpha_init[7] <- 0.1

  delta_init <- rep(0, q_effective)
  if (q_effective >= 1) delta_init[1] <- 0.1
  if (q_effective >= 2) delta_init[2] <- 0
  if (q_effective >= 3) delta_init[3] <- 0
  if (q_effective >= 4) delta_init[4] <- 0
  if (q_effective >= 5) delta_init[5] <- 0
  if (q_effective >= 6) delta_init[6] <- 0
  if (q_effective >= 7) delta_init[7] <- 0.1

  init_fn <- function() {
    list(
      beta = rep(0.5, K),
      alpha = alpha_init,
      delta = delta_init, 
      beta_scale = rep(1, K),
      alpha_scale = rep(0.03, p_effective),
      delta_scale = rep(0.03, q_effective),
      phi = 5
    )
  }

  # Fit the model
  fit <- mod$sample(
    data = data_list,
    seed = 123,
    chains = 10,
    parallel_chains = 10,
    iter_warmup = 500,
    iter_sampling = 1500,
    init = init_fn,
    adapt_delta = 0.8,   # increase adapt_delta to reduce divergences
    max_treedepth = 10    # increase max_treedepth to allow deeper exploration
  )

  # Get full summary once
  summ <- fit$summary()

  # Filter for parameter names containing one of the target substrings
  param_names <- summ$variable
  target_vars <- grepl("beta|alpha|delta|phi", param_names)

  # Subset the summary
  filtered_summ <- summ[target_vars, ]

  # Get named vector of means
  means_named <- setNames(filtered_summ$mean, filtered_summ$variable)
  
  saveRDS(means_named, paste0("model_fits/empirical/vegan/params_mean_", loc_id, ".rds"))

  # Extract posterior predictive draws and log likelihood
  y_rep_df <- as_draws_df(fit$draws("y_rep"))
  y_test_rep_df <- as_draws_df(fit$draws("y_test_rep"))

  # Remove metadata columns (.chain, .iteration, .draw)
  y_rep_df <- y_rep_df %>% dplyr::select(starts_with("y_rep"))
  y_test_rep_df <- y_test_rep_df %>% dplyr::select(starts_with("y_test_rep"))

  # Compute the posterior predictive mean for each test time point
  y_pred_mean <- colMeans(as_draws_matrix(fit$draws("y_rep")))
  y_test_pred_mean <- colMeans(as_draws_matrix(fit$draws("y_test_rep")))
  saveRDS(y_pred_mean, paste0("model_fits/empirical/vegan/y_pred_mean_", loc_id, ".rds"))
  saveRDS(y_test_pred_mean, paste0("model_fits/empirical/vegan/y_test_pred_mean_", loc_id, ".rds"))

  # # Print a summary of the results
  # print(summ, n=40)

  # Save
  saveRDS(summ, paste0("model_fits/empirical/vegan/summ_", loc_id, ".rds"))
  saveRDS(fit, paste0("model_fits/empirical/vegan/fit_", loc_id, ".rds"))

  # fit <- readRDS(paste0("model_fits/empirical/fit_", loc_id, ".rds"))

  # print(fit$summary(), n=40)

  # y_test_pred_mean <- readRDS(paste0("model_fits/empirical/y_test_pred_mean_", loc_id, ".rds"))

  # train_weekly_data <- df_loc_train %>%
  #   dplyr::select(date) %>%
  #   cbind(y_train, y_pred_mean) %>%
  #   group_by(week= floor_date(date, "week")) %>%
  #   summarize(obs = sum(y_train), pred = sum(y_pred_mean), .groups = "drop") %>%
  #   identity()

  # test_weekly_data <- df_loc_test %>%
  #   dplyr::select(date) %>%
  #   cbind(y_test, y_test_pred_mean) %>%
  #   group_by(week = floor_date(date, "week")) %>% 
  #   summarize(obs = sum(y_test),
  #             pred = sum(y_test_pred_mean), .groups = "drop") %>%
  #   identity()

  # n_test_weekly <- nrow(weekly_data)


  # # Plot observed test counts vs. posterior predictive mean
  # plot(1:n_test_weekly, weekly_data$y_test, type = "l", col = "black", lwd = 2,
  #     main = "Test Data: Observed vs. Predicted Counts",
  #     xlab = "Test Time Point", ylab = "Count")
  # lines(1:n_test_weekly, weekly_data$y_test_pred_mean, col = "red", lwd = 2)
  # legend("topright", legend = c("Observed", "Predicted"),
  #       col = c("black", "red"), lwd = 2)


  # pred_plot <- plot_train_test_side_by_side(loc_id, train_weekly_data, test_weekly_data, ar_label = "All", mean_label = "All")

  # png(paste0("model_fits/empirical/plots/",loc_id,".png"), width = 2400, height = 1600, res = 300)
  # grid.draw(pred_plot)
  # dev.off()

  
}

library(cmdstanr)
library(posterior)
library(tidyverse)
library(arrow)
library(dplyr)

print(5)

source("tools/modeling_functions.R")

set.seed(123)

df_all_daily <- read_parquet("data/5_palate_data_parquet_modeling/all_locations_daily_weather_inflation.parquet") %>% 
  filter(location_id != "2HRX9P6HKXA8V" | '2019-01-01' < date & date < '2021-05-01') %>%
  filter(location_id != "JHDN7CF1C03X5" | '2019-04-01' < date & date < '2023-06-01') %>%
  filter(location_id != "EMBVNVD207CC6" | '2016-06-01' < date & date < '2022-09-01') %>%
  filter(location_id != "LBZEEFSBJNB3Z" | '2021-09-01' < date & date < '2023-07-01') %>%
  filter(location_id != "CB2KHY1C2G9PT" | '2020-06-01' < date & date < '2023-04-01') %>%
  filter(location_id != "LFZFT3VASXPED" | '2021-10-01' < date & date < '2022-11-01') %>%
  filter(location_id != "75WYSXR9QBK5M" | '2022-05-01' < date & date < '2023-07-01')

restaurants_by_coverage <- c(
  'VLZX7K2M9QD4T',
  'SRQS8F7JWA9MZ',
  '2HRX9P6HKXA8V',
  'JHDN7CF1C03X5',
  'L69HYJ4Y3TR91',
  'ED5J990H5VAZT',
  'W8T41JZK0ZMEP',
  'EMBVNVD207CC6',
  'C0BE4NDSW26QN',
  '75WYSXR9QBK5M',
  'V3Q26BHF3SE2H',
  'LBZEEFSBJNB3Z',
  'SAFK7ND1HR6XS',
  'CB2KHY1C2G9PT',
  'S8MT0YGD2KTN9',
  'LFZFT3VASXPED',
  '1SQPTEGYPH0GA',
  '9XKJD8DQTH559',
  'LQ5EH4BKGV61T',
  '78AY09MVJVTYE')

# df_all_daily %>% filter(location_id %in% restaurants_by_coverage) %>% is.na() %>% colSums()

predictors <- c(
    "vegan_price_real",
    "meat_price_real",
    "day_of_week_cat",
    "weekend",
    "inflation",
    "temp",
    "precip"
  )

formula_var <- ~ 1 + vegan_price_real + meat_price_real +
    day_of_week_cat + weekend +
    inflation + temp + precip

outcome_str <- "nonvegan"
outcome <- paste0(outcome_str, "_outcome")

for (loc_id in restaurants_by_coverage[1:1]) {

  df_loc <- df_all_daily %>% filter(location_id == loc_id)
    # 1. Randomly split into train/test (75% train)
  n <- nrow(df_loc)
  df_loc_train <- df_loc[1:floor(0.75 * n), ]
  df_loc_test  <- df_loc[(floor(0.75 * n)+1):n, ]

  # 1. Get names of numeric columns (excluding outcome and date)
  numeric_cols <- df_loc_train %>%
    dplyr::select(-date, -location_id, -contains("day_of"), -contains("cat"), -season, -weekend, -nonvegan_outcome, -vegan_outcome, vegetarian_outcome, meat_outcome) %>%
    dplyr::select(where(is.numeric)) %>%
    # dplyr::select(where(~ sd(.x, na.rm=TRUE) > 0)) %>%
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

  X_train <- model.matrix(formula_var, data = df_loc_train)
  X_test  <- model.matrix(formula_var, data = df_loc_test)
  y_train <- df_loc_train[[outcome]]
  y_test  <- df_loc_test[[outcome]]

  # Compile the Stan model using cmdstanr
  mod <- cmdstan_model("model_fixed_lasso.stan")

  # Define dimensions and lag orders
  N_train <- X_train %>% nrow()
  N_test  <- X_test %>% nrow()
  J       <- X_train %>% ncol()
  p <- 56   # lag order for counts
  q <- 56   # lag order for intensities
  effective_lags_alpha <- c(1,2,3,4,5,6,7,14,21,28,35,42)
  effective_lags_delta <- c(1,2,3,4,5,6,7,14,21,28,35,42)
  p_effective <- length(effective_lags_alpha)
  q_effective <- length(effective_lags_delta)

  # Hyperprior parameter inputs
  beta_scale_input <- rep(1, J)
  alpha_scale_input <- seq(0.05,0.01,length.out=p)
  delta_scale_input <- seq(0.05,0.01,length.out=q)

  # Prepare data list for Stan
  data_list <- list(
    J = J,
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
    beta_scale = beta_scale_input,
    alpha_scale = alpha_scale_input,
    delta_scale = delta_scale_input
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
      beta = rep(0.5, J),
      alpha = alpha_init,
      delta = delta_init, 
      phi = 5
    )
  }


  # if (file.exists(paste0("model_fits/empirical/simple/", outcome_str, "/fit_", loc_id, ".rds"))) {
  #   fit <- readRDS(paste0("model_fits/empirical/simple/", outcome_str, "/fit_", loc_id, ".rds"))
  # }
  # else {
    # Fit the model
  fit <- mod$sample(
    data = data_list,
    seed = 123,
    chains = 3,
    parallel_chains = 3,
    iter_warmup = 500,
    iter_sampling = 2000, # 1500
    init = init_fn,
    adapt_delta = 0.9,   # increase adapt_delta to reduce divergences # 0.8
    max_treedepth = 14    # increase max_treedepth to allow deeper exploration # 10
  )
  # }
  saveRDS(fit, paste0("model_fits/empirical/simple/", outcome_str, "/fit_", loc_id, ".rds"))
  
  # Get full summary once
  summ <- fit$summary()
  saveRDS(summ, paste0("model_fits/empirical/simple/", outcome_str, "/summ_", loc_id, ".rds"))

  # Filter for parameter names containing one of the target substrings
  param_names <- summ$variable
  target_vars <- grepl("beta|alpha|delta|phi", param_names)

  # Subset the summary
  filtered_summ <- summ[target_vars, ]

  # Get named vector of means
  means_named <- setNames(filtered_summ$mean, filtered_summ$variable)
  
  saveRDS(means_named, paste0("model_fits/empirical/simple/", outcome_str, "/params_mean_", loc_id, ".rds"))

  # Extract posterior predictive draws and log likelihood
  y_rep_df <- as_draws_df(fit$draws("y_rep"))
  y_test_rep_df <- as_draws_df(fit$draws("y_test_rep"))

  # Remove metadata columns (.chain, .iteration, .draw)
  y_rep_df <- y_rep_df %>% dplyr::select(starts_with("y_rep"))
  y_test_rep_df <- y_test_rep_df %>% dplyr::select(starts_with("y_test_rep"))

  
  # Compute the posterior predictive mean for each test time point
  y_pred_mean <- colMeans(as_draws_matrix(fit$draws("y_rep")))
  y_test_pred_mean <- colMeans(as_draws_matrix(fit$draws("y_test_rep")))
  saveRDS(y_pred_mean, paste0("model_fits/empirical/simple/", outcome_str, "/y_pred_mean_", loc_id, ".rds"))
  saveRDS(y_test_pred_mean, paste0("model_fits/empirical/simple/", outcome_str, "/y_test_pred_mean_", loc_id, ".rds"))

  # # Print a summary of the results
  # print(summ, n=40)

  ########################################

  # fit <- readRDS(paste0("model_fits/empirical/simple/", outcome_str, "/fit_", loc_id, ".rds"))

  #print(fit$summary(), n=40)

  y_pred_mean <- readRDS(paste0("model_fits/empirical/simple/", outcome_str, "/y_pred_mean_", loc_id, ".rds"))
  y_test_pred_mean <- readRDS(paste0("model_fits/empirical/simple/", outcome_str, "/y_test_pred_mean_", loc_id, ".rds"))

  length(y_train)
  length(y_pred_mean)
  length(y_test_pred_mean)

  train_weekly_data <- df_loc_train %>%
    dplyr::select(date) %>%
    cbind(y_train, y_pred_mean) %>%
    group_by(week= floor_date(date, "week")) %>%
    summarize(obs = sum(y_train), pred = sum(y_pred_mean), .groups = "drop") %>%
    identity()

  test_weekly_data <- df_loc_test %>%
    dplyr::select(date) %>%
    cbind(y_test, y_test_pred_mean) %>%
    group_by(week = floor_date(date, "week")) %>% 
    summarize(obs = sum(y_test),
              pred = sum(y_test_pred_mean), .groups = "drop") %>%
    identity()

  # n_test_weekly <- nrow(test_weekly_data)

  # # Plot observed test counts vs. posterior predictive mean
  # plot(1:n_test_weekly, test_weekly_data$y_test, type = "l", col = "black", lwd = 2,
  #     main = "Test Data: Observed vs. Predicted Counts",
  #     xlab = "Test Time Point", ylab = "Count")
  # lines(1:n_test_weekly, test_weekly_data$y_test_pred_mean, col = "red", lwd = 2)
  # legend("topright", legend = c("Observed", "Predicted"),
  #       col = c("black", "red"), lwd = 2)

  nrow(test_weekly_data)

  pred_plot <- plot_train_test_side_by_side(loc_id, train_weekly_data, test_weekly_data, ar_label = "All", mean_label = "All")

  png(paste0("model_fits/empirical/simple/", outcome_str, "/plots/",loc_id,".png"), width = 2400, height = 1600, res = 300)
  grid.draw(pred_plot)
  dev.off()

  
}


library(cmdstanr)
library(posterior)
library(tidyverse)
library(arrow)
library(dplyr)
library(lubridate)
library(grid)
library(patchwork)

set_cmdstan_path("C:/Users/godli/.cmdstan/cmdstan-2.36.0/cmdstan-2.36.0")
source("tools/modeling_functions.R") 

set.seed(123)

# --- 1. Load and Prepare Data ---

restaurants_to_model <- c(
  'VLZX7K2M9QD4T', 
  'SRQS8F7JWA9MZ', 
  '2HRX9P6HKXA8V', 
  'JHDN7CF1C03X5', 
  'L69HYJ4Y3TR91',
  'ED5J990H5VAZT', 
  'W8T41JZK0ZMEP', 
  
  #'EMBVNVD207CC6', 
  
  'C0BE4NDSW26QN', 
  #'75WYSXR9QBK5M',
  'V3Q26BHF3SE2H', 
  'LBZEEFSBJNB3Z', 
  'SAFK7ND1HR6XS', 
  'CB2KHY1C2G9PT', 
  'S8MT0YGD2KTN9',
  'LFZFT3VASXPED', 
  '1SQPTEGYPH0GA', 
  '9XKJD8DQTH559', 
  'LQ5EH4BKGV61T', 
  '78AY09MVJVTYE'
)

df_all_daily <- read_parquet("data/5_palate_data_parquet_modeling/all_locations_daily_weather_inflation.parquet") %>%
  filter(location_id != "2HRX9P6HKXA8V" | ('2019-01-01' < date & date < '2021-05-01')) %>%
  filter(location_id != "JHDN7CF1C03X5" | ('2019-04-01' < date & date < '2023-06-01')) %>%
  filter(location_id != "EMBVNVD207CC6" | ('2016-06-01' < date & date < '2022-09-01')) %>%
  filter(location_id != "LBZEEFSBJNB3Z" | ('2021-09-01' < date & date < '2023-07-01')) %>%
  filter(location_id != "CB2KHY1C2G9PT" | ('2020-06-01' < date & date < '2023-04-01')) %>%
  filter(location_id != "LFZFT3VASXPED" | ('2021-10-01' < date & date < '2022-11-01')) %>%
  filter(location_id != "75WYSXR9QBK5M" | ('2022-05-01' < date & date < '2023-07-01')) %>%
  mutate(location_id = factor(location_id, levels = restaurants_to_model))# %>%
  #arrange(location_id, date)
df_all_daily %>% glimpse()
# --- 2. Define Model Variables ---

# Fixed slopes
fixed_predictors <- c(
  "day_of_week_cat",
  "inflation",
  "temp",
  "precip"
)

# Random slopes
random_slope_predictors <- c(
  "vegan_price_real",
  "meat_price_real",
  "weekend",
  "season",  # factor
)

# Order matters for index identification later!
# Intercept + Random Slopes + Fixed Slopes
formula_str <- paste("~ 1 +",
                     paste(random_slope_predictors, collapse = " + "), "+",
                     paste(fixed_predictors, collapse = " + ")
                     )
formula_var <- as.formula(formula_str)

outcome_str <- "vegan" # Choose outcome: "nonvegan", "vegan", "vegetarian", "meat"
outcome <- paste0(outcome_str, "_outcome")

# Lags and fixed lags
p <- 56 # Max lag considered (only for prior scale array dimension)
q <- 56
effective_lags_alpha <- c(1, 2, 3, 4, 5, 6, 7, 14, 21, 28, 35, 42)
effective_lags_delta <- c(1, 2, 3, 4, 5, 6, 7, 14, 21, 28, 35, 42)
p_effective <- length(effective_lags_alpha)
q_effective <- length(effective_lags_delta)

# Random lags (match values in effective_lags_*)
random_lags_alpha_values <- c(1, 7)
random_lags_delta_values <- c(1, 7)

# --- 3. Process Data for Multilevel Model (Train/Test Split, Scaling, Matrix Creation) ---

train_data_list <- list()
test_data_list <- list()
N_train_vec <- integer(length(restaurants_to_model))
N_test_vec <- integer(length(restaurants_to_model))

# Get numeric columns needing scaling (excluding outcome)
all_numeric_cols <- df_all_daily %>%
    dplyr::select(where(is.numeric),
                  -any_of(outcome), 
                  -contains("_outcome"),
                  -weekend          # Exclude known binary dummy
                  ) %>%
    colnames()

print("Numeric columns considered for scaling:")
print(all_numeric_cols)

for (i in seq_along(restaurants_to_model)) {
  loc_id <- restaurants_to_model[i]
  df_loc <- df_all_daily %>% filter(location_id == loc_id)

  # Train/Test Split
  n <- nrow(df_loc)
  split_idx <- floor(0.75 * n)
  df_loc_train <- df_loc[1:split_idx, ]
  df_loc_test  <- df_loc[(split_idx + 1):n, ]

  # Check for zero variance in training data numeric columns for this location
  numeric_cols_loc_train <- df_loc_train %>%
    dplyr::select(any_of(all_numeric_cols)) %>% 
    dplyr::select(where(~ !is.na(sd(.x, na.rm = TRUE)) & sd(.x, na.rm = TRUE) > 1e-8)) %>% # Check for non-NA and non-zero SD in train
    colnames()

  # Scaling
  if (length(numeric_cols_loc_train) > 0) {
      means <- map_dbl(df_loc_train[numeric_cols_loc_train], mean, na.rm = TRUE)
      sds   <- map_dbl(df_loc_train[numeric_cols_loc_train], sd, na.rm = TRUE)

      scale_fn <- function(df, cols_to_scale, means_loc, sds_loc) {
        # Only scale columns present in BOTH df and cols_to_scale
        actual_cols_to_scale <- intersect(names(df), cols_to_scale)
        # Ensure sds are not zero or NA for the columns we are actually scaling
        valid_scale_cols <- actual_cols_to_scale[!is.na(sds_loc[actual_cols_to_scale]) & sds_loc[actual_cols_to_scale] > 1e-9] # Use slightly larger threshold for safety

        if (length(valid_scale_cols) > 0) {
           df[valid_scale_cols] <- map2_dfc(df[valid_scale_cols], valid_scale_cols,
                                             ~ (.x - means_loc[.y]) / sds_loc[.y])
           # Handle potential NaNs produced specifically by scaling
           # The replace_na below handles columns not scaled or NAs resulting from 0/0 division if threshold check fails somehow
           # df[valid_scale_cols] <- map_dfc(df[valid_scale_cols], ~replace_na(., 0))
        }
        if (length(actual_cols_to_scale) != length(valid_scale_cols)) {
             warning(paste("Some columns identified for scaling had zero or NA sd for", loc_id, ":",
                           paste(setdiff(actual_cols_to_scale, valid_scale_cols), collapse=", ")))
        }
        df
      }

      df_loc_train_scaled <- scale_fn(df_loc_train, numeric_cols_loc_train, means, sds)
      df_loc_test_scaled  <- scale_fn(df_loc_test, numeric_cols_loc_train, means, sds)

  } else {
      warning(paste("No columns with sufficient variance found for scaling for", loc_id))
      df_loc_train_scaled <- df_loc_train
      df_loc_test_scaled  <- df_loc_test
  }


#   # Handle potential NaNs/NAs more broadly AFTER scaling attempt
#   df_loc_train_scaled <- df_loc_train_scaled %>% mutate(across(where(is.numeric), ~replace_na(., 0)))
#   df_loc_test_scaled <- df_loc_test_scaled %>% mutate(across(where(is.numeric), ~replace_na(., 0)))


  # Create Model Matrices & Store Data
  X_train_loc <- model.matrix(formula_var, data = df_loc_train_scaled)
  X_test_loc  <- model.matrix(formula_var, data = df_loc_test_scaled)

  # Check for missing columns (due to factors having only one level in subset)
  if (ncol(X_train_loc) != ncol(X_test_loc)) {
       warning(paste("Mismatch in columns for", loc_id, " Check factor levels in train/test split."))
       # Attempt to align (simplistic approach - assumes test is missing cols from train)
       missing_cols <- setdiff(colnames(X_train_loc), colnames(X_test_loc))
       if (length(missing_cols) > 0) {
           print(paste("Adding missing columns to test matrix:", paste(missing_cols, collapse=", ")))
           add_mat <- matrix(0, nrow = nrow(X_test_loc), ncol = length(missing_cols), dimnames = list(NULL, missing_cols))
           X_test_loc <- cbind(X_test_loc, add_mat)
           X_test_loc <- X_test_loc[, colnames(X_train_loc)] # Reorder to match train
       }
  }


  train_data_list[[i]] <- list(
      X = X_train_loc,
      y = df_loc_train_scaled[[outcome]],
      N = nrow(X_train_loc),
      id = i
  )
  test_data_list[[i]] <- list(
      X = X_test_loc,
      y = df_loc_test_scaled[[outcome]],
      N = nrow(X_test_loc),
      id = i
  )
  N_train_vec[i] <- nrow(X_train_loc)
  N_test_vec[i] <- nrow(X_test_loc)

   # Store column names from the first restaurant to ensure consistency
  if (i == 1) {
    model_colnames <- colnames(X_train_loc)
  } else {
      if (!identical(colnames(X_train_loc), model_colnames)) {
          stop(paste("Column name mismatch for restaurant", loc_id,
                     ". Expected:", paste(model_colnames, collapse=", "),
                     "Got:", paste(colnames(X_train_loc), collapse=", ")))
      }
      if (!identical(colnames(X_test_loc), model_colnames)) {
            # Attempt fix if test matrix was adjusted
          if (ncol(X_test_loc) == length(model_colnames) && all(model_colnames %in% colnames(X_test_loc))) {
             test_data_list[[i]]$X <- X_test_loc[, model_colnames] # Reorder
             warning(paste("Reordered test columns for", loc_id))
          } else {
            stop(paste("Column name mismatch for test data restaurant", loc_id))
          }
      }
  }
}

# --- 4. Recombine Data into Long Format ---

X_train_all <- do.call(rbind, lapply(train_data_list, function(x) x$X))
y_train_all <- do.call(c, lapply(train_data_list, function(x) x$y))
restaurant_id_train <- do.call(c, lapply(train_data_list, function(x) rep(x$id, x$N)))

X_test_all <- do.call(rbind, lapply(test_data_list, function(x) x$X))
y_test_all <- do.call(c, lapply(test_data_list, function(x) x$y))
restaurant_id_test <- do.call(c, lapply(test_data_list, function(x) rep(x$id, x$N)))

N_train_total <- sum(N_train_vec)
N_test_total <- sum(N_test_vec)
R <- length(restaurants_to_model)

# Calculate start/end indices for Stan
train_end_idx <- cumsum(N_train_vec)
train_start_idx <- c(1, train_end_idx[-R] + 1)
test_end_idx <- cumsum(N_test_vec)
test_start_idx <- c(1, test_end_idx[-R] + 1)

# --- 5. Identify Parameter Indices for Stan ---

J <- ncol(X_train_all)

# Intercept Index
idx_intercept <- which(model_colnames == "(Intercept)")
if (length(idx_intercept) == 0) stop("Intercept column not found!")

# Beta Random Slope Indices
random_col_patterns = c(
    paste0("^", random_slope_predictors[!(random_slope_predictors %in% c("season"))], "$"), # Exact match for non-factors
    paste0("^", "season") # Starts with 'season' for factor dummies
    # Add other factors here if they were random slopes, e.g. paste0("^", "day_of_week_cat")
)
idx_beta_random <- which(grepl(paste(random_col_patterns, collapse="|"), model_colnames))
# Sanity check: vegan_price_real, meat_price_real, weekend, season* (3) -> should be 6
print(paste("Identified", length(idx_beta_random), "random beta slope columns:",
            paste(model_colnames[idx_beta_random], collapse=", ")))
if (length(idx_beta_random) != 6) warning("Expected 6 random beta slopes, found differently. Check formula and predictor names.")


# Beta Fixed Slope Indices
idx_beta_fixed <- setdiff(1:J, c(idx_intercept, idx_beta_random))
print(paste("Identified", length(idx_beta_fixed), "fixed beta slope columns:",
            paste(model_colnames[idx_beta_fixed], collapse=", ")))


# Alpha Random/Fixed Indices (indices within effective_lags_alpha)
idx_alpha_random <- which(effective_lags_alpha %in% random_lags_alpha_values)
idx_alpha_fixed <- setdiff(1:p_effective, idx_alpha_random)
print(paste("Identified", length(idx_alpha_random), "random alpha indices (positions):", paste(idx_alpha_random, collapse=", ")))


# Delta Random/Fixed Indices (indices within effective_lags_delta)
idx_delta_random <- which(effective_lags_delta %in% random_lags_delta_values)
idx_delta_fixed <- setdiff(1:q_effective, idx_delta_random)
print(paste("Identified", length(idx_delta_random), "random delta indices (positions):", paste(idx_delta_random, collapse=", ")))

# Counts for Stan data list
K_beta_random <- length(idx_beta_random)
K_beta_fixed <- length(idx_beta_fixed)
K_alpha_random <- length(idx_alpha_random)
K_alpha_fixed <- length(idx_alpha_fixed)
K_delta_random <- length(idx_delta_random)
K_delta_fixed <- length(idx_delta_fixed)


# --- 6. Prepare Stan Data List ---

# Hyperprior scale inputs
mu_beta_scale_input  <- 1.0 # Scale for normal priors on mu_beta_*
sigma_beta_scale_input <- 1.0 # Rate for exponential priors on sigma_beta_*
mu_alpha_scale_input <- 1.0
sigma_alpha_scale_input <- 1.0
mu_delta_scale_input <- 1.0
sigma_delta_scale_input <- 1.0
mu_phi_log_scale_input <- 1.0
sigma_phi_log_scale_input <- 1.0

data_list <- list(
  # Number of restaurants
  R = R,
  # Number of predictors
  J = J,
  # Ids of the intercept, fixed slope variables, and random slope varialbes within the design matrix
  idx_intercept = idx_intercept,
  K_beta_random = K_beta_random,
  idx_beta_random = idx_beta_random,
  K_beta_fixed = K_beta_fixed,
  idx_beta_fixed = idx_beta_fixed,
  # Lags and IDs of the the fixed lags and random lags within effective_lags_*
  p_effective = p_effective,
  effective_lags_alpha = effective_lags_alpha,
  K_alpha_random = K_alpha_random,
  idx_alpha_random = idx_alpha_random,
  K_alpha_fixed = K_alpha_fixed,
  idx_alpha_fixed = idx_alpha_fixed,
  q_effective = q_effective,
  effective_lags_delta = effective_lags_delta,
  K_delta_random = K_delta_random,
  idx_delta_random = idx_delta_random,
  K_delta_fixed = K_delta_fixed,
  idx_delta_fixed = idx_delta_fixed,
  # Training Data
  N_train = N_train_total,
  X_train = X_train_all,
  y_train = y_train_all,
  # A map from the index to restaurants, indicating which restaurant it is (since it is long data)
  restaurant_id_train = restaurant_id_train,
  train_start_idx = train_start_idx,
  train_end_idx = train_end_idx,
  # Testing Data
  N_test = N_test_total,
  X_test = X_test_all,
  y_test = y_test_all,
  # Again, a map from the index to restaurants, indicating which restaurant it is (since it is long data)
  restaurant_id_test = restaurant_id_test,
  test_start_idx = test_start_idx,
  test_end_idx = test_end_idx,
  # Prior Scales
  mu_beta_scale = mu_beta_scale_input,
  sigma_beta_scale = sigma_beta_scale_input,
  mu_alpha_scale = mu_alpha_scale_input,
  sigma_alpha_scale = sigma_alpha_scale_input,
  mu_delta_scale = mu_delta_scale_input,
  sigma_delta_scale = sigma_delta_scale_input,
  mu_phi_log_scale = mu_phi_log_scale_input,
  sigma_phi_log_scale = sigma_phi_log_scale_input
)

# --- 7. Compile and Fit ---

mod <- cmdstan_model("model_multilevel.stan")

# Initialize close to zero mean and small variance
init_fn <- function(chain_id = 1) {
    list(
        # Population Means (initialize near zero, maybe slightly positive intercept)
        mu_beta_intercept = rnorm(1, 0.5, 0.1), # Slightly positive
        mu_beta_random = rnorm(K_beta_random, 0, 0.1),
        mu_beta_fixed = rnorm(K_beta_fixed, 0, 0.1),
        mu_alpha_random_raw = rnorm(K_alpha_random, 0, 0.1), # Raw scale
        mu_alpha_fixed_raw = rnorm(K_alpha_fixed, 0, 0.1),   # Raw scale
        mu_delta_random_raw = rnorm(K_delta_random, 0, 0.1), # Raw scale
        mu_delta_fixed_raw = rnorm(K_delta_fixed, 0, 0.1),   # Raw scale
        mu_phi_log = rnorm(1, log(5), 0.5), # Init phi around 5 on log scale

        # Population Standard Deviations (initialize small positive)
        sigma_beta_intercept = abs(rnorm(1, 0, 0.5)) + 0.1,
        sigma_beta_random = abs(rnorm(K_beta_random, 0, 0.5)) + 0.1,
        sigma_alpha_random = abs(rnorm(K_alpha_random, 0, 0.5)) + 0.1,
        sigma_delta_random = abs(rnorm(K_delta_random, 0, 0.5)) + 0.1,
        sigma_phi_log = abs(rnorm(1, 0, 0.5)) + 0.1,

        # Standardized Deviations (initialize standard normal)
        z_beta_intercept = rnorm(R, 0, 1),
        z_beta_random = matrix(rnorm(K_beta_random * R, 0, 1), K_beta_random, R),
        z_alpha_random = matrix(rnorm(K_alpha_random * R, 0, 1), K_alpha_random, R),
        z_delta_random = matrix(rnorm(K_delta_random * R, 0, 1), K_delta_random, R),
        z_phi_log = rnorm(R, 0, 1)
    )
}

# Create directories if they don't exist
output_dir <- file.path("model_fits/empirical/multilevel_selective", outcome_str)
plot_dir <- file.path(output_dir, "plots")
if (!dir.exists(plot_dir)) dir.create(plot_dir, recursive = TRUE)

fit_file <- file.path(output_dir, "fit_multi.rds")
if (file.exists(fit_file)) {
  print("Loading existing fit file...")
  fit <- readRDS(fit_file)
} else {
  print("Fitting the multilevel model...")
  fit <- mod$sample(
    data = data_list,
    seed = 123,
    chains = 3, 
    parallel_chains = 3,
    iter_warmup = 700,
    iter_sampling = 1500,
    init = init_fn,
    adapt_delta = 0.95, # This is relatively high
    max_treedepth = 12
  )
  print("Saving fit object...")
  fit$save_object(fit_file)
}


# --- 8. Saving Results & Analysis ---

print("Calculating summaries...")
summ_file <- file.path(output_dir, "summ_multi.rds")
if (file.exists(summ_file)) {
    summ <- readRDS(summ_file)
} else {
    summ <- fit$summary()
    saveRDS(summ, summ_file)
}

print("Calculating samples...")
samples_file <- file.path(output_dir, "samples_multi.rds")
if (file.exists(samples_file)) {
    samples <- readRDS(samples_file)
} else {
    samples <- as_draws_df(fit$draws())
    saveRDS(samples, samples_file)
}

print("Calculating metadata...")
metadata_file <- file.path(output_dir, "metadata_multi.rds")
if (file.exists(metadata_file)) {
  metadata <- readRDS(metadata_file)
} else {
  metadata <- fit$metadata()
  saveRDS(metadata, metadata_file)
}

print("Summary of Hyperpriors (mu_*, sigma_*):")
print(summ %>% filter(grepl("^(mu_|sigma_)", variable)), n=300) 

print("Extracting predictions...")
y_rep_mean_file <- file.path(output_dir, "y_rep_mean_multi.rds")
if (file.exists(y_rep_mean_file)) {
    y_rep_mean <- readRDS(y_rep_mean_file)
} else {
    y_rep_mean <- as_draws_df(fit$draws("y_rep")) %>% 
      dplyr::select(starts_with("y_rep")) %>%
      colMeans()
    saveRDS(y_rep_mean, file.path(output_dir, "y_rep_mean_multi.rds"))
}

y_test_rep_mean_file <- file.path(output_dir, "y_test_rep_mean_multi.rds")
if (file.exists(y_test_rep_mean_file)) {
    y_test_rep_mean <- readRDS(y_test_rep_mean_file)
} else {
    y_test_rep_mean <- as_draws_df(fit$draws("y_test_rep")) %>% 
      dplyr::select(starts_with("y_test_rep")) %>% 
      colMeans()
    saveRDS(y_test_rep_mean, file.path(output_dir, "y_test_rep_mean_multi.rds"))
}


# --- 9. Plotting Results (Example: Per Restaurant) ---

print("Generating plots...")

plot_data_train <- tibble(
    pred = y_rep_mean,
    obs = y_train_all,
    restaurant_idx = restaurant_id_train
) %>%
    mutate(time_idx = 1:n())

plot_data_test <- tibble(
    pred = y_test_rep_mean,
    obs = y_test_all,
    restaurant_idx = restaurant_id_test
) %>%
   mutate(time_idx = 1:n())


# We need the original dates back. Easiest way is to rebuild the date sequence

# Helper df with original dates and restaurant index
original_dates_df <- df_all_daily %>%
    mutate(restaurant_idx = as.integer(location_id)) %>%
    arrange(restaurant_idx, date) %>%
    group_by(restaurant_idx) %>%
    mutate(row_in_restaurant = row_number()) %>%
    ungroup() %>%
    dplyr::select(restaurant_idx, date, row_in_restaurant)

# Add train/test identifier and overall row index within train/test sets
train_indices_df <- tibble(
    restaurant_idx = restaurant_id_train,
    overall_train_idx = 1:N_train_total
) %>%
    group_by(restaurant_idx) %>%
    mutate(row_in_restaurant = row_number()) %>%
    ungroup()

test_indices_df <- tibble(
    restaurant_idx = restaurant_id_test,
    overall_test_idx = 1:N_test_total
) %>%
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
for(i in 1:R) {
    loc_id <- restaurants_to_model[i]
    
    # Filter data for the current restaurant
    train_data_loc <- plot_data_train %>% filter(restaurant_idx == i)
    test_data_loc <- plot_data_test %>% filter(restaurant_idx == i)

    # Aggregate weekly
    train_weekly_data <- train_data_loc %>%
        filter(!is.na(date)) %>%
        group_by(week = floor_date(date, "week")) %>%
        summarize(obs = sum(obs), pred = sum(pred), .groups = "drop")

    test_weekly_data <- test_data_loc %>%
        filter(!is.na(date)) %>%
        group_by(week = floor_date(date, "week")) %>%
        summarize(obs = sum(obs), pred = sum(pred), .groups = "drop")

    if(nrow(train_weekly_data) > 0 && nrow(test_weekly_data) > 0) {

       p_train <- ggplot(train_weekly_data, aes(x = week)) +
           geom_line(aes(y = obs, color = "Observed")) +
           geom_line(aes(y = pred, color = "Predicted")) +
           labs(title = paste(loc_id, "- Training Data"), y = "Weekly Count", x = "Week") +
           scale_color_manual(values = c("Observed" = "black", "Predicted" = "red")) +
           theme_minimal() + theme(legend.position = "bottom")

       p_test <- ggplot(test_weekly_data, aes(x = week)) +
           geom_line(aes(y = obs, color = "Observed")) +
           geom_line(aes(y = pred, color = "Predicted")) +
           labs(title = paste(loc_id, "- Test Data"), y = "Weekly Count", x = "Week") +
           scale_color_manual(values = c("Observed" = "black", "Predicted" = "red")) +
           theme_minimal() + theme(legend.position = "bottom")

        library(patchwork)
        combined_plot <- p_train + p_test + plot_layout(guides = "collect") & theme(legend.position = 'bottom')


        png(file.path(plot_dir, paste0(loc_id, "_multi.png")), width = 2400, height = 1200, res = 300)
        # grid.draw(pred_plot) # If using your original function
        print(combined_plot) # Otherwise
        dev.off()
    } else {
        print(paste("Skipping plot for", loc_id, "due to missing weekly data."))
    }
}

print("Script finished.")


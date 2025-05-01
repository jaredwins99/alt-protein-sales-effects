library(cmdstanr)
library(posterior)
library(tidyverse)
library(arrow)
library(dplyr)
library(lubridate) # For floor_date
library(grid) # For grid.draw

source("tools/modeling_functions.R") 

set.seed(123)

# --- 1. Load and Prepare Data (Once for all restaurants) ---

# Define the 20 restaurants
restaurants_to_model <- c(
  'VLZX7K2M9QD4T', 'SRQS8F7JWA9MZ', '2HRX9P6HKXA8V', 'JHDN7CF1C03X5', 'L69HYJ4Y3TR91',
  'ED5J990H5VAZT', 'W8T41JZK0ZMEP', 'EMBVNVD207CC6', 'C0BE4NDSW26QN', '75WYSXR9QBK5M',
  'V3Q26BHF3SE2H', 'LBZEEFSBJNB3Z', 'SAFK7ND1HR6XS', 'CB2KHY1C2G9PT', 'S8MT0YGD2KTN9',
  'LFZFT3VASXPED', '1SQPTEGYPH0GA', '9XKJD8DQTH559', 'LQ5EH4BKGV61T', '78AY09MVJVTYE'
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

df_all_daily %>% is.na() %>% colSums()

# --- 2. Define Model Variables ---

# Predictors for the fixed part of the model (excluding intercept and random slopes)
# Note: day_of_week_cat is included here, its dummies will be fixed effects.
# Note: temp and precip are included here as requested.
# Note: year and month_cat are NOT included as per the request. Add them here if needed.
fixed_predictors <- c(
  "day_of_week_cat",
  "inflation",
  "temp",
  "precip"
)

# Predictors that will have random slopes
random_slope_predictors <- c(
  "vegan_price_real",
  "meat_price_real",
  "weekend",         # Single binary variable
  "season"           # Factor, will generate dummies
)

# Construct the full formula string
# Order matters for index identification later!
# Intercept + Random Slopes + Fixed Slopes
formula_str <- paste("~ 1 +",
                     paste(random_slope_predictors, collapse = " + "), "+",
                     paste(fixed_predictors, collapse = " + ")
                     )
formula_var <- as.formula(formula_str)

outcome_str <- "nonvegan" # Choose outcome: "nonvegan", "vegan", "vegetarian", "meat"
outcome <- paste0(outcome_str, "_outcome")

# Lag definitions
p <- 56 # Max lag considered (only for prior scale array dimension)
q <- 56 # Max lag considered
effective_lags_alpha <- c(1, 2, 3, 4, 5, 6, 7, 14, 21, 28, 35, 42)
effective_lags_delta <- c(1, 2, 3, 4, 5, 6, 7, 14, 21, 28, 35, 42)
p_effective <- length(effective_lags_alpha)
q_effective <- length(effective_lags_delta)

# Lags to get random effects (match values in effective_lags_*)
random_lags_alpha_values <- c(1, 7)
random_lags_delta_values <- c(1, 7)

# --- 3. Process Data for Multilevel Model (Train/Test Split, Scaling, Matrix Creation) ---

train_data_list <- list()
test_data_list <- list()
N_train_vec <- integer(length(restaurants_to_model))
N_test_vec <- integer(length(restaurants_to_model))

# Get numeric columns needing scaling (excluding outcome, factors, dummies)
# Do this on the full dataset *before* splitting to identify candidates
# Actual scaling happens per-restaurant based on its training data
all_numeric_cols <- df_all_daily %>%
    dplyr::select(where(is.numeric), # Select all numeric initially
                  -any_of(outcome),   # Exclude the specific outcome
                  -contains("_outcome"), # Exclude any other outcomes
                  -weekend          # Exclude known binary dummy
                  ) %>%
    colnames()

print("Numeric columns considered for scaling:")
print(all_numeric_cols)


for (i in seq_along(restaurants_to_model)) {
  loc_id <- restaurants_to_model[i]
  df_loc <- df_all_daily %>% filter(location_id == loc_id)

  # 1. Train/Test Split
  n <- nrow(df_loc)
  split_idx <- floor(0.75 * n)
  df_loc_train <- df_loc[1:split_idx, ]
  df_loc_test  <- df_loc[(split_idx + 1):n, ]

  # Check for zero variance in training data numeric columns for this location
  # Identify numeric columns relevant for this restaurant's training data
  numeric_cols_loc_train <- df_loc_train %>%
    dplyr::select(any_of(all_numeric_cols)) %>% # Select from pre-defined list
    # V--- CORRECTED LINE ---V
    dplyr::select(where(~ !is.na(sd(.x, na.rm = TRUE)) & sd(.x, na.rm = TRUE) > 1e-8)) %>% # Check for non-NA and non-zero SD in train
    colnames()

  # print(paste("Scaling columns for", loc_id, ":"))
  # print(numeric_cols_loc_train)

  # 2. Scaling (using this location's training data stats)
  # Check if there are actually columns to scale before proceeding
  if (length(numeric_cols_loc_train) > 0) {
      means <- map_dbl(df_loc_train[numeric_cols_loc_train], mean, na.rm = TRUE)
      sds   <- map_dbl(df_loc_train[numeric_cols_loc_train], sd, na.rm = TRUE)

      # Define scaling function scoped to this location's stats
      scale_fn <- function(df, cols_to_scale, means_loc, sds_loc) {
        # Important: only scale columns present in BOTH df and cols_to_scale
        actual_cols_to_scale <- intersect(names(df), cols_to_scale)
        # Ensure sds are not zero or NA for the columns we are actually scaling
        valid_scale_cols <- actual_cols_to_scale[!is.na(sds_loc[actual_cols_to_scale]) & sds_loc[actual_cols_to_scale] > 1e-9] # Use slightly larger threshold for safety

        if (length(valid_scale_cols) > 0) {
           df[valid_scale_cols] <- map2_dfc(df[valid_scale_cols], valid_scale_cols,
                                             ~ (.x - means_loc[.y]) / sds_loc[.y])
           # Handle potential NaNs produced specifically by scaling (e.g., if an original value was NA)
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
      # If no columns need scaling for this restaurant, just use the unscaled data
      warning(paste("No columns with sufficient variance found for scaling for", loc_id))
      df_loc_train_scaled <- df_loc_train
      df_loc_test_scaled  <- df_loc_test
  }


  # Handle potential NaNs/NAs more broadly AFTER scaling attempt
  # This covers NAs in original columns not scaled, and any potential NaNs from scaling
  df_loc_train_scaled <- df_loc_train_scaled %>% mutate(across(where(is.numeric), ~replace_na(., 0)))
  df_loc_test_scaled <- df_loc_test_scaled %>% mutate(across(where(is.numeric), ~replace_na(., 0)))


  # 3. Create Model Matrices & Store Data
  # Ensure factor levels are consistent when creating matrix
  X_train_loc <- model.matrix(formula_var, data = df_loc_train_scaled)
  X_test_loc  <- model.matrix(formula_var, data = df_loc_test_scaled)

  # Check for missing columns (due to factors having only one level in subset)
  # This is complex; safer to ensure factors are defined globally first.
  # Basic check:
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
       # Could also be train missing cols from test, handle if necessary
  }


  train_data_list[[i]] <- list(
      X = X_train_loc,
      y = df_loc_train_scaled[[outcome]],
      N = nrow(X_train_loc),
      id = i # Restaurant index (1 to R)
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

# --- 4. Combine Data into Long Format ---

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

J <- ncol(X_train_all) # Total number of columns in design matrix

# Intercept Index
idx_intercept <- which(model_colnames == "(Intercept)")
if (length(idx_intercept) == 0) stop("Intercept column not found!")

# Beta Random Slope Indices
# Find columns matching the random predictor names OR starting with 'season'/'day_of_week' etc.
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
# All columns EXCEPT intercept and random slopes
idx_beta_fixed <- setdiff(1:J, c(idx_intercept, idx_beta_random))
print(paste("Identified", length(idx_beta_fixed), "fixed beta slope columns:",
            paste(model_colnames[idx_beta_fixed], collapse=", ")))


# Alpha Random/Fixed Indices (based on POSITION in effective_lags_alpha)
idx_alpha_random <- which(effective_lags_alpha %in% random_lags_alpha_values)
idx_alpha_fixed <- setdiff(1:p_effective, idx_alpha_random)
print(paste("Identified", length(idx_alpha_random), "random alpha indices (positions):", paste(idx_alpha_random, collapse=", ")))


# Delta Random/Fixed Indices (based on POSITION in effective_lags_delta)
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

# Hyperprior scale inputs (adjust these as needed)
# These now control the scale/rate of the priors on mu_* and sigma_*
mu_beta_scale_input  <- 1.0 # Scale for normal priors on mu_beta_*
sigma_beta_scale_input <- 1.0 # Rate for exponential priors on sigma_beta_*
mu_alpha_scale_input <- 1.0
sigma_alpha_scale_input <- 1.0
mu_delta_scale_input <- 1.0
sigma_delta_scale_input <- 1.0
mu_phi_log_scale_input <- 1.0
sigma_phi_log_scale_input <- 1.0

data_list <- list(
  # Restaurant Structure
  R = R,
  # Covariate Structure
  J = J,
  idx_intercept = idx_intercept,
  K_beta_random = K_beta_random,
  idx_beta_random = idx_beta_random,
  K_beta_fixed = K_beta_fixed,
  idx_beta_fixed = idx_beta_fixed,
  # Lag Structure
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
  restaurant_id_train = restaurant_id_train,
  train_start_idx = train_start_idx,
  train_end_idx = train_end_idx,
  # Testing Data
  N_test = N_test_total,
  X_test = X_test_all,
  y_test = y_test_all,
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

# --- 7. Compile and Run Stan Model ---

# Compile the NEW Stan model
mod <- cmdstan_model("model_multilevel.stan")

# Simplified Initialization Function for Multilevel Model
# Initialize close to zero mean and small variance
init_fn <- function(chain_id = 1) {
    list(
        # Population Means (initialize near zero, maybe slightly positive intercept)
        mu_beta_intercept = rnorm(1, 0.5, 0.1), # Slightly positive baseline
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
    chains = 3, # Start with 3, increase if needed
    parallel_chains = 3,
    iter_warmup = 700,   # Increase warmup for complex models
    iter_sampling = 1500,# Increase sampling
    init = init_fn,
    adapt_delta = 0.95,  # Higher adapt_delta often needed
    max_treedepth = 12     # Higher treedepth often needed
  )
  print("Saving fit object...")
  saveRDS(fit, fit_file)
}


# --- 8. Post-Processing and Analysis ---

print("Calculating summaries...")
summ_file <- file.path(output_dir, "summ_multi.rds")
if (file.exists(summ_file)) {
    summ <- readRDS(summ_file)
} else {
    summ <- fit$summary()
    saveRDS(summ, summ_file)
}

# Print summary of hyperparameters and maybe a few specific parameters
print("Summary of Hyperpriors (mu_*, sigma_*):")
print(summ %>% filter(grepl("^(mu_|sigma_)", variable)), n=100)

# Extract predictions (these are still long vectors)
print("Extracting predictions...")
y_rep_mean <- colMeans(as_draws_matrix(fit$draws("y_rep")))
y_test_rep_mean <- colMeans(as_draws_matrix(fit$draws("y_test_rep")))

saveRDS(y_rep_mean, file.path(output_dir, "y_rep_mean_multi.rds"))
saveRDS(y_test_rep_mean, file.path(output_dir, "y_test_rep_mean_multi.rds"))

# --- Plotting Results (Example: Per Restaurant) ---

print("Generating plots...")

# Re-combine original dates with predictions for plotting
plot_data_train <- tibble(
    pred = y_rep_mean,
    obs = y_train_all,
    restaurant_idx = restaurant_id_train
) %>%
    mutate(time_idx = 1:n()) # Add overall time index

plot_data_test <- tibble(
    pred = y_test_rep_mean,
    obs = y_test_all,
    restaurant_idx = restaurant_id_test
) %>%
   mutate(time_idx = 1:n()) # Add overall time index


# We need the original dates back. Easiest way is to add row numbers before splitting
# and merge back based on those, or rebuild the date sequence carefully.
# Let's try rebuilding based on restaurant indices and start/end indices.

# Create a helper df with original dates and restaurant index
original_dates_df <- df_all_daily %>%
    mutate(restaurant_idx = as.integer(location_id)) %>% # Match the integer index used
    arrange(restaurant_idx, date) %>%
    group_by(restaurant_idx) %>%
    mutate(row_in_restaurant = row_number()) %>%
    ungroup() %>%
    select(restaurant_idx, date, row_in_restaurant)

# Add train/test identifier and overall row index *within* train/test sets
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
        filter(!is.na(date)) %>% # Ensure date is present
        group_by(week = floor_date(date, "week")) %>%
        summarize(obs = sum(obs), pred = sum(pred), .groups = "drop")

    test_weekly_data <- test_data_loc %>%
        filter(!is.na(date)) %>%
        group_by(week = floor_date(date, "week")) %>%
        summarize(obs = sum(obs), pred = sum(pred), .groups = "drop")

    if(nrow(train_weekly_data) > 0 && nrow(test_weekly_data) > 0) {
       # Generate plot using your function (assuming it takes these inputs)
       # You might need to adapt plot_train_test_side_by_side if it wasn't designed for this
       
       # Basic ggplot version if function is unavailable
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

        # Combine plots (requires library(gridExtra) or library(patchwork))
        library(patchwork)
        combined_plot <- p_train + p_test + plot_layout(guides = "collect") & theme(legend.position = 'bottom')


        png(file.path(plot_dir, paste0(loc_id, "_multi.png")), width = 2400, height = 1200, res = 300)
        # grid.draw(pred_plot) # If using your original function
        print(combined_plot)   # If using ggplot/patchwork
        dev.off()
    } else {
        print(paste("Skipping plot for", loc_id, "due to missing weekly data."))
    }
}

print("Script finished.")
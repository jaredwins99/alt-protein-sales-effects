suppressPackageStartupMessages({
  library(cmdstanr)
  library(posterior)
  library(tidyverse)
  library(arrow)
  library(lubridate)
  library(grid)
  library(patchwork)
  library(conflicted)
  library(reticulate)
  library(mlflow)
})

c("select", "filter") %>% walk(~ conflict_prefer(.x, "dplyr"))
c("year", "month") %>% walk(~ conflict_prefer(.x, "lubridate"))
c("sd") %>%  walk(~ conflict_prefer(.x, "stats"))
c("match") %>%  walk(~ conflict_prefer(.x, "base"))
c("map") %>% walk( ~ conflict_prefer(.x, "purrr"))

source("tools/modeling_functions.R") 

run_ingarch <- function(
  analysis = c("proportion","its","customer","targeted_its","its_t2","customer_t2","targeted_its_t2"),
  outcome = "nonvegan",
  data_file = "all_locations_daily_weather_inflation_customers.parquet",
  seed = 123,
  chains = 3,
  parallel_chains = 3,
  iter_warmup = 700,
  iter_sampling = 1500,
  adapt_delta = 0.95,
  max_treedepth = 12,
  restaurants_to_model = c(
    # Tier 1
    #'VLZX7K2M9QD4T', 
    'SRQS8F7JWA9MZ', 
    '2HRX9P6HKXA8V', 
    'JHDN7CF1C03X5', 
    'L69HYJ4Y3TR91',
    'ED5J990H5VAZT',
    #'W8T41JZK0ZMEP',
    
    # # Tier 2
    # #'EMBVNVD207CC6',
    # 'C0BE4NDSW26QN',
    # #'75WYSXR9QBK5M',
    # 'V3Q26BHF3SE2H',
    # 'LBZEEFSBJNB3Z',
    # 'SAFK7ND1HR6XS',
    # 'CB2KHY1C2G9PT',
    # 'S8MT0YGD2KTN9',
    # 'LFZFT3VASXPED',
    # '1SQPTEGYPH0GA',
    # '9XKJD8DQTH559',
    # 'LQ5EH4BKGV61T',
    # '78AY09MVJVTYE'
    ),
  
  # Fixed predictors
  fixed_predictors = c(
    "day_of_week_cat", # factor
    "inflation", # continuous
    "temp", # continuous
    "precip" # continuous
  ),
  
  # Random predictors
  random_predictors = c(
    "vegan_price_real", # continuous
    "meat_price_real", # continuous
    "weekend", # binary
    "holiday_window", # binary
    "month_cat", # factor
    "season",  # factor
    "year_cat", # factor
    "date_num" # continuous
  )
) {

result <- tryCatch({

  set.seed(seed)

  DATA_DIR <- file.path(
    "data",
    "5_palate_data_parquet_modeling",
    data_file)

  # local_store <- file.path(getwd(), "mlflow")
  # uri <- paste0(
  #   "file:///", 
  #   URLencode(normalizePath(local_store, winslash = "/")))
  # mlflow_set_tracking_uri(uri)
  # mlflow_set_experiment("Multilevel INGARCH Linear Transfer")

  # ──────────────────────────────────
  #     1. Load and Prepare Data  
  # ──────────────────────────────────
  
  before_after_details_true <- read.csv("data/before_after_details_true.csv") %>%
    mutate(cross_over_date = as.Date(cross_over_date),
           cross_over_date_num = as.integer(cross_over_date))
  
  df <- read_parquet(DATA_DIR) %>%
    
    # Filter to relevant restaurants
    filter(location_id %in% restaurants_to_model) %>%

    # Remove poor data boundaries
    filter(location_id != "2HRX9P6HKXA8V" | ('2019-01-01' < date & date < '2021-05-01')) %>%
    filter(location_id != "JHDN7CF1C03X5" | ('2019-04-01' < date & date < '2023-06-01')) %>%
    filter(location_id != "EMBVNVD207CC6" | ('2016-06-01' < date & date < '2022-09-01')) %>%
    filter(location_id != "LBZEEFSBJNB3Z" | ('2021-09-01' < date & date < '2023-07-01')) %>%
    filter(location_id != "CB2KHY1C2G9PT" | ('2020-06-01' < date & date < '2023-04-01')) %>%
    filter(location_id != "LFZFT3VASXPED" | ('2021-10-01' < date & date < '2022-11-01')) %>%
    filter(location_id != "75WYSXR9QBK5M" | ('2022-05-01' < date & date < '2023-07-01')) %>%
    filter(location_id != "SAFK7ND1HR6XS" | ('2019-04-18' < date & date < '2020-03-25')) %>%
    
    # Remove neighborhood columns
    select(-contains("neighborhood")) %>%
    
    # Add exposure times
    left_join(before_after_details_true %>% 
                select(location_id, cross_over_date_num),
              by = "location_id") %>%
    
    # Add centered date as numeric, factor locations
    mutate(location_id = factor(location_id, levels = restaurants_to_model),
           location_id_num = as.integer(factor(location_id, levels = restaurants_to_model)),
           date_num = date %>% as.integer() - cross_over_date_num) %>%
    
    # Arrange by location id
    arrange(location_id_num, date) %>%
    identity()
  

  # ──────────────────────────────────
  #     2. Select Predictors  
  # ──────────────────────────────────
  
  # Analysis
  analysis <- match.arg(analysis)
  
  output_dir <- file.path(
    "model_fits",
    "official",
    analysis,
    outcome)
  plot_dir <- file.path(
    output_dir,
    "plots")
  if (!dir.exists(plot_dir)) dir.create(plot_dir, recursive = TRUE)
  fit_file <- file.path(
    output_dir, 
    "fit_multi.rds")
  
  # Exposure predictors
  M <- 2 # We have two parameter types: intercept and slope for each exposure
  exposure_predictors <- names(df)[
    startsWith(names(df), "exposure_") &
      sub("^exposure_([a-zA-Z0-9]+)_\\d+$", "\\1", names(df)) %in% restaurants_to_model
  ]
  interaction_predictors <- paste0(exposure_predictors, "_slope")
  all_exposure_predictors <- c(exposure_predictors, interaction_predictors)
  print(paste("Found", length(exposure_predictors), 
              "exposure columns in the data:", 
              paste(exposure_predictors, collapse=", ")))
  
  
  # Order matters for index identification later!
  # Intercept + Random Slopes + Fixed Slopes
  formula_str <- paste("~ 1 +",
                       paste(random_predictors, collapse = " + "), "+",
                       paste(fixed_predictors, collapse = " + "), "+",
                       paste(all_exposure_predictors, collapse = " + "))
  formula_var <- as.formula(formula_str)

  
  # Lags
  effective_lags_alpha <- c(1, 2, 3, 4, 5, 6, 7, 14, 21, 28, 35, 42)
  effective_lags_delta <- c(1, 2, 3, 4, 5, 6, 7, 14, 21, 28, 35, 42)
  p_effective <- length(effective_lags_alpha)
  q_effective <- length(effective_lags_delta)
  
  # Max lags considered 
  p_max <- max(effective_lags_alpha)
  q_max <- max(effective_lags_delta)
  
  # Random lags
  random_lags_alpha_values <- c(1, 7) # (match values in effective_lags_*)
  random_lags_delta_values <- c(1, 7)
  
  # Train frac
  train_frac <- 0.95
  

  # ──────────────────────────────────
  #     3. Process Data
  # ──────────────────────────────────
  # (Train/Test Split, Scaling, Interactions, Matrix Creation, and Stack)
  
  # Identify numeric predictors to be scaled
  outcome_col <- paste0(outcome, "_outcome")
  numeric_predictors <- df %>%
    select(
      where(~ is.numeric(.x) && n_distinct(.x, na.rm = TRUE) > 12),
      -contains("_outcome"),
      -contains("_cat"),
      -contains("_id"),
      #-contains("date_num")
      ) %>%
    colnames()
  cat("Numeric columns considered for scaling:\n", 
      paste0(numeric_predictors, collapse = ",\n"), sep="")
  
  # Processing pipeline
  df_list <- df %>%
    
    # ────────────────────────────
    # For each restaurant
    group_by(location_id_num) %>%
    
    mutate(
      # Train test split
      train_test = if_else(row_number() <= floor(train_frac * n()), "train", "test"),
    
      # Standardize
      across(
        .cols = all_of(numeric_predictors), 
        .fns = ~ (.x - mean(.x[train_test == "train"], na.rm = TRUE)) 
        / (sd(.x[train_test == "train"], na.rm = TRUE) + 1e-8)),
      
    # Add exposure interaction columns (grouping is irrelevant for this)
      across(
        .cols = all_of(exposure_predictors),
        .fns = ~ .x * .data[["date_num"]],
        .names = "{.col}_slope")) %>%
    
    # ────────────────────────────
    # For each restaurant, for each of train and test
    group_by(location_id_num, train_test) %>%
    
    # Form into design matrices
    nest() %>% # lists are named data by default
    mutate(
      X_loc = data %>% map(~ model.matrix(formula_var, data = .x)),
      y_loc = data %>% map(~ .x[[outcome_col]]),
      N_loc = data %>% map_int(nrow)) %>%
    select(-data) %>%

    # ────────────────────────────
    # For each of train and test
    group_by(train_test) %>%
    
    # Concatenate into one long matrix
    summarize(
      X = list(do.call(rbind, X_loc)),
      y = list(list_c(y_loc)),
      N = sum(N_loc),
      end_idx = list(cumsum(N_loc)),
      start_idx = list(c(1, head(cumsum(N_loc), -1) + 1)),
      restaurant_id = list(rep(location_id_num, times = N_loc)),
      .groups = "drop") %>%
    
    # Separate train and test
    pivot_wider(
      names_from = train_test,
      values_from = c(X, y, N, restaurant_id, 
                      start_idx, 
                      end_idx
                      ),
      names_glue = "{.value}_{train_test}") %>%
    
    # Ungroup, convert from df to list, and unnest
    ungroup() %>%
    as.list() %>%
    map(~ {if (is.list(.x)) .x[[1]] else .x}) %>%
    identity()
  
  
  # ──────────────────────────────────
  #   4. Identify Column Indices 
  # ──────────────────────────────────
  
  # Pull the final, combined matrices and vectors from the list
  X_train <- df_list$X_train
  X_test  <- df_list$X_test
  restaurant_id_train <- df_list$restaurant_id_train
  
  # Get the final, correct dimensions
  R <- length(unique(restaurant_id_train))
  J <- ncol(X_train)
  model_colnames <- colnames(X_train)
  
  # ────────────────────────────
  # Predictors
  
  # Intercept index
  idx_intercept <- which(model_colnames == "(Intercept)")
  
  # Beta random slope indices
  regex_random = c(  # Exact match for non-factors
    paste0("^", random_predictors[!(random_predictors %in% c("season"))], "$"),
    paste0("^", "season")) # Starts with 'season' for factor dummies
  
  # Identify indices within design matrix
  idx_beta_random <- which(grepl(paste(regex_random, collapse="|"), model_colnames))
  idx_exposure <- which(startsWith(model_colnames, "exposure_"))
  idx_beta_fixed <- setdiff(1:J, c(idx_intercept, idx_beta_random, idx_exposure))
  
  # ────────────────────────────
  # Exposures

  # Number of exposures
  K_exposure <- length(idx_exposure)
  
  # Create the expo_to_rest mapping
  # Tells Stan which restaurant each exposure column belongs to
  if (K_exposure > 0) {
    expo_to_rest <- integer(K_exposure)
    for (k in 1:K_exposure) {
      col_idx <- idx_exposure[k]
      active <- unique(restaurant_id_train[X_train[, col_idx] != 0])
      if (length(active) == 0) {
        stop(paste("Exposure column", model_colnames[col_idx], "is all zeros in the training data."))
      } else if (length(active) > 1) {
        stop(paste("Exposure column", model_colnames[col_idx], "is active for multiple restaurants:", paste(active, collapse=", "), ". Each exposure needs to belong to only one restaurant."))
      } else {
        expo_to_rest[k] <- active}}
    print("Successfully created `expo_to_rest` mapping.")
  } else {
    expo_to_rest <- integer(0)}
  
  # Create the expo_to_param mapping
  # Links each exposure column to a parameter type (1=intercept, 2=slope)
  if (K_exposure > 0) {
    exposure_colnames <- model_colnames[idx_exposure]
    expo_to_param <- ifelse(grepl("_slope$", exposure_colnames), 2, 1)
    print("Successfully created `expo_to_param` mapping.")
  } else {
    expo_to_param <- integer(0)}
  
  # ────────────────────────────
  # Lags
  
  # Alpha & delta random/fixed indices 
  # (indices within effective_lags_alpha, and effective_lags_delta)
  idx_alpha_random <- which(effective_lags_alpha %in% random_lags_alpha_values)
  idx_alpha_fixed <- setdiff(1:p_effective, idx_alpha_random)
  idx_delta_random <- which(effective_lags_delta %in% random_lags_delta_values)
  idx_delta_fixed <- setdiff(1:q_effective, idx_delta_random)
  
  # ────────────────────────────
  # View
  
  cat("Identified ", length(idx_beta_random), 
      " random beta columns: \n", 
      paste(model_colnames[idx_beta_random], collapse=", \n"), "\n", sep="")
  cat("Identified ", length(idx_exposure), 
      " exposure columns in the design matrix: \n",
      paste(model_colnames[idx_exposure], collapse=", \n"), "\n", sep="")
  cat("Identified ", length(idx_beta_fixed), 
      " fixed beta columns: \n",
      paste(model_colnames[idx_beta_fixed], collapse=", \n"), "\n", sep="")
  cat("Identified ", length(idx_alpha_random), 
      " random alpha indices (positions): \n", 
      paste(idx_alpha_random, collapse=", "), "\n", sep="")
  cat("Identified ", length(idx_delta_random), 
      " random delta indices (positions): \n", 
      paste(idx_delta_random, collapse=", "), "\n", sep="") 
  
  
  # ──────────────────────────────────
  #   5. Prepare Stan Data List
  # ──────────────────────────────────
  
  # ────────────────────────────
  # Hyperpriors (for scales)
  
  # Gamma, for exposure
  mu_gamma_scale_input <- 1.0
  sigma_gamma_between_scale_input <- 1.0
  sigma_gamma_within_scale_input <- 1.0
  
  # Predictors
  mu_beta_scale_input  <- 1.0 # Scale for normal priors on mu_beta_*
  sigma_beta_scale_input <- 1.0 # Rate for exponential priors on sigma_beta_*
  
  # Lagged outcomes
  mu_alpha_scale_input <- 1.0
  sigma_alpha_scale_input <- 1.0
  
  # Lagged intensities
  mu_delta_scale_input <- 1.0
  sigma_delta_scale_input <- 1.0
  
  # Dispersion 
  mu_phi_log_scale_input <- 1.0
  sigma_phi_log_scale_input <- 1.0
  
  data_list <- list(
    
    # ────────────────────────────
    #         Metadata
    
    # Size of design matrix
    R = R, # Number of restaurants
    J = J, # Number of predictors
    p_effective = p_effective,
    q_effective = q_effective,
    M = M, # Number of exposures
    
    # Indices for pooled versus non-pooled predictors
    idx_intercept = idx_intercept,
    K_beta_random = length(idx_beta_random),
    idx_beta_random = idx_beta_random,
    K_beta_fixed = length(idx_beta_fixed),
    idx_beta_fixed = idx_beta_fixed,
    
    # Exposure data
    K_exposure = K_exposure,
    idx_exposure = idx_exposure,
    expo_to_rest = expo_to_rest,
    expo_to_param = expo_to_param,
    
    # Indices for outcome lags (within effective_lags_*)
    effective_lags_alpha = effective_lags_alpha,
    K_alpha_random = length(idx_alpha_random),
    idx_alpha_random = idx_alpha_random,
    K_alpha_fixed = length(idx_alpha_fixed),
    idx_alpha_fixed = idx_alpha_fixed,
    
    # Indices for latent intensities
    effective_lags_delta = effective_lags_delta,
    K_delta_random = length(idx_delta_random),
    idx_delta_random = idx_delta_random,
    K_delta_fixed = length(idx_delta_fixed),
    idx_delta_fixed = idx_delta_fixed,
    
    # ────────────────────────────
    #            Data
    
    # Training Data
    N_train = df_list[['N_train']],
    X_train = df_list[['X_train']],
    y_train = df_list[['y_train']],
    
    # A map from the index to restaurants, 
    # indicating which restaurant it is (since it is long data)
    idx_to_rest_train = df_list[['restaurant_id_train']],
    train_start_idx = df_list[['start_idx_train']],
    train_end_idx = df_list[['end_idx_train']],
    
    # Testing Data
    N_test = df_list[['N_test']],
    X_test = df_list[['X_test']],
    y_test = df_list[['y_test']],
    
    # Again, a map from the index to restaurants,
    # indicating which restaurant it is (since it is long data)
    idx_to_rest_test = df_list[['restaurant_id_test']],
    test_start_idx = df_list[['start_idx_test']],
    test_end_idx = df_list[['end_idx_test']],
    
    # Gamma hyperpriors
    mu_gamma_scale = mu_gamma_scale_input,
    sigma_gamma_between_scale = sigma_gamma_between_scale_input,
    sigma_gamma_within_scale = sigma_gamma_within_scale_input,
    
    # Hyperprior Scales
    mu_beta_scale = mu_beta_scale_input,
    sigma_beta_scale = sigma_beta_scale_input,
    mu_alpha_scale = mu_alpha_scale_input,
    sigma_alpha_scale = sigma_alpha_scale_input,
    mu_delta_scale = mu_delta_scale_input,
    sigma_delta_scale = sigma_delta_scale_input,
    mu_phi_log_scale = mu_phi_log_scale_input,
    sigma_phi_log_scale = sigma_phi_log_scale_input)
  
  
  # ──────────────────────────────────
  #       6. Compile and Fit
  # ──────────────────────────────────
  
  mod <- cmdstan_model("model_multilevel_transfer.stan")
  
  init_fn <- function(chain_id = 1) {
    init_list <- list(
      
      # Population Means (initialize near zero, maybe slightly positive intercept)
      mu_beta_intercept = rnorm(1, 0.5, 0.1), # Slightly positive
      mu_beta_random = rnorm(data_list$K_beta_random, 0, 0.1),
      mu_beta_fixed = rnorm(data_list$K_beta_fixed, 0, 0.1),
      mu_alpha_random_raw = rnorm(data_list$K_alpha_random, 0, 0.1), # Raw scale
      mu_alpha_fixed_raw = rnorm(data_list$K_alpha_fixed, 0, 0.1),   # Raw scale
      mu_delta_random_raw = rnorm(data_list$K_delta_random, 0, 0.1), # Raw scale
      mu_delta_fixed_raw = rnorm(data_list$K_delta_fixed, 0, 0.1),   # Raw scale
      mu_phi_log = rnorm(1, log(5), 0.5), # Init phi around 5 on log scale
      
      # Population Standard Deviations (initialize small positive)
      sigma_beta_intercept = abs(rnorm(1, 0, 0.5)) + 0.1,
      sigma_beta_random = abs(rnorm(data_list$K_beta_random, 0, 0.5)) + 0.1,
      sigma_alpha_random = abs(rnorm(data_list$K_alpha_random, 0, 0.5)) + 0.1,
      sigma_delta_random = abs(rnorm(data_list$K_delta_random, 0, 0.5)) + 0.1,
      sigma_phi_log = abs(rnorm(1, 0, 0.5)) + 0.1,
      
      # Standardized Deviations (initialize standard normal)
      z_beta_intercept = rnorm(R, 0, 1),
      z_beta_random = matrix(rnorm(data_list$K_beta_random * R, 0, 1), data_list$K_beta_random, R),
      z_alpha_random = matrix(rnorm(data_list$K_alpha_random * R, 0, 1), data_list$K_alpha_random, R),
      z_delta_random = matrix(rnorm(data_list$K_delta_random * R, 0, 1), data_list$K_delta_random, R),
      z_phi_log = rnorm(R, 0, 1))
    
    # Conditionally add gamma-related initial values if there are exposure columns
    if (K_exposure > 0) {
      init_list$mu_gamma <- rnorm(M, 0, 0.1)
      init_list$sigma_gamma_between <- abs(rnorm(M, 0, 0.5)) + 0.1
      init_list$sigma_gamma_within <- abs(rnorm(M, 0, 0.5)) + 0.1
      init_list$z_eta <- matrix(rnorm(M * R, 0, 1), M, R) # Now a matrix
      init_list$z_gamma <- rnorm(K_exposure, 0, 1)}
    
    return(init_list)
  }
  
  new_fit_created <- FALSE
  # Create directories if they don't exist
  if (file.exists(fit_file)) {
    print("Loading existing fit file...")
    fit <- readRDS(fit_file)
  } else {
    new_fit_created <- TRUE
    print("Fitting the multilevel model...")
    fit <- mod$sample(
      data = data_list,
      seed = seed,
      chains = chains, 
      parallel_chains = parallel_chains,
      iter_warmup = iter_warmup,
      iter_sampling = iter_sampling,
      init = init_fn,
      adapt_delta = adapt_delta, # This is relatively high
      max_treedepth = max_treedepth
    )
    print("Saving fit object...")
    fit$save_object(fit_file)}
  
  
  # ──────────────────────────────────
  #       7. Save Results
  # ──────────────────────────────────
  
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
  
  print("Extracting test predictions...")
  y_test_rep_mean_file <- file.path(output_dir, "y_test_rep_mean_multi.rds")
  if (file.exists(y_test_rep_mean_file)) {
    y_test_rep_mean <- readRDS(y_test_rep_mean_file)
  } else {
    y_test_rep_mean <- as_draws_df(fit$draws("y_test_rep")) %>% 
      dplyr::select(starts_with("y_test_rep")) %>% 
      colMeans()
    saveRDS(y_test_rep_mean, file.path(output_dir, "y_test_rep_mean_multi.rds"))
  }
  
  # ────────────────────────────
  # Mlflow logging
  
  # Log key diagnostic metrics from Stan
  # These tell you if the model converged well
  max_rhat <- max(summ$rhat, na.rm = TRUE)
  min_ess_bulk <- min(summ$ess_bulk, na.rm = TRUE)
  min_ess_tail <- min(summ$ess_tail, na.rm = TRUE)
  
  # Log performance metrics
  # Calculate simple error metrics to compare models
  mae_train <- mean(abs(y_rep_mean - data_list$y_train))
  mae_test <- mean(abs(y_test_rep_mean - data_list$y_test))
  
  
  
  # ──────────────────────────────────
  #        8. Plot Results
  # ──────────────────────────────────

  print("Generating plots...")
  
  exposure_dates_df <- df %>%
    select(location_id, date, any_of(exposure_predictors)) %>%
    pivot_longer(
      cols = any_of(exposure_predictors),
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

  plot_data_test <- tibble(
    pred = y_test_rep_mean,
    obs = data_list$y_test,
    restaurant_idx = data_list$idx_to_rest_test) %>%
    mutate(time_idx = 1:n())
  
  # We need the original dates back. Easiest way is to rebuild the date sequence
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
  for(i in 1:R) {
    loc_id <- restaurants_to_model[i]
    
    loc_exposure_dates <- exposure_dates_df %>%
      filter(location_id == loc_id) %>%
      pull(date)


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
        geom_vline(xintercept = loc_exposure_dates, linetype = "dashed", color = "blue", alpha = 0.7) +
        labs(title = paste(loc_id, "- Training Data"), y = "Weekly Count", x = "Week") +
        scale_color_manual(values = c("Observed" = "black", "Predicted" = "red")) +
        theme_minimal() + theme(legend.position = "bottom")
      
      p_test <- ggplot(test_weekly_data, aes(x = week)) +
        geom_line(aes(y = obs, color = "Observed")) +
        geom_line(aes(y = pred, color = "Predicted")) +
        geom_vline(xintercept = loc_exposure_dates, linetype = "dashed", color = "blue", alpha = 0.7) +
        labs(title = paste(loc_id, "- Test Data"), y = "Weekly Count", x = "Week") +
        scale_color_manual(values = c("Observed" = "black", "Predicted" = "red")) +
        theme_minimal() + theme(legend.position = "bottom")
      
      combined_plot <- p_train + p_test + plot_layout(guides = "collect") & theme(legend.position = 'bottom')
      
      
      # png(file.path(plot_dir, paste0(loc_id, "_multi.png")), width = 2400, height = 1200, res = 300)
      # # grid.draw(pred_plot) # If using your original function
      # print(combined_plot) # Otherwise
      # dev.off()

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
  }
  
  list(
      fit_file = fit_file, summ_file = summ_file, samples_file = samples_file,
      y_rep_mean_file = y_rep_mean_file, y_test_rep_mean_file = y_test_rep_mean_file,
      plot_dir = plot_dir,
      max_rhat = max_rhat, min_ess_bulk = min_ess_bulk, min_ess_tail = min_ess_tail,
      mae_train = mae_train, mae_test = mae_test,
      # keep anything else you want to log (params, predictors, etc.)
      exposure_predictors = exposure_predictors,
      fixed_predictors = fixed_predictors,
      random_predictors = random_predictors,
      R = R, J = J, K_exposure = K_exposure,
      p_max = p_max, q_max = q_max, p_effective = p_effective, q_effective = q_effective,
      random_lags_alpha_values = random_lags_alpha_values,
      random_lags_delta_values = random_lags_delta_values
    )
  }, error = function(e) {
    message("run_ingarch failed before MLflow logging: ", conditionMessage(e))
    return(NULL)  # <- no MLflow run is created
  })

  if (is.null(result)) {
    # Failed: exit quietly, nothing in MLflow
    return(invisible(NULL))
  }

  if (isTRUE(result$new_fit_created)) {

    # 2) Success: open MLflow run and log
    run <- mlflow_start_run(run_name = paste(analysis, outcome, "allpred", iter_sampling, sep = "_"))
    on.exit(mlflow_end_run(status = "FINISHED"), add = TRUE)

    # params (log now that we know the job succeeded)
    mlflow_log_param("outcome", outcome)
    mlflow_log_param("restaurants", paste(restaurants_to_model, collapse = ", "))
    mlflow_log_param("fixed_predictors", paste(result$fixed_predictors, collapse = ", "))
    mlflow_log_param("random_predictors", paste(result$random_predictors, collapse = ", "))
    mlflow_log_param("exposure_predictors", paste(result$exposure_predictors, collapse = ", "))
    mlflow_log_param("R", result$R); mlflow_log_param("J", result$J); mlflow_log_param("K_exposure", result$K_exposure)
    mlflow_log_param("p_max", p_max); mlflow_log_param("q_max", q_max)
    mlflow_log_param("p_effective", p_effective); mlflow_log_param("q_effective", q_effective)
    mlflow_log_param("random_lags_alpha_values", paste(random_lags_alpha_values, collapse = ", "))
    mlflow_log_param("random_lags_delta_values", paste(random_lags_delta_values, collapse = ", "))
    mlflow_log_param("chains", chains); mlflow_log_param("parallel_chains", parallel_chains)
    mlflow_log_param("iter_warmup", iter_warmup); mlflow_log_param("iter_sampling", iter_sampling)
    mlflow_log_param("adapt_delta", adapt_delta); mlflow_log_param("max_treedepth", max_treedepth)

    # metrics
    mlflow_log_metric("max_rhat", result$max_rhat)
    mlflow_log_metric("min_ess_bulk", result$min_ess_bulk)
    mlflow_log_metric("min_ess_tail", result$min_ess_tail)
    mlflow_log_metric("mae_train", result$mae_train)
    mlflow_log_metric("mae_test", result$mae_test)

    # artifacts
    mlflow_log_artifact("model_multilevel_transfer.stan")
    mlflow_log_artifact(result$fit_file)
    mlflow_log_artifact(result$summ_file)
    mlflow_log_artifact(result$samples_file)
    mlflow_log_artifact(result$y_rep_mean_file)
    mlflow_log_artifact(result$y_test_rep_mean_file)
    mlflow_log_artifacts(result$plot_dir)
  } else {
    print("Skipping MLflow logging as existing fit file was loaded.")
  }

  print("Done.")
  invisible(result)
  
  



}
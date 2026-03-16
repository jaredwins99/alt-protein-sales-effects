library(rprojroot)
root <- rprojroot::find_root(rprojroot::is_git_root)
setwd(root)

library(tidyverse)
library(dplyr)
library(lubridate)
library(cmdstanr)
library(posterior)
library(reticulate)
library(mlflow)
library(renv)

if (TRUE) print(5) 
else {
  print(10)}

ingarch_path <- file.path("model_scripts","ingarch_scripts")
source(file.path("tools","modeling_functions.R"))
source(file.path(ingarch_path,"1_data_ingarch.R"))
source(file.path(ingarch_path,"2_index_ingarch.R"))
source(file.path(ingarch_path,"3_init_ingarch.R"))
source(file.path(ingarch_path,"4_plot_ingarch.R"))

run_ingarch <- function(
  directory = "official",
  analysis = c("proportion","its","customer","targeted_proportion","targeted_its","targeted_customer"),
  outcome = "nonvegan",
  data_file = "all_locations_daily_weather_inflation.parquet",
  seed = 123,
  chains = 3,
  parallel_chains = 3,
  iter_warmup = 700,
  iter_sampling = 1500,
  adapt_delta = 0.95, # This is relatively high
  max_treedepth = 12,
  restaurants_to_model = c(
    ## Tier 1
    'VLZX7K2M9QD4T', 'SRQS8F7JWA9MZ', '2HRX9P6HKXA8V', 'JHDN7CF1C03X5',
    'L69HYJ4Y3TR91','ED5J990H5VAZT'#,#'W8T41JZK0ZMEP',
    ## Tier 2
    # #'EMBVNVD207CC6',
    # 'C0BE4NDSW26QN',
    # #'75WYSXR9QBK5M',
    # 'V3Q26BHF3SE2H','LBZEEFSBJNB3Z','SAFK7ND1HR6XS','CB2KHY1C2G9PT',
    # 'S8MT0YGD2KTN9','LFZFT3VASXPED','1SQPTEGYPH0GA','9XKJD8DQTH559',
    # 'LQ5EH4BKGV61T','78AY09MVJVTYE')
  ),
  group2_restaurants = c(),#"JHDN7CF1C03X5",
  random_predictors = c(
    "vegan_price_real", # continuous
    "vegetarian_price_real", # continuous
    "meat_price_real", # continuous
    "weekend", # binary
    "holiday_window", # binary
    "month_cat", # factor
    "season",  # factor
    "year_cat", # factor
    "date_num" # continuous
  ),
  fixed_predictors = c(
    "day_of_week_cat", # factor
    "inflation", # continuous
    "temp", # continuous
    "precip" # continuous
  ),
  exposure = NULL,
  effective_lags_alpha = c(1, 2, 3, 4, 5, 6, 7, 14, 21, 28, 35, 42),
  effective_lags_delta = c(1, 2, 3, 4, 5, 6, 7, 14, 21, 28, 35, 42),
  random_lags_alpha_values = c(1, 7),
  random_lags_delta_values = c(1, 7),
  # ────────────────────────────
  # Hyperpriors (for scales)
    
  mu_gamma_scale_input = 1.0, # Gamma: for exposure
  sigma_gamma_between_scale_input = 1.0,
  sigma_gamma_within_scale_input = 1.0,
  
  mu_beta_scale_input  = 1.0, # Predictors: scale for normal priors on mu_beta_*
  sigma_beta_scale_input = 1.0,  # Predictors: rate for exponential priors on sigma_beta_*
  
  # Group 2 hyperpriors for strong regularization to zero # <<< NEW
  mu_beta_scale_group2_input  = 0.001,
  sigma_beta_scale_group2_input = 10.0,

  mu_alpha_scale_input = 1.0,  # Lagged outcomes
  sigma_alpha_scale_input = 1.0,
  mu_delta_scale_input = 1.0,   # Lagged intensities
  sigma_delta_scale_input = 1.0,

  mu_phi_log_scale_input = 1.0,   # Dispersion
  sigma_phi_log_scale_input = 1.0,
  
  # Group 2 hyperpriors for strong regularization to zero # <<< NEW
  mu_alpha_scale_group2_input = 0.001,
  sigma_alpha_scale_group2_input = 10.0,
  mu_delta_scale_group2_input = 0.001,
  sigma_delta_scale_group2_input = 10.0,

  mu_phi_log_scale_group2_input = 1.0,
  sigma_phi_log_scale_group2_input = 10.0
) {
      
  result <- tryCatch({

    set.seed(seed)
    
    analysis <- match.arg(analysis)
    DATA_DIR <- file.path("data", "4_data_parquet_modeling", data_file)
    if (is.null(exposure)) output_dir <- file.path("model_fits", directory, analysis, outcome, exposure)
    else output_dir <- file.path("model_fits", directory, analysis, outcome)
    plot_dir <- file.path(output_dir, "plots")
    fit_file <- file.path(output_dir, "fit.rds")
    if (!dir.exists(plot_dir)) dir.create(plot_dir, recursive = TRUE)
    
    train_frac <- 0.95
    
    prepared_list <- prepare_data(
      data_dir = DATA_DIR,
      outcome = outcome,
      restaurants_to_model = restaurants_to_model,
      random_predictors = random_predictors,
      fixed_predictors = fixed_predictors,
      train_frac = train_frac)
    df_unscaled <- prepared_list$df_unscaled
    df <- prepared_list$df_scaled
    matrix_list <- prepared_list$matrix_list
    predictor_map <- prepared_list$predictor_map
    exposure_predictors <- prepared_list$exposure_predictors
    term_from_assign <- prepared_list$term_from_assign

    index_list <- index_data(
      matrix_list = matrix_list, 
      random_predictors = random_predictors,
      term_from_assign = term_from_assign,
      effective_lags_alpha = effective_lags_alpha, 
      effective_lags_delta = effective_lags_delta, 
      random_lags_alpha_values = random_lags_alpha_values, 
      random_lags_delta_values = random_lags_delta_values)

    # ──────────────────────────────────
    #   Create restaurant group vector
    # ──────────────────────────────────
    
    # Create the grouping vector based on the function arguments
    restaurant_to_group <- rep(1, index_list$R) # Default all to group 1
    group2_indices <- which(restaurants_to_model %in% group2_restaurants)
    if (length(group2_indices) > 0) {
      restaurant_to_group[group2_indices] <- 2
      print("Assigning restaurants to group 2:")
      print(restaurants_to_model[group2_indices])
    }

    # ──────────────────────────────────
    #   1. Prepare Stan Data List
    # ──────────────────────────────────
    
    data_list <- list(
      
      # ────────────────────────────
      #         Metadata
      
      # Size of design matrix
      R = index_list$R, # Number of restaurants
      J = index_list$J, # Number of predictors
      p_effective = index_list$p_effective,
      q_effective = index_list$q_effective,
      M = index_list$M, # Number of exposures
      
      # Indices for pooled versus non-pooled predictors
      idx_intercept = index_list$idx_intercept,
      K_beta_random = length(index_list$idx_beta_random),
      idx_beta_random = index_list$idx_beta_random,
      K_beta_fixed = length(index_list$idx_beta_fixed),
      idx_beta_fixed = index_list$idx_beta_fixed,
      
      # Exposure data
      K_exposure = index_list$K_exposure,
      idx_exposure = index_list$idx_exposure,
      expo_to_rest = index_list$expo_to_rest,
      expo_to_param = index_list$expo_to_param,
      
      # Indices for outcome lags (within effective_lags_*)
      effective_lags_alpha = effective_lags_alpha,
      K_alpha_random = length(index_list$idx_alpha_random),
      idx_alpha_random = index_list$idx_alpha_random,
      K_alpha_fixed = length(index_list$idx_alpha_fixed),
      idx_alpha_fixed = index_list$idx_alpha_fixed,

      # Indices for latent intensities (within effective_lags_*)
      effective_lags_delta = effective_lags_delta,
      K_delta_random = length(index_list$idx_delta_random),
      idx_delta_random = index_list$idx_delta_random,
      K_delta_fixed = length(index_list$idx_delta_fixed),
      idx_delta_fixed = index_list$idx_delta_fixed,

      # Indices for grouping
      restaurant_to_group = restaurant_to_group, # <<< NEW

      # ────────────────────────────
      #            Data
      
      # Training Data
      N_train = matrix_list[['N_train']],
      X_train = matrix_list[['X_train']],
      y_train = matrix_list[['y_train']],
      
      # A map from the index to restaurants for long data
      idx_to_rest_train = matrix_list[['restaurant_id_train']],
      train_start_idx = matrix_list[['start_idx_train']],
      train_end_idx = matrix_list[['end_idx_train']],
      
      # Testing Data
      N_test = matrix_list[['N_test']],
      X_test = matrix_list[['X_test']],
      y_test = matrix_list[['y_test']],
      
      # A map from the index to restaurants for long data
      idx_to_rest_test = matrix_list[['restaurant_id_test']],
      test_start_idx = matrix_list[['start_idx_test']],
      test_end_idx = matrix_list[['end_idx_test']],
      
      # Gamma hyperpriors
      mu_gamma_scale = mu_gamma_scale_input,
      sigma_gamma_between_scale = sigma_gamma_between_scale_input,
      sigma_gamma_within_scale = sigma_gamma_within_scale_input,
      
      # Hyperprior Scales
      mu_beta_scale = mu_beta_scale_input,
      sigma_beta_scale = sigma_beta_scale_input,

      # Group 2 Hyperpriors # <<< NEW
      mu_beta_scale_group2 = mu_beta_scale_group2_input,
      sigma_beta_scale_group2 = sigma_beta_scale_group2_input,

      # Hyperprior Scales
      mu_alpha_scale = mu_alpha_scale_input,
      sigma_alpha_scale = sigma_alpha_scale_input,
      mu_delta_scale = mu_delta_scale_input,
      sigma_delta_scale = sigma_delta_scale_input,
      mu_phi_log_scale = mu_phi_log_scale_input,
      sigma_phi_log_scale = sigma_phi_log_scale_input,
      
      # Group 2 Hyperpriors # <<< NEW
      mu_alpha_scale_group2 = mu_alpha_scale_group2_input,
      sigma_alpha_scale_group2 = sigma_alpha_scale_group2_input,
      mu_delta_scale_group2 = mu_delta_scale_group2_input,
      sigma_delta_scale_group2 = sigma_delta_scale_group2_input,
      mu_phi_log_scale_group2 = mu_phi_log_scale_group2_input,
      sigma_phi_log_scale_group2 = sigma_phi_log_scale_group2_input
      )
  

    # ──────────────────────────────────
    #       2. Compile and Fit
    # ──────────────────────────────────
    
    print(data_list %>% lapply(head))

    mod <- cmdstan_model((file.path("models","model_multilevel_transfer.stan")))
    
    init_fn <- function(chain_id = 1) init_ingarch(data_list, chain_id)

    samples_file <- file.path(output_dir, "samples.rds")
    new_fit_created <- FALSE
    # Create directories if they don't exist
    if (file.exists(samples_file)) {
      print("Existing samples found, skipping fit...")
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
        init = init_fn, # in init_ingarch.R
        adapt_delta = adapt_delta, 
        max_treedepth = max_treedepth)
      print("Saving fit object...")
      fit$save_object(fit_file)}
    
    
    # ──────────────────────────────────
    #       3. Save Results
    # ──────────────────────────────────
    
    
    summ_file <- file.path(output_dir, "summ.rds")
    if (file.exists(summ_file)) {
      print("Loading existing summary file...")
      summ <- readRDS(summ_file)
    } else {
      print("Calculating summary...")
      summ <- fit$summary()
      saveRDS(summ, summ_file)}
      saveRDS(predictor_map, file.path(output_dir, "predictor_map.rds"))
    
    if (file.exists(samples_file)) {
      print("Loading existing samples file...")
      samples <- readRDS(samples_file)
    } else {
      print("Calculating samples...")
      samples <- as_draws_df(fit$draws())
      saveRDS(samples, samples_file)}
    
    metadata_file <- file.path(output_dir, "metadata.rds")
    if (file.exists(metadata_file)) {
      print("Loading existing metadata file...")
      metadata <- readRDS(metadata_file)
    } else {
      print("Calculating metadata...")
      metadata <- fit$metadata()
      saveRDS(metadata, metadata_file)}
    
    print("Summary of Hyperpriors (mu_*, sigma_*):")
    print(summ %>% filter(grepl("^(mu_|sigma_)", variable)), n=300) 
    
    lambda_mean_file <- file.path(output_dir, "lambda_mean.rds")
    if (file.exists(lambda_mean_file)) {
      print("Loading existing lambda_mean file...")
      lambda_mean <- readRDS(lambda_mean_file)
    } else {
      print("Calculating lambda_mean...")
      lambda_mean <- as_draws_df(fit$draws("lambda")) %>% 
        dplyr::select(starts_with("lambda")) %>%
        colMeans()
      saveRDS(lambda_mean, lambda_mean_file)
    }

    lambda_test_mean_file <- file.path(output_dir, "lambda_test_mean.rds")
    if (file.exists(lambda_test_mean_file)) {
      print("Loading existing lambda_test_mean file...")
      lambda_test_mean <- readRDS(lambda_test_mean_file)
    } else {
      print("Calculating lambda_test_mean...")
      lambda_test_mean <- as_draws_df(fit$draws("lambda_test")) %>% 
        dplyr::select(starts_with("lambda_test")) %>%
        colMeans()
      saveRDS(lambda_test_mean, lambda_test_mean_file)
    }

    y_rep_mean_file <- file.path(output_dir, "y_rep_mean.rds")
    if (file.exists(y_rep_mean_file)) {
      print("Loading existing y_rep_mean file...")
      y_rep_mean <- readRDS(y_rep_mean_file)
    } else {
      print("Calculating y_rep_mean...")
      y_rep_mean <- as_draws_df(fit$draws("y_rep")) %>% 
        dplyr::select(starts_with("y_rep")) %>%
        colMeans()
      saveRDS(y_rep_mean, file.path(output_dir, "y_rep_mean.rds"))}
    
    y_test_rep_mean_file <- file.path(output_dir, "y_test_rep_mean.rds")
    if (file.exists(y_test_rep_mean_file)) {
      print("Loading existing y_test_rep_mean file...")
      y_test_rep_mean <- readRDS(y_test_rep_mean_file)
    } else {
      print("Calculating y_test_rep_mean...")
      y_test_rep_mean <- as_draws_df(fit$draws("y_test_rep")) %>% 
        dplyr::select(starts_with("y_test_rep")) %>% 
        colMeans()
      saveRDS(y_test_rep_mean, file.path(output_dir, "y_test_rep_mean.rds"))}
    
    # ────────────────────────────
    # For Mlflow logging later
    
    # Log key diagnostic metrics from Stan
    max_rhat <- max(summ$rhat, na.rm = TRUE)
    min_ess_bulk <- min(summ$ess_bulk, na.rm = TRUE)
    min_ess_tail <- min(summ$ess_tail, na.rm = TRUE)
    
    # Log performance metrics
    mae_train <- mean(abs(lambda_mean - data_list$y_train)) # y_rep_mean
    mae_test <- mean(abs(lambda_test_mean - data_list$y_test)) # lambda_test_mean

    plot_ingarch(
        df = df,
        restaurants_to_model = restaurants_to_model,
        data_list = data_list,
        y_rep_mean = lambda_mean, #y_rep_mean,
        y_test_rep_mean = lambda_test_mean, # y_test_rep_mean
        plot_dir = plot_dir
    )

    list(
        fit_file = fit_file, samples_file = samples_file, 
        summ_file = summ_file, y_rep_mean_file = y_rep_mean_file, y_test_rep_mean_file = y_test_rep_mean_file,
        plot_dir = plot_dir,
        max_rhat = max_rhat, min_ess_bulk = min_ess_bulk, min_ess_tail = min_ess_tail,
        mae_train = mae_train, mae_test = mae_test,
        exposure_predictors = exposure_predictors, fixed_predictors = fixed_predictors, random_predictors = random_predictors,
        R = data_list$R, J = data_list$J, K_exposure = data_list$K_exposure,
        p_max = data_list$p_max, q_max = data_list$q_max, p_effective = data_list$p_effective, q_effective = data_list$q_effective,
        random_lags_alpha_values = random_lags_alpha_values, random_lags_delta_values = random_lags_delta_values
      )

    }, error = function(e) {

      message("run_ingarch failed: ", conditionMessage(e))
      return(NULL)

    })

  if (!is.null(result) && isTRUE(result$new_fit_created)) {

    # Open MLflow run and log
    run <- mlflow_start_run(run_name = paste(analysis, outcome, directory, iter_sampling, sep = "_"))
    on.exit(mlflow_end_run(status = "FINISHED"), add = TRUE)

    # Params
    mlflow_log_param("analysis", analysis)
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

    # Metrics
    mlflow_log_metric("max_rhat", result$max_rhat)
    mlflow_log_metric("min_ess_bulk", result$min_ess_bulk)
    mlflow_log_metric("min_ess_tail", result$min_ess_tail)
    mlflow_log_metric("mae_train", result$mae_train)
    mlflow_log_metric("mae_test", result$mae_test)

    # Artifacts
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
  return(invisible())

}
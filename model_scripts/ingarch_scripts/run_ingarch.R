library(rprojroot)
root <- rprojroot::find_root(rprojroot::is_git_root)
setwd(root)

library(tidyverse)
library(dplyr)
library(lubridate)
library(cmdstanr)
library(posterior)
library(reticulate)
# library(mlflow)  # skipped for now
library(renv)

ingarch_path <- file.path("model_scripts","ingarch_scripts")
source(file.path("tools","modeling_functions.R"))
source(file.path(ingarch_path,"1_data_ingarch.R"))
source(file.path(ingarch_path,"2_index_ingarch.R"))
source(file.path(ingarch_path,"3_init_ingarch.R"))
source(file.path(ingarch_path,"4_plot_ingarch.R"))

run_ingarch <- function(
  data_file = file.path("a3_its","finalized.parquet"),
  directory = "official",
  analysis = c("a1_proportion", "a2_proportion_t", "a3_its", "a4_its_t", "customer", "customer_targeted",
               "t2_a1_proportion", "t2_a2_proportion_t", "t2_a3_its", "t2_a4_its_t", "t2_customer", "t2_customer_targeted"),
  outcome = "nonvegan",
  exposure = NULL,
  include_slopes=TRUE,
  seed = 123,
  chains = 3,
  parallel_chains = 3,
  iter_warmup = 1500,#700,
  iter_sampling = 2000, #1500,
  adapt_delta = 0.85,
  max_treedepth = 12,
  # ────────────────────────────
  # Restaurants, preds, and lags
  # ────────────────────────────
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
  effective_lags_alpha = c(1, 2, 3, 4, 5, 6, 7, 14, 21, 28, 35, 42),
  effective_lags_delta = c(1, 2, 3, 4, 5, 6, 7, 14, 21, 28, 35, 42),
  random_lags_alpha_values = c(1, 7),
  random_lags_delta_values = c(1, 7),
  # ────────────────────────────
  # Hyperpriors (for scales)
  # ────────────────────────────
  # Exposures
  mu_gamma_scale_input = 1.0, # Gamma: for exposure
  sigma_gamma_between_scale_input = 1.0,
  sigma_gamma_within_scale_input = 1.0,
  # Predictors
  mu_beta_scale_input  = 1.0, # Predictors: scale for normal priors on mu_beta_*
  sigma_beta_scale_input = 1.0,  # Predictors: rate for exponential priors on sigma_beta_*
  # Lags
  mu_alpha_scale_input = 1.0,  # Lagged outcomes
  sigma_alpha_scale_input = 1.0,
  mu_delta_scale_input = 1.0,   # Lagged intensities
  sigma_delta_scale_input = 1.0,
  # Dispersion
  mu_phi_log_scale_input = 2.0,   # Dispersion
  sigma_phi_log_scale_input = 1.0,
  # Zero-inflation
  mu_pi_logit_scale_input = 2.0,  # Prior scale for global zero-inflation (logit scale)
  sigma_pi_logit_scale_input = 1.0,  # Prior rate for between-restaurant SD
  # Non-centered deviate scales (set > 1 for less informative priors on restaurant-specific effects)
  z_eta_scale_input = 1.0,       # Between-restaurant exposure deviates (standard NCP)
  z_gamma_scale_input = 1.0,     # Within-restaurant exposure deviates (standard NCP)
  z_beta_scale_input = 1.0,      # Restaurant-specific covariate deviates (standard NCP)
  z_alpha_scale_input = 1.0,     # Lagged outcome deviates (standard NCP)
  z_delta_scale_input = 1.0,     # Lagged intensity deviates (standard NCP)
  z_phi_scale_input = 1.0,       # Dispersion deviates (standard NCP)
  z_pi_scale_input = 1.0,        # Zero-inflation deviates (standard NCP)
  # Truncation
  apply_truncation = FALSE,       # TRUE for total outcome (zero-truncated NB), FALSE for subsets (regular NB on open days)
  # Thinning
  thin = 1,
  # Replot mode
  replot_only = FALSE             # TRUE to skip model fitting/loading and just regenerate plots from saved predictions
) {

  result <- tryCatch({

    set.seed(seed)

    analysis <- match.arg(analysis)
    DATA_DIR <- file.path("data", "4_data_parquet_modeling", data_file)
    if (is.null(exposure)) output_dir <- file.path("model_fits", directory, analysis, outcome)
    else output_dir <- file.path("model_fits", directory, analysis, outcome, exposure)
    plot_dir <- file.path(output_dir, "plots")
    fit_file <- file.path(output_dir, "fit.rds")
    if (!dir.exists(plot_dir)) dir.create(plot_dir, recursive = TRUE)

    # Replot-only mode: skip fitting, just regenerate plots from saved predictions
    if (replot_only) {
      y_rep_mean_file <- file.path(output_dir, "y_rep_mean.rds")
      y_test_rep_mean_file <- file.path(output_dir, "y_test_rep_mean.rds")
      data_list_file <- file.path(output_dir, "data_list.rds")
      if (!file.exists(y_rep_mean_file) || !file.exists(y_test_rep_mean_file) || !file.exists(data_list_file)) {
        print(paste("Skipping replot for", output_dir, "- missing prediction files"))
        return(NULL)
      }
      print(paste("Replotting:", output_dir))
      prepared_list <- prepare_data(
        data_dir = DATA_DIR, outcome = outcome, restaurants_to_model = restaurants_to_model,
        random_predictors = random_predictors, fixed_predictors = fixed_predictors,
        train_frac = 0.95, include_slopes = include_slopes)
      df <- prepared_list$df_scaled
      data_list <- readRDS(data_list_file)
      y_rep_mean <- readRDS(y_rep_mean_file)
      y_test_rep_mean <- readRDS(y_test_rep_mean_file)
      plot_ingarch(
        df = df, restaurants_to_model = restaurants_to_model, data_list = data_list,
        y_rep_mean = y_rep_mean, y_test_rep_mean = y_test_rep_mean,
        plot_dir = plot_dir, outcome_label = tools::toTitleCase(gsub("_", " ", outcome)))
      print(paste("Done replotting:", output_dir))
      return(invisible())
    }

    train_frac <- 0.95

    prepared_list <- prepare_data(
      data_dir = DATA_DIR,
      outcome = outcome,
      restaurants_to_model = restaurants_to_model,
      random_predictors = random_predictors,
      fixed_predictors = fixed_predictors,
      train_frac = train_frac,
      include_slopes = include_slopes)
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

      # Hyperprior Scales
      mu_alpha_scale = mu_alpha_scale_input,
      sigma_alpha_scale = sigma_alpha_scale_input,
      mu_delta_scale = mu_delta_scale_input,
      sigma_delta_scale = sigma_delta_scale_input,
      mu_phi_log_scale = mu_phi_log_scale_input,
      sigma_phi_log_scale = sigma_phi_log_scale_input,

      # Non-centered deviate scales
      z_eta_scale = z_eta_scale_input,
      z_gamma_scale = z_gamma_scale_input,
      z_beta_scale = z_beta_scale_input,
      z_alpha_scale = z_alpha_scale_input,
      z_delta_scale = z_delta_scale_input,
      z_phi_scale = z_phi_scale_input
      )

    # Save restaurant order
    saveRDS(restaurants_to_model, file.path(output_dir, "restaurants_order.rds"))

    # Compute open-day indices from total_outcome column (available in all data files)
    # Days where total_outcome == 0 are closed days — excluded from likelihood for all models
    total_outcome_train <- df %>% filter(train_test == "train") %>% pull(total_outcome)
    total_outcome_test <- df %>% filter(train_test == "test") %>% pull(total_outcome)
    idx_total_nonzero_train <- which(total_outcome_train > 0)
    idx_total_nonzero_test <- which(total_outcome_test > 0)
    print(paste("Open-day filtering: using", length(idx_total_nonzero_train), "of",
                matrix_list[['N_train']], "train obs,", length(idx_total_nonzero_test), "of",
                matrix_list[['N_test']], "test obs"))
    data_list$apply_truncation <- as.integer(apply_truncation)
    data_list$N_total_nonzero <- length(idx_total_nonzero_train)
    data_list$idx_total_nonzero <- as.array(idx_total_nonzero_train)
    data_list$N_total_nonzero_test <- length(idx_total_nonzero_test)
    data_list$idx_total_nonzero_test <- as.array(idx_total_nonzero_test)
  
    # Save data_list as RDS in the model fit directory (output_dir)
    data_list_file <- file.path(output_dir, "data_list.rds")
    saveRDS(data_list, data_list_file)

    # ──────────────────────────────────
    #       2. Compile and Fit
    # ──────────────────────────────────
    
    print(data_list %>% lapply(head))

    stan_file <- "model_multilevel_transfer_truncated.stan"
    print(paste("Using Stan model:", stan_file))
    # Use pre-compiled model if available (e.g. in Docker/Singularity), otherwise compile from source
    precompiled <- file.path("/opt/stan_models", tools::file_path_sans_ext(stan_file))
    if (file.exists(precompiled)) {
      mod <- cmdstan_model(exe_file = precompiled)
    } else {
      mod <- cmdstan_model(file.path("models", stan_file))
    }
    
    init_fn <- function(chain_id = 1) init_ingarch(data_list, chain_id)

    samples_file <- file.path(output_dir, "samples.rds")
    new_fit_created <- FALSE
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
        max_treedepth = max_treedepth,
        thin = thin)
      print("Saving fit object...")
      fit$save_object(fit_file)
      }


    # ──────────────────────────────────
    #       3. Save Results (from fit, before freeing memory)
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
      lambda_mean <- colMeans(fit$draws("lambda", format = "matrix"))
      saveRDS(lambda_mean, lambda_mean_file)
    }

    lambda_test_mean_file <- file.path(output_dir, "lambda_test_mean.rds")
    if (file.exists(lambda_test_mean_file)) {
      print("Loading existing lambda_test_mean file...")
      lambda_test_mean <- readRDS(lambda_test_mean_file)
    } else {
      print("Calculating lambda_test_mean...")
      lambda_test_mean <- colMeans(fit$draws("lambda_test", format = "matrix"))
      saveRDS(lambda_test_mean, lambda_test_mean_file)
    }

    y_rep_mean_file <- file.path(output_dir, "y_rep_mean.rds")
    if (file.exists(y_rep_mean_file)) {
      print("Loading existing y_rep_mean file...")
      y_rep_mean <- readRDS(y_rep_mean_file)
    } else {
      print("Calculating y_rep_mean...")
      y_rep_mean <- colMeans(fit$draws("y_rep", format = "matrix"))
      saveRDS(y_rep_mean, file.path(output_dir, "y_rep_mean.rds"))}

    y_test_rep_mean_file <- file.path(output_dir, "y_test_rep_mean.rds")
    if (file.exists(y_test_rep_mean_file)) {
      print("Loading existing y_test_rep_mean file...")
      y_test_rep_mean <- readRDS(y_test_rep_mean_file)
    } else {
      print("Calculating y_test_rep_mean...")
      y_test_rep_mean <- colMeans(fit$draws("y_test_rep", format = "matrix"))
      saveRDS(y_test_rep_mean, file.path(output_dir, "y_test_rep_mean.rds"))}

    # Free fit from memory — everything needed has been extracted
    rm(fit); gc()

    # ────────────────────────────
    # Diagnostics and Plotting

    max_rhat <- max(summ$rhat, na.rm = TRUE)
    min_ess_bulk <- min(summ$ess_bulk, na.rm = TRUE)
    min_ess_tail <- min(summ$ess_tail, na.rm = TRUE)
    mae_train <- mean(abs(lambda_mean - data_list$y_train))
    mae_test <- mean(abs(lambda_test_mean - data_list$y_test))

    structural_zero_prob <- NULL
    structural_zero_prob_test <- NULL

    plot_ingarch(
        df = df,
        restaurants_to_model = restaurants_to_model,
        data_list = data_list,
        y_rep_mean = y_rep_mean,
        y_test_rep_mean = y_test_rep_mean,
        plot_dir = plot_dir,
        outcome_label = tools::toTitleCase(gsub("_", " ", outcome)),
        structural_zero_prob = structural_zero_prob,
        structural_zero_prob_test = structural_zero_prob_test
    )

    # samples.rds skipped here — extract from fit.rds later to avoid peak memory doubling

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

  # MLflow logging — commented out, not installed
  # if (!is.null(result) && isTRUE(result$new_fit_created) && requireNamespace("mlflow", quietly = TRUE)) {
  #   run <- mlflow::mlflow_start_run(run_name = paste(analysis, outcome, directory, iter_sampling, sep = "_"))
  #   on.exit(mlflow::mlflow_end_run(status = "FINISHED"), add = TRUE)
  #   mlflow::mlflow_log_param("analysis", analysis)
  #   ...
  # }

  print("Done.")
  return(invisible())

}
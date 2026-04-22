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

cgi_path <- file.path("model_scripts","ingarch_scripts_customer_gaussian_iid")
source(file.path("tools","modeling_functions.R"))
source(file.path(cgi_path,"1_data_gaussian_iid_day.R"))
source(file.path(cgi_path,"2_index_gaussian_iid.R"))
source(file.path(cgi_path,"3_init_gaussian_iid.R"))
source(file.path(cgi_path,"4_plot_gaussian_iid.R"))

run_gaussian_iid_day <- function(
  data_file = file.path("customer_day","finalized.parquet"),
  directory = "official",
  analysis = "customer_gaussian_iid_transaction",
  outcome = "nonvegan",
  exposure = NULL,
  include_slopes=TRUE,
  include_gender_interactions=TRUE,
  seed = 123,
  chains = 3,
  parallel_chains = 3,
  iter_warmup = 1500,
  iter_sampling = 2000,
  adapt_delta = 0.85,
  max_treedepth = 12,
  # ────────────────────────────
  # Restaurants, preds
  # ────────────────────────────
  restaurants_to_model = c(
    'SRQS8F7JWA9MZ', '2HRX9P6HKXA8V',
    'L69HYJ4Y3TR91','ED5J990H5VAZT'
  ),
  random_predictors = c(
    "vegan_price_real",
    "vegetarian_price_real",
    "meat_price_real",
    "weekend",
    "holiday_window",
    "month_cat",
    "season",
    "year_cat",
    "date_num"
  ),
  fixed_predictors = c(
    "day_of_week_cat",
    "inflation",
    "temp",
    "precip"
  ),
  # ────────────────────────────
  # Hyperpriors (for scales)
  # ────────────────────────────
  # Exposures
  mu_gamma_scale_input = 1.0,
  sigma_gamma_between_scale_input = 1.0,
  sigma_gamma_within_scale_input = 1.0,
  # Predictors
  mu_beta_scale_input  = 1.0,
  sigma_beta_scale_input = 1.0,
  # Gaussian SD
  mu_sigma_log_scale_input = 2.0,
  sigma_sigma_log_scale_input = 1.0,
  # Non-centered deviate scales
  z_eta_scale_input = 1.0,
  z_gamma_scale_input = 1.0,
  z_beta_scale_input = 1.0,
  z_sigma_scale_input = 1.0,
  # Thinning
  thin = 1,
  # Replot mode
  replot_only = FALSE
) {

  result <- tryCatch({

    set.seed(seed)

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
      prepared_list <- prepare_data_gaussian_iid_day(
        data_dir = DATA_DIR,
        outcome = outcome, restaurants_to_model = restaurants_to_model,
        random_predictors = random_predictors, fixed_predictors = fixed_predictors,
        train_frac = 0.95, include_slopes = include_slopes,
        include_gender_interactions = include_gender_interactions)
      df <- prepared_list$df_scaled
      data_list <- readRDS(data_list_file)
      y_rep_mean <- readRDS(y_rep_mean_file)
      y_test_rep_mean <- readRDS(y_test_rep_mean_file)
      plot_gaussian_iid(
        df = df, restaurants_to_model = restaurants_to_model, data_list = data_list,
        y_rep_mean = y_rep_mean, y_test_rep_mean = y_test_rep_mean,
        plot_dir = plot_dir, outcome_label = tools::toTitleCase(gsub("_", " ", outcome)))
      print(paste("Done replotting:", output_dir))
      return(invisible())
    }

    train_frac <- 0.95

    prepared_list <- prepare_data_gaussian_iid_day(
      data_dir = DATA_DIR,
      outcome = outcome,
      restaurants_to_model = restaurants_to_model,
      random_predictors = random_predictors,
      fixed_predictors = fixed_predictors,
      train_frac = train_frac,
      include_slopes = include_slopes,
      include_gender_interactions = include_gender_interactions)
    df_unscaled <- prepared_list$df_unscaled
    df <- prepared_list$df_scaled
    matrix_list <- prepared_list$matrix_list
    predictor_map <- prepared_list$predictor_map
    exposure_predictors <- prepared_list$exposure_predictors
    term_from_assign <- prepared_list$term_from_assign
    random_predictors <- prepared_list$random_predictors

    index_list <- index_data_gaussian_iid(
      matrix_list = matrix_list,
      random_predictors = random_predictors,
      term_from_assign = term_from_assign)

    # ──────────────────────────────────
    #   1. Prepare Stan Data List
    # ──────────────────────────────────

    data_list <- list(

      # ────────────────────────────
      #         Metadata

      # Size of design matrix
      R = index_list$R,
      J = index_list$J,
      M = index_list$M,

      # Indices for pooled versus non-pooled predictors
      idx_intercept = index_list$idx_intercept,
      K_beta_random = length(index_list$idx_beta_random),
      idx_beta_random = as.array(as.integer(index_list$idx_beta_random)),
      K_beta_fixed = length(index_list$idx_beta_fixed),
      idx_beta_fixed = as.array(as.integer(index_list$idx_beta_fixed)),

      # Exposure data
      K_exposure = index_list$K_exposure,
      idx_exposure = as.array(as.integer(index_list$idx_exposure)),
      expo_to_rest = as.array(as.integer(index_list$expo_to_rest)),
      expo_to_param = as.array(as.integer(index_list$expo_to_param)),

      # ────────────────────────────
      #            Data

      # Training Data (y_train is numeric/real for Gaussian model)
      N_train = matrix_list[['N_train']],
      X_train = matrix_list[['X_train']],
      y_train = as.numeric(matrix_list[['y_train']]),

      # A map from the index to restaurants for long data.
      # as.array() keeps the dim even for R=1 / K=1 so cmdstanr doesn't
      # serialize length-1 vectors as Stan scalars.
      idx_to_rest_train = as.array(as.integer(matrix_list[['restaurant_id_train']])),
      train_start_idx   = as.array(as.integer(matrix_list[['start_idx_train']])),
      train_end_idx     = as.array(as.integer(matrix_list[['end_idx_train']])),

      # Testing Data
      N_test = matrix_list[['N_test']],
      X_test = matrix_list[['X_test']],
      y_test = as.numeric(matrix_list[['y_test']]),

      # A map from the index to restaurants for long data
      idx_to_rest_test = as.array(as.integer(matrix_list[['restaurant_id_test']])),
      test_start_idx   = as.array(as.integer(matrix_list[['start_idx_test']])),
      test_end_idx     = as.array(as.integer(matrix_list[['end_idx_test']])),

      # Gamma hyperpriors
      mu_gamma_scale = mu_gamma_scale_input,
      sigma_gamma_between_scale = sigma_gamma_between_scale_input,
      sigma_gamma_within_scale = sigma_gamma_within_scale_input,

      # Beta hyperprior scales
      mu_beta_scale = mu_beta_scale_input,
      sigma_beta_scale = sigma_beta_scale_input,

      # Gaussian SD hyperprior scales
      mu_sigma_log_scale = mu_sigma_log_scale_input,
      sigma_sigma_log_scale = sigma_sigma_log_scale_input,

      # Non-centered deviate scales
      z_eta_scale = z_eta_scale_input,
      z_gamma_scale = z_gamma_scale_input,
      z_beta_scale = z_beta_scale_input,
      z_sigma_scale = z_sigma_scale_input
      )

    # Save restaurant order
    saveRDS(restaurants_to_model, file.path(output_dir, "restaurants_order.rds"))

    # Save data_list as RDS
    data_list_file <- file.path(output_dir, "data_list.rds")
    saveRDS(data_list, data_list_file)

    # ──────────────────────────────────
    #       2. Compile and Fit
    # ──────────────────────────────────

    print(data_list %>% lapply(head))

    stan_file <- "model_multilevel_transfer_customer_gaussian_iid.stan"
    print(paste("Using Stan model:", stan_file))
    # Use pre-compiled model if available (e.g. in Docker/Singularity), otherwise compile from source
    precompiled <- file.path("/opt/stan_models", tools::file_path_sans_ext(stan_file))
    if (file.exists(precompiled)) {
      mod <- cmdstan_model(exe_file = precompiled)
    } else {
      mod <- cmdstan_model(file.path("models", stan_file))
    }

    init_fn <- function(chain_id = 1) init_gaussian_iid(data_list, chain_id)

    samples_file <- file.path(output_dir, "samples.rds")
    new_fit_created <- FALSE
    if (file.exists(fit_file)) {
      print(paste("Existing fit.rds found at", fit_file, "- loading instead of resampling"))
      fit <- readRDS(fit_file)
    } else {
      new_fit_created <- TRUE
      print("Fitting the Gaussian IID (transaction-level demeaned) model...")
      fit <- mod$sample(
        data = data_list,
        seed = seed,
        chains = chains,
        parallel_chains = parallel_chains,
        iter_warmup = iter_warmup,
        iter_sampling = iter_sampling,
        init = init_fn,
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

    # Extract mu (identity link, not lambda = exp(nu))
    mu_mean_file <- file.path(output_dir, "mu_mean.rds")
    if (file.exists(mu_mean_file)) {
      print("Loading existing mu_mean file...")
      mu_mean <- readRDS(mu_mean_file)
    } else {
      print("Calculating mu_mean...")
      mu_mean <- colMeans(fit$draws("mu", format = "matrix"))
      saveRDS(mu_mean, mu_mean_file)
    }

    mu_test_mean_file <- file.path(output_dir, "mu_test_mean.rds")
    if (file.exists(mu_test_mean_file)) {
      print("Loading existing mu_test_mean file...")
      mu_test_mean <- readRDS(mu_test_mean_file)
    } else {
      print("Calculating mu_test_mean...")
      mu_test_mean <- colMeans(fit$draws("mu_test", format = "matrix"))
      saveRDS(mu_test_mean, mu_test_mean_file)
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

    # MAE using mu (identity link)
    mae_train <- mean(abs(mu_mean - data_list$y_train))
    mae_test <- mean(abs(mu_test_mean - data_list$y_test))

    plot_gaussian_iid(
        df = df,
        restaurants_to_model = restaurants_to_model,
        data_list = data_list,
        y_rep_mean = y_rep_mean,
        y_test_rep_mean = y_test_rep_mean,
        plot_dir = plot_dir,
        outcome_label = tools::toTitleCase(gsub("_", " ", outcome))
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
        new_fit_created = new_fit_created
      )

    }, error = function(e) {

      message("run_gaussian_iid failed: ", conditionMessage(e))
      return(NULL)

    })

  # MLflow logging — commented out, not installed
  # if (!is.null(result) && isTRUE(result$new_fit_created)) {
  #   run <- mlflow_start_run(...)
  #   ...
  # }

  print("Done.")
  return(invisible())

}

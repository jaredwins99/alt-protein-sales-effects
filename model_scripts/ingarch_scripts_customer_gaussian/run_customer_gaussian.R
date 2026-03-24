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

cg_path <- file.path("model_scripts","ingarch_scripts_customer_gaussian")
source(file.path("tools","modeling_functions.R"))
source(file.path(cg_path,"1_data_customer_gaussian.R"))
source(file.path(cg_path,"2_index_customer_gaussian.R"))
source(file.path(cg_path,"3_init_customer_gaussian.R"))
source(file.path(cg_path,"4_plot_customer_gaussian.R"))

run_customer_gaussian <- function(
  data_file = file.path("customer","finalized_customers.parquet"),
  item_data_file = file.path("customer","finalized_transactions_customers.parquet"),
  directory = "official",
  analysis = "customer_gaussian",
  outcome = "nonvegan",
  exposure = NULL,
  include_slopes=TRUE,
  seed = 123,
  chains = 3,
  parallel_chains = 3,
  iter_warmup = 1500,
  iter_sampling = 2000,
  adapt_delta = 0.85,
  max_treedepth = 12,
  # ────────────────────────────
  # Restaurants, preds, and lags
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
  effective_lags_alpha = c(1, 2, 3, 4, 5, 6, 7, 14, 21, 28, 35, 42),
  effective_lags_delta = c(1, 2, 3, 4, 5, 6, 7, 14, 21, 28, 35, 42),
  random_lags_alpha_values = c(1, 7),
  random_lags_delta_values = c(1, 7),
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
  # Lags
  mu_alpha_scale_input = 1.0,
  sigma_alpha_scale_input = 1.0,
  mu_delta_scale_input = 1.0,
  sigma_delta_scale_input = 1.0,
  # Gaussian SD (replaces NegBin dispersion phi)
  mu_sigma_log_scale_input = 2.0,
  sigma_sigma_log_scale_input = 1.0,
  # Non-centered deviate scales
  z_eta_scale_input = 1.0,
  z_gamma_scale_input = 1.0,
  z_beta_scale_input = 1.0,
  z_alpha_scale_input = 1.0,
  z_delta_scale_input = 1.0,
  z_sigma_scale_input = 1.0,
  # Replot mode
  replot_only = FALSE
) {

  result <- tryCatch({

    set.seed(seed)

    DATA_DIR <- file.path("data", "4_data_parquet_modeling", data_file)
    ITEM_DATA_DIR <- file.path("data", "4_data_parquet_modeling", item_data_file)
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
      prepared_list <- prepare_data_customer_gaussian(
        data_dir = DATA_DIR, item_data_dir = ITEM_DATA_DIR,
        outcome = outcome, restaurants_to_model = restaurants_to_model,
        random_predictors = random_predictors, fixed_predictors = fixed_predictors,
        train_frac = 0.95, include_slopes = include_slopes)
      df <- prepared_list$df_scaled
      data_list <- readRDS(data_list_file)
      y_rep_mean <- readRDS(y_rep_mean_file)
      y_test_rep_mean <- readRDS(y_test_rep_mean_file)
      plot_customer_gaussian(
        df = df, restaurants_to_model = restaurants_to_model, data_list = data_list,
        y_rep_mean = y_rep_mean, y_test_rep_mean = y_test_rep_mean,
        plot_dir = plot_dir, outcome_label = tools::toTitleCase(gsub("_", " ", outcome)))
      print(paste("Done replotting:", output_dir))
      return(invisible())
    }

    train_frac <- 0.95

    prepared_list <- prepare_data_customer_gaussian(
      data_dir = DATA_DIR,
      item_data_dir = ITEM_DATA_DIR,
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

    index_list <- index_data_customer_gaussian(
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
      R = index_list$R,
      J = index_list$J,
      p_effective = index_list$p_effective,
      q_effective = index_list$q_effective,
      M = index_list$M,

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

      # Training Data (y_train is numeric/real for Gaussian model)
      N_train = matrix_list[['N_train']],
      X_train = matrix_list[['X_train']],
      y_train = as.numeric(matrix_list[['y_train']]),

      # A map from the index to restaurants for long data
      idx_to_rest_train = matrix_list[['restaurant_id_train']],
      train_start_idx = matrix_list[['start_idx_train']],
      train_end_idx = matrix_list[['end_idx_train']],

      # Testing Data
      N_test = matrix_list[['N_test']],
      X_test = matrix_list[['X_test']],
      y_test = as.numeric(matrix_list[['y_test']]),

      # A map from the index to restaurants for long data
      idx_to_rest_test = matrix_list[['restaurant_id_test']],
      test_start_idx = matrix_list[['start_idx_test']],
      test_end_idx = matrix_list[['end_idx_test']],

      # Gamma hyperpriors
      mu_gamma_scale = mu_gamma_scale_input,
      sigma_gamma_between_scale = sigma_gamma_between_scale_input,
      sigma_gamma_within_scale = sigma_gamma_within_scale_input,

      # Beta hyperprior scales
      mu_beta_scale = mu_beta_scale_input,
      sigma_beta_scale = sigma_beta_scale_input,

      # Lag hyperprior scales
      mu_alpha_scale = mu_alpha_scale_input,
      sigma_alpha_scale = sigma_alpha_scale_input,
      mu_delta_scale = mu_delta_scale_input,
      sigma_delta_scale = sigma_delta_scale_input,

      # Gaussian SD hyperprior scales (replaces phi)
      mu_sigma_log_scale = mu_sigma_log_scale_input,
      sigma_sigma_log_scale = sigma_sigma_log_scale_input,

      # Non-centered deviate scales
      z_eta_scale = z_eta_scale_input,
      z_gamma_scale = z_gamma_scale_input,
      z_beta_scale = z_beta_scale_input,
      z_alpha_scale = z_alpha_scale_input,
      z_delta_scale = z_delta_scale_input,
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

    stan_file <- "model_multilevel_transfer_customer_gaussian.stan"
    print(paste("Using Stan model:", stan_file))
    mod <- cmdstan_model(file.path("models", stan_file))

    init_fn <- function(chain_id = 1) init_customer_gaussian(data_list, chain_id)

    samples_file <- file.path(output_dir, "samples.rds")
    new_fit_created <- FALSE
    if (file.exists(samples_file)) {
      print("Existing samples found, skipping fit...")
    } else {
      new_fit_created <- TRUE
      print("Fitting the Gaussian demeaning model...")
      fit <- mod$sample(
        data = data_list,
        seed = seed,
        chains = chains,
        parallel_chains = parallel_chains,
        iter_warmup = iter_warmup,
        iter_sampling = iter_sampling,
        init = init_fn,
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

    # Extract mu (identity link, not lambda = exp(nu))
    mu_mean_file <- file.path(output_dir, "mu_mean.rds")
    if (file.exists(mu_mean_file)) {
      print("Loading existing mu_mean file...")
      mu_mean <- readRDS(mu_mean_file)
    } else {
      print("Calculating mu_mean...")
      mu_mean <- as_draws_df(fit$draws("mu")) %>%
        dplyr::select(starts_with("mu[")) %>%
        colMeans()
      saveRDS(mu_mean, mu_mean_file)
    }

    mu_test_mean_file <- file.path(output_dir, "mu_test_mean.rds")
    if (file.exists(mu_test_mean_file)) {
      print("Loading existing mu_test_mean file...")
      mu_test_mean <- readRDS(mu_test_mean_file)
    } else {
      print("Calculating mu_test_mean...")
      mu_test_mean <- as_draws_df(fit$draws("mu_test")) %>%
        dplyr::select(starts_with("mu_test[")) %>%
        colMeans()
      saveRDS(mu_test_mean, mu_test_mean_file)
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
    # Diagnostics and Plotting

    max_rhat <- max(summ$rhat, na.rm = TRUE)
    min_ess_bulk <- min(summ$ess_bulk, na.rm = TRUE)
    min_ess_tail <- min(summ$ess_tail, na.rm = TRUE)

    # MAE using mu (identity link)
    mae_train <- mean(abs(mu_mean - data_list$y_train))
    mae_test <- mean(abs(mu_test_mean - data_list$y_test))

    # Compute idx_total_nonzero for plotting (not used by Stan model)
    total_outcome_train <- df %>% filter(train_test == "train") %>% pull(total_outcome)
    total_outcome_test <- df %>% filter(train_test == "test") %>% pull(total_outcome)
    idx_total_nonzero_train <- which(total_outcome_train > 0)
    idx_total_nonzero_test <- which(total_outcome_test > 0)
    data_list$idx_total_nonzero <- as.array(idx_total_nonzero_train)
    data_list$idx_total_nonzero_test <- as.array(idx_total_nonzero_test)

    plot_customer_gaussian(
        df = df,
        restaurants_to_model = restaurants_to_model,
        data_list = data_list,
        y_rep_mean = y_rep_mean,
        y_test_rep_mean = y_test_rep_mean,
        plot_dir = plot_dir,
        outcome_label = tools::toTitleCase(gsub("_", " ", outcome))
    )

    list(
        fit_file = fit_file, samples_file = samples_file,
        summ_file = summ_file, y_rep_mean_file = y_rep_mean_file, y_test_rep_mean_file = y_test_rep_mean_file,
        plot_dir = plot_dir,
        max_rhat = max_rhat, min_ess_bulk = min_ess_bulk, min_ess_tail = min_ess_tail,
        mae_train = mae_train, mae_test = mae_test,
        exposure_predictors = exposure_predictors, fixed_predictors = fixed_predictors, random_predictors = random_predictors,
        R = data_list$R, J = data_list$J, K_exposure = data_list$K_exposure,
        p_effective = data_list$p_effective, q_effective = data_list$q_effective,
        random_lags_alpha_values = random_lags_alpha_values, random_lags_delta_values = random_lags_delta_values,
        new_fit_created = new_fit_created
      )

    }, error = function(e) {

      message("run_customer_gaussian failed: ", conditionMessage(e))
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
    mlflow_log_param("p_effective", result$p_effective); mlflow_log_param("q_effective", result$q_effective)
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
    mlflow_log_artifact("models/model_multilevel_transfer_customer_gaussian.stan")
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

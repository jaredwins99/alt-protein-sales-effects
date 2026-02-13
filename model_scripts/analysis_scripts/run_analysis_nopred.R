library(tidyverse)
library(dplyr)

source(file.path("model_scripts","ingarch_scripts","run_ingarch.R"))

CORES_PER_MODEL <- 1

EMPTY_PREDS <- c()
EMPTY_LAGS <- integer(0)

# ══════════════════════════════════════════════════════════════
#   Simple ITS: No predictors, no lags (mirrors run_analysis_finalized.R)
# ══════════════════════════════════════════════════════════════

# A1 Simple
run_simple_prop <- function(outcome, exposure, restaurants_to_model = c(
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT',
            'W8T41JZK0ZMEP'), directory="finalized_simple", adapt_delta = .85, max_treedepth = 10) {
    run_ingarch(
        data_file = file.path("proportion", paste0("finalized_",exposure,".parquet")),
        directory = directory,
        analysis = "proportion",
        outcome = outcome,
        exposure = exposure,
        include_slopes = FALSE,
        restaurants_to_model = restaurants_to_model,
        random_predictors = EMPTY_PREDS,
        fixed_predictors = EMPTY_PREDS,
        effective_lags_alpha = EMPTY_LAGS,
        effective_lags_delta = EMPTY_LAGS,
        random_lags_alpha_values = EMPTY_LAGS,
        random_lags_delta_values = EMPTY_LAGS,
        chains = CORES_PER_MODEL,
        parallel_chains = CORES_PER_MODEL,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth)
    gc()
}

# A2 Simple
run_simple_prop_targeted <- function(outcome, exposure, restaurants_to_model, extra_price_predictor, directory="finalized_simple", adapt_delta = .85, max_treedepth = 10) {
    run_ingarch(
        data_file = file.path("proportion_targeted", paste0("finalized_",exposure,".parquet")),
        directory = directory,
        analysis = "proportion_targeted",
        outcome = outcome,
        exposure = exposure,
        include_slopes = FALSE,
        restaurants_to_model = restaurants_to_model,
        random_predictors = EMPTY_PREDS,
        fixed_predictors = EMPTY_PREDS,
        effective_lags_alpha = EMPTY_LAGS,
        effective_lags_delta = EMPTY_LAGS,
        random_lags_alpha_values = EMPTY_LAGS,
        random_lags_delta_values = EMPTY_LAGS,
        chains = CORES_PER_MODEL,
        parallel_chains = CORES_PER_MODEL,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth)
    gc()
}

# A3 Simple
run_simple_its <- function(outcome, restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'), directory="finalized_simple", adapt_delta = .85, max_treedepth = 10) {
    run_ingarch(
        data_file = file.path("its","finalized.parquet"),
        directory = directory,
        analysis = "its",
        outcome = outcome,
        restaurants_to_model = restaurants_to_model,
        random_predictors = EMPTY_PREDS,
        fixed_predictors = EMPTY_PREDS,
        effective_lags_alpha = EMPTY_LAGS,
        effective_lags_delta = EMPTY_LAGS,
        random_lags_alpha_values = EMPTY_LAGS,
        random_lags_delta_values = EMPTY_LAGS,
        chains = CORES_PER_MODEL,
        parallel_chains = CORES_PER_MODEL,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth)
    gc()
}

# A4 Simple
run_simple_its_targeted <- function(outcome, restaurants_to_model, extra_price_predictor, directory="finalized_simple", adapt_delta = .85, max_treedepth = 10) {
    run_ingarch(
        data_file = file.path("its","finalized.parquet"),
        directory = directory,
        analysis = "its_targeted",
        outcome = outcome,
        restaurants_to_model = restaurants_to_model,
        random_predictors = EMPTY_PREDS,
        fixed_predictors = EMPTY_PREDS,
        effective_lags_alpha = EMPTY_LAGS,
        effective_lags_delta = EMPTY_LAGS,
        random_lags_alpha_values = EMPTY_LAGS,
        random_lags_delta_values = EMPTY_LAGS,
        chains = CORES_PER_MODEL,
        parallel_chains = CORES_PER_MODEL,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth)
    gc()
}

# A5 Simple
run_simple_customer <- function(outcome, directory="finalized_simple", adapt_delta = .85, max_treedepth = 10) {
    run_ingarch(
        data_file = file.path("customer","finalized_customers.parquet"),
        directory = directory,
        analysis = "customer",
        outcome = outcome,
        chains = CORES_PER_MODEL,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        random_predictors = EMPTY_PREDS,
        fixed_predictors = EMPTY_PREDS,
        effective_lags_alpha = EMPTY_LAGS,
        effective_lags_delta = EMPTY_LAGS,
        random_lags_alpha_values = EMPTY_LAGS,
        random_lags_delta_values = EMPTY_LAGS,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth)
    gc()
}

# A6 Simple
run_simple_customer_targeted <- function(outcome, restaurants_to_model, extra_price_predictor, directory="finalized_simple", adapt_delta = .85, max_treedepth = 10) {
    run_ingarch(
        data_file = file.path("customer","finalized_customers.parquet"),
        directory = directory,
        analysis = "customer_targeted",
        outcome = outcome,
        restaurants_to_model = restaurants_to_model,
        random_predictors = EMPTY_PREDS,
        fixed_predictors = EMPTY_PREDS,
        effective_lags_alpha = EMPTY_LAGS,
        effective_lags_delta = EMPTY_LAGS,
        random_lags_alpha_values = EMPTY_LAGS,
        random_lags_delta_values = EMPTY_LAGS,
        chains = CORES_PER_MODEL,
        parallel_chains = CORES_PER_MODEL,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth)
    gc()
}

# A1 T2 Simple
run_simple_prop_t2 <- function(outcome, exposure, restaurants_to_model=c(
            # Tier 1
            'SRQS8F7JWA9MZ', '2HRX9P6HKXA8V', 'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91','ED5J990H5VAZT','W8T41JZK0ZMEP',
            # Tier 2
            'EMBVNVD207CC6',
            'C0BE4NDSW26QN',
            #'75WYSXR9QBK5M',
            'V3Q26BHF3SE2H','LBZEEFSBJNB3Z','SAFK7ND1HR6XS','CB2KHY1C2G9PT',
            'S8MT0YGD2KTN9','LFZFT3VASXPED','1SQPTEGYPH0GA','9XKJD8DQTH559',
            'LQ5EH4BKGV61T','78AY09MVJVTYE'), directory="finalized_simple", adapt_delta = .85, max_treedepth = 10) {
    run_ingarch(
        data_file = file.path("proportion", paste0("finalized_",exposure,".parquet")),
        directory = directory,
        analysis = "t2_proportion",
        outcome = outcome,
        exposure = exposure,
        include_slopes = FALSE,
        restaurants_to_model = restaurants_to_model,
        random_predictors = EMPTY_PREDS,
        fixed_predictors = EMPTY_PREDS,
        effective_lags_alpha = EMPTY_LAGS,
        effective_lags_delta = EMPTY_LAGS,
        random_lags_alpha_values = EMPTY_LAGS,
        random_lags_delta_values = EMPTY_LAGS,
        chains = CORES_PER_MODEL,
        parallel_chains = CORES_PER_MODEL,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth)
    gc()
}

# A2 T2 Simple
run_simple_prop_targeted_t2 <- function(outcome, exposure, restaurants_to_model, extra_price_predictor, directory="finalized_simple", adapt_delta = .85, max_treedepth = 10) {
    run_ingarch(
        data_file = file.path("proportion_targeted", paste0("finalized_",exposure,".parquet")),
        directory = directory,
        analysis = "t2_proportion_targeted",
        outcome = outcome,
        exposure = exposure,
        include_slopes = FALSE,
        restaurants_to_model = restaurants_to_model,
        random_predictors = EMPTY_PREDS,
        fixed_predictors = EMPTY_PREDS,
        effective_lags_alpha = EMPTY_LAGS,
        effective_lags_delta = EMPTY_LAGS,
        random_lags_alpha_values = EMPTY_LAGS,
        random_lags_delta_values = EMPTY_LAGS,
        chains = CORES_PER_MODEL,
        parallel_chains = CORES_PER_MODEL,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth)
    gc()
}

# A3 T2 Simple
run_simple_its_t2 <- function(outcome, restaurants_to_model = c(
            # Tier 1
            'VLZX7K2M9QD4T', 'SRQS8F7JWA9MZ', '2HRX9P6HKXA8V', 'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91','ED5J990H5VAZT','W8T41JZK0ZMEP',
            # Tier 2
            'EMBVNVD207CC6',
            'C0BE4NDSW26QN',
            #'75WYSXR9QBK5M',
            'V3Q26BHF3SE2H','LBZEEFSBJNB3Z','SAFK7ND1HR6XS',#'CB2KHY1C2G9PT',
            'S8MT0YGD2KTN9',#'LFZFT3VASXPED',
            '1SQPTEGYPH0GA','9XKJD8DQTH559',
            'LQ5EH4BKGV61T','78AY09MVJVTYE'), directory="finalized_simple", adapt_delta = .85, max_treedepth = 10) {
    run_ingarch(
        data_file = file.path("its","finalized.parquet"),
        directory = directory,
        analysis = "t2_its",
        outcome = outcome,
        restaurants_to_model = restaurants_to_model,
        random_predictors = EMPTY_PREDS,
        fixed_predictors = EMPTY_PREDS,
        effective_lags_alpha = EMPTY_LAGS,
        effective_lags_delta = EMPTY_LAGS,
        random_lags_alpha_values = EMPTY_LAGS,
        random_lags_delta_values = EMPTY_LAGS,
        chains = CORES_PER_MODEL,
        parallel_chains = CORES_PER_MODEL,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth)
    gc()
}

# A4 T2 Simple
run_simple_its_targeted_t2 <- function(outcome, restaurants_to_model, extra_price_predictor, directory="finalized_simple", adapt_delta = .85, max_treedepth = 10) {
    run_ingarch(
        data_file = file.path("its","finalized.parquet"),
        directory = directory,
        analysis = "t2_its_targeted",
        outcome = outcome,
        restaurants_to_model = restaurants_to_model,
        random_predictors = EMPTY_PREDS,
        fixed_predictors = EMPTY_PREDS,
        effective_lags_alpha = EMPTY_LAGS,
        effective_lags_delta = EMPTY_LAGS,
        random_lags_alpha_values = EMPTY_LAGS,
        random_lags_delta_values = EMPTY_LAGS,
        chains = CORES_PER_MODEL,
        parallel_chains = CORES_PER_MODEL,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth)
    gc()
}

# A5 T2 Simple
run_simple_customer_t2 <- function(outcome, directory="finalized_simple", adapt_delta = .85, max_treedepth = 10) {
    run_ingarch(
        data_file = file.path("customer","finalized_customers.parquet"),
        directory = directory,
        analysis = "t2_customer",
        outcome = outcome,
        chains = CORES_PER_MODEL,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            # Tier 1
            'SRQS8F7JWA9MZ', '2HRX9P6HKXA8V',
            'L69HYJ4Y3TR91','ED5J990H5VAZT','W8T41JZK0ZMEP',
            # Tier 2
            'EMBVNVD207CC6',
            'C0BE4NDSW26QN',
            'V3Q26BHF3SE2H','LBZEEFSBJNB3Z','SAFK7ND1HR6XS',
            'S8MT0YGD2KTN9',
            '1SQPTEGYPH0GA','9XKJD8DQTH559',
            'LQ5EH4BKGV61T','78AY09MVJVTYE'),
        random_predictors = EMPTY_PREDS,
        fixed_predictors = EMPTY_PREDS,
        effective_lags_alpha = EMPTY_LAGS,
        effective_lags_delta = EMPTY_LAGS,
        random_lags_alpha_values = EMPTY_LAGS,
        random_lags_delta_values = EMPTY_LAGS,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth)
    gc()
}

# A6 T2 Simple
run_simple_customer_targeted_t2 <- function(outcome, restaurants_to_model, extra_price_predictor, directory="finalized_simple", adapt_delta = .85, max_treedepth = 10) {
    run_ingarch(
        data_file = file.path("customer","finalized_customers.parquet"),
        directory = directory,
        analysis = "t2_customer_targeted",
        outcome = outcome,
        restaurants_to_model = restaurants_to_model,
        random_predictors = EMPTY_PREDS,
        fixed_predictors = EMPTY_PREDS,
        effective_lags_alpha = EMPTY_LAGS,
        effective_lags_delta = EMPTY_LAGS,
        random_lags_alpha_values = EMPTY_LAGS,
        random_lags_delta_values = EMPTY_LAGS,
        chains = CORES_PER_MODEL,
        parallel_chains = CORES_PER_MODEL,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth)
    gc()
}

# ══════════════════════════════════════════════════════════════
#   Legacy / Experimental functions below
# ══════════════════════════════════════════════════════════════

run_nopred_its <- function(outcome, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = "nopred_redux",
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
          fixed_predictors = c(),
          random_predictors = c(),
          effective_lags_alpha = integer(0),
          effective_lags_delta = integer(0),
          random_lags_alpha_values = integer(0),
          random_lags_delta_values = integer(0),
          adapt_delta = adapt_delta, # This is relatively high
          max_treedepth = max_treedepth,
    )
    gc()
}

run_nopred_customer <- function(outcome) {
    run_ingarch(
        directory = "nopred",
        analysis = "customer",
        outcome = outcome,
        data_file = "customer/all_locations_daily_customers_weather_inflation.parquet",
        chains = 3,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT',
            'W8T41JZK0ZMEP'),
        fixed_predictors = c(),
        random_predictors = c())
    gc()
}

run_nopred_targeted_its <- function(outcome, restaurants_to_model) {
    run_ingarch(
        directory = "nopred",
        analysis = "targeted_its",
        outcome = outcome,
        data_file = "targeted/all_locations_daily_targeted_weather_inflation.parquet",
        chains = 3,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = restaurants_to_model,
        fixed_predictors = c(),
        random_predictors = c())
    gc()
}

run_nopred_targeted_customer <- function(outcome, restaurants_to_model) {
    run_ingarch(
        directory = "nopred",
        analysis = "targeted_customer",
        outcome = outcome,
        data_file = "customer/all_locations_daily_customers_weather_inflation.parquet",
        chains = 3,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = restaurants_to_model,
        fixed_predictors = c(),
        random_predictors = c())
        gc()
}

run_nolags_its <- function(outcome, directory) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        effective_lags_alpha = integer(0),
        effective_lags_delta = integer(0),
        random_lags_alpha_values = integer(0),
        random_lags_delta_values = integer(0)
    )
    gc()
}

run_fewlags_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        effective_lags_alpha = c(1,7),
        effective_lags_delta = c(1,7),
        random_lags_alpha_values = c(1,7),
        random_lags_delta_values = c(1,7)
    )
    gc()
}

run_regularized_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepthd,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = .5, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 2,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_alpha_scale_input = .5,  # Lagged outcomes
        sigma_alpha_scale_input = 2,

        mu_delta_scale_input = .5,   # Lagged intensities
        sigma_delta_scale_input = 2,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}

run_regularized2_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = .25, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 4,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_alpha_scale_input = .25,  # Lagged outcomes
        sigma_alpha_scale_input = 4,

        mu_delta_scale_input = .25,   # Lagged intensities
        sigma_delta_scale_input = 4,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}


run_regularized3_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = .1, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 4,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_alpha_scale_input = .1,  # Lagged outcomes
        sigma_alpha_scale_input = 4,

        mu_delta_scale_input = .1,   # Lagged intensities
        sigma_delta_scale_input = 4,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}


run_regularized4_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = .05, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 4,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_alpha_scale_input = .05,  # Lagged outcomes
        sigma_alpha_scale_input = 4,

        mu_delta_scale_input = .05,   # Lagged intensities
        sigma_delta_scale_input = 4,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}


run_regularized5_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = .005, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 4,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_alpha_scale_input = .005,  # Lagged outcomes
        sigma_alpha_scale_input = 4,

        mu_delta_scale_input = .005,   # Lagged intensities
        sigma_delta_scale_input = 4,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}

run_regularized5_noweekend_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        random_predictors = c(
            "vegan_price_real", # continuous
            "vegetarian_price_real", # continuous
            "meat_price_real", # continuous
            #"weekend", # binary 
            "holiday_window", # binary
            "month_cat", # factor
            "season",  # factor
            "year_cat", # factor
            "date_num", # continuous
            "day_of_week_cat" # factor
        ),
        fixed_predictors = c(
            "inflation", # continuous
            "temp", # continuous
            "precip" # continuous
        ),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = .005, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 4,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_alpha_scale_input = .005,  # Lagged outcomes
        sigma_alpha_scale_input = 4,

        mu_delta_scale_input = .005,   # Lagged intensities
        sigma_delta_scale_input = 4,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}

run_regularized4_noweekend_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        random_predictors = c(
            "vegan_price_real", # continuous
            "vegetarian_price_real", # continuous
            "meat_price_real", # continuous
            #"weekend", # binary 
            "holiday_window", # binary
            "month_cat", # factor
            "season",  # factor
            "year_cat", # factor
            "date_num", # continuous
            "day_of_week_cat" # factor
        ),
        fixed_predictors = c(
            "inflation", # continuous
            "temp", # continuous
            "precip" # continuous
        ),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = .05, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 4,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_alpha_scale_input = .05,  # Lagged outcomes
        sigma_alpha_scale_input = 4,

        mu_delta_scale_input = .05,   # Lagged intensities
        sigma_delta_scale_input = 4,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}


run_notime_its <- function(outcome, directory=directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 2,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        random_predictors = c(
            "vegan_price_real", # continuous
            "vegetarian_price_real", # continuous
            "meat_price_real", # continuous
            "date_num" # continuous
        ),
        fixed_predictors = c(
            "inflation", # continuous
            "temp", # continuous
            "precip" # continuous
        )#,
          #effective_lags_alpha = integer(0),
          #effective_lags_delta = integer(0),
          #random_lags_alpha_values = integer(0),
          #random_lags_delta_values = integer(0)
    )
    gc()
}

run_1time_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 2,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        random_predictors = c(
            "vegan_price_real", # continuous
            "vegetarian_price_real", # continuous
            "meat_price_real", # continuous
            
            "holiday_window", # binary
            "date_num" # continuous
        ),
        fixed_predictors = c(
            "inflation", # continuous
            "temp", # continuous
            "precip" # continuous
        )#,
          #effective_lags_alpha = integer(0),
          #effective_lags_delta = integer(0),
          #random_lags_alpha_values = integer(0),
          #random_lags_delta_values = integer(0)
    )
    gc()
}

run_2time_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 2,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        random_predictors = c(
            "vegan_price_real", # continuous
            "vegetarian_price_real", # continuous
            "meat_price_real", # continuous
 
            "holiday_window", # binary
            "month_cat", # factor
            "date_num" # continuous
        ),
        fixed_predictors = c(
            "inflation", # continuous
            "temp", # continuous
            "precip" # continuous
        )#,
          #effective_lags_alpha = integer(0),
          #effective_lags_delta = integer(0),
          #random_lags_alpha_values = integer(0),
          #random_lags_delta_values = integer(0)
    )
    gc()
}

run_3time_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 2,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        random_predictors = c(
            "vegan_price_real", # continuous
            "vegetarian_price_real", # continuous
            "meat_price_real", # continuous

            "holiday_window", # binary
            "month_cat", # factor
            "season",  # factor
            "date_num" # continuous
        ),
        fixed_predictors = c(
            "inflation", # continuous
            "temp", # continuous
            "precip" # continuous
        )#,
          #effective_lags_alpha = integer(0),
          #effective_lags_delta = integer(0),
          #random_lags_alpha_values = integer(0),
          #random_lags_delta_values = integer(0)
    )
    gc()
}

run_4time_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 2,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        random_predictors = c(
            "vegan_price_real", # continuous
            "vegetarian_price_real", # continuous
            "meat_price_real", # continuous

            "holiday_window", # binary
            "month_cat", # factor
            "season",  # factor
            "year_cat", # factor
            "date_num" # continuous
        ),
        fixed_predictors = c(
            "inflation", # continuous
            "temp", # continuous
            "precip" # continuous
        )#,
          #effective_lags_alpha = integer(0),
          #effective_lags_delta = integer(0),
          #random_lags_alpha_values = integer(0),
          #random_lags_delta_values = integer(0)
    )
    gc()
}

run_5time_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 2,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        random_predictors = c(
            "vegan_price_real", # continuous
            "vegetarian_price_real", # continuous
            "meat_price_real", # continuous

            "holiday_window", # binary
            "month_cat", # factor
            "season",  # factor
            "year_cat", # factor
            "date_num", # continuous
            "day_of_week_cat" # factor
        ),
        fixed_predictors = c(
            "inflation", # continuous
            "temp", # continuous
            "precip" # continuous
        )#,
          #effective_lags_alpha = integer(0),
          #effective_lags_delta = integer(0),
          #random_lags_alpha_values = integer(0),
          #random_lags_delta_values = integer(0)
    )
    gc()
}


run_6time_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 2,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        random_predictors = c(
            "vegan_price_real", # continuous
            "vegetarian_price_real", # continuous
            "meat_price_real", # continuous
            "weekend", # binary 
            "holiday_window", # binary
            "month_cat", # factor
            "season",  # factor
            "year_cat", # factor
            "date_num", # continuous
            "day_of_week_cat" # factor
        ),
        fixed_predictors = c(
            "inflation", # continuous
            "temp", # continuous
            "precip" # continuous
        )#,
          #effective_lags_alpha = integer(0),
          #effective_lags_delta = integer(0),
          #random_lags_alpha_values = integer(0),
          #random_lags_delta_values = integer(0)
    )
    gc()
}

run_regpred_noreglag_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = .01, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 4,  # Predictors: rate for exponential priors on sigma_beta_*

        # mu_alpha_scale_input = .05,  # Lagged outcomes
        # sigma_alpha_scale_input = 4,

        # mu_delta_scale_input = .05,   # Lagged intensities
        # sigma_delta_scale_input = 4,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}


run_reglag_noregpred_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        #mu_beta_scale_input  = .01, # Predictors: scale for normal priors on mu_beta_*
        #sigma_beta_scale_input = 4,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_alpha_scale_input = .01,  # Lagged outcomes
        sigma_alpha_scale_input = 4,

        mu_delta_scale_input = .01,   # Lagged intensities
        sigma_delta_scale_input = 4,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}

run_reglag_noregpred_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        #mu_beta_scale_input  = .01, # Predictors: scale for normal priors on mu_beta_*
        #sigma_beta_scale_input = 4,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_alpha_scale_input = .01,  # Lagged outcomes
        sigma_alpha_scale_input = 4,

        mu_delta_scale_input = .01,   # Lagged intensities
        sigma_delta_scale_input = 4,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}

run_reg4_largesigma_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = .01, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = .5,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_alpha_scale_input = .01,  # Lagged outcomes
        sigma_alpha_scale_input = .5,

        mu_delta_scale_input = .01,   # Lagged intensities
        sigma_delta_scale_input = .5,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}

run_reg4_largersigma_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = .01, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = .1,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_alpha_scale_input = .01,  # Lagged outcomes
        sigma_alpha_scale_input = .1,

        mu_delta_scale_input = .01,   # Lagged intensities
        sigma_delta_scale_input = .1,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}

run_reg4_laglargesigma_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = .01, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 1,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_alpha_scale_input = .01,  # Lagged outcomes
        sigma_alpha_scale_input = .1,

        mu_delta_scale_input = .01,   # Lagged intensities
        sigma_delta_scale_input = .1,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}

run_regsanitycheck_largesigma_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = .01, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = .1,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_beta_scale_group2_input  = 0.001,
        sigma_beta_scale_group2_input = 10.0,

        mu_alpha_scale_input = .01,  # Lagged outcomes
        sigma_alpha_scale_input = .1,
        mu_delta_scale_input = .01,   # Lagged intensities
        sigma_delta_scale_input = .1,

        mu_alpha_scale_group2_input = 0.001,
        sigma_alpha_scale_group2_input = 10.0,
        mu_delta_scale_group2_input = 0.001,
        sigma_delta_scale_group2_input = 10.0,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}

run_reglessheavy_largesigma_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = .01, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = .1,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_beta_scale_group2_input  = 0.0001,
        sigma_beta_scale_group2_input = 10.0,

        mu_alpha_scale_input = .01,  # Lagged outcomes
        sigma_alpha_scale_input = .1,
        mu_delta_scale_input = .01,   # Lagged intensities
        sigma_delta_scale_input = .1,

        mu_alpha_scale_group2_input = 0.0001,
        sigma_alpha_scale_group2_input = 10.0,
        mu_delta_scale_group2_input = 0.0001,
        sigma_delta_scale_group2_input = 10.0,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}


run_reglessheavyonlyevil_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = 1.0, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 1.0,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_beta_scale_group2_input  = 0.0001,
        sigma_beta_scale_group2_input = 10.0,

        mu_alpha_scale_input = 1.0,  # Lagged outcomes
        sigma_alpha_scale_input = 1.0,
        mu_delta_scale_input = 1.0,   # Lagged intensities
        sigma_delta_scale_input = 1.0,

        mu_alpha_scale_group2_input = 0.0001,
        sigma_alpha_scale_group2_input = 10.0,
        mu_delta_scale_group2_input = 0.0001,
        sigma_delta_scale_group2_input = 10.0,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}

run_reglesslessheavyonlyevil_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = 1.0, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 1.0,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_beta_scale_group2_input  = 0.001,
        sigma_beta_scale_group2_input = 10.0,

        mu_alpha_scale_input = 1.0,  # Lagged outcomes
        sigma_alpha_scale_input = 1.0,
        mu_delta_scale_input = 1.0,   # Lagged intensities
        sigma_delta_scale_input = 1.0,

        mu_alpha_scale_group2_input = 0.001,
        sigma_alpha_scale_group2_input = 10.0,
        mu_delta_scale_group2_input = 0.001,
        sigma_delta_scale_group2_input = 10.0,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}

run_reglesslesslessheavyonlyevil_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = 1.0, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 1.0,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_beta_scale_group2_input  = 0.01,
        sigma_beta_scale_group2_input = 10.0,

        mu_alpha_scale_input = 1.0,  # Lagged outcomes
        sigma_alpha_scale_input = 1.0,
        mu_delta_scale_input = 1.0,   # Lagged intensities
        sigma_delta_scale_input = 1.0,

        mu_alpha_scale_group2_input = 0.01,
        sigma_alpha_scale_group2_input = 10.0,
        mu_delta_scale_group2_input = 0.01,
        sigma_delta_scale_group2_input = 10.0,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}

run_reglesslessheavyonlyevil_lesstight_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = 1.0, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 1.0,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_beta_scale_group2_input  = 0.001,
        sigma_beta_scale_group2_input = 1.0,

        mu_alpha_scale_input = 1.0,  # Lagged outcomes
        sigma_alpha_scale_input = 1.0,
        mu_delta_scale_input = 1.0,   # Lagged intensities
        sigma_delta_scale_input = 1.0,

        mu_alpha_scale_group2_input = 0.001,
        sigma_alpha_scale_group2_input = 1.0,
        mu_delta_scale_group2_input = 0.001,
        sigma_delta_scale_group2_input = 1.0,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}

run_reglessheavyonlyevil_hugesigma_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = 1.0, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = .01,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_beta_scale_group2_input  = 0.0001,
        sigma_beta_scale_group2_input = 10.0,

        mu_alpha_scale_input = 1.0,  # Lagged outcomes
        sigma_alpha_scale_input = .01,
        mu_delta_scale_input = 1.0,   # Lagged intensities
        sigma_delta_scale_input = .01,

        mu_alpha_scale_group2_input = 0.0001,
        sigma_alpha_scale_group2_input = 10.0,
        mu_delta_scale_group2_input = 0.0001,
        sigma_delta_scale_group2_input = 10.0,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}



##### NEW SET ######

run_reg5preds_onlyevil_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = 1.0, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 1.0,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_beta_scale_group2_input  = 0.0001,
        sigma_beta_scale_group2_input = 10.0,

        mu_alpha_scale_input = 1.0,  # Lagged outcomes
        sigma_alpha_scale_input = 1.0,
        mu_delta_scale_input = 1.0,   # Lagged intensities
        sigma_delta_scale_input = 1.0,

        mu_alpha_scale_group2_input = 1.0,
        sigma_alpha_scale_group2_input = 10.0,
        mu_delta_scale_group2_input = 1.0,
        sigma_delta_scale_group2_input = 10.0,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}


run_reg5lags_onlyevil_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = 1.0, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 1.0,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_beta_scale_group2_input  = 1.0,
        sigma_beta_scale_group2_input = 10.0,

        mu_alpha_scale_input = 1.0,  # Lagged outcomes
        sigma_alpha_scale_input = 1.0,
        mu_delta_scale_input = 1.0,   # Lagged intensities
        sigma_delta_scale_input = 1.0,

        mu_alpha_scale_group2_input = 0.0001,
        sigma_alpha_scale_group2_input = 10.0,
        mu_delta_scale_group2_input = 0.0001,
        sigma_delta_scale_group2_input = 10.0,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}


run_reg5lags4preds_onlyevil_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = 1.0, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 1.0,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_beta_scale_group2_input  = 0.001,
        sigma_beta_scale_group2_input = 10.0,

        mu_alpha_scale_input = 1.0,  # Lagged outcomes
        sigma_alpha_scale_input = 1.0,
        mu_delta_scale_input = 1.0,   # Lagged intensities
        sigma_delta_scale_input = 1.0,

        mu_alpha_scale_group2_input = 0.0001,
        sigma_alpha_scale_group2_input = 10.0,
        mu_delta_scale_group2_input = 0.0001,
        sigma_delta_scale_group2_input = 10.0,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}


run_reg5preds4lags_onlyevil_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = 1.0, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 1.0,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_beta_scale_group2_input  = 0.0001,
        sigma_beta_scale_group2_input = 10.0,

        mu_alpha_scale_input = 1.0,  # Lagged outcomes
        sigma_alpha_scale_input = 1.0,
        mu_delta_scale_input = 1.0,   # Lagged intensities
        sigma_delta_scale_input = 1.0,

        mu_alpha_scale_group2_input = 0.001,
        sigma_alpha_scale_group2_input = 10.0,
        mu_delta_scale_group2_input = 0.001,
        sigma_delta_scale_group2_input = 10.0,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}


run_reg5lags3preds_onlyevil_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = 1.0, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 1.0,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_beta_scale_group2_input  = 0.01,
        sigma_beta_scale_group2_input = 10.0,

        mu_alpha_scale_input = 1.0,  # Lagged outcomes
        sigma_alpha_scale_input = 1.0,
        mu_delta_scale_input = 1.0,   # Lagged intensities
        sigma_delta_scale_input = 1.0,

        mu_alpha_scale_group2_input = 0.0001,
        sigma_alpha_scale_group2_input = 10.0,
        mu_delta_scale_group2_input = 0.0001,
        sigma_delta_scale_group2_input = 10.0,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}


run_reg5preds3lags_onlyevil_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = 1.0, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 1.0,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_beta_scale_group2_input  = 0.0001,
        sigma_beta_scale_group2_input = 10.0,

        mu_alpha_scale_input = 1.0,  # Lagged outcomes
        sigma_alpha_scale_input = 1.0,
        mu_delta_scale_input = 1.0,   # Lagged intensities
        sigma_delta_scale_input = 1.0,

        mu_alpha_scale_group2_input = 0.01,
        sigma_alpha_scale_group2_input = 10.0,
        mu_delta_scale_group2_input = 0.01,
        sigma_delta_scale_group2_input = 10.0,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}

run_reg5lags2preds_onlyevil_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = 1.0, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 1.0,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_beta_scale_group2_input  = 0.1,
        sigma_beta_scale_group2_input = 10.0,

        mu_alpha_scale_input = 1.0,  # Lagged outcomes
        sigma_alpha_scale_input = 1.0,
        mu_delta_scale_input = 1.0,   # Lagged intensities
        sigma_delta_scale_input = 1.0,

        mu_alpha_scale_group2_input = 0.0001,
        sigma_alpha_scale_group2_input = 10.0,
        mu_delta_scale_group2_input = 0.0001,
        sigma_delta_scale_group2_input = 10.0,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}

run_reg5preds2lags_onlyevil_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = 1.0, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 1.0,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_beta_scale_group2_input  = 0.0001,
        sigma_beta_scale_group2_input = 10.0,

        mu_alpha_scale_input = 1.0,  # Lagged outcomes
        sigma_alpha_scale_input = 1.0,
        mu_delta_scale_input = 1.0,   # Lagged intensities
        sigma_delta_scale_input = 1.0,

        mu_alpha_scale_group2_input = 0.1,
        sigma_alpha_scale_group2_input = 10.0,
        mu_delta_scale_group2_input = 0.1,
        sigma_delta_scale_group2_input = 10.0,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}

run_phiseparate_onlyevil_reg4preds4lags_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = 0.1, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 0.1,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_beta_scale_group2_input  = 0.001,
        sigma_beta_scale_group2_input = 10.0,

        mu_alpha_scale_input = 0.1,  # Lagged outcomes
        sigma_alpha_scale_input = 0.1,
        mu_delta_scale_input = 0.1,   # Lagged intensities
        sigma_delta_scale_input = 0.1,

        mu_alpha_scale_group2_input = 0.001,
        sigma_alpha_scale_group2_input = 10.0,
        mu_delta_scale_group2_input = 0.001,
        sigma_delta_scale_group2_input = 10.0,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}


run_phiseparate_onlyevil_reg4preds6lags_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = 0.1, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 0.1,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_beta_scale_group2_input  = 0.001,
        sigma_beta_scale_group2_input = 10.0,

        mu_alpha_scale_input = 0.1,  # Lagged outcomes
        sigma_alpha_scale_input = 0.1,
        mu_delta_scale_input = 0.1,   # Lagged intensities
        sigma_delta_scale_input = 0.1,

        mu_alpha_scale_group2_input = 0.00001,
        sigma_alpha_scale_group2_input = 10.0,
        mu_delta_scale_group2_input = 0.00001,
        sigma_delta_scale_group2_input = 10.0,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}


run_phiseparate_onlyevil_reg4preds6lags_smallsigma_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = 1.0, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 1.0,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_beta_scale_group2_input  = 0.001,
        sigma_beta_scale_group2_input = 10.0,

        mu_alpha_scale_input = 1.0,  # Lagged outcomes
        sigma_alpha_scale_input = 1.0,
        mu_delta_scale_input = 1.0,   # Lagged intensities
        sigma_delta_scale_input = 1.0,

        mu_alpha_scale_group2_input = 0.00001,
        sigma_alpha_scale_group2_input = 10.0,
        mu_delta_scale_group2_input = 0.00001,
        sigma_delta_scale_group2_input = 10.0,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}

run_phiseparate_onlyevil_reg4preds7lags_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = 1.0, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 0.1,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_beta_scale_group2_input  = 0.001,
        sigma_beta_scale_group2_input = 10.0,

        mu_alpha_scale_input = 1.0,  # Lagged outcomes
        sigma_alpha_scale_input = 0.1,
        mu_delta_scale_input = 1.0,   # Lagged intensities
        sigma_delta_scale_input = 0.1,

        mu_alpha_scale_group2_input = 0.000001,
        sigma_alpha_scale_group2_input = 10.0,
        mu_delta_scale_group2_input = 0.000001,
        sigma_delta_scale_group2_input = 10.0,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}


run_phiseparate_onlyevil_reg3preds7lags_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = 1.0, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 0.1,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_beta_scale_group2_input  = 0.01,
        sigma_beta_scale_group2_input = 10.0,

        mu_alpha_scale_input = 1.0,  # Lagged outcomes
        sigma_alpha_scale_input = 0.1,
        mu_delta_scale_input = 1.0,   # Lagged intensities
        sigma_delta_scale_input = 0.1,

        mu_alpha_scale_group2_input = 0.000001,
        sigma_alpha_scale_group2_input = 10.0,
        mu_delta_scale_group2_input = 0.000001,
        sigma_delta_scale_group2_input = 10.0,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}

run_phiseparate_regothers_reg4preds4lags_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = 0.1, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 0.1,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_beta_scale_group2_input  = 0.001,
        sigma_beta_scale_group2_input = 10.0,

        mu_alpha_scale_input = 0.1,  # Lagged outcomes
        sigma_alpha_scale_input = 0.1,
        mu_delta_scale_input = 0.1,   # Lagged intensities
        sigma_delta_scale_input = 0.1,

        mu_alpha_scale_group2_input = 0.001,
        sigma_alpha_scale_group2_input = 10.0,
        mu_delta_scale_group2_input = 0.001,
        sigma_delta_scale_group2_input = 10.0,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}


run_phiseparate_regothers_reg4preds6lags_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = 0.1, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 0.1,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_beta_scale_group2_input  = 0.001,
        sigma_beta_scale_group2_input = 10.0,

        mu_alpha_scale_input = 0.1,  # Lagged outcomes
        sigma_alpha_scale_input = 0.1,
        mu_delta_scale_input = 0.1,   # Lagged intensities
        sigma_delta_scale_input = 0.1,

        mu_alpha_scale_group2_input = 0.00001,
        sigma_alpha_scale_group2_input = 10.0,
        mu_delta_scale_group2_input = 0.00001,
        sigma_delta_scale_group2_input = 10.0,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}


run_phiseparate_regothers_reg4preds6lags_smallsigma_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = 0.1, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 1.0,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_beta_scale_group2_input  = 0.001,
        sigma_beta_scale_group2_input = 10.0,

        mu_alpha_scale_input = 0.1,  # Lagged outcomes
        sigma_alpha_scale_input = 1.0,
        mu_delta_scale_input = 0.1,   # Lagged intensities
        sigma_delta_scale_input = 1.0,

        mu_alpha_scale_group2_input = 0.00001,
        sigma_alpha_scale_group2_input = 10.0,
        mu_delta_scale_group2_input = 0.00001,
        sigma_delta_scale_group2_input = 10.0,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}

run_phiseparate_regothers_reg4preds7lags_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = 0.1, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 0.1,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_beta_scale_group2_input  = 0.001,
        sigma_beta_scale_group2_input = 10.0,

        mu_alpha_scale_input = 0.1,  # Lagged outcomes
        sigma_alpha_scale_input = 0.1,
        mu_delta_scale_input = 0.1,   # Lagged intensities
        sigma_delta_scale_input = 0.1,

        mu_alpha_scale_group2_input = 0.000001,
        sigma_alpha_scale_group2_input = 10.0,
        mu_delta_scale_group2_input = 0.000001,
        sigma_delta_scale_group2_input = 10.0,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}


run_phiseparate_regothers_reg3preds7lags_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = 0.1, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 0.1,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_beta_scale_group2_input  = 0.01,
        sigma_beta_scale_group2_input = 10.0,

        mu_alpha_scale_input = 0.1,  # Lagged outcomes
        sigma_alpha_scale_input = 0.1,
        mu_delta_scale_input = 0.1,   # Lagged intensities
        sigma_delta_scale_input = 0.1,

        mu_alpha_scale_group2_input = 0.000001,
        sigma_alpha_scale_group2_input = 10.0,
        mu_delta_scale_group2_input = 0.000001,
        sigma_delta_scale_group2_input = 10.0,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}


run_phiseparate_reg3others_reg4preds4lags_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = 0.01, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 0.1,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_beta_scale_group2_input  = 0.001,
        sigma_beta_scale_group2_input = 10.0,

        mu_alpha_scale_input = 0.01,  # Lagged outcomes
        sigma_alpha_scale_input = 0.1,
        mu_delta_scale_input = 0.01,   # Lagged intensities
        sigma_delta_scale_input = 0.1,

        mu_alpha_scale_group2_input = 0.001,
        sigma_alpha_scale_group2_input = 10.0,
        mu_delta_scale_group2_input = 0.001,
        sigma_delta_scale_group2_input = 10.0,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}


run_phiseparate_reg3others_reg4preds6lags_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = 0.01, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 0.1,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_beta_scale_group2_input  = 0.001,
        sigma_beta_scale_group2_input = 10.0,

        mu_alpha_scale_input = 0.01,  # Lagged outcomes
        sigma_alpha_scale_input = 0.1,
        mu_delta_scale_input = 0.01,   # Lagged intensities
        sigma_delta_scale_input = 0.1,

        mu_alpha_scale_group2_input = 0.00001,
        sigma_alpha_scale_group2_input = 10.0,
        mu_delta_scale_group2_input = 0.00001,
        sigma_delta_scale_group2_input = 10.0,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}


run_phiseparate_reg3others_reg4preds6lags_smallsigma_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = 0.01, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 1.0,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_beta_scale_group2_input  = 0.001,
        sigma_beta_scale_group2_input = 10.0,

        mu_alpha_scale_input = 0.01,  # Lagged outcomes
        sigma_alpha_scale_input = 1.0,
        mu_delta_scale_input = 0.01,   # Lagged intensities
        sigma_delta_scale_input = 1.0,

        mu_alpha_scale_group2_input = 0.00001,
        sigma_alpha_scale_group2_input = 10.0,
        mu_delta_scale_group2_input = 0.00001,
        sigma_delta_scale_group2_input = 10.0,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}

run_phiseparate_reg3others_reg4preds7lags_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = 0.01, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 0.1,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_beta_scale_group2_input  = 0.001,
        sigma_beta_scale_group2_input = 10.0,

        mu_alpha_scale_input = 0.01,  # Lagged outcomes
        sigma_alpha_scale_input = 0.1,
        mu_delta_scale_input = 0.01,   # Lagged intensities
        sigma_delta_scale_input = 0.1,

        mu_alpha_scale_group2_input = 0.000001,
        sigma_alpha_scale_group2_input = 10.0,
        mu_delta_scale_group2_input = 0.000001,
        sigma_delta_scale_group2_input = 10.0,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}


run_phiseparate_reg3others_reg3preds7lags_its <- function(outcome, directory, adapt_delta=.95, max_treedepth=12) {
    #mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = adapt_delta,
        max_treedepth = max_treedepth,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'),
        mu_gamma_scale_input = 1.0, # Gamma: for exposure
        sigma_gamma_between_scale_input = 1.0, 
        sigma_gamma_within_scale_input = 1.0,

        mu_beta_scale_input  = 0.01, # Predictors: scale for normal priors on mu_beta_*
        sigma_beta_scale_input = 0.1,  # Predictors: rate for exponential priors on sigma_beta_*

        mu_beta_scale_group2_input  = 0.01,
        sigma_beta_scale_group2_input = 10.0,

        mu_alpha_scale_input = 0.01,  # Lagged outcomes
        sigma_alpha_scale_input = 0.1,
        mu_delta_scale_input = 0.01,   # Lagged intensities
        sigma_delta_scale_input = 0.1,

        mu_alpha_scale_group2_input = 0.000001,
        sigma_alpha_scale_group2_input = 10.0,
        mu_delta_scale_group2_input = 0.000001,
        sigma_delta_scale_group2_input = 10.0,

        mu_phi_log_scale_input = 1.0,   # Dispersion 
        sigma_phi_log_scale_input = 1.0
)
    gc()
}




# Run 1

# random_predictors = c(
#     "vegan_price_real", # continuous
#     "vegetarian_price_real", # continuous
#     "meat_price_real", # continuous

#     "weekend", # binary # 1
#     "holiday_window", # binary # 2
#     "month_cat", # factor # 3
#     "season",  # factor # 4
#     "year_cat", # factor # 5
#     "date_num", # continuous 
#     "day_of_week_cat" # factor # 6
# )
# fixed_predictors = c(
#     "inflation", # continuous
#     "temp", # continuous
#     "precip" # continuous
# )

# # Run 2 (Different order)

# random_predictors = c(
#     "vegan_price_real", # continuous
#     "vegetarian_price_real", # continuous
#     "meat_price_real", # continuous
#     "holiday_window", # binary # 1
#     "month_cat", # factor # 2
#     "season",  # factor # 3
#     "year_cat", # factor # 4
#     "date_num" # continuous 
#     "day_of_week_cat" # factor # 5
#     "weekend", # binary # 6
# )
# fixed_predictors = c(
#     "inflation", # continuous
#     "temp", # continuous
#     "precip" # continuous
# )

# # Run 3 (With all lags)

# random_predictors = c(
#     "vegan_price_real", # continuous
#     "vegetarian_price_real", # continuous
#     "meat_price_real", # continuous
#     "holiday_window", # binary # 1
#     "month_cat", # factor # 2
#     "season",  # factor # 3
#     "year_cat", # factor # 4
#     "date_num" # continuous 
#     "day_of_week_cat" # factor # 5
#     "weekend", # binary # 6
# )
# fixed_predictors = c(
#     "inflation", # continuous
#     "temp", # continuous
#     "precip" # continuous
# )

# # Run 4 (With All Lags and *Which Things are Random Preds Fixed*)

# random_predictors = c(
#     "vegan_price_real", # continuous
#     "vegetarian_price_real", # continuous
#     "meat_price_real", # continuous
#     "holiday_window", # binary # 1
#     "month_cat", # factor # 2
#     "season",  # factor # 3
#     "year_cat", # factor # 4
#     "date_num" # continuous 
#     "day_of_week_cat" # factor # 5
#     "weekend", # binary # 6
# )
# fixed_predictors = c(
#     "inflation", # continuous
#     "temp", # continuous
#     "precip" # continuous
# )

# # Run 5 (Don't Clip Data for JHDN7CF1C03X5)

# random_predictors = c(
#     "vegan_price_real", # continuous
#     "vegetarian_price_real", # continuous
#     "meat_price_real", # continuous
#     "holiday_window", # binary # 1
#     "month_cat", # factor # 2
#     "season",  # factor # 3
#     "year_cat", # factor # 4
#     "date_num" # continuous 
#     "day_of_week_cat" # factor # 5
#     "weekend", # binary # 6
# )
# fixed_predictors = c(
#     "inflation", # continuous
#     "temp", # continuous
#     "precip" # continuous
# )
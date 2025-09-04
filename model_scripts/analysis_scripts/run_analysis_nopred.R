library(tidyverse)
library(dplyr)

source(file.path("model_scripts","ingarch_scripts","run_ingarch.R"))

CORES_PER_MODEL <- 2

run_nopred_its <- function(outcome) {
    mlflow_set_experiment("Nopred INGARCH - ITS")
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
          random_lags_delta_values = integer(0)
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

# # Run 4 (With All Lags and Random Preds Fixed)

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
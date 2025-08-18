source("run_ingarch.R")

run_nopred_its <- function(outcome) {
    mlflow_set_experiment("Nopred INGARCH - ITS")
    run_ingarch(
        directory = "nopred",
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
        random_predictors = c())
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

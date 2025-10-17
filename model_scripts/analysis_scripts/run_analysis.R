library(tidyverse)
library(dplyr)

source(file.path("model_scripts","ingarch_scripts","run_ingarch.R"))

CORES_PER_MODEL <- 3

run_its <- function(outcome, directory="official", adapt_delta = .9, max_treedepth = 10) {
    #mlflow_set_experiment("Multilevel INGARCH - ITS")
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
        adapt_delta = adapt_delta, # This is relatively high
        max_treedepth = max_treedepth)
    gc()
}

run_its_fast <- function(outcome, directory="official") {
    #mlflow_set_experiment("Multilevel INGARCH - ITS")
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        adapt_delta = .8,
        max_treedepth = 8,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'))
    gc()
}

run_customer <- function(outcome, directory) {
    #mlflow_set_experiment("Multilevel INGARCH - Customer")
    run_ingarch(
        directory = directory,
        analysis = "customer",
        outcome = outcome,
        data_file = "customer/all_locations_daily_customers_weather_inflation.parquet",
        chains = 3,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'))
    gc()
}

run_targeted_its <- function(outcome, restaurants_to_model, directory) {
    #mlflow_set_experiment("Multilevel INGARCH - Targeted ITS")
    run_ingarch(
        directory = directory,
        analysis = "targeted_its",
        outcome = outcome,
        data_file = "targeted/all_locations_daily_targeted_weather_inflation.parquet",
        chains = 3,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'VLZX7K2M9QD4T',
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'))
        gc()
}

run_targeted_customer <- function(outcome, restaurants_to_model, directory) {
    #mlflow_set_experiment("Multilevel INGARCH - Targeted Customer")
    run_ingarch(
        directory = directory,
        analysis = "targeted_customer",
        outcome = outcome,
        data_file = "targeted/all_locations_daily_targeted_customers_weather_inflation.parquet",
        chains = 3,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT'))
        gc()
}
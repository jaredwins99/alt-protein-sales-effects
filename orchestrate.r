library(tidyverse)
library(future)
library(furrr)

source("run_ingarch.R")

Sys.setenv(
  MLFLOW_PYTHON_BIN = "/home/researcher/miniconda3/envs/mlflow/bin/python",
  MLFLOW_BIN        = "/home/researcher/miniconda3/envs/mlflow/bin/mlflow"
)
use_condaenv("mlflow", required = TRUE)

run_its <- function(outcome) {
    run_ingarch(
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
            'ED5J990H5VAZT'))
    gc()
}

run_customer <- function(outcome) {
    run_ingarch(
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
            'W8T41JZK0ZMEP'))
    gc()
}

run_targeted <- function(outcome, restaurants_to_model) {
    run_ingarch(
        analysis = "targeted_its",
        outcome = outcome,
        data_file = "targeted/all_locations_daily_targeted_weather_inflation.parquet",
        chains = 3,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = restaurants_to_model)
        gc()
}

TOTAL_CORES_TO_USE <- 30
CORES_PER_MODEL    <- 3
NUM_PARALLEL_MODELS <- max(1L, floor(TOTAL_CORES_TO_USE / (CORES_PER_MODEL + 1)))
plan(multisession, workers = NUM_PARALLEL_MODELS)

rng_options <- furrr_options(seed = TRUE)

its_outcomes = c("chicken_fish","meat","nonvegan","total","vegan","vegetarian")
furrr::future_walk(its_outcomes, run_its, .options = rng_options)
furrr::future_walk(its_outcomes, run_customer, .options = rng_options)
targeted_outcomes = c("breakfast","untextured","textured")
furrr::future_walk2(targeted_outcomes, 
             list(c('2HRX9P6HKXA8V','JHDN7CF1C03X5','L69HYJ4Y3TR91','ED5J990H5VAZT'),
                  c('SRQS8F7JWA9MZ','JHDN7CF1C03X5'),
                  c('VLZX7K2M9QD4T')), 
             run_targeted, 
             .options = rng_options)

message(">>> ALL ANALYSES COMPLETE <<<")
plan(sequential)
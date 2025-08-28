library(tidyverse)
library(dplyr)

source(file.path("model_scripts","ingarch_scripts","run_ingarch.R"))

CORES_PER_MODEL <- 3

run_its <- function(outcome, directory) {
    run_ingarch(
        directory = directory,
        analysis = "its",
        outcome = outcome,
        data_file = "all_locations_daily_weather_inflation.parquet",
        chains = 3,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            # Tier 1
            'VLZX7K2M9QD4T', 
            'SRQS8F7JWA9MZ', 
            '2HRX9P6HKXA8V', 
            'JHDN7CF1C03X5', 
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT',
            'W8T41JZK0ZMEP',

            # Tier 2
            #'EMBVNVD207CC6',
            'C0BE4NDSW26QN',
            #'75WYSXR9QBK5M',
            'V3Q26BHF3SE2H',
            'LBZEEFSBJNB3Z',
            'SAFK7ND1HR6XS',
            'CB2KHY1C2G9PT',
            'S8MT0YGD2KTN9',
            'LFZFT3VASXPED',
            '1SQPTEGYPH0GA',
            '9XKJD8DQTH559',
            'LQ5EH4BKGV61T',
            '78AY09MVJVTYE'))
    gc()
}

run_customer <- function(outcome, directory) {
    run_ingarch(
        directory = directory,
        analysis = "customer",
        outcome = outcome,
        data_file = "customer/all_locations_daily_customers_weather_inflation.parquet",
        chains = 3,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            # Tier 1
            #'VLZX7K2M9QD4T', 
            'SRQS8F7JWA9MZ', 
            '2HRX9P6HKXA8V', 
            #'JHDN7CF1C03X5', 
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT',
            'W8T41JZK0ZMEP',
            
            # Tier 2
            #'EMBVNVD207CC6',
            'C0BE4NDSW26QN',
            #'75WYSXR9QBK5M',
            'V3Q26BHF3SE2H',
            'LBZEEFSBJNB3Z',
            'SAFK7ND1HR6XS',
            'CB2KHY1C2G9PT',
            'S8MT0YGD2KTN9',
            'LFZFT3VASXPED',
            '1SQPTEGYPH0GA',
            '9XKJD8DQTH559',
            'LQ5EH4BKGV61T',
            '78AY09MVJVTYE'))
    gc()
}

run_targeted_its <- function(outcome, restaurants_to_model, directory) {
    run_ingarch(
        directory = directory,
        analysis = "targeted_its",
        outcome = outcome,
        data_file = "targeted/all_locations_daily_targeted_weather_inflation.parquet",
        chains = 3,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = restaurants_to_model)
        gc()
}

run_targeted_customer <- function(outcome, restaurants_to_model, directory) {
    run_ingarch(
        directory = directory,
        analysis = "targeted_customer",
        outcome = outcome,
        data_file = "customer/all_locations_daily_customers_weather_inflation.parquet",
        chains = 3,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = restaurants_to_model)
        gc()
}
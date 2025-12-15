library(tidyverse)
library(dplyr)

source(file.path("model_scripts","ingarch_scripts","run_ingarch.R"))

test <- read_parquet(file.path("data","4_data_parquet_modeling","proportion_targeted","finalized_untextured_dishes_count.parquet"))

test %>% pull(exposure_LQ5EH4BKGV61T_1)

CORES_PER_MODEL <- 3

# A1
run_prop <- function(outcome, exposure, directory="finalized", adapt_delta = .85, max_treedepth = 10) {
    run_ingarch(
        data_file = file.path("proportion", paste0("finalized_",exposure,".parquet")),
        directory = directory,
        analysis = "proportion",
        outcome = outcome,
        exposure = exposure,
        include_slopes = FALSE,
        restaurants_to_model = c(
            'SRQS8F7JWA9MZ',
            '2HRX9P6HKXA8V',
            'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91',
            'ED5J990H5VAZT',
            'W8T41JZK0ZMEP'),
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
        chains = CORES_PER_MODEL,
        parallel_chains = CORES_PER_MODEL,
        adapt_delta = adapt_delta, # This is relatively high
        max_treedepth = max_treedepth)
    gc()
}

# A2
run_prop_targeted <- function(outcome, exposure, restaurants_to_model, extra_price_predictor, directory="finalized", adapt_delta = .85, max_treedepth = 10) {
    run_ingarch(
        data_file = file.path("proportion_targeted", paste0("finalized_",exposure,".parquet")),
        directory = directory,
        analysis = "proportion_targeted",
        outcome = outcome,
        exposure = exposure,
        include_slopes = FALSE,
        restaurants_to_model = restaurants_to_model,
        random_predictors = c(
            "vegan_price_real", # continuous
            "vegetarian_price_real", # continuous
            "meat_price_real", # continuous
            extra_price_predictor, # continuous - category-specific price
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
        chains = CORES_PER_MODEL,
        parallel_chains = CORES_PER_MODEL,
        adapt_delta = adapt_delta, # This is relatively high
        max_treedepth = max_treedepth)
    gc()
}

# A3
run_its <- function(outcome, directory="finalized", adapt_delta = .85, max_treedepth = 10) {
    run_ingarch(
        data_file = file.path("its","finalized.parquet"),
        directory = directory,
        analysis = "its",
        outcome = outcome,
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
            "date_num" # continuous
        ),
        fixed_predictors = c(
            "day_of_week_cat", # factor
            "inflation", # continuous
            "temp", # continuous
            "precip" # continuous
        ),
        chains = CORES_PER_MODEL,
        parallel_chains = CORES_PER_MODEL,
        adapt_delta = adapt_delta, # This is relatively high
        max_treedepth = max_treedepth)
    gc()
}

# A4
run_its_targeted <- function(outcome, restaurants_to_model, extra_price_predictor, directory="finalized", adapt_delta = .85, max_treedepth = 10) {
    run_ingarch(
        data_file = file.path("its","finalized.parquet"),
        directory = directory,
        analysis = "its_targeted",
        outcome = outcome,
        restaurants_to_model = restaurants_to_model,
        random_predictors = c(
            "vegan_price_real", # continuous
            "vegetarian_price_real", # continuous
            "meat_price_real", # continuous
            extra_price_predictor, # continuous - category-specific price
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
        chains = CORES_PER_MODEL,
        parallel_chains = CORES_PER_MODEL,
        adapt_delta = adapt_delta, # This is relatively high
        max_treedepth = max_treedepth)
    gc()
}

# A5
run_customer <- function(outcome, directory="finalized", adapt_delta = .85, max_treedepth = 10) {
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
        adapt_delta = adapt_delta, # This is relatively high
        max_treedepth = max_treedepth)
    gc()
}

# A6
run_customer_targeted <- function(outcome, restaurants_to_model, extra_price_predictor, directory="finalized", adapt_delta = .85, max_treedepth = 10) {
    run_ingarch(
        data_file = file.path("customer","finalized_customers.parquet"),
        directory = directory,
        analysis = "customer_targeted",
        outcome = outcome,
        restaurants_to_model = restaurants_to_model,
        random_predictors = c(
            "vegan_price_real", # continuous
            "vegetarian_price_real", # continuous
            "meat_price_real", # continuous
            extra_price_predictor, # continuous - category-specific price
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
        chains = CORES_PER_MODEL,
        parallel_chains = CORES_PER_MODEL,
        adapt_delta = adapt_delta, # This is relatively high
        max_treedepth = max_treedepth)
    gc()
}

# A1 T2
run_prop_t2 <- function(outcome, exposure, directory="finalized", adapt_delta = .85, max_treedepth = 10) {
    run_ingarch(
        data_file = file.path("proportion", paste0("finalized_",exposure,".parquet")),
        directory = directory,
        analysis = "t2_proportion",
        outcome = outcome,
        exposure = exposure,
        include_slopes = FALSE,
        restaurants_to_model = c(
            # Tier 1
            'SRQS8F7JWA9MZ', '2HRX9P6HKXA8V', 'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91','ED5J990H5VAZT','W8T41JZK0ZMEP',
            # Tier 2
            'EMBVNVD207CC6',
            'C0BE4NDSW26QN',
            #'75WYSXR9QBK5M',
            'V3Q26BHF3SE2H','LBZEEFSBJNB3Z','SAFK7ND1HR6XS','CB2KHY1C2G9PT',
            'S8MT0YGD2KTN9','LFZFT3VASXPED','1SQPTEGYPH0GA','9XKJD8DQTH559',
            'LQ5EH4BKGV61T','78AY09MVJVTYE'),
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
        chains = CORES_PER_MODEL,
        parallel_chains = CORES_PER_MODEL,
        adapt_delta = adapt_delta, # This is relatively high
        max_treedepth = max_treedepth)
    gc()
}

# A2 T2
run_prop_targeted_t2 <- function(outcome, exposure, restaurants_to_model, extra_price_predictor, directory="finalized", adapt_delta = .85, max_treedepth = 10) {
    run_ingarch(
        data_file = file.path("proportion_targeted", paste0("finalized_",exposure,".parquet")),
        directory = directory,
        analysis = "t2_proportion_targeted",
        outcome = outcome,
        exposure = exposure,
        include_slopes = FALSE,
        restaurants_to_model = restaurants_to_model,
        random_predictors = c(
            "vegan_price_real", # continuous
            "vegetarian_price_real", # continuous
            "meat_price_real", # continuous
            extra_price_predictor, # continuous - category-specific price
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
        chains = CORES_PER_MODEL,
        parallel_chains = CORES_PER_MODEL,
        adapt_delta = adapt_delta, # This is relatively high
        max_treedepth = max_treedepth)
    gc()
}

# A3 T2
run_its_t2 <- function(outcome, directory="finalized", adapt_delta = .85, max_treedepth = 10) {
    run_ingarch(
        data_file = file.path("its","finalized.parquet"),
        directory = directory,
        analysis = "t2_its",
        outcome = outcome,
        restaurants_to_model = c(
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
            'LQ5EH4BKGV61T','78AY09MVJVTYE'),
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
        chains = CORES_PER_MODEL,
        parallel_chains = CORES_PER_MODEL,
        adapt_delta = adapt_delta, # This is relatively high
        max_treedepth = max_treedepth)
    gc()
}

# A4 T2
run_its_targeted_t2 <- function(outcome, restaurants_to_model, extra_price_predictor, directory="finalized", adapt_delta = .85, max_treedepth = 10) {
    run_ingarch(
        data_file = file.path("its","finalized.parquet"),
        directory = directory,
        analysis = "t2_its_targeted",
        outcome = outcome,
        restaurants_to_model = restaurants_to_model,
        random_predictors = c(
            "vegan_price_real", # continuous
            "vegetarian_price_real", # continuous
            "meat_price_real", # continuous
            extra_price_predictor, # continuous - category-specific price
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
        chains = CORES_PER_MODEL,
        parallel_chains = CORES_PER_MODEL,
        adapt_delta = adapt_delta, # This is relatively high
        max_treedepth = max_treedepth)
    gc()
}

# A5 T2
run_customer_t2 <- function(outcome, directory="finalized", adapt_delta = .85, max_treedepth = 10) {
    run_ingarch(
        data_file = file.path("customer","finalized_customers.parquet"),
        directory = directory,
        analysis = "t2_customer",
        outcome = outcome,
        chains = CORES_PER_MODEL,
        parallel_chains = CORES_PER_MODEL,
        restaurants_to_model = c(
            # Tier 1
            #'VLZX7K2M9QD4T', 
            'SRQS8F7JWA9MZ', '2HRX9P6HKXA8V', #'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91','ED5J990H5VAZT','W8T41JZK0ZMEP',
            # Tier 2
            'EMBVNVD207CC6',
            'C0BE4NDSW26QN',
            #'75WYSXR9QBK5M',
            'V3Q26BHF3SE2H','LBZEEFSBJNB3Z','SAFK7ND1HR6XS',#'CB2KHY1C2G9PT',
            'S8MT0YGD2KTN9',#'LFZFT3VASXPED',
            '1SQPTEGYPH0GA','9XKJD8DQTH559',
            'LQ5EH4BKGV61T','78AY09MVJVTYE'),
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
        adapt_delta = adapt_delta, # This is relatively high
        max_treedepth = max_treedepth)
    gc()
}

# A6 T2
run_customer_targeted_t2 <- function(outcome, restaurants_to_model, extra_price_predictor, directory="finalized", adapt_delta = .85, max_treedepth = 10) {
    run_ingarch(
        data_file = file.path("customer","finalized_customers.parquet"),
        directory = directory,
        analysis = "t2_customer_targeted",
        outcome = outcome,
        restaurants_to_model = restaurants_to_model,
        random_predictors = c(
            "vegan_price_real", # continuous
            "vegetarian_price_real", # continuous
            "meat_price_real", # continuous
            extra_price_predictor, # continuous - category-specific price
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
        chains = CORES_PER_MODEL,
        parallel_chains = CORES_PER_MODEL,
        adapt_delta = adapt_delta, # This is relatively high
        max_treedepth = max_treedepth)
    gc()
}

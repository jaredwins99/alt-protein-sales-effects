library(tidyverse)
library(dplyr)
library(future)
library(furrr)
library(reticulate)
# library(mlflow)  # skipped for now
library(conflicted)

#source(".Rprofile")
source("model_scripts/analysis_scripts/run_analysis.R")
#source(".Rprofile")
source("model_scripts/analysis_scripts/run_analysis_nopred.R")

c("select", "filter") %>% walk(~ conflict_prefer(.x, "dplyr"))
c("year", "month") %>% walk(~ conflict_prefer(.x, "lubridate"))
c("map") %>% walk( ~ conflict_prefer(.x, "purrr"))
c("sd") %>%  walk(~ conflict_prefer(.x, "stats"))
c("match") %>%  walk(~ conflict_prefer(.x, "base"))

# Sys.setenv(
#   MLFLOW_PYTHON_BIN = "/home/godli/miniconda3/envs/mlflow/bin/python",
#   MLFLOW_BIN        = "/home/godli/miniconda3/envs/mlflow/bin/mlflow"
# )
# use_condaenv("mlflow", required = TRUE)

local_store <- file.path(getwd(), "mlflow")
uri <- paste0(
  "file:///", 
  URLencode(normalizePath(local_store, winslash = "/")))
mlflow_set_tracking_uri(uri)

its_outcomes <- c("chicken_fish","meat","nonvegan","total","vegan","vegetarian")
targeted_its_outcomes <- c("breakfast","untextured","textured")
targeted_customer_outcomes <- c("breakfast","untextured")

targeted_its_restaurants <- list(breakfast = c('2HRX9P6HKXA8V','JHDN7CF1C03X5','L69HYJ4Y3TR91','ED5J990H5VAZT'),
                                 untextured = c('SRQS8F7JWA9MZ','JHDN7CF1C03X5'),
                                 textured = c('VLZX7K2M9QD4T'))
targeted_customer_restaurants <- list(breakfast = c('2HRX9P6HKXA8V','L69HYJ4Y3TR91','ED5J990H5VAZT'),
                                      untextured = c('SRQS8F7JWA9MZ'))

rng_options <- furrr_options(seed = TRUE)
TOTAL_CORES_TO_USE <- 30
CORES_PER_MODEL <- 3
NUM_PARALLEL_MODELS <- max(1L, floor(TOTAL_CORES_TO_USE / (CORES_PER_MODEL + 1)))
plan(multisession, workers = NUM_PARALLEL_MODELS)

# furrr::future_walk(its_outcomes, ~ run_its(.x, directory="official_redux"), .options = rng_options)
# furrr::future_walk(its_outcomes, ~ run_customer(.x, directory="official_redux"), .options = rng_options)
# furrr::future_walk2(targeted_its_outcomes, targeted_its_restaurants, ~ run_targeted_its(.x, .y, directory="official_redux"), .options = rng_options)
# furrr::future_walk2(targeted_customer_outcomes, targeted_customer_restaurants, ~ run_targeted_customer(.x, .y, directory="official_redux"), .options = rng_options)

# furrr::future_walk(its_outcomes, run_nopred_its, .options = rng_options)
# furrr::future_walk(its_outcomes, run_nopred_customer, .options = rng_options)
# furrr::future_walk2(targeted_its_outcomes, targeted_its_restaurants, run_nopred_targeted_its, .options = rng_options)
# furrr::future_walk2(targeted_customer_outcomes, targeted_customer_restaurants, run_nopred_targeted_customer, .options = rng_options)

#furrr::future_walk(its_outcomes, ~ run_nolags_its(.x, directory="testing_no_lags"), .options = rng_options)
 #furrr::future_walk(its_outcomes, ~ run_fewlags_its(.x, directory="testing_few_lags"), .options = rng_options)
furrr::future_walk(its_outcomes, ~ run_regularized_its(.x, directory="testing_regularized"), .options = rng_options)

message(">>> ALL ANALYSES COMPLETE <<<")
plan(sequential)
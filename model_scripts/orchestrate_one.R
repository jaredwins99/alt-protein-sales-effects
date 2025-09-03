renv::snapshot()

library(tidyverse)
library(dplyr)
library(future)
library(furrr)
library(reticulate)
library(mlflow)
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

its_outcomes <- c("chicken_fish","meat","nonvegan","total","vegan","vegetarian")
targeted_its_outcomes <- c("breakfast","untextured","textured")
targeted_customer_outcomes <- c("breakfast","untextured")

targeted_its_restaurants <- list(breakfast = c('2HRX9P6HKXA8V','JHDN7CF1C03X5','L69HYJ4Y3TR91','ED5J990H5VAZT'),
                                 untextured = c('SRQS8F7JWA9MZ','JHDN7CF1C03X5'),
                                 textured = c('VLZX7K2M9QD4T'))
targeted_customer_restaurants <- list(breakfast = c('2HRX9P6HKXA8V','L69HYJ4Y3TR91','ED5J990H5VAZT'),
                                      untextured = c('SRQS8F7JWA9MZ'))

#run_its(outcome="nonvegan",directory="testing")
#run_its_fast(outcome="nonvegan",directory="fast")
#run_nolags_its(outcome="nonvegan", directory="testing_no_lags")
#run_fewlags_its(outcome="nonvegan", directory="testing_few_lags", adapt_delta=.85, max_treedepth=10)
#run_regularized_its(outcome="nonvegan", directory="testing_regularized", adapt_delta=.85, max_treedepth=10)
#run_nopred_its(outcome="nonvegan")
run_regularized2_its(outcome="nonvegan", directory="testing_regularized2", adapt_delta=.85, max_treedepth=10)
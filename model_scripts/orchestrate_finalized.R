#renv::snapshot()

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

targeted_its_restaurants <- list(
    breakfast = c('2HRX9P6HKXA8V','JHDN7CF1C03X5','L69HYJ4Y3TR91','ED5J990H5VAZT'),
    untextured = c('SRQS8F7JWA9MZ','JHDN7CF1C03X5'),
    textured = c('VLZX7K2M9QD4T'))
targeted_customer_restaurants <- list(
    breakfast = c('2HRX9P6HKXA8V','L69HYJ4Y3TR91','ED5J990H5VAZT'),
    untextured = c('SRQS8F7JWA9MZ'))
targeted_its_t2_restaurants <- list(
    breakfast = c('2HRX9P6HKXA8V','JHDN7CF1C03X5','L69HYJ4Y3TR91','ED5J990H5VAZT','W8T41JZK0ZMEP','78AY09MVJVTYE','V3Q26BHF3SE2H'),
    untextured = c('SRQS8F7JWA9MZ','JHDN7CF1C03X5','C0BE4NDSW26QN','S8MT0YGD2KTN9','9XKJD8DQTH559','LQ5EH4BKGV61T','1SQPTEGYPH0GA'),
    textured = c('VLZX7K2M9QD4T','SAFK7ND1HR6XS'),
    chicken = c('V3Q26BHF3SE2H'),
    dairy = c('W8T41JZK0ZMEP','EMBVNVD207CC6','9XKJD8DQTH559'))
targeted_customer_t2_restaurants <- list(
    breakfast = c('2HRX9P6HKXA8V','L69HYJ4Y3TR91','ED5J990H5VAZT','78AY09MVJVTYE','W8T41JZK0ZMEP','V3Q26BHF3SE2H'),
    untextured = c('SRQS8F7JWA9MZ','C0BE4NDSW26QN','S8MT0YGD2KTN9','9XKJD8DQTH559','LQ5EH4BKGV61T','1SQPTEGYPH0GA'),
    textured = c('SAFK7ND1HR6XS'),
    chicken = c('V3Q26BHF3SE2H'),
    dairy = c('W8T41JZK0ZMEP','EMBVNVD207CC6','9XKJD8DQTH559'))

                                        



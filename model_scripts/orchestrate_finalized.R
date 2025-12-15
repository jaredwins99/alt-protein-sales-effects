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
targeted_proportion_restaurants <- list(
    untextured = c('JHDN7CF1C03X5', 'SRQS8F7JWA9MZ', 'W8T41JZK0ZMEP'),
    breakfast = c('2HRX9P6HKXA8V', 'ED5J990H5VAZT', 'JHDN7CF1C03X5', 'L69HYJ4Y3TR91', 'SRQS8F7JWA9MZ', 'W8T41JZK0ZMEP'),
    chicken = c('JHDN7CF1C03X5', 'W8T41JZK0ZMEP'),
    dairy = c('ED5J990H5VAZT', 'JHDN7CF1C03X5', 'W8T41JZK0ZMEP'),
    egg = c('ED5J990H5VAZT','W8T41JZK0ZMEP'))
targeted_proportion_t2_restaurants <- list(
    textured = c('W8T41JZK0ZMEP', '9XKJD8DQTH559', 'SAFK7ND1HR6XS'),
    untextured = c('JHDN7CF1C03X5', 'SRQS8F7JWA9MZ', 'W8T41JZK0ZMEP', '1SQPTEGYPH0GA', '9XKJD8DQTH559', 'C0BE4NDSW26QN', 'CB2KHY1C2G9PT', 'EMBVNVD207CC6', 'LFZFT3VASXPED', 'LQ5EH4BKGV61T', 'S8MT0YGD2KTN9', 'SAFK7ND1HR6XS'),
    breakfast = c('2HRX9P6HKXA8V', 'ED5J990H5VAZT', 'JHDN7CF1C03X5', 'L69HYJ4Y3TR91', 'SRQS8F7JWA9MZ', 'W8T41JZK0ZMEP', '78AY09MVJVTYE', '9XKJD8DQTH559', 'CB2KHY1C2G9PT', 'EMBVNVD207CC6', 'LBZEEFSBJNB3Z', 'LQ5EH4BKGV61T', 'SAFK7ND1HR6XS', 'V3Q26BHF3SE2H'),
    chicken = c('JHDN7CF1C03X5', 'W8T41JZK0ZMEP', '9XKJD8DQTH559', 'LBZEEFSBJNB3Z', 'SAFK7ND1HR6XS', 'V3Q26BHF3SE2H'),
    dairy = c('ED5J990H5VAZT', 'JHDN7CF1C03X5', 'W8T41JZK0ZMEP', '9XKJD8DQTH559', 'C0BE4NDSW26QN', 'EMBVNVD207CC6', 'LBZEEFSBJNB3Z', 'LFZFT3VASXPED', 'SAFK7ND1HR6XS', 'V3Q26BHF3SE2H'),
    egg = c('ED5J990H5VAZT','W8T41JZK0ZMEP','LBZEEFSBJNB3Z','78AY09MVJVTYE','V3Q26BHF3SE2H'))
                                        



#renv::snapshot()

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
#tmurun_regularized_its(outcome="nonvegan", directory="testing_regularized", adapt_delta=.85, max_treedepth=10)
#run_nopred_its(outcome="nonvegan", adapt_delta=.85, max_treedepth=10)
# run_nopred_its(outcome="chicken_fish", adapt_delta=.85, max_treedepth=10)
# run_nopred_its(outcome="meat", adapt_delta=.85, max_treedepth=10)
# run_nopred_its(outcome="vegan", adapt_delta=.85, max_treedepth=10)
# run_nopred_its(outcome="vegetarian", adapt_delta=.85, max_treedepth=10)
# run_nopred_its(outcome="total", adapt_delta=.85, max_treedepth=10)
#run_regularized2_its(outcome="nonvegan", directory="testing_regularized2", adapt_delta=.85, max_treedepth=10)
#run_notime_its(outcome="nonvegan", directory="testing4_notime", adapt_delta=.85, max_treedepth=10)
#run_1time_its(outcome="nonvegan", directory="testing4_1time", adapt_delta=.85, max_treedepth=10)
#run_2time_its(outcome="nonvegan", directory="testing4_2time", adapt_delta=.85, max_treedepth=10)
#run_3time_its(outcome="nonvegan", directory="testing4_3time", adapt_delta=.85, max_treedepth=10)
#run_4time_its(outcome="nonvegan", directory="testing4_4time", adapt_delta=.85, max_treedepth=10)
#run_5time_its(outcome="nonvegan", directory="testing4_5time", adapt_delta=.85, max_treedepth=10)
#run_6time_its(outcome="nonvegan", directory="testing4_6time", adapt_delta=.85, max_treedepth=10)
#run_regularized3_its(outcome="nonvegan", directory="testing_regularized3", adapt_delta=.85, max_treedepth=10)
#run_regularized4_its(outcome="nonvegan", directory="testing_regularized4", adapt_delta=.85, max_treedepth=10)
#run_regularized5_its(outcome="nonvegan", directory="testing_regularized5", adapt_delta=.85, max_treedepth=10)
#run_6time_its(outcome="nonvegan", directory="testing_lessclipped", adapt_delta=.85, max_treedepth=10)
#run_5time_its(outcome="nonvegan", directory="testing_lessclipped_noweekend", adapt_delta=.85, max_treedepth=10)
#run_regularized4_its(outcome="nonvegan", directory="testing_lessclipped_regularized4", adapt_delta=.85, max_treedepth=10)
#run_regularized4_noweekend_its(outcome="nonvegan", directory="testing_lessclipped_regularized4_noweekend", adapt_delta=.85, max_treedepth=10)
#run_regularized5_noweekend_its(outcome="nonvegan", directory="testing_lessclipped_regularized5_noweekend", adapt_delta=.85, max_treedepth=10)
#run_reglag_noregpred_its(outcome="nonvegan", directory="testing_lessclipped_reglag_noregpred", adapt_delta=.85, max_treedepth=10)
#run_regpred_noreglag_its(outcome="nonvegan", directory="testing_lessclipped_regpred_noreglag", adapt_delta=.85, max_treedepth=10)



#run_reg4_largesigma_its(outcome="nonvegan", directory="testing_reg4_group2_largesigma", adapt_delta=.85, max_treedepth=10)
#run_reg4_largersigma_its(outcome="nonvegan", directory="testing_reg4_group2_largersigma", adapt_delta=.85, max_treedepth=10)
#run_reg4_laglargesigma_its(outcome="nonvegan", directory="testing_reg4_group2_laglargesigma", adapt_delta=.85, max_treedepth=10)
#run_regheavy_largesigma_its(outcome="nonvegan", directory="testing_regheavy_group2_largesigma", adapt_delta=.85, max_treedepth=10)



#run_regsanitycheck_largesigma_its(outcome="nonvegan", directory="testing_regsanitycheck_group2_largesigma", adapt_delta=.85, max_treedepth=10)
## #run_reglessheavy_largesigma_its(outcome="nonvegan", directory="testing_reglessheavy_group2_largesigma", adapt_delta=.85, max_treedepth=10)
#run_reglessheavyonlyevil_its(outcome="nonvegan", directory="testing_reglessheavyonlyevil_group2_largesigma", adapt_delta=.85, max_treedepth=10)
#run_reglesslessheavyonlyevil_its(outcome="nonvegan", directory="testing_reglesslessheavyonlyevil_group2_largesigma", adapt_delta=.85, max_treedepth=10)
#run_reglesslesslessheavyonlyevil_its(outcome="nonvegan", directory="testing_reglesslesslessheavyonlyevil_group2_largesigma", adapt_delta=.85, max_treedepth=10)
#run_reglesslessheavyonlyevil_lesstight_its(outcome="nonvegan", directory="testing_reglesslessheavyonlyevil_group2_lesstight", adapt_delta=.85, max_treedepth=10)
#run_reglessheavyonlyevil_hugesigma_its(outcome="nonvegan", directory="testing_reglessheavyonlyevil_group2_hugesigma", adapt_delta=.85, max_treedepth=10)


#run_reglessheavy_largesigma_its(outcome="nonvegan", directory="testing_reglessheavy_group2_largesigma", adapt_delta=.85, max_treedepth=10)


#run_reg5lags_onlyevil_its(outcome="nonvegan", directory="testing_reg5lags_onlyevil_group2_largesigma", adapt_delta=.85, max_treedepth=10)
#run_reg5lags2preds_onlyevil_its(outcome="nonvegan", directory="testing_reg5lags2preds_onlyevil_group2_largesigma", adapt_delta=.85, max_treedepth=10)
#run_reg5lags3preds_onlyevil_its(outcome="nonvegan", directory="testing_reg5lags3preds_onlyevil_group2_largesigma", adapt_delta=.85, max_treedepth=10)
#run_reg5lags4preds_onlyevil_its(outcome="nonvegan", directory="testing_reg5lags4preds_onlyevil_group2_largesigma", adapt_delta=.85, max_treedepth=10)

#run_reg5preds_onlyevil_its(outcome="nonvegan", directory="testing_reg5preds_onlyevil_group2_largesigma", adapt_delta=.85, max_treedepth=10)
#run_reg5preds2lags_onlyevil_its(outcome="nonvegan", directory="testing_reg5preds2lags_onlyevil_group2_largesigma", adapt_delta=.85, max_treedepth=10)
#run_reg5preds3lags_onlyevil_its(outcome="nonvegan", directory="testing_reg5preds3lags_onlyevil_group2_largesigma", adapt_delta=.85, max_treedepth=10)
#run_reg5preds4lags_onlyevil_its(outcome="nonvegan", directory="testing_reg5preds4lags_onlyevil_group2_largesigma", adapt_delta=.85, max_treedepth=10)

#run_phiseparate_onlyevil_reg4preds4lags_its(outcome="nonvegan", directory="testing_phiseparate_onlyevil_reg4preds4lags", adapt_delta=.85, max_treedepth=10)
# run_phiseparate_onlyevil_reg4preds6lags_its(outcome="nonvegan", directory="testing_phiseparate_onlyevil_reg4preds6lags", adapt_delta=.85, max_treedepth=10)
# run_phiseparate_onlyevil_reg4preds6lags_smallsigma_its(outcome="nonvegan", directory="testing_phiseparate_onlyevil_reg4preds6lags_smallsigma", adapt_delta=.85, max_treedepth=10)
# run_phiseparate_onlyevil_reg4preds7lags_its(outcome="nonvegan", directory="testing_phiseparate_onlyevil_reg4preds7lags", adapt_delta=.85, max_treedepth=10)
# run_phiseparate_onlyevil_reg3preds7lags_its(outcome="nonvegan", directory="testing_phiseparate_onlyevil_reg3preds7lags", adapt_delta=.85, max_treedepth=10)

# run_phiseparate_regothers_reg4preds4lags_its(outcome="nonvegan", directory="testing_phiseparate_regothers_reg4preds4lags", adapt_delta=.85, max_treedepth=10)
# run_phiseparate_regothers_reg4preds6lags_its(outcome="nonvegan", directory="testing_phiseparate_regothers_reg4preds6lags", adapt_delta=.85, max_treedepth=10)
# run_phiseparate_regothers_reg4preds6lags_smallsigma_its(outcome="nonvegan", directory="testing_phiseparate_regothers_reg4preds6lags_smallsigma", adapt_delta=.85, max_treedepth=10)
# run_phiseparate_regothers_reg4preds7lags_its(outcome="nonvegan", directory="testing_phiseparate_regothers_reg4preds7lags", adapt_delta=.85, max_treedepth=10)
# run_phiseparate_regothers_reg3preds7lags_its(outcome="nonvegan", directory="testing_phiseparate_regothers_reg3preds7lags", adapt_delta=.85, max_treedepth=10)

#run_phiseparate_reg3others_reg4preds4lags_its(outcome="nonvegan", directory="testing_phiseparate_reg3others_reg4preds4lags", adapt_delta=.85, max_treedepth=10)
# run_phiseparate_reg3others_reg4preds6lags_its(outcome="nonvegan", directory="testing_phiseparate_reg3others_reg4preds6lags", adapt_delta=.85, max_treedepth=10)
# run_phiseparate_reg3others_reg4preds6lags_smallsigma_its(outcome="nonvegan", directory="testing_phiseparate_reg3others_reg4preds6lags_smallsigma", adapt_delta=.85, max_treedepth=10)
# run_phiseparate_reg3others_reg4preds7lags_its(outcome="nonvegan", directory="testing_phiseparate_reg3others_reg4preds7lags", adapt_delta=.85, max_treedepth=10)
# run_phiseparate_reg3others_reg3preds7lags_its(outcome="nonvegan", directory="testing_phiseparate_reg3others_reg3preds7lags", adapt_delta=.85, max_treedepth=10)


#run_its(outcome="meat",directory="testing_lessclipped", adapt_delta=.85, max_treedepth=10)
#run_its(outcome="chicken_fish",directory="testing_lessclipped", adapt_delta=.85, max_treedepth=10)
#run_its(outcome="vegan",directory="testing_lessclipped", adapt_delta=.85, max_treedepth=10)
#run_its(outcome="vegetarian",directory="testing_lessclipped", adapt_delta=.85, max_treedepth=10)
####### run_its(outcome="total",directory="testing_lessclipped", adapt_delta=.85, max_treedepth=10)

#run_reg5preds_onlyevil_its(outcome="meat", directory="testing_reg5preds_onlyevil_group2_largesigma", adapt_delta=.85, max_treedepth=10)
#run_reg5preds_onlyevil_its(outcome="chicken_fish", directory="testing_reg5preds_onlyevil_group2_largesigma", adapt_delta=.85, max_treedepth=10)
#run_reg5preds_onlyevil_its(outcome="vegan", directory="testing_reg5preds_onlyevil_group2_largesigma", adapt_delta=.85, max_treedepth=10)
#run_reg5preds_onlyevil_its(outcome="vegetarian", directory="testing_reg5preds_onlyevil_group2_largesigma", adapt_delta=.85, max_treedepth=10)
#run_reg5preds_onlyevil_its(outcome="total", directory="testing_reg5preds_onlyevil_group2_largesigma", adapt_delta=.85, max_treedepth=10)

# run_prop(outcome="total", exposure="mpba_dishes_count", directory="testing_lessclipped", adapt_delta=.85, max_treedepth=10)
# run_prop(outcome="total", exposure="mpba_dishes_prop", directory="testing_lessclipped", adapt_delta=.85, max_treedepth=10)
# run_prop(outcome="total", exposure="vegan_dishes_count", directory="testing_lessclipped", adapt_delta=.85, max_treedepth=10)
# run_prop(outcome="total", exposure="vegan_dishes_prop", directory="testing_lessclipped", adapt_delta=.85, max_treedepth=10)
# run_prop(outcome="total", exposure="vegetarian_dishes_count", directory="testing_lessclipped", adapt_delta=.85, max_treedepth=10)
# run_prop(outcome="total", exposure="vegetarian_dishes_prop", directory="testing_lessclipped", adapt_delta=.85, max_treedepth=10)

#run_prop(outcome="nonvegan", exposure="mpbamod_dishes_count", directory="testing_lessclipped", adapt_delta=.85, max_treedepth=10)
#run_prop(outcome="nonvegan", exposure="mpbamod_dishes_prop", directory="testing_lessclipped", adapt_delta=.85, max_treedepth=10)
#run_prop(outcome="nonvegan", exposure="vegan_dishes_count", directory="testing_lessclipped", adapt_delta=.85, max_treedepth=10)
#run_prop(outcome="nonvegan", exposure="vegan_dishes_prop", directory="testing_lessclipped", adapt_delta=.85, max_treedepth=10)
#run_prop(outcome="nonvegan", exposure="vegetarian_dishes_count", directory="testing_lessclipped", adapt_delta=.85, max_treedepth=10)
#run_prop(outcome="nonvegan", exposure="vegetarian_dishes_prop", directory="testing_lessclipped", adapt_delta=.85, max_treedepth=10)

#run_prop(outcome="meat", exposure="mpbamod_dishes_count", directory="testing_lessclipped", adapt_delta=.85, max_treedepth=10)
#run_prop(outcome="meat", exposure="mpbamod_dishes_prop", directory="testing_lessclipped", adapt_delta=.85, max_treedepth=10)
#run_prop(outcome="meat", exposure="vegan_dishes_count", directory="testing_lessclipped", adapt_delta=.85, max_treedepth=10)
#run_prop(outcome="meat", exposure="vegan_dishes_prop", directory="testing_lessclipped", adapt_delta=.85, max_treedepth=10)
#run_prop(outcome="meat", exposure="vegetarian_dishes_count", directory="testing_lessclipped", adapt_delta=.85, max_treedepth=10)
run_prop(outcome="meat", exposure="vegetarian_dishes_prop", directory="testing_lessclipped", adapt_delta=.85, max_treedepth=10)
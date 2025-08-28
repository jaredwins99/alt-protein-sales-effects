# Processing and visualizing
library(fpp3) # tibble, dplyr, tidyr, lubridate, ggplot2, tsibble, tsibbledata, feasts, fable
library(arrow)
library(skimr)
library(shiny)
library(grid)
library(gridExtra)

# Modeling
library(tscount)
library(MASS)
library(bayesforecast)

# Parallel
library(doParallel)
library(future)
library(furrr)
library(data.table)
library(pryr)

source("tools/modeling_functions.R")

# ===============================
#             Set Up
# ===============================

# ===== Data =====

before_after_details_true <- read.csv("data/before_after_details_true.csv")

bad_restaurants <- c(
  "AQD04SM0J92WA", "LBMCPAYT7W36V", "L3XS7WSJ4AJA3", "1G5AJ17XCH2A8",
  "3AXDVZJYN9DRS", "MS8R16DY0JQAM", "N0PC58FB2XAZ3", "ADPFRN3QZRCXK",
  "WJA3YCD4QBWRX", "0RJH3FFPYBPEY", "LZ5MR1TS37E7W"
)

restaurants_by_coverage <- read.csv("data/2_palate_data_parquet_cleaned/restaurants_by_4m_coverage.csv") %>%
  filter(!(location_id %in% bad_restaurants)) %>%
  filter(!(location_id %in% c("75WYSXR9QBK5M",
                              "V3Q26BHF3SE2H",
                              "CB2KHY1C2G9PT",
                              "LFZFT3VASXPED",
                              "LQ5EH4BKGV61T"))) %>%
  pull(location_id)

df_all_daily <- read_parquet("data/3_palate_data_parquet_modeling/all_locations_daily_weather_inflation.parquet")


# ===== Subset Data =====

num_weeks_before <- 25 # 8
num_weeks_after <- 17 # 2

# Filter each restaurants to k months before to k months after the promo date in before_after_details_true
df_all_intervention_period <- df_all_daily %>%
  left_join(before_after_details_true %>%
              mutate(cross_over_date = as.Date(cross_over_date)),
            by = "location_id") %>%
  group_by(location_id) %>%
  filter(created_at >= (cross_over_date %m-% weeks(num_weeks_before)) &
           created_at <= (cross_over_date %m+% weeks(num_weeks_after))) %>%
  ungroup()


# ===== Predictors =====

predictors <- c(
  "vegan_price_real",
  "meat_price_real",
  "day_of_week_cat",
  "weekend",
  "month_cat",
  "season",
  "year",
  "inflation",
  "temp",
  "precip"
)

ar_lag_sets_1 <- list(
  c(1)

)

mean_lag_sets_1 <- list(
  c(1)
)

# Create the grid of hand-picked configurations.
# Using I() will preserve the list elements in each cell.
param_grid_lags <- expand.grid(
  ar_lags = I(ar_lag_sets_1),
  mean_lags = I(mean_lag_sets_1),
  stringsAsFactors = FALSE
)

# Define candidate lag values for AR and Mean
lag_values <- c(1, 2, 3, 4, 5, 5, 6, 7, 14, 21, 28, 35, 42, 49, 56)
# Concatenate for AR and Mean so that we have a total of 30 positions
# The first 15 positions correspond to AR and the next 15 to Mean.
candidate_lags <- c(lag_values, lag_values)
n <- length(candidate_lags)  # n = 30

# Parameters for our design
n_pool <- 1000   # Size of the random pool (increase for better coverage)
n_design <- 80   # Number of configurations you want to keep

set.seed(123)  # For reproducibility

# Generate a pool of random binary configurations (each row is one configuration)
candidate_configs <- matrix(rbinom(n_pool * n, 1, 0.5), nrow = n_pool, ncol = n)

# Function to compute the Hamming distance between two binary vectors
hamming_distance <- function(x, y) {
  sum(x != y)
}

# Greedy selection:
# Start with a randomly chosen configuration,
# then iteratively add the candidate that maximizes the minimum Hamming distance
selected_indices <- integer(n_design)
selected_indices[1] <- sample(1:n_pool, 1)
remaining_indices <- setdiff(1:n_pool, selected_indices[1])

for (i in 2:n_design) {
  # For each remaining candidate, compute its minimum Hamming distance to the already selected ones.
  min_dists <- sapply(remaining_indices, function(j) {
    candidate <- candidate_configs[j, ]
    min(sapply(selected_indices[1:(i - 1)], function(idx) {
      hamming_distance(candidate_configs[idx, ], candidate)
    }))
  })
  
  # Choose the candidate that maximizes this minimum distance
  best_idx <- remaining_indices[which.max(min_dists)]
  selected_indices[i] <- best_idx
  remaining_indices <- setdiff(remaining_indices, best_idx)
}

# The final design is the set of selected configurations.
final_design <- candidate_configs[selected_indices, ]

# Function to convert a binary row (length = 30) into a list with AR and Mean lags.
# The first 15 elements are for AR; the next 15 are for Mean.
convert_config <- function(binary_row, lag_values) {
  # For AR: select lags where binary indicator is 1
  ar_selected <- lag_values[as.logical(binary_row[1:15])]
  # For Mean: select lags where binary indicator is 1
  mean_selected <- lag_values[as.logical(binary_row[16:30])]
  return(list(ar_lags = ar_selected, mean_lags = mean_selected))
}

# Apply the function to each row of your final_design matrix
# (Assume final_design has been created as in your code)
design_list <- apply(final_design, 1, convert_config, lag_values = lag_values)

# Convert the list into a data frame with list columns
df_design <- data.frame(
  ar_lags = I(lapply(design_list, function(x) x$ar_lags)),
  mean_lags = I(lapply(design_list, function(x) x$mean_lags))
)

# Combine the two designs (rows will be stacked)
combined_design <- rbind(param_grid_lags, df_design)

outcome <- "nonvegan_outcome"

predictors <- c(
  "vegan_price_real",
  "meat_price_real",
  "day_of_week_cat",
  "weekend",
  "month_cat",
  "season",
  "year",
  "inflation",
  "temp",
  "precip"
)

## ======= View Dataset Sizes =======

# df_subset_numeric <- df_all_daily %>%
#   filter(location_id == "SRQS8F7JWA9MZ") %>%
#   mutate(across(all_of(predictors), as.numeric)) %>%
#   dplyr::select(all_of(predictors)) %>%
#   identity()
# cor(df_subset_numeric)

# # Full data
# df_all_daily %>%
#   group_by(location_id) %>%
#   summarize(count = n()) %>%
#   arrange(match(location_id, restaurants_by_coverage)) %>%
#   identity()

# # Partial data before and after intervention
# df_all_daily %>%
#   left_join(before_after_details_true %>% 
#               mutate(cross_over_date = as.Date(cross_over_date)), 
#             by = "location_id") %>%
#   group_by(location_id) %>%
#   filter(created_at >= (cross_over_date %m-% weeks(num_weeks_before)) & # 8
#            created_at <= (cross_over_date %m+% weeks(num_weeks_after))) %>% # 2
#   summarize(count = n(), na_count = sum(is.na(vegan_outcome))) %>%
#   arrange(match(location_id, restaurants_by_coverage)) %>%
#   identity()


## ======= AR/Mean Selection Functions =======

# 4. Cross-validation wrapper function
fit_and_cv <- function(df, 
                       loc_id, 
                       outcome, 
                       predictors, 
                       ar_lags, 
                       mean_lags, 
                       initial_train_days = 63, 
                       test_days = 42) {
  
  print(mean_lags)
  
  # Calculate CV result
  cv_result <- tryCatch(
    walk_forward_cv_nbar(df,
                         loc = loc_id,
                         outcome = outcome,
                         predictors = predictors,
                         initial_train_days = initial_train_days,
                         test_days = test_days,
                         ar_lags = ar_lags,
                         mean_lags = mean_lags,
                         sample = FALSE), 
    error = function(e) {
      message("fit_and_cv: Error in cross-validation: ", e$message)
      NULL}
    )
  
  # Don't try to aggregate if it already failed
  if (is.null(cv_result)) return(Inf)
  
  # Fit CV result
  tryCatch(
    aggregate_cv_results(cv_result), 
    error = function(e) {
      message("Error aggregating CV results: ", e$message)
      Inf}
    )
}



parallelize_garch_models <- function(fit_func, 
                                     df, 
                                     loc_id,  
                                     outcome,
                                     predictors,
                                     ar_lag_sets, 
                                     mean_lag_sets,
                                     timeout = 3 # timeout in minutes
                                     ) {
  
  # Add a time bound
  time_bounded_func <- function(df_, loc_id_, outcome_, predictors_, ar_lags_, mean_lags_) {
    withTimeout(
      fit_func(df_, loc_id_, outcome_, predictors_, ar_lags_, mean_lags_), 
      timeout = timeout * 60,
      onTimeout = "error"
      )  
  }

  # Add error handling
  error_handled_func <- function(df_, loc_id_, outcome_, predictors_, ar_lags_, mean_lags_) {
    result <- tryCatch(
      time_bounded_func(df_, loc_id_, outcome_, predictors_, ar_lags_, mean_lags_),
      error = function(e) {
        message("Grid search error for ar_lags = ",
                paste(ar_lags_, collapse = ","),
                " and mean_lags = ", 
                paste(mean_lags_, collapse = ","),
                ": ", 
                e$message) 
        list(cv_error = Inf, predictors = predictors_)}
    )
    if (is.null(result)) result <- list(cv_error = Inf, predictors = predictors_)
    result
  }
  
  # Initialize grid of AR and mean lags
  param_grid_lags <- expand.grid(ar_lags = ar_lag_sets_1, 
                                 mean_lags = mean_lag_sets_1, stringsAsFactors = FALSE)
  names(param_grid_lags) <- c("ar_lags", 
                              "mean_lags")
  
  
  
  # Start memory and time tracking
  mem_used <- mem_used()
  start_time <- Sys.time()
  
  # Run model training over grid in parallel
  param_grid_lags$cv_results <- future_pmap(param_grid_lags, function(ar_lags_, mean_lags_) {error_handled_func(df, loc_id, outcome, predictors, ar_lags_, mean_lags_)})

  # End memory and time tracking
  end_time <- Sys.time()
  mem_used_after <- mem_used()
  print(mem_used_after - mem_used)
  print(difftime(end_time, start_time, units = "secs"))
  
  # Return to single core
  
  
  # # Save
  # saveRDS(param_grid_lags, file = paste0("param_grid_lags_",loc_id,".rds"))
  
  # Return
  param_grid_lags
}

# Start multisession
num_cores <- 90
print(num_cores)
plan(multisession, workers = num_cores)
for (loc_id in restaurants_by_coverage[5:5]) {

  # Rprof("profile_output.out")
  param_grid_lags <- parallelize_garch_models(fit_func = fit_and_cv,
                                              df = df_all_daily, # df_all_intervention_period
                                              loc_id = loc_id,
                                              outcome = outcome,
                                              predictors = predictors,
                                              ar_lag_sets = ar_lag_sets_1,
                                              mean_lag_sets = mean_lag_sets_1)
  # Rprof(NULL)

  saveRDS(param_grid_lags, file = paste0("validation_results/early_stopping/param_grid_lags_entire_data_",loc_id,".rds"))

}

plan(sequential)


readRDS("validation_results/early_stopping/param_grid_lags_entire_data_ED5J990H5VAZT.rds")

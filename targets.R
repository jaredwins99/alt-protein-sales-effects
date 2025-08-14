suppressPackageStartupMessages({
  library(targets)
  library(tarchetypes)
  library(future)
  library(tibble)
  library(purrr)
})

plan(multicore, workers = 1)

tar_option_set(packages = c("cmdstanr","posterior","tidyverse","arrow","lubridate","grid","patchwork","conflicted","reticulate","mlflow"))

source("run_ingarch.R")

df_for <- function(analysis, outcomes) tibble(analysis = analysis, outcome = outcomes)

A1_outcomes <- c("chicken_fish","meat","nonvegan","total","vegan","vegetarian")
A2_outcomes <- c()
A3_outcomes <- c("chicken_fish","meat","nonvegan","total","vegan","vegetarian")
A4_outcomes <- c()
A5_outcomes <- c(#"chicken_fish","meat","nonvegan",
  "total","vegan","vegetarian"
)
A6_outcomes <- c()

runs_tbl <- dplyr::bind_rows(
#   df_for("proportion", A1_outcomes),
#   df_for("proportion", A2_outcomes),
#   df_for("its", A3_outcomes),
#   df_for("its", A4_outcomes),
  df_for("customer", A5_outcomes)#,
#   df_for("customer", A6_outcomes)
)

list(
  # Pass the data frame itself to tar_map instead of using a runs target
  tar_map(
    values = runs_tbl,
    names = outcome,
    tar_target(
      fit_ok,
      run_ingarch(
        outcome = outcome,
        analysis = analysis,
        data_file = "all_locations_daily_weather_inflation_customers.parquet",
        chains = 3,
        parallel_chains = 3
      ),
      iteration = "vector"
    )
  )
)
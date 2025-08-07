library(cmdstanr)
library(posterior)
library(tidyverse)
library(arrow)
library(dplyr)
library(lubridate)
library(grid)

restaurants_to_model <- c(
  'VLZX7K2M9QD4T', 'SRQS8F7JWA9MZ', '2HRX9P6HKXA8V', 'JHDN7CF1C03X5', 'L69HYJ4Y3TR91',
  'ED5J990H5VAZT', 'W8T41JZK0ZMEP', 'EMBVNVD207CC6', 'C0BE4NDSW26QN', '75WYSXR9QBK5M',
  'V3Q26BHF3SE2H', 'LBZEEFSBJNB3Z', 'SAFK7ND1HR6XS', 'CB2KHY1C2G9PT', 'S8MT0YGD2KTN9',
  'LFZFT3VASXPED', '1SQPTEGYPH0GA', '9XKJD8DQTH559', 'LQ5EH4BKGV61T', '78AY09MVJVTYE'
)

outcome_str <- 'nonvegan'
for (location in restaurants_to_model) {
    base_path <- paste0('model_fits/empirical/', outcome_str)
    file_name <- paste0(base_path,'/fit_', location, '.rds')
    if (!file.exists(file_name)) {
        next
    }
    fit <- readRDS(file_name)
    write_parquet(fit$draws(format='df'), paste0(base_path, "/samples_", location, ".parquet", compression = "ZSTD"))
    jsonlite::write_json(fit$metadata(), paste0(base_path, "/metadata_", location, ".json"), pretty = TRUE)
    file.remove(file_name)
}

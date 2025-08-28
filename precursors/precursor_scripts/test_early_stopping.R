# Load required libraries
library(tidyverse)
library(tscount)
library(lubridate)
library(arrow)

# Source our functions
source("tools/modeling_functions.R")

# Define bad restaurants
bad_restaurants <- c(
  "AQD04SM0J92WA", "LBMCPAYT7W36V", "L3XS7WSJ4AJA3", "1G5AJ17XCH2A8",
  "3AXDVZJYN9DRS", "MS8R16DY0JQAM", "N0PC58FB2XAZ3", "ADPFRN3QZRCXK",
  "WJA3YCD4QBWRX", "0RJH3FFPYBPEY", "LZ5MR1TS37E7W"
)

# Run the abysmal predictions test
print("Testing check_abysmal_predictions:")
test_check_abysmal_predictions()

# Load data for first fold test
print("\nLoading data...")
df_all_daily <- read_parquet("data/3_palate_data_parquet_modeling/all_locations_daily_weather_inflation.parquet")
restaurants_by_coverage <- read.csv("data/2_palate_data_parquet_cleaned/restaurants_by_4m_coverage.csv") %>%
  filter(!(location_id %in% bad_restaurants)) %>%
  filter(!(location_id %in% c("75WYSXR9QBK5M",
                            "V3Q26BHF3SE2H",
                            "CB2KHY1C2G9PT",
                            "LFZFT3VASXPED",
                            "LQ5EH4BKGV61T"))) %>%
  pull(location_id)

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

# Run the first fold test
print("\nTesting test_first_fold:")
test_test_first_fold(df_all_daily, 
                    restaurants_by_coverage[1], 
                    "nonvegan_outcome", 
                    predictors) 
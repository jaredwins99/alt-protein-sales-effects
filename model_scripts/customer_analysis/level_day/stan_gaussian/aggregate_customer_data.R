# Aggregate item-level customer transactions to customer-day level.
# Input is pre-filtered to customers with pre+post exposure observations.

library(tidyverse)
library(arrow)
library(data.table)

INPUT_PATH  <- "data/4_data_parquet_modeling/customer/finalized_transactions_customers.parquet"
OUTPUT_PATH <- "model_scripts/customer_analysis/day/finalized_customer_day.parquet"

df <- read_parquet(INPUT_PATH)

# --- Column definitions ---

outcome_cols <- c(
  "vegan_outcome", "vegetarian_outcome", "total_outcome",
  "nonvegan_outcome", "meat_outcome", "chicken_fish_outcome",
  "breakfast_outcome_p", "textured_outcome_p", "untextured_outcome_p",
  "chicken_outcome_p", "dairy_outcome_p", "egg_outcome_p",
  "breakfast_outcome", "textured_outcome", "untextured_outcome",
  "chicken_outcome", "dairy_outcome",
  "breakfast_t2_outcome", "textured_t2_outcome", "untextured_t2_outcome",
  "chicken_t2_outcome", "dairy_t2_outcome"
)

exposure_cols    <- names(df)[grepl("^exposure_", names(df))]
price_cols       <- names(df)[grepl("_price_real$", names(df))]
calendar_cols    <- c("day_of_week_cat", "day_of_week", "weekend",
                      "day_of_month_cat", "day_of_month",
                      "month_cat", "month", "season",
                      "year_cat", "year", "date_code", "holiday_window")
weather_cols     <- c("inflation", "temp", "precip")
restaurant_cols  <- c("cuisine", "city", "state", "restaurant_type", "pos_type", "zip_code")
customer_cols    <- c("gender", "age")

first_value_cols <- intersect(
  c(exposure_cols, price_cols, calendar_cols, weather_cols,
    restaurant_cols, "batch_x", customer_cols),
  names(df)
)

# --- 1. Aggregate to customer x location x date ---

dt <- as.data.table(df)
sum_exprs   <- paste0(outcome_cols, " = sum(", outcome_cols, ", na.rm = TRUE)")
first_exprs <- paste0(first_value_cols, " = first(", first_value_cols, ")")
agg_expr    <- paste0("list(", paste(c(sum_exprs, first_exprs), collapse = ", "), ")")

cust_day <- as_tibble(dt[, eval(parse(text = agg_expr)), by = .(customer_id, location_id, date)])

# --- 2. AR lag covariates at restaurant-day level ---

ar_outcomes <- c(
  "vegan_outcome", "vegetarian_outcome", "total_outcome",
  "nonvegan_outcome", "meat_outcome", "chicken_fish_outcome",
  "breakfast_outcome", "untextured_outcome",
  "breakfast_t2_outcome", "chicken_t2_outcome", "dairy_t2_outcome",
  "textured_t2_outcome", "untextured_t2_outcome"
)

lag_periods <- c(1, 2, 3, 7)

rest_day <- cust_day %>%
  group_by(location_id, date) %>%
  summarize(across(all_of(ar_outcomes), ~sum(., na.rm = TRUE), .names = "restday_{.col}"),
            .groups = "drop") %>%
  arrange(location_id, date) %>%
  group_by(location_id)

for (outcome in ar_outcomes) {
  restday_col <- paste0("restday_", outcome)
  stub <- sub("_outcome$", "", outcome)
  for (l in lag_periods)
    rest_day <- rest_day %>% mutate(!!paste0(stub, "_ar_lag_", l) := lag(log1p(.data[[restday_col]]), l))
}
rest_day <- rest_day %>% ungroup()

ar_lag_cols <- names(rest_day)[grepl("_ar_lag_", names(rest_day))]
cust_day <- cust_day %>%
  left_join(rest_day %>% select(location_id, date, all_of(ar_lag_cols)),
            by = c("location_id", "date"))

# --- 3. Per-customer total counts (sufficient statistics for conditional Poisson) ---

customer_totals <- cust_day %>%
  group_by(customer_id, location_id) %>%
  summarize(across(all_of(outcome_cols), ~sum(., na.rm = TRUE),
                   .names = "n_i_{.col}"),
            .groups = "drop")

cust_day <- cust_day %>%
  left_join(customer_totals, by = c("customer_id", "location_id"))

# --- 4. Save ---

cust_day <- cust_day %>% arrange(location_id, customer_id, date)
dir.create(dirname(OUTPUT_PATH), showWarnings = FALSE, recursive = TRUE)
write_parquet(cust_day, OUTPUT_PATH)

message(sprintf("Saved %d rows x %d cols to %s", nrow(cust_day), ncol(cust_day), OUTPUT_PATH))

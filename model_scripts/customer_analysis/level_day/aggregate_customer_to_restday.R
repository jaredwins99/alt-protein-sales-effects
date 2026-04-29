# Aggregate transaction-level customer data to restaurant-day level
# EXACTLY matching the filtering and demeaning in 1_data_gaussian_iid.R
#
# Each outcome column is demeaned independently per customer,
# then summed to restaurant-day level. One output file with all outcomes.

library(tidyverse)
library(arrow)

# --- Observability helper ---
report <- function(df, label) {
  ncust <- if ("customer_id" %in% names(df)) length(unique(df$customer_id)) else NA
  nloc  <- if ("location_id" %in% names(df)) length(unique(df$location_id)) else NA
  cat(sprintf("[%s] rows=%d  cols=%d  customers=%s  locations=%s\n",
              label, nrow(df), ncol(df),
              ifelse(is.na(ncust), "-", format(ncust, big.mark=",")),
              ifelse(is.na(nloc),  "-", as.character(nloc))))
}

INPUT_PATH <- "data/4_data_parquet_modeling/customer/finalized_transactions_customers.parquet"
OUTPUT_FILE <- "data/4_data_parquet_modeling/customer_day/finalized.parquet"
dir.create(dirname(OUTPUT_FILE), showWarnings = FALSE, recursive = TRUE)

# --- All outcomes ---
outcome_cols <- c(
  # A5 (untargeted)
  "vegan_outcome", "vegetarian_outcome", "total_outcome",
  "nonvegan_outcome", "meat_outcome", "chicken_fish_outcome",
  # A6 T1 (targeted)
  "breakfast_outcome", "untextured_outcome",
  # A6 T2 (targeted)
  "breakfast_t2_outcome", "untextured_t2_outcome",
  "chicken_t2_outcome", "dairy_t2_outcome", "textured_t2_outcome"
)

# --- Introduction dates ---
intros_wide <- read.csv("data/mpba_introductions.csv") %>%
  group_by(location_id) %>%
  mutate(intervention_counter = row_number()) %>%
  ungroup() %>%
  mutate(
    exposure_key = paste0("exposure_", location_id, "_", intervention_counter),
    intro_date_num = as.integer(as.Date(intro_date))) %>%
  select(location_id, exposure_key, intro_date_num) %>%
  pivot_wider(
    names_from = exposure_key,
    values_from = intro_date_num,
    names_prefix = "date_num_")

# --- STEP 1: Load source parquet ---
df <- read_parquet(INPUT_PATH)
report(df, "1. loaded source parquet")

# --- STEP 2: Defensive rename of *_outcome_p -> *_p_outcome ---
if ("breakfast_outcome_p" %in% colnames(df)) {
  df <- df %>% rename(
    breakfast_p_outcome = breakfast_outcome_p,
    chicken_p_outcome = chicken_outcome_p,
    dairy_p_outcome = dairy_outcome_p,
    egg_p_outcome = egg_outcome_p,
    textured_p_outcome = textured_outcome_p,
    untextured_p_outcome = untextured_outcome_p)
  cat("[2. renamed *_outcome_p -> *_p_outcome]\n")
} else {
  cat("[2. rename skipped (cols already in target form)]\n")
}

# --- STEP 3: Drop neighborhood cols ---
ncol_before <- ncol(df)
df <- df %>% select(-contains("neighborhood"))
cat(sprintf("[3. dropped neighborhood cols] cols %d -> %d\n", ncol_before, ncol(df)))

# --- STEP 4: Per-restaurant date-window filters (8 restaurants) ---
df <- df %>%
  filter(location_id != "2HRX9P6HKXA8V" | ('2019-01-01' < date & date < '2023-08-01')) %>%
  filter(location_id != "JHDN7CF1C03X5" | (date < '2023-06-01')) %>%
  filter(location_id != "EMBVNVD207CC6" | ('2016-06-01' < date & date < '2022-09-01')) %>%
  filter(location_id != "LBZEEFSBJNB3Z" | ('2021-09-01' < date & date < '2023-07-01')) %>%
  filter(location_id != "CB2KHY1C2G9PT" | ('2020-06-01' < date & date < '2023-04-01')) %>%
  filter(location_id != "LFZFT3VASXPED" | ('2021-10-01' < date & date < '2022-11-01')) %>%
  filter(location_id != "75WYSXR9QBK5M" | ('2022-05-01' < date & date < '2023-07-01')) %>%
  filter(location_id != "SAFK7ND1HR6XS" | ('2019-04-18' < date & date < '2020-03-25'))
report(df, "4. after per-restaurant date filters")

# --- Covariate columns ---
covariate_cols <- df %>%
  select(
    location_id, date, gender, age,
    starts_with("exposure_"),
    starts_with("date_num_"),
    matches("_price_real$"),
    weekend, holiday_window, month_cat, season, year_cat,
    day_of_week_cat, inflation, temp, precip, date_code
  ) %>% colnames()
covariate_cols <- setdiff(covariate_cols, c("customer_id", "order_id"))

# --- STEP 6: Aggregate items -> transactions (group by customer x order) ---
df <- df %>%
  group_by(customer_id, order_id) %>%
  summarize(
    across(all_of(outcome_cols), sum, na.rm = TRUE),
    across(all_of(covariate_cols), first),
    .groups = "drop")
report(df, "6. items -> transactions")
cat("    sample outcome sums (first row):",
    paste(outcome_cols[1:3], "=",
          round(as.numeric(df[1, outcome_cols[1:3]]), 3), collapse = ", "), "\n")

# --- STEP 7: Add intro dates, location factor, date_num, exposure deltas, NA->0 ---
ncol_before <- ncol(df)
df <- df %>%
  left_join(intros_wide, by = "location_id") %>%
  mutate(
    location_id_factor = factor(location_id),
    location_id_num = as.integer(location_id_factor),
    date_num = as.integer(date),
    across(starts_with("date_num_exposure_"), ~ date_num - .x),
    across(starts_with("date_num"), ~ .x / 365.25)) %>%
  mutate(across(where(is.numeric), ~ replace_na(.x, 0)))
cat(sprintf("[7. joined intros + computed date_num/exposure deltas] cols %d -> %d\n",
            ncol_before, ncol(df)))

# --- STEP 8: Build exposure_cols list (excludes _slope, _gender*) ---
exposure_cols <- df %>%
  select(starts_with("exposure_"), -contains("slope"), -contains("gender")) %>%
  colnames()
cat("[8. exposure_cols identified]:", length(exposure_cols), "cols ->",
    paste(exposure_cols, collapse = ", "), "\n")

# --- STEP 9: Pre/post filter (per customer x location, binary any_exposure) ---
# Matches the multi-intervention-safe filter from 1_data_customer_gaussian.R
n_before <- nrow(df)
ncust_before <- length(unique(df$customer_id))
df <- df %>%
  mutate(any_exposure = as.integer(rowSums(select(., all_of(exposure_cols))) > 0)) %>%
  group_by(customer_id, location_id) %>%
  mutate(
    has_pre  = any(any_exposure == 0),
    has_post = any(any_exposure > 0)) %>%
  ungroup() %>%
  filter(has_pre & has_post) %>%
  select(-has_pre, -has_post)
cat(sprintf("[9. pre/post filter] rows %d -> %d (dropped %d), customers %d -> %d (dropped %d)\n",
            n_before, nrow(df), n_before - nrow(df),
            ncust_before, length(unique(df$customer_id)),
            ncust_before - length(unique(df$customer_id))))

# --- STEP 10: Per (customer x location) demean using pre-period (any_exposure==0) ---
cat("[10. demeaning per customer x location...]\n")
pre_means_before <- sapply(outcome_cols, function(oc) mean(df[[oc]], na.rm = TRUE))
df <- df %>%
  group_by(customer_id, location_id) %>%
  mutate(across(all_of(outcome_cols),
                ~ .x - mean(.x[any_exposure == 0], na.rm = TRUE))) %>%
  ungroup()
post_means_after <- sapply(outcome_cols, function(oc) mean(df[[oc]], na.rm = TRUE))
for (oc in outcome_cols) {
  cat(sprintf("    %-25s mean before=%9.4f  after=%9.4f\n",
              oc, pre_means_before[oc], post_means_after[oc]))
}
gc()

# --- STEP 11: Normalize gender -> {male, female, unknown} ---
gender_before <- table(df$gender, useNA = "always")
df <- df %>%
  mutate(gender = case_when(
    is.na(gender) ~ "unknown",
    !gender %in% c("male", "female") ~ "unknown",
    TRUE ~ gender))
gender_after <- table(df$gender, useNA = "always")
cat("[11. gender normalize]\n")
cat("    before:"); print(gender_before)
cat("    after :"); print(gender_after)

# --- STEP 12: Aggregate to restaurant x day x gender ---
# Outcomes are MEAN per cell (per-customer average of demeaned outcomes),
# so cell-level beta has the same per-customer interpretation as the
# transaction-level model. n_customers retained for optional weighting.
rest_day <- df %>%
  group_by(location_id, date, gender) %>%
  summarize(
    across(all_of(outcome_cols), \(x) mean(x, na.rm = TRUE)),
    n_customers = n(),
    across(all_of(setdiff(intersect(covariate_cols, names(df)),
                          c("location_id", "date", "gender", "age"))), first),
    .groups = "drop") %>%
  select(-any_of("customer_id")) %>%
  arrange(location_id, date, gender)
report(rest_day, "12. restaurant x day x gender")
cat("    distinct dates:", length(unique(rest_day$date)),
    "  distinct (loc,date) pairs:",
    nrow(distinct(rest_day, location_id, date)), "\n")
cat("    n_customers per row: min=", min(rest_day$n_customers),
    " median=", median(rest_day$n_customers),
    " mean=", round(mean(rest_day$n_customers),1),
    " max=", max(rest_day$n_customers), "\n")

# --- Save ---
write_parquet(rest_day, OUTPUT_FILE)
cat("Saved to", OUTPUT_FILE, "\n")

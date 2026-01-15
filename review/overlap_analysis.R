# Statistical Overlap Analysis for MPBA Study
# Analyzes exposure variation in proportion and ITS data

library(arrow)
library(dplyr)
library(tidyr)

# Set output file
sink("/home/researcher/Documents/Jared/Other/testing/review/analysis_output.txt")

cat("===========================================\n")
cat("STATISTICAL OVERLAP ANALYSIS\n")
cat("===========================================\n\n")

#####################################################################
# SECTION 1: A1/A2 - PROPORTION ANALYSES
#####################################################################

cat("===== SECTION 1: PROPORTION ANALYSES (A1/A2) =====\n\n")

# Read proportion data files
prop_dir <- "data/4_data_parquet_modeling/proportion/"

# 1a. MPBA Proportion
cat("--- 1a. MPBA PROPORTION (mpbamod_dishes_prop) ---\n")
mpba_prop <- read_parquet(paste0(prop_dir, "finalized_mpbamod_dishes_prop.parquet"))

mpba_var <- mpba_prop %>%
  group_by(location_id) %>%
  summarise(
    n_obs = n(),
    n_non_na = sum(!is.na(mpbamod_dishes_prop)),
    exposure_min = min(mpbamod_dishes_prop, na.rm=TRUE),
    exposure_max = max(mpbamod_dishes_prop, na.rm=TRUE),
    exposure_range = exposure_max - exposure_min,
    exposure_mean = mean(mpbamod_dishes_prop, na.rm=TRUE),
    exposure_sd = sd(mpbamod_dishes_prop, na.rm=TRUE),
    exposure_var = var(mpbamod_dishes_prop, na.rm=TRUE),
    n_unique = n_distinct(mpbamod_dishes_prop, na.rm=TRUE),
    outcome_mean = mean(meat_outcome, na.rm=TRUE),
    outcome_var = var(meat_outcome, na.rm=TRUE)
  ) %>%
  arrange(exposure_var)

print(mpba_var)

cat("\nSummary statistics:\n")
cat(paste0("Total restaurants: ", nrow(mpba_var), "\n"))
cat(paste0("Restaurants with zero variance: ", sum(mpba_var$exposure_var == 0, na.rm=TRUE), "\n"))
cat(paste0("Restaurants with <5 unique values: ", sum(mpba_var$n_unique < 5, na.rm=TRUE), "\n"))
cat(paste0("Restaurants with variance < 0.001: ", sum(mpba_var$exposure_var < 0.001, na.rm=TRUE), "\n"))
cat(paste0("Restaurants with range < 0.05: ", sum(mpba_var$exposure_range < 0.05, na.rm=TRUE), "\n\n"))

# 1b. Vegan Proportion
cat("--- 1b. VEGAN PROPORTION (vegan_dishes_prop) ---\n")
vegan_prop <- read_parquet(paste0(prop_dir, "finalized_vegan_dishes_prop.parquet"))

vegan_var <- vegan_prop %>%
  group_by(location_id) %>%
  summarise(
    n_obs = n(),
    n_non_na = sum(!is.na(vegan_dishes_prop)),
    exposure_min = min(vegan_dishes_prop, na.rm=TRUE),
    exposure_max = max(vegan_dishes_prop, na.rm=TRUE),
    exposure_range = exposure_max - exposure_min,
    exposure_mean = mean(vegan_dishes_prop, na.rm=TRUE),
    exposure_sd = sd(vegan_dishes_prop, na.rm=TRUE),
    exposure_var = var(vegan_dishes_prop, na.rm=TRUE),
    n_unique = n_distinct(vegan_dishes_prop, na.rm=TRUE)
  ) %>%
  arrange(exposure_var)

print(vegan_var)

cat("\nSummary statistics:\n")
cat(paste0("Total restaurants: ", nrow(vegan_var), "\n"))
cat(paste0("Restaurants with zero variance: ", sum(vegan_var$exposure_var == 0, na.rm=TRUE), "\n"))
cat(paste0("Restaurants with <5 unique values: ", sum(vegan_var$n_unique < 5, na.rm=TRUE), "\n"))
cat(paste0("Restaurants with variance < 0.001: ", sum(vegan_var$exposure_var < 0.001, na.rm=TRUE), "\n\n"))

# 1c. Vegetarian Proportion
cat("--- 1c. VEGETARIAN PROPORTION (vegetarian_dishes_prop) ---\n")
veg_prop <- read_parquet(paste0(prop_dir, "finalized_vegetarian_dishes_prop.parquet"))

veg_var <- veg_prop %>%
  group_by(location_id) %>%
  summarise(
    n_obs = n(),
    n_non_na = sum(!is.na(vegetarian_dishes_prop)),
    exposure_min = min(vegetarian_dishes_prop, na.rm=TRUE),
    exposure_max = max(vegetarian_dishes_prop, na.rm=TRUE),
    exposure_range = exposure_max - exposure_min,
    exposure_mean = mean(vegetarian_dishes_prop, na.rm=TRUE),
    exposure_sd = sd(vegetarian_dishes_prop, na.rm=TRUE),
    exposure_var = var(vegetarian_dishes_prop, na.rm=TRUE),
    n_unique = n_distinct(vegetarian_dishes_prop, na.rm=TRUE)
  ) %>%
  arrange(exposure_var)

print(veg_var)

cat("\nSummary statistics:\n")
cat(paste0("Total restaurants: ", nrow(veg_var), "\n"))
cat(paste0("Restaurants with zero variance: ", sum(veg_var$exposure_var == 0, na.rm=TRUE), "\n"))
cat(paste0("Restaurants with <5 unique values: ", sum(veg_var$n_unique < 5, na.rm=TRUE), "\n"))
cat(paste0("Restaurants with variance < 0.001: ", sum(veg_var$exposure_var < 0.001, na.rm=TRUE), "\n\n"))

#####################################################################
# SECTION 2: PROPORTION_TARGETED ANALYSES
#####################################################################

cat("===== SECTION 2: PROPORTION_TARGETED ANALYSES =====\n\n")

prop_targ_dir <- "data/4_data_parquet_modeling/proportion_targeted/"

# Read all presence files
for (item in c("breakfast", "chicken", "dairy", "egg", "textured", "untextured")) {
  cat(paste0("--- ", toupper(item), " DISHES PRESENCE ---\n"))

  presence_file <- paste0(prop_targ_dir, "finalized_", item, "_dishes_presence.parquet")
  df <- read_parquet(presence_file)

  exposure_col <- paste0(item, "_dishes_presence")
  outcome_col <- paste0(item, "_outcome_p")

  if (exposure_col %in% names(df)) {
    presence_var <- df %>%
      group_by(location_id) %>%
      summarise(
        n_obs = n(),
        n_non_na = sum(!is.na(.data[[exposure_col]])),
        exposure_min = min(.data[[exposure_col]], na.rm=TRUE),
        exposure_max = max(.data[[exposure_col]], na.rm=TRUE),
        exposure_mean = mean(.data[[exposure_col]], na.rm=TRUE),
        exposure_var = var(.data[[exposure_col]], na.rm=TRUE),
        n_unique = n_distinct(.data[[exposure_col]], na.rm=TRUE),
        pct_ones = mean(.data[[exposure_col]] == 1, na.rm=TRUE),
        pct_zeros = mean(.data[[exposure_col]] == 0, na.rm=TRUE)
      ) %>%
      arrange(exposure_var)

    print(presence_var)

    cat("\nSummary statistics:\n")
    cat(paste0("Restaurants with all zeros: ", sum(presence_var$pct_zeros == 1, na.rm=TRUE), "\n"))
    cat(paste0("Restaurants with all ones: ", sum(presence_var$pct_ones == 1, na.rm=TRUE), "\n"))
    cat(paste0("Restaurants with zero variance: ", sum(presence_var$exposure_var == 0, na.rm=TRUE), "\n\n"))
  }
}

#####################################################################
# SECTION 3: ITS ANALYSES (A3-A6)
#####################################################################

cat("===== SECTION 3: ITS ANALYSES (A3-A6) =====\n\n")

its_data <- read_parquet("data/4_data_parquet_modeling/its/finalized.parquet")

cat("ITS Data Structure:\n")
cat(paste0("Total rows: ", nrow(its_data), "\n"))
cat(paste0("Columns: ", paste(names(its_data), collapse=", "), "\n\n"))

# Find exposure columns (binary step function columns)
exposure_cols <- names(its_data)[grepl("^exposure_", names(its_data))]
cat(paste0("Exposure columns found: ", paste(exposure_cols, collapse=", "), "\n\n"))

# Analyze each exposure
for (exp_col in exposure_cols) {
  cat(paste0("--- ", exp_col, " ---\n"))

  exp_summary <- its_data %>%
    group_by(location_id) %>%
    summarise(
      n_obs = n(),
      n_non_na = sum(!is.na(.data[[exp_col]])),
      n_pre = sum(.data[[exp_col]] == 0, na.rm=TRUE),
      n_post = sum(.data[[exp_col]] == 1, na.rm=TRUE),
      pct_pre = n_pre / n_non_na,
      pct_post = n_post / n_non_na,
      exposure_var = var(.data[[exp_col]], na.rm=TRUE)
    ) %>%
    arrange(n_pre)

  print(exp_summary)

  cat("\nPre/Post Summary:\n")
  cat(paste0("Restaurants with <30 pre-period obs: ", sum(exp_summary$n_pre < 30, na.rm=TRUE), "\n"))
  cat(paste0("Restaurants with <30 post-period obs: ", sum(exp_summary$n_post < 30, na.rm=TRUE), "\n"))
  cat(paste0("Restaurants with zero variance (no exposure change): ", sum(exp_summary$exposure_var == 0, na.rm=TRUE), "\n"))
  cat(paste0("Restaurants with all pre-period: ", sum(exp_summary$pct_pre == 1, na.rm=TRUE), "\n"))
  cat(paste0("Restaurants with all post-period: ", sum(exp_summary$pct_post == 1, na.rm=TRUE), "\n\n"))
}

#####################################################################
# SECTION 4: CROSS-CHECK OUTCOME-EXPOSURE RELATIONSHIP
#####################################################################

cat("===== SECTION 4: OUTCOME-EXPOSURE CROSS-CHECK =====\n\n")

# For restaurants with constant exposure, check outcome variance
cat("--- MPBA Proportion: Outcome variance where exposure is constant ---\n")
constant_exposure_rest <- mpba_var %>% filter(exposure_var < 0.001)

if (nrow(constant_exposure_rest) > 0) {
  cat(paste0("Restaurants with near-constant MPBA exposure:\n"))
  print(constant_exposure_rest %>% select(location_id, exposure_var, exposure_mean, outcome_mean, outcome_var))
} else {
  cat("No restaurants with constant MPBA exposure\n")
}

cat("\n--- Overall Exposure Distribution ---\n")
cat("MPBA Proportion Summary:\n")
print(summary(mpba_prop$mpbamod_dishes_prop))

cat("\nVegan Proportion Summary:\n")
print(summary(vegan_prop$vegan_dishes_prop))

cat("\nVegetarian Proportion Summary:\n")
print(summary(veg_prop$vegetarian_dishes_prop))

sink()

cat("Analysis complete. Output written to analysis_output.txt\n")

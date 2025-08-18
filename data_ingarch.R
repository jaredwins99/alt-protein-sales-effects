suppressPackageStartupMessages({
    library(tidyverse)
    library(arrow)
    library(lubridate)
    library(conflicted)
})

c("select", "filter") %>% walk(~ conflict_prefer(.x, "dplyr"))
c("year", "month") %>% walk(~ conflict_prefer(.x, "lubridate"))
c("map") %>% walk( ~ conflict_prefer(.x, "purrr"))
c("sd") %>%  walk(~ conflict_prefer(.x, "stats"))
c("match") %>%  walk(~ conflict_prefer(.x, "base"))

print_rows <- function(df) {
    df %>% nrow() %>% {paste("# of rows:", .)} %>% print()
    return(df)
}

# ──────────────────────────────────
#           Prepare Data
# ──────────────────────────────────

prepare_data <- function(
    data_dir, 
    outcome, 
    restaurants_to_model, 
    random_predictors, 
    fixed_predictors,
    train_frac) {

    # ──────────────────────────────────
    #     1. Load and Prepare Data  
    # ──────────────────────────────────
  
    before_after_details_true <- read.csv("data/before_after_details_true.csv") %>%
        mutate(cross_over_date = as.Date(cross_over_date),
               cross_over_date_num = as.integer(cross_over_date))

    df <- read_parquet(data_dir) %>%

        print_rows() %>%

      # Filter to relevant restaurants
      filter(location_id %in% restaurants_to_model) %>%

      # Remove poor data boundaries
      filter(location_id != "2HRX9P6HKXA8V" | ('2019-01-01' < date & date < '2021-05-01')) %>%
      filter(location_id != "JHDN7CF1C03X5" | ('2019-04-01' < date & date < '2023-06-01')) %>%
      filter(location_id != "EMBVNVD207CC6" | ('2016-06-01' < date & date < '2022-09-01')) %>%
      filter(location_id != "LBZEEFSBJNB3Z" | ('2021-09-01' < date & date < '2023-07-01')) %>%
      filter(location_id != "CB2KHY1C2G9PT" | ('2020-06-01' < date & date < '2023-04-01')) %>%
      filter(location_id != "LFZFT3VASXPED" | ('2021-10-01' < date & date < '2022-11-01')) %>%
      filter(location_id != "75WYSXR9QBK5M" | ('2022-05-01' < date & date < '2023-07-01')) %>%
      filter(location_id != "SAFK7ND1HR6XS" | ('2019-04-18' < date & date < '2020-03-25')) %>%

        print_rows() %>%

      # Remove neighborhood columns
      select(-contains("neighborhood")) %>%

      # Add exposure times
      left_join(before_after_details_true %>% 
                  select(location_id, cross_over_date_num),
                by = "location_id") %>%

      # Add centered date as numeric, factor locations
      mutate(location_id = factor(location_id, levels = restaurants_to_model),
             location_id_num = as.integer(factor(location_id, levels = restaurants_to_model)),
             date_num = (as.integer(date) - cross_over_date_num)/365) %>%

      # Arrange by location id
      arrange(location_id_num, date) %>%
      identity()

    # ──────────────────────────────────
    #     2. Select Predictors  
    # ──────────────────────────────────

    # Exposure predictors
    M <- 2 # We have two parameter types: intercept and slope for each exposure
    exposure_predictors <- names(df)[
      startsWith(names(df), "exposure_") &
      sub("^exposure_([a-zA-Z0-9]+)_\\d+$", "\\1", names(df)) %in% restaurants_to_model]
    interaction_predictors <- paste0(exposure_predictors, "_slope")
    all_exposure_predictors <- c(exposure_predictors, interaction_predictors)
    print(paste("Found", length(exposure_predictors), 
                "exposure columns in the data:", 
                paste(exposure_predictors, collapse=", ")))

    # Order matters for index identification later!
    # Intercept + Random Slopes + Fixed Slopes
    formula_str <- paste("~ 1 +",
                         paste(random_predictors, collapse = " + "), "+",
                         paste(fixed_predictors, collapse = " + "), "+",
                         paste(all_exposure_predictors, collapse = " + "))
    formula_var <- as.formula(formula_str)

    # ──────────────────────────────────
    #     3. Process Data
    # ──────────────────────────────────
    # (Train/Test Split, Scaling, Interactions, Matrix Creation, and Stack)
    
    # Identify numeric predictors to be scaled
    outcome_col <- paste0(outcome, "_outcome")
    numeric_predictors <- df %>%
      select(
        where(~ is.numeric(.x) && n_distinct(.x, na.rm = TRUE) > 12),
        -contains("_outcome"),
        -contains("_cat"),
        -contains("_id"),
        -contains("date_num")
        ) %>%
      colnames()

    cat("Numeric columns considered for scaling:\n", 
        paste0(numeric_predictors, collapse = ",\n"), sep="")

    # Processing pipeline
    df_scaled <- df %>%

      # ────────────────────────────
      # For each restaurant
      group_by(location_id_num) %>%

      mutate(
        # Train test split
        train_test = if_else(row_number() <= floor(train_frac * n()), "train", "test"),

        # Standardize
        across(
          .cols = all_of(numeric_predictors), 
          .fns = ~ (.x - mean(.x[train_test == "train"], na.rm = TRUE)) 
          / (sd(.x[train_test == "train"], na.rm = TRUE) + 1e-8)),

      # Add exposure interaction columns (grouping is irrelevant for this)
        across(
          .cols = all_of(exposure_predictors),
          .fns = ~ .x * .data[["date_num"]],
          .names = "{.col}_slope"))

    list_df <- df_scaled %>%

      # ────────────────────────────
      # For each restaurant, for each of train and test
      group_by(location_id_num, train_test) %>%

      # Form into design matrices
      nest() %>% # lists are named data by default
      mutate(
        X_loc = data %>% map(~ model.matrix(formula_var, data = .x)),
        y_loc = data %>% map(~ .x[[outcome_col]]),
        N_loc = data %>% map_int(nrow)) %>%
      select(-data) %>%

      # ────────────────────────────
      # For each of train and test
      group_by(train_test) %>%

      # Concatenate into one long matrix
      summarize(
        X = list(do.call(rbind, X_loc)),
        y = list(list_c(y_loc)),
        N = sum(N_loc),
        end_idx = list(cumsum(N_loc)),
        start_idx = list(c(1, head(cumsum(N_loc), -1) + 1)),
        restaurant_id = list(rep(location_id_num, times = N_loc)),
        .groups = "drop") %>%

      # Separate train and test
      pivot_wider(
        names_from = train_test,
        values_from = c(X, y, N, restaurant_id, 
                        start_idx, 
                        end_idx
                        ),
        names_glue = "{.value}_{train_test}") %>%

      # Ungroup, convert from df to list, and unnest
      ungroup() %>%
      as.list() %>%
      map(~ {if (is.list(.x)) .x[[1]] else .x}) %>%
      identity()

      return(list(df=df, df_scaled=df_scaled, list_df=list_df))
}
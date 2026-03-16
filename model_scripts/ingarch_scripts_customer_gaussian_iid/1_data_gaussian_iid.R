
library(tidyverse)
library(dplyr)
library(arrow)

print_rows <- function(df) {
    df %>% nrow() %>% {paste("# of rows:", .)} %>% print()
    return(df)
}

# ──────────────────────────────────
#           Prepare Data
# ──────────────────────────────────
# Transaction-level Gaussian IID data prep.
# Loads item-level data, aggregates to transaction (order_id) level,
# applies within-customer pre-period demeaning, then builds design matrices.
# No INGARCH lags, no customer indexing for conditional Poisson.

prepare_data_gaussian_iid <- function(
    data_dir,
    outcome,
    restaurants_to_model,
    random_predictors,
    fixed_predictors,
    train_frac,
    include_slopes=TRUE,
    include_gender_interactions=TRUE) {

    # ──────────────────────────────────
    #     1. Load and Prepare Data
    # ──────────────────────────────────

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

    all_restaurants <- c(
        ## Tier 1
        'VLZX7K2M9QD4T', 'SRQS8F7JWA9MZ', '2HRX9P6HKXA8V', 'JHDN7CF1C03X5',
        'L69HYJ4Y3TR91','ED5J990H5VAZT','W8T41JZK0ZMEP',
        ## Tier 2
        'EMBVNVD207CC6',
        'C0BE4NDSW26QN',
        '75WYSXR9QBK5M',
        'V3Q26BHF3SE2H','LBZEEFSBJNB3Z','SAFK7ND1HR6XS','CB2KHY1C2G9PT',
        'S8MT0YGD2KTN9','LFZFT3VASXPED','1SQPTEGYPH0GA','9XKJD8DQTH559',
        'LQ5EH4BKGV61T','78AY09MVJVTYE')

    restaurants_to_remove <- setdiff(all_restaurants, restaurants_to_model)

    outcome_col <- paste0(outcome, "_outcome")

    df_unscaled <- read_parquet(data_dir) %>%
        {if ("breakfast_outcome_p" %in% colnames(.)) rename(., breakfast_p_outcome = breakfast_outcome_p, chicken_p_outcome = chicken_outcome_p, dairy_p_outcome = dairy_outcome_p, egg_p_outcome = egg_outcome_p, textured_p_outcome = textured_outcome_p, untextured_p_outcome = untextured_outcome_p) else .} %>%

        # Relevant rows and cols
        print_rows() %>%
        filter(location_id %in% restaurants_to_model) %>%
        select(-contains("neighborhood")) %>%

        # Remove poor data boundaries
        filter(location_id != "2HRX9P6HKXA8V" | ('2019-01-01' < date & date < '2023-08-01')) %>%
        filter(location_id != "JHDN7CF1C03X5" | (date < '2023-06-01')) %>%
        filter(location_id != "EMBVNVD207CC6" | ('2016-06-01' < date & date < '2022-09-01')) %>%
        filter(location_id != "LBZEEFSBJNB3Z" | ('2021-09-01' < date & date < '2023-07-01')) %>%
        filter(location_id != "CB2KHY1C2G9PT" | ('2020-06-01' < date & date < '2023-04-01')) %>%
        filter(location_id != "LFZFT3VASXPED" | ('2021-10-01' < date & date < '2022-11-01')) %>%
        filter(location_id != "75WYSXR9QBK5M" | ('2022-05-01' < date & date < '2023-07-01')) %>%
        filter(location_id != "SAFK7ND1HR6XS" | ('2019-04-18' < date & date < '2020-03-25')) %>%

        print_rows()

    cat("  Items before transaction aggregation:", nrow(df_unscaled), "\n")

    # ──────────────────────────────────
    #   1a. Aggregate Items to Transactions
    # ──────────────────────────────────
    # Each order_id is one transaction. Sum outcome items per order.
    # Covariates are constant within an order, so take first.

    # Identify columns to keep (non-outcome, non-item-specific)
    covariate_cols <- df_unscaled %>%
        select(
            customer_id, location_id, date, order_id, gender, age,
            starts_with("exposure_"),
            starts_with("date_num_"),
            matches("_price_real$"),
            weekend, holiday_window, month_cat, season, year_cat,
            day_of_week_cat, inflation, temp, precip, date_code
        ) %>% colnames()

    # Remove grouping columns from covariate_cols (they're preserved by group_by)
    covariate_cols <- setdiff(covariate_cols, c("customer_id", "order_id"))

    df_unscaled <- df_unscaled %>%
        group_by(customer_id, order_id) %>%
        summarize(
            outcome_val = sum(.data[[outcome_col]], na.rm = TRUE),
            across(all_of(covariate_cols), first),
            .groups = "drop")

    cat("  Transactions after aggregation:", nrow(df_unscaled), "\n")

    # ──────────────────────────────────
    #   1b. Introductions and Date Processing
    # ──────────────────────────────────

    df_unscaled <- df_unscaled %>%
        left_join(intros_wide, by = "location_id") %>%
        mutate(
            location_id = factor(location_id, levels = restaurants_to_model),
            location_id_num = as.integer(factor(location_id, levels = restaurants_to_model)),
            date_num = as.integer(date),
            across(starts_with("date_num_exposure_"), ~ date_num - .x),
            across(starts_with("date_num"), ~ .x / 365.25)) %>%
        mutate(across(where(is.numeric), ~ replace_na(.x, 0)))

    if (include_slopes) {
        df_unscaled <- df_unscaled %>%
          mutate(across(
              .cols = starts_with("exposure_"),
              .fns = ~ .x * dplyr::pick(cur_column() %>% str_replace("^exposure_", "date_num_exposure_"))[[1]],
              .names = "{.col}_slope"))
    }

    df_unscaled <- df_unscaled %>%
        # Remove irrelevant columns
        select(-matches(paste(restaurants_to_remove, collapse = "|"))) %>%
        select(-matches("^exposure_JHDN7CF1C03X5_2")) %>%
        select(-matches("^exposure_JHDN7CF1C03X5_2_slope")) %>%
        select(-starts_with("date_num_exposure_")) %>%
        identity()

    # ──────────────────────────────────
    #   1c. Filter Customers Pre/Post
    # ──────────────────────────────────
    # Keep customers who have variation in their exposure count — i.e., they have
    # transactions at FEWER active exposures than their maximum. This is more
    # inclusive than requiring "no exposure at all": a customer between exposure_1
    # and exposure_2 has pre-data (exposure_1 only) relative to the later intro.

    exposure_cols <- df_unscaled %>% select(matches(restaurants_to_model %>% paste(collapse='|'))) %>%
        select(starts_with("exposure_"), -contains("slope"), -contains("gendermale")) %>% colnames()

    cat("  Exposure level columns used for pre/post:", paste(exposure_cols, collapse=", "), "\n")

    df_unscaled <- df_unscaled %>%
        mutate(n_exposures_active = rowSums(select(., all_of(exposure_cols)))) %>%
        group_by(customer_id) %>%
        mutate(
            max_exposures = max(n_exposures_active),
            customer_has_pre = any(n_exposures_active < max_exposures),
            customer_has_post = any(n_exposures_active == max_exposures & max_exposures > 0)) %>%
        ungroup()

    n_before <- nrow(df_unscaled)
    df_unscaled <- df_unscaled %>%
        filter(customer_has_pre & customer_has_post) %>%
        select(-customer_has_pre, -customer_has_post) %>%
        print_rows()

    cat("  Transactions after pre/post filter:", nrow(df_unscaled),
        "(removed", n_before - nrow(df_unscaled), ")\n")

    # ──────────────────────────────────
    #   1d. Within-Customer Pre-Period Demeaning
    # ──────────────────────────────────
    # Subtract each customer's PRE-exposure mean outcome from all their transactions.
    # "Pre" = rows where fewer exposures are active than the customer's max.
    # For customers between two intros, pre = period with only the earlier exposure.

    df_unscaled <- df_unscaled %>%
        group_by(customer_id) %>%
        mutate(
            min_exposures = min(n_exposures_active),
            customer_pre_mean = mean(outcome_val[n_exposures_active == min_exposures], na.rm = TRUE),
            outcome_demeaned = outcome_val - customer_pre_mean) %>%
        ungroup() %>%
        select(-n_exposures_active, -max_exposures, -min_exposures)

    cat("  Demeaned outcome range: [",
        round(min(df_unscaled$outcome_demeaned), 3), ", ",
        round(max(df_unscaled$outcome_demeaned), 3), "]\n")
    cat("  Demeaned outcome mean:", round(mean(df_unscaled$outcome_demeaned), 6), "\n")

    # Use demeaned outcome as the outcome column
    df_unscaled[[outcome_col]] <- df_unscaled$outcome_demeaned

    # ──────────────────────────────────
    #   1e. Gender x Exposure Interactions
    # ──────────────────────────────────

    has_gender <- include_gender_interactions &&
                  ("gender" %in% colnames(df_unscaled)) &&
                  sum(!is.na(df_unscaled$gender)) > 0 &&
                  length(unique(na.omit(df_unscaled$gender))) > 1

    gender_interaction_cols <- character(0)

    if (has_gender) {
        is_male <- as.integer(!is.na(df_unscaled$gender) & df_unscaled$gender == "male")

        for (ec in exposure_cols) {
            interaction_col <- paste0(ec, "_gendermale")
            df_unscaled[[interaction_col]] <- df_unscaled[[ec]] * is_male
            gender_interaction_cols <- c(gender_interaction_cols, interaction_col)
        }

        print(paste("Created", length(gender_interaction_cols),
                     "gender x exposure interaction columns:",
                     paste(gender_interaction_cols, collapse = ", ")))
    } else {
        if (include_gender_interactions) {
            print("Gender interactions requested but gender column not found or has insufficient variation. Skipping.")
        }
    }

    # ──────────────────────────────────
    #   1f. Arrange for Restaurant Contiguity
    # ──────────────────────────────────

    df_unscaled <- df_unscaled %>%
        arrange(location_id_num, customer_id, date) %>%
        identity()

    # ──────────────────────────────────
    #     2. Select Predictors
    # ──────────────────────────────────

    # Exposure predictors
    exposure_predictors <- df_unscaled %>% select(matches(restaurants_to_model %>% paste(collapse='|'))) %>% colnames()
    print(paste("Found", length(exposure_predictors),
                "exposure columns in the data:",
                paste(exposure_predictors, collapse=", ")))

    # Order matters for index identification later!
    formula_str <- paste("~ 1 +",
                         paste(random_predictors, collapse = " + "), "+",
                         paste(fixed_predictors, collapse = " + "), "+",
                         paste(exposure_predictors, collapse = " + "))
    formula_var <- as.formula(formula_str)

    # ──────────────────────────────────
    #     3. Process Data
    # ──────────────────────────────────

    numeric_predictors <- df_unscaled %>%
      select(
        where(~ is.numeric(.x) && n_distinct(.x, na.rm = TRUE) > 12),
        -contains("exposure"),
        -contains("_outcome"),
        -contains("_cat"),
        -contains("_id"),
        -contains("date_num"),
        -contains("slope"),
        -contains("count"),
        -contains("prop"),
        -contains("_gendermale"),
        -contains("outcome_val"),
        -contains("outcome_demeaned"),
        -contains("customer_pre_mean")
        ) %>%
      colnames()

    cat("Numeric columns considered for scaling:\n",
        paste0(numeric_predictors, collapse = ",\n"), sep="")

    # Processing pipeline
    df_scaled <- df_unscaled %>%

      # For each restaurant
      group_by(location_id_num) %>%

      mutate(
        # Train test split (chronological within restaurant)
        train_test = if_else(row_number() <= floor(train_frac * n()), "train", "test"),

        # Standardize
        across(
          .cols = all_of(numeric_predictors),
          .fns = ~ (.x - mean(.x[train_test == "train"], na.rm = TRUE))
          / (sd(.x[train_test == "train"], na.rm = TRUE) + 1e-8)))

    matrix_list <- df_scaled %>%

      # For each restaurant, for each of train and test
      group_by(location_id_num, train_test) %>%

      {. %>% print(); .} %>%

      # Form into design matrices
      nest() %>%
      mutate(
        X_loc = data %>% map(~ model.matrix(formula_var, data = .x)),
        y_loc = data %>% map(~ .x[[outcome_col]]),
        N_loc = data %>% map_int(nrow)) %>%
      select(-data) %>%

        {. %>% head() %>% print(); .} %>%

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

    {. %>% head() %>% print(); .} %>%

      # Separate train and test
      pivot_wider(
        names_from = train_test,
        values_from = c(X, y, N, restaurant_id,
                        start_idx,
                        end_idx
                        ),
        names_glue = "{.value}_{train_test}") %>%

      # Ungroup, convert to list
      ungroup() %>%
      as.list() %>%
      map(~ {if (is.list(.x)) .x[[1]] else .x}) %>%
      identity()

    # No customer indexing needed (Gaussian likelihood, not conditional Poisson)

    print(paste("Train: N =", matrix_list$N_train))
    print(paste("Test: N =", matrix_list$N_test))

    # ──────────────────────────────────
    #   4. Predictor Map
    # ──────────────────────────────────

    X_ref <- model.matrix(formula_var, df_unscaled)

    term_labels <- attr(terms(formula_var), "term.labels")
    assign_idx  <- attr(X_ref, "assign")
    term_lookup <- c("(Intercept)", term_labels)
    term_from_assign <- term_lookup[assign_idx + 1]

    predictor_map <- tibble(
        col_index = seq_len(ncol(X_ref)),
        model_col = colnames(X_ref),
        assign    = assign_idx,
        term      = term_from_assign) %>%
      mutate(
        type = case_when(
          grepl("_slope$", model_col)         ~ "slope",
          term == "(Intercept)"               ~ "intercept",
          term %in% random_predictors         ~ "random",
          term %in% fixed_predictors          ~ "fixed",
          term %in% exposure_predictors       ~ "exposure",
          TRUE                                ~ "other")) %>%
      select(model_col, col_index, type, term)

    res <- list(
      df_unscaled=df_unscaled,
      df_scaled=df_scaled,
      matrix_list=matrix_list,
      predictor_map=predictor_map,
      exposure_predictors=exposure_predictors,
      term_from_assign=term_from_assign,
      random_predictors=random_predictors)

    return(res)
}

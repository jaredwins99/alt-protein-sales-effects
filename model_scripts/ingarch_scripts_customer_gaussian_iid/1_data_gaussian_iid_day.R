
library(tidyverse)
library(dplyr)
library(arrow)

print_rows <- function(df) {
    df %>% nrow() %>% {paste("# of rows:", .)} %>% print()
    return(df)
}

step_report <- function(df, label) {
    nloc <- if ("location_id" %in% names(df)) length(unique(df$location_id)) else NA
    cat(sprintf("[day %s] rows=%d cols=%d locations=%s\n",
                label, nrow(df), ncol(df),
                ifelse(is.na(nloc), "-", as.character(nloc))))
    invisible(df)
}

# ──────────────────────────────────
#           Prepare Data
# ──────────────────────────────────
# Day-level Gaussian IID data prep.
# Loads pre-demeaned restaurant-day data (from aggregate_customer_to_restday.R),
# builds design matrices. No transaction aggregation, no demeaning, no customer filtering.

prepare_data_gaussian_iid_day <- function(
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

    # STEP A: Load pre-demeaned restaurant-day parquet
    df_unscaled <- read_parquet(data_dir)
    step_report(df_unscaled, "A. loaded parquet")

    # STEP B: Filter to restaurants_to_model
    df_unscaled <- df_unscaled %>% filter(location_id %in% restaurants_to_model)
    step_report(df_unscaled, sprintf("B. filter to %d target restaurants", length(restaurants_to_model)))

    # STEP C: Re-apply per-restaurant date-window filters (defensive; already in agg)
    df_unscaled <- df_unscaled %>%
        filter(location_id != "2HRX9P6HKXA8V" | ('2019-01-01' < date & date < '2023-08-01')) %>%
        filter(location_id != "JHDN7CF1C03X5" | (date < '2023-06-01')) %>%
        filter(location_id != "EMBVNVD207CC6" | ('2016-06-01' < date & date < '2022-09-01')) %>%
        filter(location_id != "LBZEEFSBJNB3Z" | ('2021-09-01' < date & date < '2023-07-01')) %>%
        filter(location_id != "CB2KHY1C2G9PT" | ('2020-06-01' < date & date < '2023-04-01')) %>%
        filter(location_id != "LFZFT3VASXPED" | ('2021-10-01' < date & date < '2022-11-01')) %>%
        filter(location_id != "75WYSXR9QBK5M" | ('2022-05-01' < date & date < '2023-07-01')) %>%
        filter(location_id != "SAFK7ND1HR6XS" | ('2019-04-18' < date & date < '2020-03-25'))
    step_report(df_unscaled, "C. re-applied date filters")

    # ──────────────────────────────────
    #   1b. Introductions and Date Processing
    # ──────────────────────────────────

    # STEP D: Join intros + compute location_id_num, date_num, exposure deltas
    df_unscaled <- df_unscaled %>%
        left_join(intros_wide, by = "location_id") %>%
        mutate(
            location_id = factor(location_id, levels = restaurants_to_model),
            location_id_num = as.integer(factor(location_id, levels = restaurants_to_model)),
            date_num = as.integer(date),
            across(starts_with("date_num_exposure_"), ~ date_num - .x),
            across(starts_with("date_num"), ~ .x / 365.25)) %>%
        mutate(across(where(is.numeric), ~ replace_na(.x, 0)))
    step_report(df_unscaled, "D. joined intros + date_num/exposure deltas")

    # STEP E: Slope columns (exposure × date_num_exposure)
    if (include_slopes) {
        ncol_before <- ncol(df_unscaled)
        df_unscaled <- df_unscaled %>%
          mutate(across(
              .cols = starts_with("exposure_"),
              .fns = ~ .x * dplyr::pick(cur_column() %>% str_replace("^exposure_", "date_num_exposure_"))[[1]],
              .names = "{.col}_slope"))
        cat(sprintf("[day E. slope cols added] cols %d -> %d (+%d)\n",
                    ncol_before, ncol(df_unscaled), ncol(df_unscaled) - ncol_before))
    }

    # STEP F: Drop irrelevant restaurant exposure cols + date_num_exposure
    ncol_before <- ncol(df_unscaled)
    df_unscaled <- df_unscaled %>%
        select(-matches(paste(restaurants_to_remove, collapse = "|"))) %>%
        select(-matches("^exposure_JHDN7CF1C03X5_2")) %>%
        select(-matches("^exposure_JHDN7CF1C03X5_2_slope")) %>%
        select(-starts_with("date_num_exposure_"))
    cat(sprintf("[day F. drop irrelevant exposure cols + date_num_exposure] cols %d -> %d (-%d)\n",
                ncol_before, ncol(df_unscaled), ncol_before - ncol(df_unscaled)))

    exposure_cols <- df_unscaled %>% select(matches(restaurants_to_model %>% paste(collapse='|'))) %>%
        select(starts_with("exposure_"), -contains("slope"), -contains("gendermale"), -contains("genderfemale")) %>% colnames()
    cat(sprintf("[day G. base exposure_cols (level only)]: %d -> %s\n",
                length(exposure_cols), paste(exposure_cols, collapse=", ")))

    # ──────────────────────────────────
    #   1e. Gender x Exposure Interactions (unknown is reference)
    # ──────────────────────────────────

    has_gender <- "gender" %in% colnames(df_unscaled) &&
                  sum(!is.na(df_unscaled$gender)) > 0 &&
                  length(unique(na.omit(df_unscaled$gender))) > 1

    cat(sprintf("[day H. gender check] has_gender=%s, gender table:\n", has_gender))
    print(table(df_unscaled$gender, useNA = "always"))

    if (has_gender) {
        is_male <- as.integer(!is.na(df_unscaled$gender) & df_unscaled$gender == "male")
        is_female <- as.integer(!is.na(df_unscaled$gender) & df_unscaled$gender == "female")
        ncol_before <- ncol(df_unscaled)
        for (ec in exposure_cols) {
            df_unscaled[[paste0(ec, "_gendermale")]] <- df_unscaled[[ec]] * is_male
            df_unscaled[[paste0(ec, "_genderfemale")]] <- df_unscaled[[ec]] * is_female
        }
        cat(sprintf("[day H. created gender x exposure interactions] cols %d -> %d (+%d)\n",
                    ncol_before, ncol(df_unscaled), ncol(df_unscaled) - ncol_before))
    }

    # ──────────────────────────────────
    #   1f. Arrange for Restaurant Contiguity
    # ──────────────────────────────────

    df_unscaled <- df_unscaled %>%
        arrange(location_id_num, date)
    step_report(df_unscaled, "I. arranged by (location_id_num, date)")

    # ──────────────────────────────────
    #     2. Select Predictors
    # ──────────────────────────────────

    # Exposure predictors
    exposure_predictors <- df_unscaled %>% select(matches(restaurants_to_model %>% paste(collapse='|'))) %>% colnames()
    cat(sprintf("[day J. exposure_predictors (final, incl slopes + gender)]: %d cols\n",
                length(exposure_predictors)))
    cat("    ->", paste(exposure_predictors, collapse=", "), "\n")

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

    cat(sprintf("[day K. numeric predictors selected for scaling]: %d cols\n",
                length(numeric_predictors)))
    cat("    ->", paste(numeric_predictors, collapse=", "), "\n")

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
          / (sd(.x[train_test == "train"], na.rm = TRUE) + 1e-8))) %>%
      ungroup()
    cat(sprintf("[day L. train/test split + scaled] train=%d test=%d total=%d\n",
                sum(df_scaled$train_test == "train"),
                sum(df_scaled$train_test == "test"),
                nrow(df_scaled)))
    df_scaled <- df_scaled %>% group_by(location_id_num)

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

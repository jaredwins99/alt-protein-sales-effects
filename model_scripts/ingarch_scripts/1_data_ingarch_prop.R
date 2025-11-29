
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

prepare_data_prop <- function(
    data_dir, 
    outcome, 
    restaurants_to_model, 
    random_predictors, 
    fixed_predictors,
    train_frac) {

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

    print('it actually went here')
    df_unscaled <- read_parquet(data_dir) %>%

        select(-contains("exposure")) %>%

        # Relevant rows and cols
        print_rows() %>%
        filter(location_id %in% restaurants_to_model) %>%
        select(-contains("neighborhood")) %>%

        # Remove poor data boundaries
        filter(location_id != "2HRX9P6HKXA8V" | ('2019-01-01' < date & date < '2021-05-01')) %>%
        filter(location_id != "JHDN7CF1C03X5" | (date < '2023-06-01')) %>% # '2019-04-01' < date &
        filter(location_id != "EMBVNVD207CC6" | ('2016-06-01' < date & date < '2022-09-01')) %>%
        filter(location_id != "LBZEEFSBJNB3Z" | ('2021-09-01' < date & date < '2023-07-01')) %>%
        filter(location_id != "CB2KHY1C2G9PT" | ('2020-06-01' < date & date < '2023-04-01')) %>%
        filter(location_id != "LFZFT3VASXPED" | ('2021-10-01' < date & date < '2022-11-01')) %>%
        filter(location_id != "75WYSXR9QBK5M" | ('2022-05-01' < date & date < '2023-07-01')) %>%
        filter(location_id != "SAFK7ND1HR6XS" | ('2019-04-18' < date & date < '2020-03-25')) %>%
        print_rows() %>%

        # Introductions
        left_join(intros_wide, by = "location_id") %>%
        mutate(
            location_id = factor(location_id, levels = restaurants_to_model),
            location_id_num = as.integer(factor(location_id, levels = restaurants_to_model)),
            date_num = as.integer(date),
            across(starts_with("date_num_exposure_"), ~ date_num - .x),
            across(starts_with("date_num"), ~ .x / 365.25)) %>%
        mutate(across(where(is.numeric), ~ replace_na(.x, 0))) %>%
        mutate(across(
            .cols = starts_with("exposure_"), 
            .fns = ~ .x * dplyr::pick(cur_column() %>% str_replace("^exposure_", "date_num_exposure_"))[[1]], 
            .names = "{.col}_slope")) %>%
        
        # Remove irrelevant columns
        select(-matches(paste(restaurants_to_remove, collapse = "|"))) %>%
        select(-starts_with("date_num_exposure_")) %>%

        # Arrange
        arrange(location_id_num, date) %>%

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
    # Intercept + Random Slopes + Fixed Slopes
    formula_str <- paste("~ 1 +",
                         paste(random_predictors, collapse = " + "), "+",
                         paste(fixed_predictors, collapse = " + ")#, "+",
                         #paste(exposure_predictors, collapse = " + ")
                         )
    formula_var <- as.formula(formula_str)

    # ──────────────────────────────────
    #     3. Process Data
    # ──────────────────────────────────
    # (Train/Test Split, Scaling, Interactions, Matrix Creation, and Stack)
    
    # Identify numeric predictors to be scaled
    outcome_col <- paste0(outcome, "_outcome")
    numeric_predictors <- df_unscaled %>%
      select(
        where(~ is.numeric(.x) && n_distinct(.x, na.rm = TRUE) > 12),
        -contains("_outcome"),
        -contains("_cat"),
        -contains("_id"),
        -contains("date_num"),
        -contains("slope"),
        -contains("count"),
        -contains("prop")
        ) %>%
      colnames()

    cat("Numeric columns considered for scaling:\n", 
        paste0(numeric_predictors, collapse = ",\n"), sep="")

    # Processing pipeline
    df_scaled <- df_unscaled %>%

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
          / (sd(.x[train_test == "train"], na.rm = TRUE) + 1e-8)))

    matrix_list <- df_scaled %>%

      # ────────────────────────────
      # For each restaurant, for each of train and test
      group_by(location_id_num, train_test) %>%

      {. %>% print(); .} %>%

      # Form into design matrices
      nest() %>% # lists are named data by default
      mutate(
        X_loc = data %>% map(~ model.matrix(formula_var, data = .x)),
        y_loc = data %>% map(~ .x[[outcome_col]]),
        N_loc = data %>% map_int(nrow)) %>%
      select(-data) %>%

        {. %>% head() %>% print(); .} %>%
    

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

    {. %>% head() %>% print(); .} %>%

      # Separate train and test
      pivot_wider(
        names_from = train_test,
        values_from = c(X, y, N, restaurant_id, 
                        start_idx, 
                        end_idx
                        ),
        names_glue = "{.value}_{train_test}") %>%

      # Ungroup, convert from df_unscaled to list, and unnest
      ungroup() %>%
      as.list() %>%
      map(~ {if (is.list(.x)) .x[[1]] else .x}) %>%
      identity()

    mm_cols <- colnames(model.matrix(formula_var, df_unscaled))

    X_ref <- model.matrix(formula_var, df_unscaled)

    term_labels <- attr(terms(formula_var), "term.labels")
    assign_idx  <- attr(X_ref, "assign")
    term_lookup <- c("(Intercept)", term_labels)
    term_from_assign <- term_lookup[assign_idx + 1]

    all_vars <- unique(c(random_predictors, fixed_predictors, exposure_predictors))

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
      term_from_assign=term_from_assign)

    return(res)
}
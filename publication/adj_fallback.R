# CSV-backed fallback for the compute_adjusted_* helpers in the adj forest
# plot scripts. Source this file and the existing read_samples-based path
# gracefully falls through to publication/forest_data_adj_95ci.csv when
# samples.rds isn't present.

.ADJ_CSV_PATH <- "publication/forest_data_adj_95ci.csv"
.ADJ_CACHE <- new.env(parent = emptyenv())

.adj_load <- function() {
  if (!is.null(.ADJ_CACHE$df)) return(.ADJ_CACHE$df)
  if (!file.exists(.ADJ_CSV_PATH)) return(NULL)
  .ADJ_CACHE$df <- read.csv(.ADJ_CSV_PATH, stringsAsFactors = FALSE)
  .ADJ_CACHE$df
}

# Normalize a model_fits path so "foo/bar/baz" matches both full and short.
.adj_match_dir <- function(col, d) {
  d0 <- sub("^\\./", "", d)
  col == d0 | endsWith(col, d0) | endsWith(d0, col)
}

# Pooled: returns list(mean, median, sd, q2.5, q97.5, mean_exp, mean_exp_p10, rhat, ess_bulk)
adj_mu_gamma_from_csv <- function(outcome_path, gamma_index = 1) {
  df <- .adj_load(); if (is.null(df)) return(NULL)
  rows <- df[.adj_match_dir(df$fit_dir, outcome_path) &
             df$level == "pooled" &
             df$gamma_index == gamma_index, , drop = FALSE]
  if (!nrow(rows)) return(NULL)
  r <- rows[1, ]
  list(
    mean         = r$mean,
    median       = r$mean,   # median not stored; fall back to mean
    sd           = NA_real_,
    q2.5         = r$q2.5,
    q97.5        = r$q97.5,
    mean_exp     = r$mean_exp,
    mean_exp_p10 = r$mean_exp_p10,
    rhat         = r$rhat,
    ess_bulk     = r$ess_bulk
  )
}

# Per-restaurant: returns a data.frame with the same columns find_betas-style
# consumers expect (model_col, variable, mean, mean_exp, mean_exp_p10, q2.5,
# q97.5, rhat, ess_bulk). variable is synthesized beta[col_idx, r]-like but
# consumers generally only need model_col/restaurant/quantiles, so ok.
adj_restaurant_gammas_from_csv <- function(outcome_path) {
  df <- .adj_load(); if (is.null(df)) return(NULL)
  rows <- df[.adj_match_dir(df$fit_dir, outcome_path) &
             df$level == "restaurant", , drop = FALSE]
  if (!nrow(rows)) return(NULL)
  # Derive model_col suffix from type_fine (preferred) or gamma_index (fallback)
  # so downstream grepl("_slope$"|"_gendermale$"|"_genderfemale$") classifies
  # rows into the right effect facet.
  tf <- if ("type_fine" %in% colnames(rows)) rows$type_fine else rep(NA_character_, nrow(rows))
  gi <- if ("gamma_index" %in% colnames(rows)) rows$gamma_index else rep(NA_integer_, nrow(rows))
  suffix <- ifelse(!is.na(tf) & tf == "slope",         "_slope",
           ifelse(!is.na(tf) & tf == "gender_male",    "_gendermale",
           ifelse(!is.na(tf) & tf == "gender_female",  "_genderfemale",
           ifelse(!is.na(gi) & gi == 2,                "_slope",
           ifelse(!is.na(gi) & gi == 3,                "_gendermale",
           ifelse(!is.na(gi) & gi == 4,                "_genderfemale", ""))))))
  data.frame(
    model_col    = paste0("exposure_", rows$restaurant, "_1", suffix),
    variable     = NA_character_,
    restaurant_id= rows$restaurant,
    mean         = rows$mean,
    mean_exp     = rows$mean_exp,
    mean_exp_p10 = rows$mean_exp_p10,
    q2.5         = rows$q2.5,
    q97.5        = rows$q97.5,
    rhat         = rows$rhat,
    ess_bulk     = rows$ess_bulk,
    stringsAsFactors = FALSE
  )
}

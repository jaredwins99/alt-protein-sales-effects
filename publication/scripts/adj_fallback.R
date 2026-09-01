# CSV-backed fallback for the compute_adjusted_* helpers in the adj forest
# plot scripts. Source this file and the existing read_samples-based path
# gracefully falls through to publication/forest_data_adj_95ci.csv when
# samples.rds isn't present.

# RETIRED 2026-09-01: moved to archive/superseded_forest_data/. Its restaurant
# rows are largely raw/unadjusted (Bug 1). Only ADJ_FIXED=FALSE reaches it.
.ADJ_CSV_PATH <- "archive/superseded_forest_data/forest_data_adj_95ci.csv"
# Supplementary CSVs override / extend the main file for analyses whose
# adj entries weren't computed for the main extract (e.g., T2 A3/A4
# restaurant-level rows extracted via publication/scripts/append_t2_a3_a4_adj_to_csv.R).
.ADJ_CSV_EXTRAS <- c(
  "archive/superseded_forest_data/forest_data_adj_95ci_t2_a3_a4.csv"
)
.ADJ_CACHE <- new.env(parent = emptyenv())

.ADJ_FIXED <- toupper(Sys.getenv("ADJ_FIXED", "FALSE")) == "TRUE"
.ADJ_FIXED_PATH <- "publication/forest_data_adj_95ci_fixed.csv"

.adj_load <- function() {
  if (!is.null(.ADJ_CACHE$df)) return(.ADJ_CACHE$df)
  # ADJ_FIXED=TRUE: use the corrected extraction (name-based beta join + matched
  # pooled baseline + stored median) produced by adj_join_pass2.R. It fully
  # replaces the main + supplementary CSVs; no merging, so no stale rows leak in.
  if (.ADJ_FIXED) {
    if (!file.exists(.ADJ_FIXED_PATH))
      stop("ADJ_FIXED=TRUE but ", .ADJ_FIXED_PATH, " is missing")
    .ADJ_CACHE$df <- read.csv(.ADJ_FIXED_PATH, stringsAsFactors = FALSE)
    return(.ADJ_CACHE$df)
  }
  if (!file.exists(.ADJ_CSV_PATH)) return(NULL)
  warning("ADJ_FIXED is not TRUE, so adjusted values come from ", .ADJ_CSV_PATH,
              ", which is RETIRED: its restaurant rows are largely raw/",
              "unadjusted. Nothing published uses this path. Set ADJ_FIXED=TRUE ",
              "unless you are deliberately reproducing the old output.",
              call. = FALSE, immediate. = TRUE)
      main <- read.csv(.ADJ_CSV_PATH, stringsAsFactors = FALSE)
  for (extra in .ADJ_CSV_EXTRAS) {
    if (!file.exists(extra)) next
    ex <- read.csv(extra, stringsAsFactors = FALSE)
    keys_extra <- unique(paste(ex$analysis, ex$outcome, sep = "|"))
    main_keys  <- paste(main$analysis, main$outcome, sep = "|")
    main <- main[!main_keys %in% keys_extra, , drop = FALSE]
    main <- rbind(main, ex)
  }
  .ADJ_CACHE$df <- main
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
    median       = if (.ADJ_FIXED && !is.null(r$median)) r$median else r$mean,
    sd           = NA_real_,
    q2.5         = r$q2.5,
    q97.5        = r$q97.5,
    # exact Monte Carlo 68% band when the corrected extraction supplied it
    q16          = if (!is.null(r$q16)) r$q16 else NA_real_,
    q84          = if (!is.null(r$q84)) r$q84 else NA_real_,
    # Override stored mean_exp with exp(mean) — the CSV's mean_exp is
    # mean(exp(diff_draws)) which explodes for heavy-tailed log-ratio
    # posteriors (A2 presence with small-denominator total). exp(mean) is
    # the geometric mean / median of a log-normal and is always finite.
    # ADJ_FIXED: exp(median) is exactly the posterior median RR (medians are
    # equivariant under monotone transforms), and matches the quantile-based CI.
    # Otherwise fall back to exp(mean) = geometric mean, which only equals the
    # median under log-symmetry.
    mean_exp     = if (.ADJ_FIXED && !is.null(r$median)) exp(r$median) else exp(r$mean),
    mean_exp_p10 = if (.ADJ_FIXED && !is.null(r$median)) exp(0.1 * r$median) else exp(0.1 * r$mean),
    rhat         = if (!is.null(r$rhat)) r$rhat else NA_real_,
    ess_bulk     = if (!is.null(r$ess_bulk)) r$ess_bulk else NA_real_
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
    # See pooled-extractor comment: exp(mean) is stable; mean_exp from CSV is not.
    mean_exp     = if (.ADJ_FIXED && !is.null(rows$median)) exp(rows$median) else exp(rows$mean),
    mean_exp_p10 = if (.ADJ_FIXED && !is.null(rows$median)) exp(0.1 * rows$median) else exp(0.1 * rows$mean),
    q2.5         = rows$q2.5,
    q97.5        = rows$q97.5,
    q16          = if (!is.null(rows$q16)) rows$q16 else NA_real_,
    q84          = if (!is.null(rows$q84)) rows$q84 else NA_real_,
    rhat         = if (!is.null(rows$rhat)) rows$rhat else NA_real_,
    ess_bulk     = if (!is.null(rows$ess_bulk)) rows$ess_bulk else NA_real_,
    stringsAsFactors = FALSE
  )
}

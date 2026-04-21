# Fallback loaders for forest plot scripts.
#
# If <fit_dir>/summ.rds (or predictor_map.rds) is missing, synthesize the
# expected data frame from publication/forest_data_95ci.csv, filtered to
# rows whose fit_dir matches `dir`.  Returns a base data.frame shaped like
# what readRDS() of the original file would return.
#
# Sourcing this file defines:
#   read_summ_fallback(dir)
#   read_pmap_fallback(dir)

.FOREST_CSV <- "publication/forest_data_95ci.csv"
.FOREST_CACHE <- new.env(parent = emptyenv())

.load_fallback_csv <- function() {
  if (!is.null(.FOREST_CACHE$df)) return(.FOREST_CACHE$df)
  if (!file.exists(.FOREST_CSV)) return(NULL)
  .FOREST_CACHE$df <- read.csv(.FOREST_CSV, stringsAsFactors = FALSE)
  .FOREST_CACHE$df
}

.col_index_from_var <- function(v) {
  m <- regmatches(v, regexec("\\[([0-9]+)\\]$", v))
  out <- vapply(m, function(x) if (length(x) >= 2) as.integer(x[2]) else NA_integer_,
                integer(1))
  out
}

.type_from_fine <- function(tf) {
  out <- rep("other", length(tf))
  out[tf == "slope"] <- "slope"
  out[tf %in% c("level", "gender_male", "gender_female")] <- "exposure"
  out
}

read_summ_fallback <- function(dir) {
  f <- file.path(dir, "summ.rds")
  if (file.exists(f)) {
    s <- readRDS(f)
    # New-name aliases so downstream scripts can use q2.5 / q97.5 regardless
    # of whether the summ came from default-quantile cmdstanr (q5/q95 = 90% CI)
    # or from a true-95% samples-based run. When only q5/q95 exist we alias
    # them into q2.5/q97.5 as a best-effort (90% interval).
    if (!"q2.5"  %in% colnames(s) && "q5"  %in% colnames(s)) s$q2.5  <- s$q5
    if (!"q97.5" %in% colnames(s) && "q95" %in% colnames(s)) s$q97.5 <- s$q95
    return(s)
  }
  df <- .load_fallback_csv()
  if (is.null(df)) stop("No fits and no CSV fallback (", .FOREST_CSV, ") — cannot load summ for ", dir)
  # match dir either exactly or as suffix after "model_fits/"
  rows <- df[df$fit_dir == dir | endsWith(df$fit_dir, dir), , drop = FALSE]
  if (!nrow(rows)) stop("No fallback rows for ", dir)
  data.frame(
    variable = rows$variable,
    mean     = rows$mean,
    median   = rows$mean,
    sd       = NA_real_,
    q2.5     = rows$q2.5,
    q5       = rows$q2.5,        # backward-compat; real 95% tail
    q95      = rows$q97.5,
    q97.5    = rows$q97.5,
    rhat     = NA_real_,
    ess_bulk = NA_real_,
    ess_tail = NA_real_,
    stringsAsFactors = FALSE
  )
}

read_pmap_fallback <- function(dir) {
  f <- file.path(dir, "predictor_map.rds")
  if (file.exists(f)) return(readRDS(f))
  df <- .load_fallback_csv()
  if (is.null(df)) stop("No fits and no CSV fallback — cannot load predictor_map for ", dir)
  rows <- df[df$fit_dir == dir | endsWith(df$fit_dir, dir), , drop = FALSE]
  rows <- rows[rows$type_fine %in% c("level","slope","gender_male","gender_female"), , drop = FALSE]
  if (!nrow(rows)) stop("No fallback predictor_map rows for ", dir)
  data.frame(
    model_col = rows$model_col,
    col_index = .col_index_from_var(rows$variable),
    type      = .type_from_fine(rows$type_fine),
    term      = rows$model_col,
    stringsAsFactors = FALSE
  )
}

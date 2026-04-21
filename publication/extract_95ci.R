# Walks every fit.rds under model_fits/ and writes a single CSV of
# mean + true 95% CI (q2.5, q97.5) for every forest-plot-relevant parameter.
#
# Required packages: cmdstanr (for fit$summary). Nothing else.
#
# Usage:  Rscript publication/extract_95ci.R [fits_root] [out_csv]
# Defaults: fits_root = model_fits, out_csv = publication/forest_data_95ci.csv

suppressPackageStartupMessages(library(cmdstanr))

args <- commandArgs(trailingOnly = TRUE)
# Default: only the three publication-relevant roots. Pass a single arg to override
# (e.g. `Rscript extract_95ci.R model_fits` to walk everything under model_fits/).
DEFAULT_ROOTS <- c(
  "model_fits/finalized_redone_trunc",
  "model_fits/finalized_redone_trunc_cp",
  "model_fits/finalized_redone_trunc_cp2"
)
FITS_ROOTS <- if (length(args) >= 1) args[1] else DEFAULT_ROOTS
OUT_CSV    <- if (length(args) >= 2) args[2] else "publication/forest_data_95ci.csv"

FITS_ROOTS <- FITS_ROOTS[vapply(FITS_ROOTS, dir.exists, logical(1))]
if (!length(FITS_ROOTS)) stop("No FITS_ROOTS exist.")
dir.create(dirname(OUT_CSV), showWarnings = FALSE, recursive = TRUE)

classify_type <- function(model_col) {
  ifelse(grepl("_genderfemale$", model_col), "gender_female",
    ifelse(grepl("_gendermale$",   model_col), "gender_male",
      ifelse(grepl("_slope$",       model_col), "slope",
        ifelse(grepl("^exposure_",    model_col), "level", "other"))))
}

# Given the fit_dir, determine which transform mu_gamma / gamma / eta should
# get when displayed in forest plots / tables. Mirrors publication/extract_mu_gamma_tables.R.
#   "exp"       → display = exp(x)         (count-style, rate-ratio)
#   "exp_p10"   → display = exp(0.1 * x)   (prop / presence-style)
#   "identity"  → display = x              (A5/A6 customer Gaussian IID)
#   "unknown"   → leave to consumer
classify_transform <- function(fit_dir) {
  d <- tolower(fit_dir)
  # Customer (A5/A6) — identity link
  if (grepl("customer_gaussian_iid|customer_targeted_gaussian_iid", d)) return("identity")
  # ITS / ITS targeted (A3/A4) — exp() on both level and slope
  if (grepl("/its/|/its_targeted/|/t2_its/|/t2_its_targeted/", d)) return("exp")
  # Proportion / proportion-targeted (A1/A2) — depends on leaf (count vs prop/presence)
  if (grepl("/proportion|/t2_proportion", d)) {
    leaf <- basename(d)
    if (grepl("_dishes_count$", leaf)) return("exp")
    if (grepl("_dishes_prop$|_dishes_presence$", leaf)) return("exp_p10")
  }
  "unknown"
}

apply_transform <- function(x, kind) {
  switch(kind,
    "exp"      = exp(x),
    "exp_p10"  = exp(0.1 * x),
    "identity" = x,
    x)  # unknown → identity
}

extract_restaurant <- function(model_col) {
  m <- regmatches(model_col,
                  regexec("^exposure_([^_]+(?:_[^_]+)*)_([0-9]+)(?:_.*)?$",
                          model_col))[[1]]
  if (length(m) >= 3) m[2] else NA_character_
}

# Turn a cmdstanr summary tibble-ish into a base data.frame and pick 95% cols
as_df <- function(s) {
  as.data.frame(s, stringsAsFactors = FALSE)
}

extract_one <- function(fit_dir) {
  fit_file  <- file.path(fit_dir, "fit.rds")
  pmap_file <- file.path(fit_dir, "predictor_map.rds")
  data_file <- file.path(fit_dir, "data_list.rds")
  rest_file <- file.path(fit_dir, "restaurants_order.rds")
  if (!file.exists(fit_file) || !file.exists(pmap_file) || !file.exists(data_file))
    return(NULL)

  fit  <- tryCatch(readRDS(fit_file),  error = function(e) NULL)
  pmap <- tryCatch(readRDS(pmap_file), error = function(e) NULL)
  dl   <- tryCatch(readRDS(data_file), error = function(e) NULL)
  rnames <- if (file.exists(rest_file)) tryCatch(readRDS(rest_file),
                                                 error = function(e) NULL) else NULL
  if (is.null(fit) || is.null(pmap) || is.null(dl)) return(NULL)

  pmap$type_fine <- classify_type(pmap$model_col)

  # Per-restaurant coefficients live in the J x R `beta` matrix at the exposure
  # column rows. idx_exposure[k] gives the column, expo_to_rest[k] the restaurant.
  idx_exp  <- as.integer(dl$idx_exposure)
  expo_r   <- as.integer(dl$expo_to_rest)
  if (!length(idx_exp) || !length(expo_r) || length(idx_exp) != length(expo_r))
    return(NULL)

  beta_names <- sprintf("beta[%d,%d]", idx_exp, expo_r)
  mu_names   <- sprintf("mu_gamma[%d]", seq_len(dl$M))

  summ <- tryCatch(
    as_df(fit$summary(variables = c("mu_gamma", "beta"),
                      "mean", "median", "sd",
                      ~quantile(.x, probs = c(0.025, 0.975)),
                      "rhat", "ess_bulk", "ess_tail")),
    error = function(e) NULL)
  if (is.null(summ)) return(NULL)
  colnames(summ)[match(c("2.5%", "97.5%"), colnames(summ))] <- c("q2.5", "q97.5")
  rownames(summ) <- summ$variable

  tf_kind <- classify_transform(fit_dir)

  mk_row <- function(variable, model_col, type_fine, restaurant,
                     mean, q2.5, q97.5,
                     median, sd, rhat, ess_bulk, ess_tail) {
    data.frame(
      fit_dir    = fit_dir,
      variable   = variable,
      model_col  = model_col,
      type_fine  = type_fine,
      restaurant = restaurant,
      transform  = tf_kind,
      mean = mean, median = median, sd = sd,
      q2.5 = q2.5, q97.5 = q97.5,
      mean_t  = apply_transform(mean,  tf_kind),
      q2.5_t  = apply_transform(q2.5,  tf_kind),
      q97.5_t = apply_transform(q97.5, tf_kind),
      rhat = rhat, ess_bulk = ess_bulk, ess_tail = ess_tail,
      stringsAsFactors = FALSE)
  }

  rows <- list()

  # Per-restaurant exposure coefficients (the "gammas" embedded in beta[j,r])
  pmap_by_idx <- split(pmap, pmap$col_index)
  for (k in seq_along(idx_exp)) {
    j <- idx_exp[k]; r <- expo_r[k]
    vn <- beta_names[k]
    s <- summ[vn, , drop = FALSE]
    if (nrow(s) == 0 || is.na(s$mean[1])) next
    p <- pmap_by_idx[[as.character(j)]]
    model_col <- if (!is.null(p) && nrow(p) > 0) p$model_col[1] else vn
    tf        <- if (!is.null(p) && nrow(p) > 0) p$type_fine[1] else "level"
    rest_name <- if (!is.null(rnames) && r <= length(rnames)) rnames[r] else as.character(r)
    rows[[length(rows) + 1]] <- mk_row(
      variable = vn, model_col = model_col, type_fine = tf,
      restaurant = rest_name,
      mean = s$mean[1], q2.5 = s$q2.5[1], q97.5 = s$q97.5[1],
      median = s$median[1], sd = s$sd[1],
      rhat = s$rhat[1], ess_bulk = s$ess_bulk[1], ess_tail = s$ess_tail[1])
  }

  # Pooled mu_gamma rows
  for (vn in mu_names) {
    s <- summ[vn, , drop = FALSE]
    if (nrow(s) == 0 || is.na(s$mean[1])) next
    rows[[length(rows) + 1]] <- mk_row(
      variable = vn, model_col = vn, type_fine = "pooled_mu_gamma",
      restaurant = NA_character_,
      mean = s$mean[1], q2.5 = s$q2.5[1], q97.5 = s$q97.5[1],
      median = s$median[1], sd = s$sd[1],
      rhat = s$rhat[1], ess_bulk = s$ess_bulk[1], ess_tail = s$ess_tail[1])
  }

  if (length(rows) == 0) return(NULL)
  do.call(rbind, rows)
}

all_dirs <- unlist(lapply(FITS_ROOTS, function(r)
                          list.dirs(r, recursive = TRUE, full.names = TRUE)))
leaves   <- all_dirs[vapply(all_dirs, function(d)
                            file.exists(file.path(d, "fit.rds")), logical(1))]
cat("Walking roots:\n"); cat(paste0("  ", FITS_ROOTS, collapse = "\n"), "\n")
cat("Found", length(leaves), "fit dirs with fit.rds\n")

# Parallelize across fits using base R `parallel` (no extra deps).
N_CORES <- as.integer(Sys.getenv("EXTRACT_CORES", unset = "8"))
N_CORES <- max(1L, min(N_CORES, length(leaves)))
cat("Using", N_CORES, "workers\n")

run_one <- function(d) {
  res <- tryCatch(extract_one(d), error = function(e) NULL)
  if (is.null(res) || !nrow(res)) return(list(dir = d, n = 0L, df = NULL))
  list(dir = d, n = nrow(res), df = res)
}

if (N_CORES > 1L) {
  library(parallel)
  cl <- makeCluster(N_CORES)
  on.exit(stopCluster(cl), add = TRUE)
  clusterEvalQ(cl, suppressPackageStartupMessages(library(cmdstanr)))
  clusterExport(cl, varlist = c(
    "extract_one", "classify_type", "classify_transform",
    "apply_transform", "as_df", "extract_restaurant"),
    envir = environment())
  results <- parLapplyLB(cl, leaves, run_one)
} else {
  results <- lapply(leaves, run_one)
}

all_rows <- list()
for (r in results) {
  if (r$n > 0) {
    all_rows[[length(all_rows) + 1]] <- r$df
    cat("  [ok] ", r$dir, " -> ", r$n, " rows\n", sep = "")
  } else {
    cat("  [skip] ", r$dir, "\n", sep = "")
  }
}

if (!length(all_rows)) { cat("No data extracted.\n"); quit(save = "no", status = 1) }

combined <- do.call(rbind, all_rows)
write.csv(combined, OUT_CSV, row.names = FALSE)
cat("Wrote ", OUT_CSV, " (", nrow(combined), " rows)\n", sep = "")

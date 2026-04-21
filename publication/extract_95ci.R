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
  if (!file.exists(fit_file) || !file.exists(pmap_file)) return(NULL)

  fit  <- tryCatch(readRDS(fit_file),  error = function(e) NULL)
  pmap <- tryCatch(readRDS(pmap_file), error = function(e) NULL)
  if (is.null(fit) || is.null(pmap)) return(NULL)

  # Figure out the Stan parameter prefix the fit uses for the per-restaurant
  # regression coefficients.  Inspect the variable list once and pick one:
  vars <- tryCatch(fit$metadata()$stan_variables, error = function(e) NULL)
  if (is.null(vars)) return(NULL)

  cand <- intersect(c("beta", "gamma", "eta"), vars)
  per_col_var <- if (length(cand)) cand[1] else NA_character_

  # Pull 95% quantiles for mu_gamma (pooled) and per-column betas
  target_vars <- c("mu_gamma")
  if (!is.na(per_col_var)) target_vars <- c(target_vars, per_col_var)
  summ <- tryCatch(
    as_df(fit$summary(variables = target_vars,
                      mean, ~quantile(.x, probs = c(0.025, 0.975)))),
    error = function(e) NULL
  )
  if (is.null(summ)) return(NULL)
  # Columns now: variable, mean, 2.5%, 97.5% — normalize names
  colnames(summ)[match(c("2.5%", "97.5%"), colnames(summ))] <- c("q2.5", "q97.5")

  pmap$type_fine  <- classify_type(pmap$model_col)
  pmap$restaurant <- vapply(pmap$model_col, extract_restaurant, character(1))
  expo_rows <- pmap[pmap$type_fine %in% c("level","slope","gender_male","gender_female"),
                    , drop = FALSE]

  rows <- list()
  tf_kind <- classify_transform(fit_dir)

  mk_row <- function(fit_dir, variable, model_col, type_fine, restaurant,
                     mean, q2.5, q97.5) {
    data.frame(
      fit_dir    = fit_dir,
      variable   = variable,
      model_col  = model_col,
      type_fine  = type_fine,
      restaurant = restaurant,
      transform  = tf_kind,
      mean       = mean,
      q2.5       = q2.5,
      q97.5      = q97.5,
      mean_t     = apply_transform(mean,  tf_kind),
      q2.5_t     = apply_transform(q2.5,  tf_kind),
      q97.5_t    = apply_transform(q97.5, tf_kind),
      stringsAsFactors = FALSE
    )
  }

  # Per-restaurant (beta[k] or gamma[k] etc.)
  if (!is.na(per_col_var) && nrow(expo_rows) > 0) {
    for (i in seq_len(nrow(expo_rows))) {
      var_name  <- sprintf("%s[%d]", per_col_var, expo_rows$col_index[i])
      match_row <- summ[summ$variable == var_name, , drop = FALSE]
      if (nrow(match_row) == 0) next
      rows[[length(rows) + 1]] <- mk_row(
        fit_dir    = fit_dir,
        variable   = var_name,
        model_col  = expo_rows$model_col[i],
        type_fine  = expo_rows$type_fine[i],
        restaurant = expo_rows$restaurant[i],
        mean = match_row$mean[1], q2.5 = match_row$q2.5[1], q97.5 = match_row$q97.5[1])
    }
  }

  # Pooled mu_gamma rows
  mu_rows <- summ[grepl("^mu_gamma\\[", summ$variable), , drop = FALSE]
  for (i in seq_len(nrow(mu_rows))) {
    rows[[length(rows) + 1]] <- mk_row(
      fit_dir    = fit_dir,
      variable   = mu_rows$variable[i],
      model_col  = mu_rows$variable[i],
      type_fine  = "pooled_mu_gamma",
      restaurant = NA_character_,
      mean = mu_rows$mean[i], q2.5 = mu_rows$q2.5[i], q97.5 = mu_rows$q97.5[i])
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

all_rows <- list()
for (d in leaves) {
  res <- extract_one(d)
  if (!is.null(res) && nrow(res) > 0) {
    all_rows[[length(all_rows) + 1]] <- res
    cat("  [ok] ", d, " -> ", nrow(res), " rows\n", sep = "")
  } else {
    cat("  [skip] ", d, "\n", sep = "")
  }
}

if (!length(all_rows)) { cat("No data extracted.\n"); quit(save = "no", status = 1) }

combined <- do.call(rbind, all_rows)
write.csv(combined, OUT_CSV, row.names = FALSE)
cat("Wrote ", OUT_CSV, " (", nrow(combined), " rows)\n", sep = "")

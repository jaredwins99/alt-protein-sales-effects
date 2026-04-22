# Extract forest-plot-ready data from every Stan fit directory.
#
# Walks model_fits/<directory>/<analysis>/<outcome>[/<exposure>]/,
# loads summ.rds + predictor_map.rds + (if present) restaurants_order.rds,
# joins them, and writes:
#   - <dir>/forest_data.csv     per-model tidy rows (one row per gamma param)
#   - publication/forest_data_all.csv   concatenated across every model
#
# Minimal deps: base R only. No dplyr, no tidyr, no ggplot.
# If a fit dir is incomplete (missing summ.rds or predictor_map.rds) it is skipped.

args <- commandArgs(trailingOnly = TRUE)
FITS_ROOT <- if (length(args) >= 1) args[1] else "model_fits"
OUT_CSV   <- if (length(args) >= 2) args[2] else "publication/forest_data_all.csv"

stopifnot(dir.exists(FITS_ROOT))
dir.create(dirname(OUT_CSV), showWarnings = FALSE, recursive = TRUE)

# ── Helpers ────────────────────────────────────────────────
classify_type <- function(model_col) {
  ifelse(grepl("_genderfemale$", model_col), "gender_female",
    ifelse(grepl("_gendermale$",   model_col), "gender_male",
      ifelse(grepl("_slope$",       model_col), "slope",
        ifelse(grepl("^exposure_",    model_col), "level", "other"))))
}

extract_restaurant <- function(model_col) {
  # exposure_<REST_ID>_<k>[<suffix>]
  m <- regmatches(model_col,
                  regexec("^exposure_([^_]+(?:_[^_]+)*)_([0-9]+)(?:_.*)?$",
                          model_col))[[1]]
  if (length(m) >= 3) m[2] else NA_character_
}

extract_one <- function(fit_dir) {
  summ_file <- file.path(fit_dir, "summ.rds")
  pmap_file <- file.path(fit_dir, "predictor_map.rds")
  if (!file.exists(summ_file) || !file.exists(pmap_file)) return(NULL)

  summ <- tryCatch(readRDS(summ_file), error = function(e) NULL)
  pmap <- tryCatch(readRDS(pmap_file), error = function(e) NULL)
  if (is.null(summ) || is.null(pmap)) return(NULL)

  # summ columns expected: variable, mean, median, sd, q5, q95, rhat, ess_bulk, ess_tail
  # (older fits may have q2.5/q97.5 — harmonize by taking whichever exists)
  if (!"q2.5"  %in% colnames(summ) && "q5"  %in% colnames(summ)) summ$q2.5  <- summ$q5
  if (!"q97.5" %in% colnames(summ) && "q95" %in% colnames(summ)) summ$q97.5 <- summ$q95

  # ── per-restaurant gamma rows (gamma[j,m]) ─────────────
  # pmap: col_index, model_col, type, term
  pmap$type_fine <- classify_type(pmap$model_col)
  pmap$restaurant <- vapply(pmap$model_col, extract_restaurant, character(1))
  expo_rows <- pmap[pmap$type_fine %in% c("level","slope","gender_male","gender_female"), , drop=FALSE]

  # Build gamma variable names matching stan output. Two common conventions:
  # (a) "gamma[j,m]" with j = restaurant index, m = param-type index (1=level, 2=slope, ...)
  # (b) "beta[k]" with k = overall column index
  # We look up by model_col -> col_index, then pull beta[col_index].
  rows <- list()
  for (i in seq_len(nrow(expo_rows))) {
    col_index  <- expo_rows$col_index[i]
    model_col  <- expo_rows$model_col[i]
    type_fine  <- expo_rows$type_fine[i]
    restaurant <- expo_rows$restaurant[i]
    var_name   <- paste0("beta[", col_index, "]")
    match_row  <- summ[summ$variable == var_name, , drop = FALSE]
    if (nrow(match_row) == 0) next
    rows[[length(rows) + 1]] <- data.frame(
      fit_dir    = fit_dir,
      model_col  = model_col,
      type_fine  = type_fine,
      restaurant = restaurant,
      variable   = var_name,
      mean       = match_row$mean[1],
      q2.5       = match_row$q2.5[1],
      q97.5      = match_row$q97.5[1],
      rhat       = match_row$rhat[1],
      ess_bulk   = match_row$ess_bulk[1],
      stringsAsFactors = FALSE
    )
  }

  # ── pooled mu_gamma rows ───────────────────────────────
  mu_gamma_idx <- grep("^mu_gamma\\[", summ$variable)
  for (idx in mu_gamma_idx) {
    rows[[length(rows) + 1]] <- data.frame(
      fit_dir    = fit_dir,
      model_col  = summ$variable[idx],
      type_fine  = "pooled_mu_gamma",
      restaurant = NA_character_,
      variable   = summ$variable[idx],
      mean       = summ$mean[idx],
      q2.5       = summ$q2.5[idx],
      q97.5      = summ$q97.5[idx],
      rhat       = summ$rhat[idx],
      ess_bulk   = summ$ess_bulk[idx],
      stringsAsFactors = FALSE
    )
  }

  if (length(rows) == 0) return(NULL)
  out <- do.call(rbind, rows)

  # Per-model CSV next to the fit
  write.csv(out, file.path(fit_dir, "forest_data.csv"), row.names = FALSE)
  out
}

# ── Walk every leaf dir under FITS_ROOT ───────────────────
all_dirs <- list.dirs(FITS_ROOT, recursive = TRUE, full.names = TRUE)
is_leaf  <- function(d) file.exists(file.path(d, "summ.rds"))
leaves   <- all_dirs[vapply(all_dirs, is_leaf, logical(1))]

cat("Found", length(leaves), "fit dirs with summ.rds\n")
all_rows <- list()
for (d in leaves) {
  res <- extract_one(d)
  if (!is.null(res)) {
    all_rows[[length(all_rows) + 1]] <- res
    cat("  [ok] ", d, "  -> ", nrow(res), " rows\n", sep="")
  } else {
    cat("  [skip] ", d, "\n", sep="")
  }
}

if (length(all_rows) == 0) {
  cat("No data extracted.\n")
  quit(save = "no", status = 1)
}

combined <- do.call(rbind, all_rows)
write.csv(combined, OUT_CSV, row.names = FALSE)
cat("Wrote combined CSV: ", OUT_CSV, " (", nrow(combined), " rows)\n", sep="")

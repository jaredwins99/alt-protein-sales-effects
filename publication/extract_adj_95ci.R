# Walks every fit.rds under model_fits/ (default the 3 trunc roots),
# pairs each outcome against its corresponding "total" fit within the same
# (root, analysis) group, and writes per-draw-computed adjusted 95% CIs to
# publication/forest_data_adj_95ci.csv.
#
# Columns: fit_dir, total_dir, analysis, outcome, gamma_index, level
#          (pooled / restaurant), restaurant, mean, q2.5, q97.5,
#          mean_exp, mean_exp_p10, rhat, ess_bulk, ess_tail
#
# Required packages: cmdstanr only.  Run on the machine that has all fits.

suppressPackageStartupMessages(library(cmdstanr))
suppressPackageStartupMessages(library(parallel))

args <- commandArgs(trailingOnly = TRUE)
FITS_ROOT <- if (length(args) >= 1) args[1] else "model_fits"
OUT_CSV   <- if (length(args) >= 2) args[2] else "publication/forest_data_adj_95ci.csv"
CORES     <- as.integer(Sys.getenv("EXTRACT_CORES", 8))

stopifnot(dir.exists(FITS_ROOT))
dir.create(dirname(OUT_CSV), showWarnings = FALSE, recursive = TRUE)

.ROOTS <- c("finalized_redone_trunc",
            "finalized_redone_trunc_cp",
            "finalized_redone_trunc_cp2")

# Find every leaf dir with fit.rds under each accepted root.
list_fit_dirs <- function(root = FITS_ROOT) {
  out <- c()
  for (r in .ROOTS) {
    base <- file.path(root, r)
    if (!dir.exists(base)) next
    ds <- list.dirs(base, recursive = TRUE, full.names = TRUE)
    out <- c(out, ds[vapply(ds, function(d) file.exists(file.path(d, "fit.rds")),
                            logical(1))])
  }
  out
}

# Decompose "model_fits/<root>/<analysis>/<outcome>[/<exposure>]" into parts.
parse_fit_path <- function(d) {
  parts <- strsplit(sub("^model_fits/", "", d), "/", fixed = TRUE)[[1]]
  if (length(parts) < 3) return(NULL)
  list(root = parts[1], analysis = parts[2],
       outcome = parts[3],
       exposure = if (length(parts) >= 4) parts[4] else NA_character_,
       tail_key = paste(parts[2], parts[3:length(parts)][-1], sep = "/"))
}

# Group fits by (root, analysis) and pair each non-total outcome with the
# total outcome's fit at the matching exposure sub-path.
pair_fits <- function(dirs) {
  meta <- lapply(dirs, parse_fit_path)
  df <- data.frame(
    dir      = dirs,
    root     = vapply(meta, function(x) if (is.null(x)) NA_character_ else x$root, character(1)),
    analysis = vapply(meta, function(x) if (is.null(x)) NA_character_ else x$analysis, character(1)),
    outcome  = vapply(meta, function(x) if (is.null(x)) NA_character_ else x$outcome, character(1)),
    exposure = vapply(meta, function(x) if (is.null(x)) NA_character_ else x$exposure, character(1)),
    stringsAsFactors = FALSE
  )
  pairs <- list()
  # Root preference: prefer totals in _cp2, then _cp, then _trunc.  This lets
  # outcomes in older roots (e.g. T2 vegan in _trunc) still pair with a total
  # that lives in a newer root (_cp).
  root_rank <- c("finalized_redone_trunc_cp2" = 1,
                 "finalized_redone_trunc_cp"  = 2,
                 "finalized_redone_trunc"     = 3)
  for (i in seq_len(nrow(df))) {
    if (is.na(df$outcome[i]) || df$outcome[i] == "total") next
    cand <- which(
      df$analysis == df$analysis[i] &
      df$outcome == "total" &
      (is.na(df$exposure) & is.na(df$exposure[i]) |
       df$exposure == df$exposure[i]))
    if (length(cand) == 0) next
    # pick the total in the highest-ranked root available
    cand_ranks <- root_rank[df$root[cand]]
    cand_ranks[is.na(cand_ranks)] <- 99
    best <- cand[which.min(cand_ranks)]
    pairs[[length(pairs) + 1]] <- list(
      outcome_dir = df$dir[i],
      total_dir   = df$dir[best],
      analysis    = df$analysis[i],
      outcome     = df$outcome[i],
      exposure    = df$exposure[i])
  }
  pairs
}

safe_load_fit <- function(fit_dir) {
  f <- file.path(fit_dir, "fit.rds")
  tryCatch(readRDS(f), error = function(e) NULL)
}

safe_summ_row <- function(fit_dir, var) {
  s_f <- file.path(fit_dir, "summ.rds")
  if (!file.exists(s_f)) return(list(rhat = NA_real_, ess_bulk = NA_real_, ess_tail = NA_real_))
  s <- readRDS(s_f)
  r <- s[s$variable == var, , drop = FALSE]
  if (!nrow(r)) return(list(rhat = NA_real_, ess_bulk = NA_real_, ess_tail = NA_real_))
  list(rhat = r$rhat[1], ess_bulk = r$ess_bulk[1], ess_tail = r$ess_tail[1])
}

extract_one_pair <- function(pair) {
  fit_o <- safe_load_fit(pair$outcome_dir); if (is.null(fit_o)) return(NULL)
  fit_t <- safe_load_fit(pair$total_dir);   if (is.null(fit_t)) return(NULL)

  vars <- tryCatch(fit_o$metadata()$stan_variables, error = function(e) NULL)
  if (is.null(vars) || !"mu_gamma" %in% vars) return(NULL)

  # Pooled mu_gamma draws — all M entries
  draws_o <- as.matrix(fit_o$draws("mu_gamma", format = "draws_matrix"))
  draws_t <- as.matrix(fit_t$draws("mu_gamma", format = "draws_matrix"))
  n <- min(nrow(draws_o), nrow(draws_t))
  common <- intersect(colnames(draws_o), colnames(draws_t))

  rows <- list()
  for (v in common) {
    d <- draws_o[seq_len(n), v] - draws_t[seq_len(n), v]
    summ <- safe_summ_row(pair$outcome_dir, v)
    idx <- as.integer(sub("mu_gamma\\[(\\d+)\\]", "\\1", v))
    rows[[length(rows) + 1]] <- data.frame(
      fit_dir      = pair$outcome_dir,
      total_dir    = pair$total_dir,
      analysis     = pair$analysis,
      outcome      = pair$outcome,
      gamma_index  = idx,
      level        = "pooled",
      restaurant   = NA_character_,
      mean         = mean(d, na.rm = TRUE),
      q2.5         = unname(quantile(d, 0.025, na.rm = TRUE)),
      q97.5        = unname(quantile(d, 0.975, na.rm = TRUE)),
      mean_exp     = mean(exp(d), na.rm = TRUE),
      mean_exp_p10 = mean(exp(0.1 * d), na.rm = TRUE),
      rhat         = summ$rhat,
      ess_bulk     = summ$ess_bulk,
      ess_tail     = summ$ess_tail,
      stringsAsFactors = FALSE)
  }

  # Per-restaurant beta diffs
  data_list_o <- tryCatch(readRDS(file.path(pair$outcome_dir, "data_list.rds")),
                          error = function(e) NULL)
  data_list_t <- tryCatch(readRDS(file.path(pair$total_dir,   "data_list.rds")),
                          error = function(e) NULL)
  pmap_o      <- tryCatch(readRDS(file.path(pair$outcome_dir, "predictor_map.rds")),
                          error = function(e) NULL)
  rests_o     <- tryCatch(readRDS(file.path(pair$outcome_dir, "restaurants_order.rds")),
                          error = function(e) NULL)

  if (!is.null(data_list_o) && !is.null(data_list_t) && !is.null(pmap_o) &&
      "beta" %in% vars) {
    beta_draws_o <- as.matrix(fit_o$draws("beta", format = "draws_matrix"))
    beta_draws_t <- as.matrix(fit_t$draws("beta", format = "draws_matrix"))
    nb <- min(nrow(beta_draws_o), nrow(beta_draws_t))
    for (k in seq_along(data_list_o$idx_exposure)) {
      col_idx <- data_list_o$idx_exposure[k]
      r_idx   <- data_list_o$expo_to_rest[k]
      vn      <- sprintf("beta[%d,%d]", col_idx, r_idx)
      if (!(vn %in% colnames(beta_draws_o)) || !(vn %in% colnames(beta_draws_t))) next
      d <- beta_draws_o[seq_len(nb), vn] - beta_draws_t[seq_len(nb), vn]
      summ <- safe_summ_row(pair$outcome_dir, vn)
      mcol <- pmap_o$model_col[pmap_o$col_index == col_idx][1]
      rest <- if (!is.null(rests_o) && r_idx <= length(rests_o)) rests_o[r_idx] else NA_character_
      rows[[length(rows) + 1]] <- data.frame(
        fit_dir      = pair$outcome_dir,
        total_dir    = pair$total_dir,
        analysis     = pair$analysis,
        outcome      = pair$outcome,
        gamma_index  = NA_integer_,
        level        = "restaurant",
        restaurant   = rest,
        mean         = mean(d, na.rm = TRUE),
        q2.5         = unname(quantile(d, 0.025, na.rm = TRUE)),
        q97.5        = unname(quantile(d, 0.975, na.rm = TRUE)),
        mean_exp     = mean(exp(d), na.rm = TRUE),
        mean_exp_p10 = mean(exp(0.1 * d), na.rm = TRUE),
        rhat         = summ$rhat,
        ess_bulk     = summ$ess_bulk,
        ess_tail     = summ$ess_tail,
        stringsAsFactors = FALSE)
    }
  }
  if (!length(rows)) return(NULL)
  do.call(rbind, rows)
}

pairs <- pair_fits(list_fit_dirs(FITS_ROOT))
cat("Found", length(pairs), "(outcome, total) fit pairs\n")
if (!length(pairs)) quit(save = "no", status = 1)

cl <- makeCluster(min(CORES, length(pairs)))
clusterEvalQ(cl, suppressPackageStartupMessages(library(cmdstanr)))
clusterExport(cl, c("extract_one_pair", "safe_load_fit", "safe_summ_row"))
results <- parLapply(cl, pairs, function(p) {
  tryCatch(extract_one_pair(p), error = function(e) { message(e$message); NULL })
})
stopCluster(cl)

results <- Filter(Negate(is.null), results)
if (!length(results)) { cat("No adjusted rows extracted.\n"); quit(save = "no", status = 1) }

combined <- do.call(rbind, results)
write.csv(combined, OUT_CSV, row.names = FALSE)
cat("Wrote", OUT_CSV, "with", nrow(combined), "rows\n")

# Targeted, append-only: extract adj 95% CIs for customer_gaussian_iid_day
# (T1 A5 day) and t2_customer_gaussian_iid_day (T2 A5 day) ONLY, and append
# to publication/forest_data_adj_95ci.csv without re-extracting proportion /
# its / t2_proportion.
#
# Required packages: cmdstanr only.

suppressPackageStartupMessages(library(cmdstanr))
suppressPackageStartupMessages(library(parallel))

args <- commandArgs(trailingOnly = TRUE)
FITS_ROOT <- if (length(args) >= 1) args[1] else "model_fits"
OUT_CSV   <- if (length(args) >= 2) args[2] else "publication/forest_data_adj_95ci.csv"
CORES     <- as.integer(Sys.getenv("EXTRACT_CORES", 8))

# Analyses to extract. Each maps to the analysis whose `total` is the
# subtraction target. A5 analyses use their own internal total. A6 (targeted)
# analyses have no internal total, so they pair against the matching A5 total.
TARGET_ANALYSES <- c(
  "customer_gaussian_iid_day",
  "t2_customer_gaussian_iid_day",
  "customer_targeted_gaussian_iid_day",
  "t2_customer_targeted_gaussian_iid_day"
)
TOTAL_ANALYSIS <- c(
  "customer_gaussian_iid_day"              = "customer_gaussian_iid_day",
  "t2_customer_gaussian_iid_day"           = "t2_customer_gaussian_iid_day",
  "customer_targeted_gaussian_iid_day"     = "customer_gaussian_iid_day",
  "t2_customer_targeted_gaussian_iid_day"  = "t2_customer_gaussian_iid_day"
)

.ROOTS    <- c("finalized_redone_trunc_cp2",
               "finalized_redone_trunc")
.ROOT_RANK <- setNames(seq_along(.ROOTS), .ROOTS)

find_outcome_dirs <- function(analysis) {
  out <- c()
  for (r in .ROOTS) {
    base <- file.path(FITS_ROOT, r, analysis)
    if (!dir.exists(base)) next
    for (o in list.files(base, full.names = TRUE)) {
      if (file.exists(file.path(o, "fit.rds"))) out <- c(out, o)
    }
  }
  out
}

# For a given analysis + outcome, pick the highest-rank root that has it
pick_best <- function(cands) {
  if (!length(cands)) return(NA_character_)
  roots <- vapply(cands, function(p) {
    parts <- strsplit(p, "/", fixed = TRUE)[[1]]
    idx <- which(parts %in% names(.ROOT_RANK))
    if (!length(idx)) NA_character_ else parts[idx[1]]
  }, character(1))
  ranks <- .ROOT_RANK[roots]; ranks[is.na(ranks)] <- 99L
  cands[which.min(ranks)]
}

safe_summ_row <- function(fit_dir, var) {
  s_f <- file.path(fit_dir, "summ.rds")
  if (!file.exists(s_f)) return(list(rhat = NA_real_, ess_bulk = NA_real_, ess_tail = NA_real_))
  s <- readRDS(s_f)
  r <- s[s$variable == var, , drop = FALSE]
  if (!nrow(r)) return(list(rhat = NA_real_, ess_bulk = NA_real_, ess_tail = NA_real_))
  list(rhat = r$rhat[1], ess_bulk = r$ess_bulk[1], ess_tail = r$ess_tail[1])
}

extract_for_outcome <- function(outcome_dir, total_dir, analysis, same_analysis = TRUE) {
  outcome <- basename(outcome_dir)
  fit_o <- tryCatch(readRDS(file.path(outcome_dir, "fit.rds")), error = function(e) NULL)
  fit_t <- tryCatch(readRDS(file.path(total_dir,   "fit.rds")), error = function(e) NULL)
  if (is.null(fit_o) || is.null(fit_t)) return(NULL)

  vars <- tryCatch(fit_o$metadata()$stan_variables, error = function(e) NULL)
  if (is.null(vars) || !"mu_gamma" %in% vars) return(NULL)

  draws_o <- as.matrix(fit_o$draws("mu_gamma", format = "draws_matrix"))
  draws_t <- as.matrix(fit_t$draws("mu_gamma", format = "draws_matrix"))
  n <- min(nrow(draws_o), nrow(draws_t))
  common <- intersect(colnames(draws_o), colnames(draws_t))

  pooled_type_fine <- function(i) switch(as.character(i),
    "1" = "level", "2" = "slope", "3" = "gender_male", "4" = "gender_female",
    NA_character_)

  rows <- list()
  for (v in common) {
    d <- draws_o[seq_len(n), v] - draws_t[seq_len(n), v]
    summ <- safe_summ_row(outcome_dir, v)
    idx <- as.integer(sub("mu_gamma\\[(\\d+)\\]", "\\1", v))
    rows[[length(rows) + 1]] <- data.frame(
      fit_dir = outcome_dir, total_dir = total_dir, analysis = analysis,
      outcome = outcome, gamma_index = idx, level = "pooled",
      restaurant = NA_character_, type_fine = pooled_type_fine(idx),
      mean = mean(d, na.rm = TRUE),
      q2.5 = unname(quantile(d, 0.025, na.rm = TRUE)),
      q97.5 = unname(quantile(d, 0.975, na.rm = TRUE)),
      mean_exp     = mean(exp(d), na.rm = TRUE),
      mean_exp_p10 = mean(exp(0.1 * d), na.rm = TRUE),
      rhat = summ$rhat, ess_bulk = summ$ess_bulk, ess_tail = summ$ess_tail,
      stringsAsFactors = FALSE)
  }

  # Per-restaurant beta diffs
  dl_o <- tryCatch(readRDS(file.path(outcome_dir, "data_list.rds")), error = function(e) NULL)
  pmap_o <- tryCatch(readRDS(file.path(outcome_dir, "predictor_map.rds")), error = function(e) NULL)
  rests_o <- tryCatch(readRDS(file.path(outcome_dir, "restaurants_order.rds")), error = function(e) NULL)
  if (same_analysis && !is.null(dl_o) && !is.null(pmap_o) && "beta" %in% vars) {
    bd_o <- as.matrix(fit_o$draws("beta", format = "draws_matrix"))
    bd_t <- as.matrix(fit_t$draws("beta", format = "draws_matrix"))
    nb <- min(nrow(bd_o), nrow(bd_t))
    for (k in seq_along(dl_o$idx_exposure)) {
      col_idx <- dl_o$idx_exposure[k]
      r_idx   <- dl_o$expo_to_rest[k]
      vn      <- sprintf("beta[%d,%d]", col_idx, r_idx)
      if (!(vn %in% colnames(bd_o)) || !(vn %in% colnames(bd_t))) next
      d <- bd_o[seq_len(nb), vn] - bd_t[seq_len(nb), vn]
      summ <- safe_summ_row(outcome_dir, vn)
      mcol <- pmap_o$model_col[pmap_o$col_index == col_idx][1]
      rest <- if (!is.null(rests_o) && r_idx <= length(rests_o)) rests_o[r_idx] else NA_character_
      tf <- if (grepl("_gendermale$", mcol)) "gender_male"
            else if (grepl("_genderfemale$", mcol)) "gender_female"
            else if (grepl("_slope$", mcol)) "slope"
            else "level"
      rows[[length(rows) + 1]] <- data.frame(
        fit_dir = outcome_dir, total_dir = total_dir, analysis = analysis,
        outcome = outcome, gamma_index = NA_integer_, level = "restaurant",
        restaurant = rest, type_fine = tf,
        mean = mean(d, na.rm = TRUE),
        q2.5 = unname(quantile(d, 0.025, na.rm = TRUE)),
        q97.5 = unname(quantile(d, 0.975, na.rm = TRUE)),
        mean_exp     = mean(exp(d), na.rm = TRUE),
        mean_exp_p10 = mean(exp(0.1 * d), na.rm = TRUE),
        rhat = summ$rhat, ess_bulk = summ$ess_bulk, ess_tail = summ$ess_tail,
        stringsAsFactors = FALSE)
    }
  }
  if (!length(rows)) return(NULL)
  do.call(rbind, rows)
}

all_new_rows <- list()
for (analysis in TARGET_ANALYSES) {
  total_analysis <- TOTAL_ANALYSIS[[analysis]]
  same_analysis  <- identical(analysis, total_analysis)
  cat("Analysis: ", analysis, " (total from: ", total_analysis, ")\n", sep = "")
  # Outcomes come from `analysis`; total comes from `total_analysis` (may be same).
  outcome_map <- list()
  for (r in .ROOTS) {
    base <- file.path(FITS_ROOT, r, analysis)
    if (!dir.exists(base)) next
    for (o in list.files(base, full.names = TRUE)) {
      if (!file.exists(file.path(o, "fit.rds"))) next
      outcome <- basename(o)
      if (same_analysis && outcome == "total") next  # skip self-pairing
      outcome_map[[outcome]] <- c(outcome_map[[outcome]], o)
    }
  }
  total_cands <- c()
  for (r in .ROOTS) {
    tdir <- file.path(FITS_ROOT, r, total_analysis, "total")
    if (file.exists(file.path(tdir, "fit.rds"))) total_cands <- c(total_cands, tdir)
  }
  total_dir <- pick_best(total_cands)
  if (is.na(total_dir)) {
    cat("  no total fit found (looked in ", total_analysis, "); skipping\n", sep = ""); next
  }
  cat("  total -> ", total_dir, "\n", sep = "")

  pairs <- lapply(names(outcome_map), function(o)
    list(outcome_dir = pick_best(outcome_map[[o]]),
         total_dir = total_dir, analysis = analysis,
         same_analysis = same_analysis))

  if (CORES <= 1) {
    res <- lapply(pairs, function(p) {
      cat("  ", basename(p$outcome_dir), "\n", sep = "")
      tryCatch(extract_for_outcome(p$outcome_dir, p$total_dir, p$analysis, p$same_analysis),
               error = function(e) { message(e$message); NULL })
    })
  } else {
    cl <- makeCluster(min(CORES, max(1, length(pairs))))
    clusterEvalQ(cl, suppressPackageStartupMessages(library(cmdstanr)))
    clusterExport(cl, c("extract_for_outcome", "safe_summ_row"), envir = environment())
    res <- parLapply(cl, pairs, function(p)
      tryCatch(extract_for_outcome(p$outcome_dir, p$total_dir, p$analysis, p$same_analysis),
               error = function(e) { message(e$message); NULL }))
    stopCluster(cl)
  }
  res <- Filter(Negate(is.null), res)
  if (length(res)) all_new_rows <- c(all_new_rows, res)
  cat("  rows this analysis: ", sum(vapply(res, nrow, integer(1))), "\n", sep = "")
}

if (!length(all_new_rows)) { cat("Nothing to append.\n"); quit(save = "no", status = 0) }
new_df <- do.call(rbind, all_new_rows)

if (file.exists(OUT_CSV)) {
  existing <- read.csv(OUT_CSV, stringsAsFactors = FALSE)
  existing <- existing[!(existing$analysis %in% TARGET_ANALYSES), , drop = FALSE]
  # Ensure existing has a type_fine column so bind_rows aligns.
  if (!"type_fine" %in% colnames(existing)) existing$type_fine <- NA_character_
  all_cols <- union(colnames(existing), colnames(new_df))
  for (c in setdiff(all_cols, colnames(existing))) existing[[c]] <- NA
  for (c in setdiff(all_cols, colnames(new_df)))  new_df[[c]]   <- NA
  combined <- rbind(existing[, all_cols], new_df[, all_cols])
} else {
  combined <- new_df
}

write.csv(combined, OUT_CSV, row.names = FALSE)
cat("Appended ", nrow(new_df), " rows; total now ", nrow(combined), "\n", sep = "")

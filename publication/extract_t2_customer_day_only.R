# Append-only: non-adj + adj 95% CIs for T2 A5 + A6 day-level customer fits
# (t2_a5_customer_day, t2_a6_customer_t_day).
# Only these two analyses are touched in the CSVs.
#
# Required package: cmdstanr only.

suppressPackageStartupMessages(library(cmdstanr))

FITS_ROOT   <- "model_fits"
NON_ADJ_CSV <- "publication/forest_data_95ci.csv"
ADJ_CSV     <- "publication/forest_data_adj_95ci.csv"
ANALYSES    <- c("t2_a5_customer_day",
                 "t2_a6_customer_t_day")
ROOTS       <- c("finalized_redone_trunc_cp",
                 "finalized_redone_trunc")

classify_transform <- function(d) "identity"
apply_transform <- function(x, kind) x

safe_summ_row <- function(fit_dir, var) {
  f <- file.path(fit_dir, "summ.rds")
  if (!file.exists(f)) return(list(rhat = NA_real_, ess_bulk = NA_real_, ess_tail = NA_real_))
  s <- readRDS(f)
  r <- s[s$variable == var, , drop = FALSE]
  if (!nrow(r)) return(list(rhat = NA_real_, ess_bulk = NA_real_, ess_tail = NA_real_))
  list(rhat = r$rhat[1], ess_bulk = r$ess_bulk[1], ess_tail = r$ess_tail[1])
}

# Find leaf dirs per (analysis, outcome), pref cp2 > cp > trunc
find_outcome_dirs <- function(analysis) {
  out <- list()
  for (r in ROOTS) {
    base <- file.path(FITS_ROOT, r, analysis)
    if (!dir.exists(base)) next
    for (o in list.files(base, full.names = TRUE)) {
      if (!file.exists(file.path(o, "fit.rds"))) next
      nm <- basename(o)
      if (is.null(out[[nm]])) out[[nm]] <- o   # first hit wins (highest-rank root)
    }
  }
  out
}

# ─────────────────────────────────────────────
# Non-adj rows (one fit at a time)
# ─────────────────────────────────────────────
nonadj_new <- list()
# Collect outcome_dirs for BOTH adj pairing and non-adj extraction
analysis_map <- setNames(lapply(ANALYSES, find_outcome_dirs), ANALYSES)

for (analysis in ANALYSES) {
  for (outcome in names(analysis_map[[analysis]])) {
    fit_dir <- analysis_map[[analysis]][[outcome]]
    cat("Non-adj: ", fit_dir, "\n", sep = "")
    fit <- tryCatch(readRDS(file.path(fit_dir, "fit.rds")), error = function(e) NULL)
    if (is.null(fit)) next
    pmap  <- tryCatch(readRDS(file.path(fit_dir, "predictor_map.rds")), error = function(e) NULL)
    dl    <- tryCatch(readRDS(file.path(fit_dir, "data_list.rds")),     error = function(e) NULL)
    rests <- tryCatch(readRDS(file.path(fit_dir, "restaurants_order.rds")), error = function(e) NULL)
    tf    <- "identity"

    draws_mu   <- tryCatch(as.matrix(fit$draws("mu_gamma", format = "draws_matrix")),
                           error = function(e) { message("  mu_gamma draws error: ", conditionMessage(e)); NULL })
    draws_beta <- tryCatch(as.matrix(fit$draws("beta",     format = "draws_matrix")),
                           error = function(e) { message("  beta draws error: ", conditionMessage(e)); NULL })
    if (is.null(draws_mu) || is.null(draws_beta)) { cat("  skipping ", fit_dir, " — draws failed\n", sep=""); next }

    mk <- function(var, mcol, tfine, rest, vec) {
      data.frame(
        fit_dir = fit_dir, variable = var, model_col = mcol,
        type_fine = tfine, restaurant = rest, transform = tf,
        mean = mean(vec), median = median(vec), sd = sd(vec),
        q2.5 = unname(quantile(vec, 0.025)), q97.5 = unname(quantile(vec, 0.975)),
        mean_t = mean(vec),
        q2.5_t = unname(quantile(vec, 0.025)),
        q97.5_t = unname(quantile(vec, 0.975)),
        rhat = safe_summ_row(fit_dir, var)$rhat,
        ess_bulk = safe_summ_row(fit_dir, var)$ess_bulk,
        ess_tail = safe_summ_row(fit_dir, var)$ess_tail,
        stringsAsFactors = FALSE)
    }
    for (v in colnames(draws_mu))
      nonadj_new[[length(nonadj_new) + 1]] <- mk(v, "pooled_mu_gamma", "pooled_mu_gamma", NA_character_, draws_mu[, v])
    if (!is.null(dl$idx_exposure) && !is.null(pmap)) {
      for (k in seq_along(dl$idx_exposure)) {
        col_idx <- dl$idx_exposure[k]; r_idx <- dl$expo_to_rest[k]
        vn <- sprintf("beta[%d,%d]", col_idx, r_idx)
        if (!(vn %in% colnames(draws_beta))) next
        mcol <- pmap$model_col[pmap$col_index == col_idx][1]
        rest <- if (!is.null(rests) && r_idx <= length(rests)) rests[r_idx] else NA_character_
        tfine <- if (grepl("_genderfemale$", mcol)) "gender_female"
                 else if (grepl("_gendermale$", mcol)) "gender_male"
                 else if (grepl("_slope$", mcol)) "slope"
                 else "level"
        nonadj_new[[length(nonadj_new) + 1]] <- mk(vn, mcol, tfine, rest, draws_beta[, vn])
      }
    }
    rm(fit, draws_mu, draws_beta); gc(verbose = FALSE)
  }
}

# ─────────────────────────────────────────────
# Adj rows (each non-total outcome vs "total" within the same analysis)
# ─────────────────────────────────────────────
adj_new <- list()
for (analysis in ANALYSES) {
  outs <- analysis_map[[analysis]]
  if (is.null(outs$total)) { cat("Adj skip (no total): ", analysis, "\n"); next }
  total_dir <- outs$total
  cat("Adj pairing against: ", total_dir, "\n", sep = "")
  fit_t <- readRDS(file.path(total_dir, "fit.rds"))
  draws_t_mu   <- as.matrix(fit_t$draws("mu_gamma", format = "draws_matrix"))
  draws_t_beta <- as.matrix(fit_t$draws("beta",     format = "draws_matrix"))

  for (o in setdiff(names(outs), "total")) {
    outcome_dir <- outs[[o]]
    cat("  ", o, " @ ", outcome_dir, "\n", sep = "")
    fit_o <- readRDS(file.path(outcome_dir, "fit.rds"))
    draws_o_mu   <- as.matrix(fit_o$draws("mu_gamma", format = "draws_matrix"))
    draws_o_beta <- as.matrix(fit_o$draws("beta",     format = "draws_matrix"))

    n <- min(nrow(draws_o_mu), nrow(draws_t_mu))
    common <- intersect(colnames(draws_o_mu), colnames(draws_t_mu))
    for (v in common) {
      d <- draws_o_mu[seq_len(n), v] - draws_t_mu[seq_len(n), v]
      idx <- as.integer(sub("mu_gamma\\[(\\d+)\\]", "\\1", v))
      summ <- safe_summ_row(outcome_dir, v)
      adj_new[[length(adj_new) + 1]] <- data.frame(
        fit_dir = outcome_dir, total_dir = total_dir, analysis = analysis,
        outcome = o, gamma_index = idx, level = "pooled", restaurant = NA_character_,
        mean = mean(d),
        q2.5 = unname(quantile(d, 0.025)),
        q97.5 = unname(quantile(d, 0.975)),
        mean_exp = mean(exp(d)),
        mean_exp_p10 = mean(exp(0.1 * d)),
        rhat = summ$rhat, ess_bulk = summ$ess_bulk, ess_tail = summ$ess_tail,
        stringsAsFactors = FALSE)
    }

    dl_o    <- tryCatch(readRDS(file.path(outcome_dir, "data_list.rds")), error = function(e) NULL)
    pmap_o  <- tryCatch(readRDS(file.path(outcome_dir, "predictor_map.rds")), error = function(e) NULL)
    rests_o <- tryCatch(readRDS(file.path(outcome_dir, "restaurants_order.rds")), error = function(e) NULL)
    if (!is.null(dl_o) && !is.null(pmap_o)) {
      nb <- min(nrow(draws_o_beta), nrow(draws_t_beta))
      for (k in seq_along(dl_o$idx_exposure)) {
        col_idx <- dl_o$idx_exposure[k]; r_idx <- dl_o$expo_to_rest[k]
        vn <- sprintf("beta[%d,%d]", col_idx, r_idx)
        if (!(vn %in% colnames(draws_o_beta)) || !(vn %in% colnames(draws_t_beta))) next
        d <- draws_o_beta[seq_len(nb), vn] - draws_t_beta[seq_len(nb), vn]
        mcol <- pmap_o$model_col[pmap_o$col_index == col_idx][1]
        rest <- if (!is.null(rests_o) && r_idx <= length(rests_o)) rests_o[r_idx] else NA_character_
        summ <- safe_summ_row(outcome_dir, vn)
        adj_new[[length(adj_new) + 1]] <- data.frame(
          fit_dir = outcome_dir, total_dir = total_dir, analysis = analysis,
          outcome = o, gamma_index = NA_integer_, level = "restaurant", restaurant = rest,
          mean = mean(d),
          q2.5 = unname(quantile(d, 0.025)),
          q97.5 = unname(quantile(d, 0.975)),
          mean_exp = mean(exp(d)),
          mean_exp_p10 = mean(exp(0.1 * d)),
          rhat = summ$rhat, ess_bulk = summ$ess_bulk, ess_tail = summ$ess_tail,
          stringsAsFactors = FALSE)
      }
    }
    rm(fit_o, draws_o_mu, draws_o_beta); gc(verbose = FALSE)
  }
  rm(fit_t, draws_t_mu, draws_t_beta); gc(verbose = FALSE)
}

# ─────────────────────────────────────────────
# Merge into CSVs (replace only rows from these analyses)
# ─────────────────────────────────────────────
if (length(nonadj_new)) {
  new_df <- do.call(rbind, nonadj_new)
  if (file.exists(NON_ADJ_CSV)) {
    existing <- read.csv(NON_ADJ_CSV, stringsAsFactors = FALSE)
    # Only drop rows for the exact fit_dirs we are re-extracting
    existing <- existing[!(existing$fit_dir %in% unique(new_df$fit_dir)), , drop = FALSE]
    combined <- rbind(existing, new_df[, colnames(existing), drop = FALSE])
  } else combined <- new_df
  write.csv(combined, NON_ADJ_CSV, row.names = FALSE)
  cat("non-adj: +", nrow(new_df), " rows; total now ", nrow(combined), "\n", sep = "")
}

if (length(adj_new)) {
  new_df <- do.call(rbind, adj_new)
  if (file.exists(ADJ_CSV)) {
    existing <- read.csv(ADJ_CSV, stringsAsFactors = FALSE)
    # Only drop rows for the exact (fit_dir, total_dir) pairs we are re-extracting
    keys_new <- paste(new_df$fit_dir, new_df$total_dir)
    keys_exist <- paste(existing$fit_dir, existing$total_dir)
    existing <- existing[!(keys_exist %in% keys_new), , drop = FALSE]
    combined <- rbind(existing, new_df[, colnames(existing), drop = FALSE])
  } else combined <- new_df
  write.csv(combined, ADJ_CSV, row.names = FALSE)
  cat("adj: +", nrow(new_df), " rows; total now ", nrow(combined), "\n", sep = "")
}

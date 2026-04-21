# Append-only: re-extract non-adj + adj CSV rows for just the 2 A1 T2
# proportion reruns (total/vegan_dishes_prop and total/vegetarian_dishes_count)
# plus the 10 non-total pairings that depend on the new totals.
#
#   non-adj updates: the 2 total fits themselves (pooled + per-restaurant)
#   adj updates:     for each of the 2 exposure leafs, re-pair the 5 non-total
#                    outcomes against the fresh total fit.
#
# Required package: cmdstanr only.

suppressPackageStartupMessages(library(cmdstanr))

FITS_ROOT <- "model_fits"
NON_ADJ_CSV <- "publication/forest_data_95ci.csv"
ADJ_CSV     <- "publication/forest_data_adj_95ci.csv"

ROOT      <- "finalized_redone_trunc_cp"
EXPOSURES <- c("vegan_dishes_prop", "vegetarian_dishes_count")
OUTCOMES  <- c("chicken_fish", "meat", "nonvegan", "vegan", "vegetarian", "total")

classify_transform <- function(exposure) {
  if (grepl("_prop$", exposure))  "exp_p10"
  else if (grepl("_count$", exposure)) "exp"
  else "unknown"
}
apply_transform <- function(x, kind)
  switch(kind, "exp" = exp(x), "exp_p10" = exp(0.1 * x), "identity" = x, x)

safe_summ_row <- function(fit_dir, var) {
  f <- file.path(fit_dir, "summ.rds")
  if (!file.exists(f)) return(list(rhat = NA_real_, ess_bulk = NA_real_, ess_tail = NA_real_))
  s <- readRDS(f)
  r <- s[s$variable == var, , drop = FALSE]
  if (!nrow(r)) return(list(rhat = NA_real_, ess_bulk = NA_real_, ess_tail = NA_real_))
  list(rhat = r$rhat[1], ess_bulk = r$ess_bulk[1], ess_tail = r$ess_tail[1])
}

# ──────────────────────────────────────────────
# 1. Non-adj rows for the 2 TOTAL fits themselves
# ──────────────────────────────────────────────
nonadj_new <- list()
for (expo in EXPOSURES) {
  fit_dir <- file.path(FITS_ROOT, ROOT, "t2_proportion", "total", expo)
  fit_file <- file.path(fit_dir, "fit.rds")
  if (!file.exists(fit_file)) {
    cat("  skip (no fit.rds): ", fit_dir, "\n", sep = ""); next
  }
  cat("Non-adj: ", fit_dir, "\n", sep = "")
  fit  <- readRDS(fit_file)
  pmap <- tryCatch(readRDS(file.path(fit_dir, "predictor_map.rds")), error = function(e) NULL)
  dl   <- tryCatch(readRDS(file.path(fit_dir, "data_list.rds")),     error = function(e) NULL)
  rests<- tryCatch(readRDS(file.path(fit_dir, "restaurants_order.rds")), error = function(e) NULL)
  tf   <- classify_transform(expo)

  draws_mu   <- as.matrix(fit$draws("mu_gamma", format = "draws_matrix"))
  draws_beta <- as.matrix(fit$draws("beta",     format = "draws_matrix"))

  add_row <- function(var, mcol, tfine, rest, vec) {
    data.frame(
      fit_dir = fit_dir, variable = var, model_col = mcol,
      type_fine = tfine, restaurant = rest, transform = tf,
      mean = mean(vec), median = median(vec), sd = sd(vec),
      q2.5 = unname(quantile(vec, 0.025)), q97.5 = unname(quantile(vec, 0.975)),
      mean_t = apply_transform(mean(vec), tf),
      q2.5_t = apply_transform(unname(quantile(vec, 0.025)), tf),
      q97.5_t = apply_transform(unname(quantile(vec, 0.975)), tf),
      rhat = safe_summ_row(fit_dir, var)$rhat,
      ess_bulk = safe_summ_row(fit_dir, var)$ess_bulk,
      ess_tail = safe_summ_row(fit_dir, var)$ess_tail,
      stringsAsFactors = FALSE)
  }

  for (v in colnames(draws_mu))
    nonadj_new[[length(nonadj_new) + 1]] <-
      add_row(v, "pooled_mu_gamma", "pooled_mu_gamma", NA_character_, draws_mu[, v])

  if (!is.null(dl$idx_exposure) && !is.null(pmap)) {
    for (k in seq_along(dl$idx_exposure)) {
      col_idx <- dl$idx_exposure[k]; r_idx <- dl$expo_to_rest[k]
      vn <- sprintf("beta[%d,%d]", col_idx, r_idx)
      if (!(vn %in% colnames(draws_beta))) next
      mcol <- pmap$model_col[pmap$col_index == col_idx][1]
      rest <- if (!is.null(rests) && r_idx <= length(rests)) rests[r_idx] else NA_character_
      tfine <- if (grepl("_slope$", mcol)) "slope" else "level"
      nonadj_new[[length(nonadj_new) + 1]] <- add_row(vn, mcol, tfine, rest, draws_beta[, vn])
    }
  }
  rm(fit, draws_mu, draws_beta); gc(verbose = FALSE)
}

# ──────────────────────────────────────────────
# 2. Adj rows: re-pair 5 non-total outcomes against new totals
# ──────────────────────────────────────────────
adj_new <- list()
non_totals <- setdiff(OUTCOMES, "total")
for (expo in EXPOSURES) {
  total_dir <- file.path(FITS_ROOT, ROOT, "t2_proportion", "total", expo)
  if (!file.exists(file.path(total_dir, "fit.rds"))) next
  cat("Adj: pairing against ", total_dir, "\n", sep = "")
  fit_t <- readRDS(file.path(total_dir, "fit.rds"))
  draws_t_mu   <- as.matrix(fit_t$draws("mu_gamma", format = "draws_matrix"))
  draws_t_beta <- as.matrix(fit_t$draws("beta",     format = "draws_matrix"))

  for (o in non_totals) {
    outcome_dir <- file.path(FITS_ROOT, ROOT, "t2_proportion", o, expo)
    if (!file.exists(file.path(outcome_dir, "fit.rds"))) {
      cat("  skip (no fit): ", outcome_dir, "\n", sep = ""); next
    }
    cat("  outcome: ", o, "\n", sep = "")
    fit_o <- readRDS(file.path(outcome_dir, "fit.rds"))
    draws_o_mu   <- as.matrix(fit_o$draws("mu_gamma", format = "draws_matrix"))
    draws_o_beta <- as.matrix(fit_o$draws("beta",     format = "draws_matrix"))

    # Pooled mu_gamma diffs
    n <- min(nrow(draws_o_mu), nrow(draws_t_mu))
    common <- intersect(colnames(draws_o_mu), colnames(draws_t_mu))
    for (v in common) {
      d <- draws_o_mu[seq_len(n), v] - draws_t_mu[seq_len(n), v]
      idx <- as.integer(sub("mu_gamma\\[(\\d+)\\]", "\\1", v))
      summ <- safe_summ_row(outcome_dir, v)
      adj_new[[length(adj_new) + 1]] <- data.frame(
        fit_dir = outcome_dir, total_dir = total_dir,
        analysis = "t2_proportion", outcome = o,
        gamma_index = idx, level = "pooled", restaurant = NA_character_,
        mean = mean(d),
        q2.5 = unname(quantile(d, 0.025)),
        q97.5 = unname(quantile(d, 0.975)),
        mean_exp = mean(exp(d)),
        mean_exp_p10 = mean(exp(0.1 * d)),
        rhat = summ$rhat, ess_bulk = summ$ess_bulk, ess_tail = summ$ess_tail,
        stringsAsFactors = FALSE)
    }

    # Per-restaurant beta diffs (via outcome's idx_exposure + expo_to_rest)
    dl_o   <- tryCatch(readRDS(file.path(outcome_dir, "data_list.rds")), error = function(e) NULL)
    pmap_o <- tryCatch(readRDS(file.path(outcome_dir, "predictor_map.rds")), error = function(e) NULL)
    rests_o<- tryCatch(readRDS(file.path(outcome_dir, "restaurants_order.rds")), error = function(e) NULL)
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
          fit_dir = outcome_dir, total_dir = total_dir,
          analysis = "t2_proportion", outcome = o,
          gamma_index = NA_integer_, level = "restaurant", restaurant = rest,
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

# ──────────────────────────────────────────────
# 3. Merge into existing CSVs (replace only affected rows)
# ──────────────────────────────────────────────
if (length(nonadj_new)) {
  new_df <- do.call(rbind, nonadj_new)
  if (file.exists(NON_ADJ_CSV)) {
    existing <- read.csv(NON_ADJ_CSV, stringsAsFactors = FALSE)
    affected <- paste(FITS_ROOT, ROOT, "t2_proportion/total", EXPOSURES, sep = "/")
    existing <- existing[!(existing$fit_dir %in% affected), , drop = FALSE]
    combined <- rbind(existing, new_df[, colnames(existing), drop = FALSE])
  } else { combined <- new_df }
  write.csv(combined, NON_ADJ_CSV, row.names = FALSE)
  cat("non-adj: +", nrow(new_df), " rows; total now ", nrow(combined), "\n", sep = "")
}

if (length(adj_new)) {
  new_df <- do.call(rbind, adj_new)
  if (file.exists(ADJ_CSV)) {
    existing <- read.csv(ADJ_CSV, stringsAsFactors = FALSE)
    # drop prior adj rows for the 5 outcomes × 2 exposures
    affected <- unlist(lapply(non_totals, function(o)
      paste(FITS_ROOT, ROOT, "t2_proportion", o, EXPOSURES, sep = "/")))
    existing <- existing[!(existing$fit_dir %in% affected), , drop = FALSE]
    combined <- rbind(existing, new_df[, colnames(existing), drop = FALSE])
  } else { combined <- new_df }
  write.csv(combined, ADJ_CSV, row.names = FALSE)
  cat("adj: +", nrow(new_df), " rows; total now ", nrow(combined), "\n", sep = "")
}

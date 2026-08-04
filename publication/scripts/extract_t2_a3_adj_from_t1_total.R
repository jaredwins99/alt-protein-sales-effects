# Temporary: until T2 A3 ITS total finishes, compute T2 A3 adjusted quantities
# by subtracting the T1 ITS total mu_gamma draws per MCMC iteration.
#
#   diff_draws = T2_outcome_draws - T1_total_draws
#
# Output rows get appended to publication/forest_data_adj_95ci.csv with
# analysis="t2_a3_its" and total_dir pointing at the T1 total fit so the
# provenance is obvious.
#
# Required package: cmdstanr only.

suppressPackageStartupMessages(library(cmdstanr))

args <- commandArgs(trailingOnly = TRUE)
FITS_ROOT <- if (length(args) >= 1) args[1] else "model_fits"
OUT_CSV   <- if (length(args) >= 2) args[2] else "publication/forest_data_adj_95ci.csv"

# Candidate roots (prefer cp2 > cp > trunc for the outcome fit)
.ROOTS <- c("finalized_redone_trunc_cp",
            "finalized_redone_trunc")

# T1 ITS total can live in any root; prefer cp2 > cp > trunc.
find_t1_total <- function() {
  for (r in .ROOTS) {
    p <- file.path(FITS_ROOT, r, "a3_its", "total")
    if (file.exists(file.path(p, "fit.rds"))) return(p)
  }
  NA_character_
}
T1_TOTAL <- find_t1_total()
if (is.na(T1_TOTAL)) {
  stop("T1 ITS total fit.rds not found under any of: ",
       paste(file.path(FITS_ROOT, .ROOTS, "a3_its", "total"), collapse = ", "))
}
cat("T1 total fit: ", T1_TOTAL, "\n")

# Find the best outcome fit for an (analysis, outcome) pair
find_outcome <- function(analysis, outcome) {
  for (r in .ROOTS) {
    p <- file.path(FITS_ROOT, r, analysis, outcome)
    if (file.exists(file.path(p, "fit.rds"))) return(p)
  }
  NA_character_
}

# Stand-in targets: both T2 A3 (meat/nonvegan/etc.) AND T2 A4 (breakfast_t2/etc.)
# pair against the T1 A3 total (since no T2 A3 total fit exists).
TARGETS <- list(
  list(analysis = "t2_a3_its",  outcomes = c("meat","nonvegan","chicken_fish","vegan","vegetarian")),
  list(analysis = "t2_a4_its_t", outcomes = c("breakfast_t2","dairy_t2","textured_t2","untextured_t2"))  # chicken_t2 retired: zero outcome
)

fit_t <- readRDS(file.path(T1_TOTAL, "fit.rds"))
draws_t <- as.matrix(fit_t$draws("mu_gamma", format = "draws_matrix"))
bd_t <- tryCatch(as.matrix(fit_t$draws("beta", format = "draws_matrix")),
                 error = function(e) NULL)
pmap_t  <- tryCatch(readRDS(file.path(T1_TOTAL, "predictor_map.rds")),   error = function(e) NULL)
rests_t <- tryCatch(readRDS(file.path(T1_TOTAL, "restaurants_order.rds")),error = function(e) NULL)

rows <- list()
for (tgt in TARGETS) {
  analysis <- tgt$analysis; outcomes <- tgt$outcomes
  outcome_paths <- vapply(outcomes, function(o) find_outcome(analysis, o), character(1))
  cat("\n", analysis, " outcome fits:\n", sep = "")
  for (j in seq_along(outcomes))
    cat("  ", outcomes[j], " -> ", outcome_paths[j], "\n", sep = "")
  outcome_paths <- outcome_paths[!is.na(outcome_paths)]
  outcomes      <- names(outcome_paths)
for (i in seq_along(outcomes)) {
  op <- outcome_paths[i]
  cat("Processing ", analysis, "/", outcomes[i], " @ ", op, "\n", sep = "")
  fit_o <- readRDS(file.path(op, "fit.rds"))
  draws_o <- as.matrix(fit_o$draws("mu_gamma", format = "draws_matrix"))

  common <- intersect(colnames(draws_o), colnames(draws_t))
  n <- min(nrow(draws_o), nrow(draws_t))

  for (v in common) {
    d <- draws_o[seq_len(n), v] - draws_t[seq_len(n), v]
    idx <- as.integer(sub("mu_gamma\\[(\\d+)\\]", "\\1", v))

    summ_o_f <- file.path(op, "summ.rds")
    rhat_v <- ess_b <- ess_t <- NA_real_
    if (file.exists(summ_o_f)) {
      s <- readRDS(summ_o_f)
      srow <- s[s$variable == v, , drop = FALSE]
      if (nrow(srow)) { rhat_v <- srow$rhat[1]; ess_b <- srow$ess_bulk[1]; ess_t <- srow$ess_tail[1] }
    }

    tf <- switch(as.character(idx),
      "1" = "level", "2" = "slope",
      "3" = "gender_male", "4" = "gender_female",
      NA_character_)
    rows[[length(rows) + 1]] <- data.frame(
      fit_dir      = op,
      total_dir    = T1_TOTAL,           # provenance: T1 total as stand-in
      analysis     = analysis,
      outcome      = outcomes[i],
      gamma_index  = idx,
      level        = "pooled",
      restaurant   = NA_character_,
      type_fine    = tf,
      mean         = mean(d, na.rm = TRUE),
      q2.5         = unname(quantile(d, 0.025, na.rm = TRUE)),
      q97.5        = unname(quantile(d, 0.975, na.rm = TRUE)),
      mean_exp     = mean(exp(d), na.rm = TRUE),
      mean_exp_p10 = mean(exp(0.1 * d), na.rm = TRUE),
      rhat         = rhat_v,
      ess_bulk     = ess_b,
      ess_tail     = ess_t,
      stringsAsFactors = FALSE)
  }

  # Per-restaurant beta diffs (T2 outcome beta - T1 total beta) for RESTAURANTS
  # that exist in BOTH fits. Match by model_col name.
  bd_o <- tryCatch(as.matrix(fit_o$draws("beta", format = "draws_matrix")),
                   error = function(e) NULL)
  pmap_o  <- tryCatch(readRDS(file.path(op, "predictor_map.rds")),   error = function(e) NULL)
  dl_o    <- tryCatch(readRDS(file.path(op, "data_list.rds")),      error = function(e) NULL)
  rests_o <- tryCatch(readRDS(file.path(op, "restaurants_order.rds")), error = function(e) NULL)
  if (!is.null(bd_o) && !is.null(bd_t) && !is.null(pmap_o) && !is.null(pmap_t) &&
      !is.null(dl_o) && !is.null(rests_o) && !is.null(rests_t)) {
    nb <- min(nrow(bd_o), nrow(bd_t))
    for (k in seq_along(dl_o$idx_exposure)) {
      col_idx_o <- dl_o$idx_exposure[k]
      r_idx_o   <- dl_o$expo_to_rest[k]
      vn_o      <- sprintf("beta[%d,%d]", col_idx_o, r_idx_o)
      if (!(vn_o %in% colnames(bd_o))) next
      mcol <- pmap_o$model_col[pmap_o$col_index == col_idx_o][1]
      rest <- if (r_idx_o <= length(rests_o)) rests_o[r_idx_o] else NA_character_
      # Match by model_col in T1 total's predictor_map
      row_t <- pmap_t[pmap_t$model_col == mcol, , drop = FALSE]
      if (!nrow(row_t) || is.na(rest)) next
      col_idx_t <- row_t$col_index[1]
      r_idx_t <- match(rest, rests_t)
      if (is.na(r_idx_t)) next
      vn_t <- sprintf("beta[%d,%d]", col_idx_t, r_idx_t)
      if (!(vn_t %in% colnames(bd_t))) next
      db <- bd_o[seq_len(nb), vn_o] - bd_t[seq_len(nb), vn_t]
      # classify
      tf_r <- if (grepl("_gendermale$", mcol)) "gender_male"
              else if (grepl("_genderfemale$", mcol)) "gender_female"
              else if (grepl("_slope$", mcol)) "slope"
              else "level"
      summ_r <- if (file.exists(summ_o_f)) {
        s2 <- readRDS(summ_o_f); sr <- s2[s2$variable == vn_o, , drop = FALSE]
        if (nrow(sr)) list(rhat = sr$rhat[1], ess_bulk = sr$ess_bulk[1], ess_tail = sr$ess_tail[1])
        else list(rhat = NA_real_, ess_bulk = NA_real_, ess_tail = NA_real_)
      } else list(rhat = NA_real_, ess_bulk = NA_real_, ess_tail = NA_real_)
      rows[[length(rows) + 1]] <- data.frame(
        fit_dir      = op,
        total_dir    = T1_TOTAL,
        analysis     = analysis,
        outcome      = outcomes[i],
        gamma_index  = NA_integer_,
        level        = "restaurant",
        restaurant   = rest,
        type_fine    = tf_r,
        mean         = mean(db, na.rm = TRUE),
        q2.5         = unname(quantile(db, 0.025, na.rm = TRUE)),
        q97.5        = unname(quantile(db, 0.975, na.rm = TRUE)),
        mean_exp     = mean(exp(db), na.rm = TRUE),
        mean_exp_p10 = mean(exp(0.1 * db), na.rm = TRUE),
        rhat         = summ_r$rhat,
        ess_bulk     = summ_r$ess_bulk,
        ess_tail     = summ_r$ess_tail,
        stringsAsFactors = FALSE)
    }
  }
}
}

if (!length(rows)) { cat("No rows to append.\n"); quit(save = "no", status = 1) }
new_df <- do.call(rbind, rows)

if (file.exists(OUT_CSV)) {
  existing <- read.csv(OUT_CSV, stringsAsFactors = FALSE)
  # drop any prior placeholder rows for t2_a3_its/t2_a4_its_t with T1 total stand-in
  keep <- !(existing$analysis %in% c("t2_a3_its","t2_a4_its_t") & existing$total_dir == T1_TOTAL)
  existing <- existing[keep, , drop = FALSE]
  # Robust merge: align columns, fill missing with NA (handles type_fine etc.)
  all_cols <- union(colnames(existing), colnames(new_df))
  for (c in setdiff(all_cols, colnames(existing))) existing[[c]] <- NA
  for (c in setdiff(all_cols, colnames(new_df)))  new_df[[c]]   <- NA
  combined <- rbind(existing[, all_cols, drop = FALSE], new_df[, all_cols, drop = FALSE])
} else {
  combined <- new_df
}

write.csv(combined, OUT_CSV, row.names = FALSE)
cat("Appended ", nrow(new_df), " rows to ", OUT_CSV,
    " (total now ", nrow(combined), ")\n", sep = "")

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
  list(analysis = "t2_a4_its_t", outcomes = c("breakfast_t2","chicken_t2","dairy_t2","textured_t2","untextured_t2"))
)

fit_t <- readRDS(file.path(T1_TOTAL, "fit.rds"))
draws_t <- as.matrix(fit_t$draws("mu_gamma", format = "draws_matrix"))

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

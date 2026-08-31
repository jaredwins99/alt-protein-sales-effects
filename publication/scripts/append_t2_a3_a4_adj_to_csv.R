#!/usr/bin/env Rscript
# Compute T2 A3 + T2 A4 adjusted (outcome - total) 95% CIs and merge into
# publication/forest_data_adj_95ci.csv. Reads from already-extracted
# samples.rds files (no fit.rds re-load => low RAM, fast).
#
# For each (analysis, outcome) pair we pair it against the right "total" fit:
#   t2_a3_its/<outcome>   <-  t2_a3_its/total
#   t2_a4_its_t/<outcome> <-  t2_a3_its/total
#
# The outcome's model root may be _cp or _trunc depending on what fits exist;
# total lives in _cp for T2 A3.

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

# (analysis, outcome) -> (outcome_dir, total_dir). Both must contain samples.rds.
JOBS <- list(
  list(analysis = "t2_a3_its", outcome = "meat",
       outcome_dir = "model_fits/finalized_redone_trunc_cp/t2_a3_its/meat",
       total_dir   = "model_fits/finalized_redone_trunc_cp/t2_a3_its/total"),
  list(analysis = "t2_a3_its", outcome = "nonvegan",
       outcome_dir = "model_fits/finalized_redone_trunc_cp/t2_a3_its/nonvegan",
       total_dir   = "model_fits/finalized_redone_trunc_cp/t2_a3_its/total"),
  list(analysis = "t2_a3_its", outcome = "chicken_fish",
       outcome_dir = "model_fits/finalized_redone_trunc/t2_a3_its/chicken_fish",
       total_dir   = "model_fits/finalized_redone_trunc_cp/t2_a3_its/total"),
  list(analysis = "t2_a3_its", outcome = "vegan",
       outcome_dir = "model_fits/finalized_redone_trunc/t2_a3_its/vegan",
       total_dir   = "model_fits/finalized_redone_trunc_cp/t2_a3_its/total"),
  list(analysis = "t2_a3_its", outcome = "vegetarian",
       outcome_dir = "model_fits/finalized_redone_trunc/t2_a3_its/vegetarian",
       total_dir   = "model_fits/finalized_redone_trunc_cp/t2_a3_its/total"),
  list(analysis = "t2_a4_its_t", outcome = "breakfast_t2",
       outcome_dir = "model_fits/finalized_redone_trunc_cp/t2_a4_its_t/breakfast_t2",
       total_dir   = "model_fits/finalized_redone_trunc_cp/t2_a3_its/total"),
  list(analysis = "t2_a4_its_t", outcome = "textured_t2",
       outcome_dir = "model_fits/finalized_redone_trunc_cp/t2_a4_its_t/textured_t2",
       total_dir   = "model_fits/finalized_redone_trunc_cp/t2_a3_its/total"),
  list(analysis = "t2_a4_its_t", outcome = "untextured_t2",
       outcome_dir = "model_fits/finalized_redone_trunc_cp/t2_a4_its_t/untextured_t2",
       total_dir   = "model_fits/finalized_redone_trunc_cp/t2_a3_its/total"),
  list(analysis = "t2_a4_its_t", outcome = "chicken_t2",
       outcome_dir = "model_fits/finalized_redone_trunc/t2_a4_its_t/chicken_t2",
       total_dir   = "model_fits/finalized_redone_trunc_cp/t2_a3_its/total"),
  list(analysis = "t2_a4_its_t", outcome = "dairy_t2",
       outcome_dir = "model_fits/finalized_redone_trunc/t2_a4_its_t/dairy_t2",
       total_dir   = "model_fits/finalized_redone_trunc_cp/t2_a3_its/total")
)

OUT_CSV <- "publication/forest_data_adj_95ci_t2_a3_a4.csv"

safe_summ_row <- function(fit_dir, var) {
  s_f <- file.path(fit_dir, "summ.rds")
  if (!file.exists(s_f)) return(list(rhat = NA_real_, ess_bulk = NA_real_, ess_tail = NA_real_))
  s <- readRDS(s_f)
  r <- s[s$variable == var, , drop = FALSE]
  if (!nrow(r)) return(list(rhat = NA_real_, ess_bulk = NA_real_, ess_tail = NA_real_))
  list(rhat = r$rhat[1], ess_bulk = r$ess_bulk[1], ess_tail = r$ess_tail[1])
}

# Load total once and keep it. Total is the same for all 10 jobs.
TOTAL_DIR <- "model_fits/finalized_redone_trunc_cp/t2_a3_its/total"
cat("[load total] ", TOTAL_DIR, "/samples.rds\n", sep = "")
samples_t <- readRDS(file.path(TOTAL_DIR, "samples.rds"))

extract_one <- function(j) {
  cat("\n[job] ", j$analysis, "/", j$outcome, "\n", sep = "")
  cat("  outcome_dir = ", j$outcome_dir, "\n", sep = "")

  s_o <- readRDS(file.path(j$outcome_dir, "samples.rds"))

  # Pooled mu_gamma rows -----------------------------------------------------
  mu_cols <- grep("^mu_gamma\\[", names(s_o), value = TRUE)
  pooled_type_fine <- function(i) switch(as.character(i),
    "1" = "level", "2" = "slope", "3" = "gender_male",
    "4" = "gender_female", NA_character_)

  pooled_rows <- list()
  for (v in mu_cols) {
    if (!(v %in% names(samples_t))) next
    n <- min(nrow(s_o), nrow(samples_t))
    d <- s_o[[v]][seq_len(n)] - samples_t[[v]][seq_len(n)]
    summ <- safe_summ_row(j$outcome_dir, v)
    idx <- as.integer(sub("mu_gamma\\[(\\d+)\\]", "\\1", v))
    pooled_rows[[length(pooled_rows) + 1]] <- data.frame(
      fit_dir = j$outcome_dir, total_dir = TOTAL_DIR,
      analysis = j$analysis, outcome = j$outcome,
      gamma_index = idx, level = "pooled",
      restaurant = NA_character_, type_fine = pooled_type_fine(idx),
      mean = mean(d, na.rm = TRUE),
      q2.5 = unname(quantile(d, 0.025, na.rm = TRUE)),
      q97.5 = unname(quantile(d, 0.975, na.rm = TRUE)),
      mean_exp = mean(exp(d), na.rm = TRUE),
      mean_exp_p10 = mean(exp(0.1 * d), na.rm = TRUE),
      rhat = summ$rhat, ess_bulk = summ$ess_bulk, ess_tail = summ$ess_tail,
      stringsAsFactors = FALSE)
  }

  # Per-restaurant beta rows -------------------------------------------------
  data_list_o <- readRDS(file.path(j$outcome_dir, "data_list.rds"))
  pmap_o      <- readRDS(file.path(j$outcome_dir, "predictor_map.rds"))
  rests_o     <- readRDS(file.path(j$outcome_dir, "restaurants_order.rds"))

  rest_rows <- list()
  for (k in seq_along(data_list_o$idx_exposure)) {
    col_idx <- data_list_o$idx_exposure[k]
    r_idx   <- data_list_o$expo_to_rest[k]
    vn      <- sprintf("beta[%d,%d]", col_idx, r_idx)
    if (!(vn %in% names(s_o)) || !(vn %in% names(samples_t))) next
    n <- min(nrow(s_o), nrow(samples_t))
    d <- s_o[[vn]][seq_len(n)] - samples_t[[vn]][seq_len(n)]
    summ <- safe_summ_row(j$outcome_dir, vn)
    mcol <- pmap_o$model_col[pmap_o$col_index == col_idx][1]
    rest <- if (r_idx <= length(rests_o)) rests_o[r_idx] else NA_character_
    tf <- if (grepl("_gendermale$", mcol)) "gender_male"
          else if (grepl("_genderfemale$", mcol)) "gender_female"
          else if (grepl("_slope$", mcol)) "slope"
          else "level"
    rest_rows[[length(rest_rows) + 1]] <- data.frame(
      fit_dir = j$outcome_dir, total_dir = TOTAL_DIR,
      analysis = j$analysis, outcome = j$outcome,
      gamma_index = NA_integer_, level = "restaurant",
      restaurant = rest, type_fine = tf,
      mean = mean(d, na.rm = TRUE),
      q2.5 = unname(quantile(d, 0.025, na.rm = TRUE)),
      q97.5 = unname(quantile(d, 0.975, na.rm = TRUE)),
      mean_exp = mean(exp(d), na.rm = TRUE),
      mean_exp_p10 = mean(exp(0.1 * d), na.rm = TRUE),
      rhat = summ$rhat, ess_bulk = summ$ess_bulk, ess_tail = summ$ess_tail,
      stringsAsFactors = FALSE)
  }

  rm(s_o); invisible(gc())
  bind_rows(c(pooled_rows, rest_rows))
}

# ─── Compute new rows for every job (one fit at a time; samples.rds freed
#     after each job so peak RAM stays small) ──────────────────────────────
new_rows <- bind_rows(lapply(JOBS, extract_one))
cat("\n[new rows] ", nrow(new_rows), " total\n", sep = "")

# ─── Write supplementary CSV (does NOT overwrite the main 95ci file) ──────
cat("[write] ", OUT_CSV, " (", nrow(new_rows), " rows)\n", sep = "")
write_csv(new_rows, OUT_CSV)
cat("[done]\n")

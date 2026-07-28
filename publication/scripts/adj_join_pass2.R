#!/usr/bin/env Rscript
# adj_join_pass2.R <slim_dir> <pairs_csv> <out_csv>
#
# Pass 2: join slim per-fit draws into adjusted (RRR) estimates.
#
# Fixes two bugs in publication/scripts/extract_adj_95ci.R:
#
#   Bug 1 - restaurant rows subtracted the wrong coefficient.
#     The old code built  vn <- sprintf("beta[%d,%d]", col_idx, r_idx)  from the
#     OUTCOME model's indices and applied that same name to the TOTAL model. The
#     two fits have different predictor_maps and different restaurants_order, so
#     it subtracted a different predictor at a different restaurant -- and since
#     a restaurant's beta is 0 for another restaurant's exposure column, the
#     subtraction was usually minus ZERO, leaving the raw unadjusted effect.
#     Fix: join on (model_col name, restaurant name). Slim files are already
#     name-keyed, and every match is asserted below.
#
#   Bug 2 - pooled and restaurant rows used different baselines.
#     pooled was  mu_gamma_outcome - mu_gamma_total, where mu_gamma_total is the
#     total model's mean over ALL its restaurants, while each restaurant dot
#     subtracts that restaurant's OWN total coefficient. When the outcome model
#     holds a subset of the total model's restaurants the two sit on different
#     baselines. Fix: subtract the total-model baseline restricted to the
#     introductions actually present in the outcome model, per draw.
#     No re-fitting is needed -- the total model already estimates a separate
#     beta/eta for every restaurant it contains.
#
# Also stores a `median` column (the old CSVs had none, so adj_fallback.R fell
# back to the mean; see its "median not stored" comment).

suppressPackageStartupMessages({ library(stats) })

args <- commandArgs(trailingOnly = TRUE)
slim_dir  <- args[1]
pairs_csv <- args[2]
out_csv   <- args[3]
# Fallback total: a restaurant present in the outcome model may be absent from
# the primary total model (the T2 A3 total holds only the 12 T2 restaurants, but
# T2 A3/A4 outcome models also include the 4 T1 restaurants). That restaurant's
# own total-sales effect still exists -- in the T1 total. Subtracting it is the
# correct baseline; leaving it out silently yields a RAW, unadjusted estimate,
# which is what the committed supplementary CSV contains today.
fallback_total <- if (length(args) >= 4) args[4] else
  "model_fits/finalized_redone_trunc_cp/a3_its/total"

slim_path <- function(model_dir)
  file.path(slim_dir, paste0(gsub("[/]", "__", sub("^model_fits/", "", model_dir)), ".rds"))

summarise_draws <- function(d) {
  d <- d[is.finite(d)]
  list(mean = mean(d), median = stats::median(d),
       q2.5 = unname(quantile(d, 0.025)), q97.5 = unname(quantile(d, 0.975)))
}

pairs <- read.csv(pairs_csv, stringsAsFactors = FALSE)
rows <- list()
warn <- list()

for (i in seq_len(nrow(pairs))) {
  po <- slim_path(pairs$fit[i]); pt <- slim_path(pairs$total[i])
  if (!file.exists(po) || !file.exists(pt)) {
    warn[[length(warn)+1]] <- sprintf("MISSING slim for %s / %s", pairs$fit[i], pairs$total[i]); next
  }
  so <- readRDS(po); st <- readRDS(pt)
  pf <- slim_path(fallback_total)
  sf <- if (file.exists(pf) && !identical(pairs$total[i], fallback_total)) readRDS(pf) else NULL
  n  <- min(so$n_draws, st$n_draws)
  if (n < 1) { warn[[length(warn)+1]] <- sprintf("no draws: %s", pairs$fit[i]); next }

  bo <- so$beta_expo; bt <- st$beta_expo
  if (is.null(bo) || is.null(bt)) { warn[[length(warn)+1]] <- sprintf("no beta_expo: %s", pairs$fit[i]); next }
  ro <- attr(bo, "restaurant"); rt <- attr(bt, "restaurant")
  pro <- attr(bo, "param")

  # ---- restaurant-level rows: join by (model_col, restaurant) ----
  key_o <- paste(colnames(bo), ro, sep = "@@")
  key_t <- paste(colnames(bt), rt, sep = "@@")
  bf <- if (!is.null(sf)) sf$beta_expo else NULL
  key_f <- if (!is.null(bf)) paste(colnames(bf), attr(bf, "restaurant"), sep = "@@") else character(0)
  # per-column source of the total coefficient, for provenance
  src_t <- character(length(key_o))
  matched_cols <- integer(0)   # indices into bo that resolved in bt
  for (k in seq_along(key_o)) {
    j <- match(key_o[k], key_t)
    if (!is.na(j)) {
      # assertion: names must agree exactly (this is what Bug 1 violated)
      stopifnot(identical(colnames(bo)[k], colnames(bt)[j]), identical(ro[k], rt[j]))
      nn <- min(n, nrow(bt)); d <- bo[seq_len(nn), k] - bt[seq_len(nn), j]
      src_t[k] <- "primary"
    } else {
      jf <- if (length(key_f)) match(key_o[k], key_f) else NA_integer_
      if (is.na(jf)) {
        warn[[length(warn)+1]] <- sprintf("UNMATCHED(no fallback) %s :: %s", pairs$fit[i], key_o[k])
        src_t[k] <- ""; next
      }
      stopifnot(identical(colnames(bo)[k], colnames(bf)[jf]))
      nn <- min(n, nrow(bf)); d <- bo[seq_len(nn), k] - bf[seq_len(nn), jf]
      src_t[k] <- "fallback_t1_total"
    }
    s <- summarise_draws(d)
    mc <- colnames(bo)[k]
    tf <- if (grepl("_gendermale$", mc)) "gender_male"
          else if (grepl("_genderfemale$", mc)) "gender_female"
          else if (grepl("_slope$", mc)) "slope" else "level"
    rows[[length(rows)+1]] <- data.frame(
      fit_dir = pairs$fit[i], total_dir = pairs$total[i],
      analysis = pairs$analysis[i], outcome = pairs$outcome[i],
      gamma_index = NA_integer_, level = "restaurant", restaurant = ro[k],
      type_fine = tf, model_col = mc, total_source = src_t[k],
      mean = s$mean, median = s$median, q2.5 = s$q2.5, q97.5 = s$q97.5,
      stringsAsFactors = FALSE)
    matched_cols <- c(matched_cols, k)
  }

  # ---- pooled rows: matched baseline ----
  mo <- so$mu_gamma; if (is.null(mo)) next
  for (gi in seq_len(ncol(mo))) {
    prm <- as.integer(sub("mu_gamma\\[(\\d+)\\]", "\\1", colnames(mo)[gi]))
    if (is.na(prm)) prm <- gi
    # total-model baseline over exactly the introductions present in the outcome model
    sel <- matched_cols[!is.na(pro[matched_cols]) & pro[matched_cols] == prm]
    if (!length(sel)) next
    cols <- lapply(sel, function(k) {
      j <- match(key_o[k], key_t)
      if (!is.na(j)) bt[seq_len(n), j]
      else { jf <- match(key_o[k], key_f); if (is.na(jf)) NULL else bf[seq_len(n), jf] }
    })
    cols <- cols[!vapply(cols, is.null, logical(1))]
    if (!length(cols)) next
    base <- rowMeans(do.call(cbind, cols))
    d <- mo[seq_len(n), gi] - base
    s <- summarise_draws(d)
    tf <- switch(as.character(prm), "1"="level", "2"="slope",
                 "3"="gender_male", "4"="gender_female", NA_character_)
    rows[[length(rows)+1]] <- data.frame(
      fit_dir = pairs$fit[i], total_dir = pairs$total[i],
      analysis = pairs$analysis[i], outcome = pairs$outcome[i],
      gamma_index = prm, level = "pooled", restaurant = NA_character_,
      type_fine = tf, model_col = NA_character_, total_source = "matched_baseline",
      mean = s$mean, median = s$median, q2.5 = s$q2.5, q97.5 = s$q97.5,
      stringsAsFactors = FALSE)
  }
}

out <- do.call(rbind, rows)
dir.create(dirname(out_csv), showWarnings = FALSE, recursive = TRUE)
write.csv(out, out_csv, row.names = FALSE)
cat(sprintf("wrote %d rows (%d pooled, %d restaurant) -> %s\n",
            nrow(out), sum(out$level=="pooled"), sum(out$level=="restaurant"), out_csv))
if (length(warn)) {
  cat("WARNINGS:", length(warn), "\n")
  for (w in unique(unlist(warn))[1:min(20, length(unique(unlist(warn))))]) cat("  ", w, "\n")
}

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
# A restaurant present in the outcome model but absent from its total model has
# no coefficient to divide by, so its RRR is undefined and the row is DROPPED
# (and reported). Borrowing that coefficient from a different fit would mix
# effects across models and is not a valid adjustment. Fix is upstream: re-fit
# the two total models that were run without the Tier-1 restaurants
# (t2_a3_its/total, t2_a5_customer_day/total).

slim_path <- function(model_dir)
  file.path(slim_dir, paste0(gsub("[/]", "__", sub("^model_fits/", "", model_dir)), ".rds"))

# All summaries are Monte Carlo quantiles of the draw vector -- no distributional
# assumption anywhere. Stan's own summary only carries q5/q95 (90%), which is why
# the 95% bounds are computed here from draws.
#
# q16/q84 (the central 68%, the "1 SD" band) are stored too. Previously only
# q2.5/q97.5 were stored, so the renderer had to BACK OUT sigma from the 95%
# bounds under a log-normal assumption to draw the inner band. That
# approximation is now unnecessary: the inner band is an exact Monte Carlo
# interval as well.
summarise_draws <- function(d) {
  # Do NOT silently drop non-finite draws: that would shrink the effective
  # sample and hide a broken fit. Verified 0 non-finite across 19.2M draws, so
  # this should never fire.
  stopifnot(all(is.finite(d)))
  q <- unname(quantile(d, c(0.025, 0.16, 0.84, 0.975)))
  list(mean = mean(d), median = stats::median(d),
       q2.5 = q[1], q16 = q[2], q84 = q[3], q97.5 = q[4])
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
  n  <- min(so$n_draws, st$n_draws)
  if (n < 1) { warn[[length(warn)+1]] <- sprintf("no draws: %s", pairs$fit[i]); next }

  bo <- so$beta_expo; bt <- st$beta_expo
  if (is.null(bo) || is.null(bt)) { warn[[length(warn)+1]] <- sprintf("no beta_expo: %s", pairs$fit[i]); next }
  ro <- attr(bo, "restaurant"); rt <- attr(bt, "restaurant")
  pro <- attr(bo, "param")

  # ---- restaurant-level rows: join by (model_col, restaurant) ----
  key_o <- paste(colnames(bo), ro, sep = "@@")
  key_t <- paste(colnames(bt), rt, sep = "@@")
  matched_cols <- integer(0)   # indices into bo that resolved in bt
  for (k in seq_along(key_o)) {
    j <- match(key_o[k], key_t)
    if (is.na(j)) {
      warn[[length(warn)+1]] <- sprintf("DROPPED (restaurant absent from total fit) %s :: %s", pairs$fit[i], key_o[k])
      next
    }
    # names must agree exactly -- this is what Bug 1 violated
    stopifnot(identical(colnames(bo)[k], colnames(bt)[j]), identical(ro[k], rt[j]))
    d <- bo[seq_len(n), k] - bt[seq_len(n), j]
    s <- summarise_draws(d)
    mc <- colnames(bo)[k]
    tf <- if (grepl("_gendermale$", mc)) "gender_male"
          else if (grepl("_genderfemale$", mc)) "gender_female"
          else if (grepl("_slope$", mc)) "slope" else "level"
    rows[[length(rows)+1]] <- data.frame(
      fit_dir = pairs$fit[i], total_dir = pairs$total[i],
      analysis = pairs$analysis[i], outcome = pairs$outcome[i],
      gamma_index = NA_integer_, level = "restaurant", restaurant = ro[k],
      type_fine = tf, model_col = mc, total_source = "matched_restaurant",
      mean = s$mean, median = s$median,
      q2.5 = s$q2.5, q16 = s$q16, q84 = s$q84, q97.5 = s$q97.5,
      stringsAsFactors = FALSE)
    matched_cols <- c(matched_cols, k)
  }

  # ---- pooled rows ----
  # The pooled estimate is a POPULATION-level quantity (mu_gamma), so its
  # baseline must also be population-level. Two cases:
  #
  #  (a) outcome and total share the same restaurant set -> mu_gamma_total is
  #      already the right baseline. Use it. (Substituting an empirical mean of
  #      per-introduction betas here would introduce a spurious offset, because
  #      mu_gamma is the mean of the restaurant-level etas, not of the
  #      introduction-level gammas.)
  #  (b) the outcome model holds a SUBSET -> mu_gamma_total averages over
  #      restaurants that are not in the outcome model at all. Restrict it to
  #      the matched restaurants, staying at the same hierarchy level by
  #      averaging the total model's eta (its per-restaurant means), not beta.
  mo <- so$mu_gamma; if (is.null(mo)) next
  mt <- st$mu_gamma
  et <- st$eta
  rest_o <- unique(ro[matched_cols]); rest_t <- unique(rt)
  same_set <- length(rest_o) && setequal(rest_o, rest_t)
  for (gi in seq_len(ncol(mo))) {
    prm <- as.integer(sub("mu_gamma\\[(\\d+)\\]", "\\1", colnames(mo)[gi]))
    if (is.na(prm)) prm <- gi
    base <- NULL; src <- NA_character_
    if (same_set && !is.null(mt) && gi <= ncol(mt)) {
      base <- mt[seq_len(n), gi]; src <- "mu_gamma_total"
    } else if (!is.null(et)) {
      ep <- attr(et, "param"); er <- attr(et, "restaurant")
      jj <- which(!is.na(ep) & ep == prm & er %in% rest_o)
      if (length(jj)) { base <- rowMeans(et[seq_len(n), jj, drop = FALSE]); src <- "eta_total_matched" }
    }
    if (is.null(base) && !is.null(mt) && gi <= ncol(mt)) {
      base <- mt[seq_len(n), gi]; src <- "mu_gamma_total_unmatched"
    }
    if (is.null(base)) next
    d <- mo[seq_len(n), gi] - base
    s <- summarise_draws(d)
    tf <- switch(as.character(prm), "1"="level", "2"="slope",
                 "3"="gender_male", "4"="gender_female", NA_character_)
    rows[[length(rows)+1]] <- data.frame(
      fit_dir = pairs$fit[i], total_dir = pairs$total[i],
      analysis = pairs$analysis[i], outcome = pairs$outcome[i],
      gamma_index = prm, level = "pooled", restaurant = NA_character_,
      type_fine = tf, model_col = NA_character_, total_source = src,
      mean = s$mean, median = s$median,
      q2.5 = s$q2.5, q16 = s$q16, q84 = s$q84, q97.5 = s$q97.5,
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

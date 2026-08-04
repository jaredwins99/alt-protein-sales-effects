#!/usr/bin/env Rscript
# exch_diag.R [slim_dir] [pairs_csv] [out_csv]
#
# Baseline-exchangeability diagnostic for the subset pooled estimates.
# Produces the numbers quoted in publication/METHODS_rrr.md.
#
# The reported pooled RRR is  mu_gamma_outcome - mu_gamma_total.  When the
# outcome model holds a SUBSET R_o of the total model's restaurants, the
# baseline mu_gamma_total is a population mean over ALL restaurants while the
# numerator is a population mean over the subset's population.  The bias term is
#
#     gap = mu_gamma_total - mean(eta_total | R_o)
#
# i.e. how far the SUBSET restaurants' own total-sales exposure effect sits from
# the all-restaurant population mean.  gap ~ 0 => the subset looks like everyone
# else and the global-vs-global difference is clean.  gap large => the baseline
# being subtracted is not representative of those restaurants.
#
# Computed per posterior draw, so gap carries a credible interval.  sd_eta_total
# is the between-restaurant spread of the total effect, the scale against which
# gap should be judged.
#
# Same-set pairs are skipped: their gap is zero by construction.

args      <- commandArgs(trailingOnly = TRUE)
slim_dir  <- if (length(args) >= 1) args[1] else "/var/tmp/adj_slim"
pairs_csv <- if (length(args) >= 2) args[2] else "publication/scripts/adj_fixed_pairs.csv"
out_csv   <- if (length(args) >= 3) args[3] else "publication/exch_diag_baseline_gap.csv"

slim_path <- function(md)
  file.path(slim_dir, paste0(gsub("[/]", "__", sub("^model_fits/", "", md)), ".rds"))

pairs <- read.csv(pairs_csv, stringsAsFactors = FALSE)
out <- list()

for (i in seq_len(nrow(pairs))) {
  po <- slim_path(pairs$fit[i]); pt <- slim_path(pairs$total[i])
  if (!file.exists(po) || !file.exists(pt)) next
  so <- readRDS(po); st <- readRDS(pt)
  n <- min(so$n_draws, st$n_draws); if (n < 1) next
  bo <- so$beta_expo; bt <- st$beta_expo
  if (is.null(bo) || is.null(bt)) next
  ro <- attr(bo, "restaurant"); rt <- attr(bt, "restaurant")

  key_o <- paste(colnames(bo), ro, sep = "@@")
  key_t <- paste(colnames(bt), rt, sep = "@@")
  matched <- integer(0)
  for (k in seq_along(key_o)) if (!is.na(match(key_o[k], key_t))) matched <- c(matched, k)
  if (!length(matched)) next

  mo <- so$mu_gamma; mt <- st$mu_gamma; et <- st$eta
  if (is.null(mo) || is.null(mt) || is.null(et)) next
  rest_o <- unique(ro[matched]); rest_t <- unique(rt)
  if (setequal(rest_o, rest_t)) next            # same set -> gap is 0 by construction

  ep <- attr(et, "param"); er <- attr(et, "restaurant")

  for (gi in seq_len(ncol(mo))) {
    prm <- as.integer(sub("mu_gamma\\[(\\d+)\\]", "\\1", colnames(mo)[gi]))
    if (is.na(prm)) prm <- gi
    if (gi > ncol(mt)) next
    jsub <- which(!is.na(ep) & ep == prm & er %in% rest_o)   # subset restaurants
    jall <- which(!is.na(ep) & ep == prm)                    # all restaurants in total fit
    if (!length(jsub)) next

    gap <- mt[seq_len(n), gi] - rowMeans(et[seq_len(n), jsub, drop = FALSE])
    q   <- unname(quantile(gap, c(0.025, 0.5, 0.975)))
    sd_eta <- if (length(jall) > 1)
                median(apply(et[seq_len(n), jall, drop = FALSE], 1, sd)) else NA_real_

    out[[length(out) + 1]] <- data.frame(
      analysis = pairs$analysis[i], outcome = pairs$outcome[i],
      type = switch(as.character(prm), "1" = "level", "2" = "slope",
                    "3" = "gender_male", "4" = "gender_female", NA_character_),
      n_sub = length(rest_o), n_tot = length(rest_t),
      gap = q[2], gap_lo = q[1], gap_hi = q[3], gap_rr = exp(q[2]),
      excludes_0 = (q[1] > 0) | (q[3] < 0),
      sd_eta_total = sd_eta,
      gap_in_sd = if (is.na(sd_eta) || sd_eta == 0) NA_real_ else q[2] / sd_eta,
      stringsAsFactors = FALSE)
  }
}

res <- do.call(rbind, out)
res <- res[order(-abs(res$gap)), ]

cat(sprintf("subset pooled rows: %d\n", nrow(res)))
cat(sprintf("|gap| -- median %.3f, 90th pct %.3f, max %.3f\n",
            median(abs(res$gap)), quantile(abs(res$gap), .9), max(abs(res$gap))))
cat(sprintf("gap CI excludes 0: %d / %d (%.0f%%)\n",
            sum(res$excludes_0), nrow(res), 100 * mean(res$excludes_0)))
cat(sprintf("|gap| < 0.10: %d / %d (%.0f%%)\n",
            sum(abs(res$gap) < 0.10), nrow(res), 100 * mean(abs(res$gap) < 0.10)))
cat(sprintf("of the CI-excludes-0 rows, %d are single-restaurant (pooled marker dropped)\n",
            sum(res$excludes_0 & res$n_sub == 1)))

cat("\n=== per-analysis ===\n")
agg <- do.call(rbind, lapply(split(res, res$analysis), function(d) data.frame(
  analysis = d$analysis[1], rows = nrow(d),
  med_abs_gap = round(median(abs(d$gap)), 3),
  max_abs_gap = round(max(abs(d$gap)), 3),
  n_CI_excl_0 = sum(d$excludes_0))))
print(agg[order(agg$max_abs_gap), ], row.names = FALSE)

dir.create(dirname(out_csv), showWarnings = FALSE, recursive = TRUE)
write.csv(res, out_csv, row.names = FALSE)
cat(sprintf("\nwrote %d rows -> %s\n", nrow(res), out_csv))

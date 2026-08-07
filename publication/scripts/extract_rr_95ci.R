## extract_rr_95ci.R -- raw (unadjusted) rate ratios for exactly the estimates the
## forest plots report.
##
## The plots and publication/forest_data_adj_95ci_fixed.csv carry the RRR: the
## outcome-model effect MINUS the total-purchases effect, differenced draw by draw.
## The Supplement tables are meant to show the underlying RRs instead, so this
## walks the same fits and records mu_gamma on its own, undifferenced.
##
## Writes one row per (fit_dir, gamma_index):
##   gamma_index 1 = level term, 2 = slope term  (matches the adj CSV's convention)
##
## Resumable: rows already present in the output are skipped, so it can be stopped
## and restarted. 131 fits, so expect this to take a while.
##
## Usage:
##   Rscript publication/scripts/extract_rr_95ci.R [out_csv]
## Default out_csv: publication/forest_data_rr_95ci.csv
##
## NOTE: 121 of the 131 fits have only fit.rds, which needs cmdstanr. That path is
## unreliable under WSL -- run this on Windows.

args    <- commandArgs(trailingOnly = TRUE)
OUT     <- if (length(args) >= 1) args[1] else "publication/forest_data_rr_95ci.csv"
ADJ_CSV <- "publication/forest_data_adj_95ci_fixed.csv"

adj  <- read.csv(ADJ_CSV, stringsAsFactors = FALSE)
dirs <- unique(adj$fit_dir[adj$level == "pooled"])
dirs <- sort(dirs[!is.na(dirs) & nzchar(dirs)])

## Most of these fits were never refit, and publication/forest_data_95ci.csv already
## holds their raw mu_gamma at the same quantiles -- verified identical on
## t2_a4_its_t/textured_t2. Only the refit generations need redoing, which cuts
## this from 115 fits to about two dozen. Set RR_FORCE_ALL=TRUE to redo everything.
if (toupper(Sys.getenv("RR_FORCE_ALL", "FALSE")) != "TRUE" &&
    file.exists("publication/forest_data_95ci.csv")) {
  old  <- read.csv("publication/forest_data_95ci.csv", stringsAsFactors = FALSE)
  have <- unique(old$fit_dir[old$type_fine == "pooled_mu_gamma"])
  skip <- intersect(dirs, have)
  cat(sprintf("%d fits already covered by forest_data_95ci.csv, skipping them\n",
              length(skip)))
  dirs <- setdiff(dirs, have)
}

done <- character(0)
if (file.exists(OUT)) {
  prev <- read.csv(OUT, stringsAsFactors = FALSE)
  done <- unique(prev$fit_dir)
  cat(sprintf("resuming: %d dirs already done\n", length(done)))
}
todo <- setdiff(dirs, done)
cat(sprintf("%d fit dirs total, %d to do\n", length(dirs), length(todo)))

read_draws_any <- function(dir) {
  sp <- file.path(dir, "samples.rds")
  if (file.exists(sp)) return(list(kind = "samples", obj = readRDS(sp)))
  fp <- file.path(dir, "fit.rds")
  if (file.exists(fp)) {
    suppressPackageStartupMessages(library(cmdstanr))
    return(list(kind = "fit", obj = readRDS(fp)))
  }
  stop("no fit.rds or samples.rds in ", dir)
}

grab_mu <- function(src) {
  if (src$kind == "fit") {
    ok <- tryCatch(any(sub("\\[.*", "", src$obj$metadata()$variables) == "mu_gamma"),
                   error = function(e) FALSE)
    if (!ok) return(NULL)
    return(tryCatch(as.matrix(src$obj$draws(variables = "mu_gamma",
                                            format = "draws_matrix")),
                    error = function(e) NULL))
  }
  nm   <- names(src$obj)
  keep <- nm[sub("\\[.*", "", nm) == "mu_gamma"]
  if (!length(keep)) return(NULL)
  m <- do.call(cbind, lapply(keep, function(k) as.numeric(src$obj[[k]])))
  colnames(m) <- keep
  m
}

first <- !file.exists(OUT)
for (i in seq_along(todo)) {
  d <- todo[i]
  cat(sprintf("[%3d/%3d] %s ... ", i, length(todo), d))
  mu <- tryCatch({ src <- read_draws_any(d); grab_mu(src) },
                 error = function(e) { cat("ERR:", conditionMessage(e), "\n"); NULL })
  if (is.null(mu)) { cat("no mu_gamma\n"); next }

  idx <- as.integer(sub(".*\\[(\\d+)\\].*", "\\1", colnames(mu)))
  row <- data.frame(
    fit_dir     = d,
    gamma_index = idx,
    n_draws     = nrow(mu),
    median      = apply(mu, 2, stats::median),
    q2.5        = apply(mu, 2, stats::quantile, probs = 0.025, names = FALSE),
    q97.5       = apply(mu, 2, stats::quantile, probs = 0.975, names = FALSE),
    stringsAsFactors = FALSE
  )
  write.table(row, OUT, sep = ",", row.names = FALSE,
              col.names = first, append = !first)
  first <- FALSE
  cat(sprintf("ok (%d params, %d draws)\n", ncol(mu), nrow(mu)))
  rm(mu, src); gc(verbose = FALSE)
}
cat("DONE ->", OUT, "\n")

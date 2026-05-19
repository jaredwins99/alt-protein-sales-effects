#!/usr/bin/env Rscript
# Extract samples.rds from fit.rds for ONE model fit directory.
# Usage: Rscript scripts/extract_samples_one.R <path/to/model_dir>
# Writes <model_dir>/samples.rds. Skips if already present.

suppressPackageStartupMessages({
  library(posterior)
})

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) stop("usage: extract_samples_one.R <model_dir>")
model_dir <- args[[1]]
fit_path <- file.path(model_dir, "fit.rds")
out_path <- file.path(model_dir, "samples.rds")

if (!file.exists(fit_path)) stop("no fit.rds at: ", fit_path)
if (file.exists(out_path)) {
  cat("samples.rds already exists at: ", out_path, " (skipping)\n", sep = "")
  quit(save = "no", status = 0)
}

cat("[extract] reading fit.rds: ", fit_path, "\n", sep = "")
fit <- readRDS(fit_path)
cat("[extract] computing draws_df\n")
samples <- posterior::as_draws_df(fit$draws())
cat("[extract] saving samples.rds (", nrow(samples), " draws, ",
    ncol(samples), " vars) -> ", out_path, "\n", sep = "")
saveRDS(samples, out_path)
rm(fit, samples); invisible(gc())
cat("[extract] done\n")

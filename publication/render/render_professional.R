#!/usr/bin/env Rscript
# render_professional.R
# ----------------------------------------------------------------------
# Self-contained renderer for the publication-quality (PNG + PDF only)
# T1-adjusted forest plots, A1 through A6.  Produces exactly 12 files in
#   publication/forest_plots/professional/t1_adj/
# Inputs (sourced for their plotting logic, unchanged):
#   - publication/render/create_forest_plots_restaurants_chosen_recolored_adj.R
#       (writes A1–A4 + A5 transaction-level adj PNG/PDF/HTML/CSV
#        to publication/forest_plots/total_adjusted/t1/)
#   - publication/render/create_customer_day_forest_plots_consolidated.R
#       (writes A5/A6 day-level adj PNG/PDF/HTML/CSV to the same dir;
#        the A5/A6 day-level publication PNG/PDFs are what we want)
# After running both renderer scripts, this script copies just the 12
# publication-quality PNGs and PDFs (no HTMLs, no _data.csv) for the six
# T1-adjusted analyses (A1–A6) into the dedicated professional output
# directory.  The original total_adjusted/t1 outputs are left untouched.
# ----------------------------------------------------------------------

suppressPackageStartupMessages({
  library(tidyverse)
})

# Resolve repo root (mirrors the other render scripts that setwd here).
find_project_root <- function() {
  d <- normalizePath(getwd(), mustWork = TRUE)
  while (!file.exists(file.path(d, "publication"))) {
    p <- dirname(d)
    if (p == d) stop("Could not locate project root.")
    d <- p
  }
  d
}
setwd(find_project_root())

PROFESSIONAL_DIR <- "publication/forest_plots/professional/t1_adj"
dir.create(PROFESSIONAL_DIR, showWarnings = FALSE, recursive = TRUE)
SOURCE_DIR <- "publication/forest_plots/total_adjusted/t1"

# CLI arg: optional analysis name to render only one (e.g. "A3").
# Default: render all 6.  When a single analysis is selected, also enable
# PRO_FAST so the renderer skips PNG, plotly conversion, HTML widget,
# and log-scale overlays — PDF only.  Cuts render time dramatically.
.cli  <- toupper(commandArgs(trailingOnly = TRUE)[1])
.only <- if (length(.cli) && !is.na(.cli) && nzchar(.cli)) .cli else "ALL"
if (!.only %in% c("ALL", "A1", "A2", "A3", "A4", "A5", "A6"))
  stop("PRO_ONLY must be ALL or A1..A6 (got: ", .only, ")")
Sys.setenv(PRO_ONLY = .only)
if (.only != "ALL") Sys.setenv(PRO_FAST = "TRUE")
cat("\n[render_professional] PRO_ONLY=", .only,
    " PRO_FAST=", Sys.getenv("PRO_FAST", "FALSE"), "\n", sep = "")

# Decide which sub-renderer to source.  A1-A4 + A5 transaction live in
# recolored_adj.R; A5/A6 day-level live in consolidated.R.  When PRO_ONLY
# narrows scope, skip the renderer that doesn't produce that analysis.
.run_recolored <- .only %in% c("ALL", "A1", "A2", "A3", "A4", "A5")
.run_consolid  <- .only %in% c("ALL", "A5", "A6")

if (.run_recolored) {
  cat("\n[render_professional] Step 1: render A1–A4 (+ A5 transaction)\n")
  source("publication/render/create_forest_plots_restaurants_chosen_recolored_adj.R",
         chdir = FALSE)
}

if (.run_consolid) {
  cat("\n[render_professional] Step 2: render A5/A6 day-level adj\n")
  source("publication/render/create_customer_day_forest_plots_consolidated.R",
         chdir = FALSE)
}

EXPECTED_STEMS_ALL <- c(
  A1 = "A1_proportion_forest_restaurants",
  A2 = "A2_proportion_targeted_forest_restaurants",
  A3 = "A3_its_forest_restaurants",
  A4 = "A4_its_targeted_forest_restaurants",
  A5 = "A5_gaussian_iid_day_forest_restaurants_adj",
  A6 = "A6_gaussian_iid_day_targeted_forest_restaurants_adj"
)
EXPECTED_STEMS <- if (.only == "ALL") EXPECTED_STEMS_ALL else EXPECTED_STEMS_ALL[[.only]]

cat("\n[render_professional] Step 3: copy PDF -> ", PROFESSIONAL_DIR, "\n",
    sep = "")
# PDF only — for Overleaf/print, vector PDF is what we want; PNG is dropped
# from the professional tree (rasters are kept upstream in total_adjusted/t1/).
copied  <- character(0)
missing <- character(0)
for (stem in EXPECTED_STEMS) {
  src <- file.path(SOURCE_DIR, paste0(stem, ".pdf"))
  dst <- file.path(PROFESSIONAL_DIR, paste0(stem, ".pdf"))
  if (file.exists(src)) {
    ok <- file.copy(src, dst, overwrite = TRUE)
    if (ok) {
      copied <- c(copied, dst)
      cat("  copied: ", basename(dst), "\n", sep = "")
    } else {
      missing <- c(missing, dst)
      cat("  FAILED COPY: ", src, "\n", sep = "")
    }
  } else {
    missing <- c(missing, src)
    cat("  MISSING SOURCE: ", src, "\n", sep = "")
  }
}

cat("\n=========================================\n")
cat("Professional render complete.\n")
cat("Output dir : ", PROFESSIONAL_DIR, "\n", sep = "")
cat("Files copied: ", length(copied), " / 6\n", sep = "")
if (length(missing)) {
  cat("Missing: ", length(missing), "\n", sep = "")
  for (m in missing) cat("  - ", m, "\n", sep = "")
}
cat("=========================================\n")

invisible(NULL)

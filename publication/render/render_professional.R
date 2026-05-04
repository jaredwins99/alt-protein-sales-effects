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

# Output dir for the 12 publication-quality files.
PROFESSIONAL_DIR <- "publication/forest_plots/professional/t1_adj"
dir.create(PROFESSIONAL_DIR, showWarnings = FALSE, recursive = TRUE)

# Source the two renderer scripts.  They each setwd() to project root in
# their own initialization paths, so source() from the project root is
# safe.  These scripts produce publication-mode PNG+PDF for the six T1
# adj analyses in publication/forest_plots/total_adjusted/t1/.
SOURCE_DIR <- "publication/forest_plots/total_adjusted/t1"

cat("\n[render_professional] Step 1/3: render A1–A4 (+ A5 transaction)\n")
source("publication/render/create_forest_plots_restaurants_chosen_recolored_adj.R",
       chdir = FALSE)

cat("\n[render_professional] Step 2/3: render A5/A6 day-level adj\n")
source("publication/render/create_customer_day_forest_plots_consolidated.R",
       chdir = FALSE)

# The 12 expected files (6 analyses × {png, pdf}).
EXPECTED_STEMS <- c(
  "A1_proportion_forest_restaurants",
  "A2_proportion_targeted_forest_restaurants",
  "A3_its_forest_restaurants",
  "A4_its_targeted_forest_restaurants",
  "A5_gaussian_iid_day_forest_restaurants_adj",
  "A6_gaussian_iid_day_targeted_forest_restaurants_adj"
)

cat("\n[render_professional] Step 3/3: copy PNG+PDF -> ", PROFESSIONAL_DIR, "\n",
    sep = "")
copied  <- character(0)
missing <- character(0)
for (stem in EXPECTED_STEMS) {
  for (ext in c("png", "pdf")) {
    src <- file.path(SOURCE_DIR, paste0(stem, ".", ext))
    dst <- file.path(PROFESSIONAL_DIR, paste0(stem, ".", ext))
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
}

cat("\n=========================================\n")
cat("Professional render complete.\n")
cat("Output dir : ", PROFESSIONAL_DIR, "\n", sep = "")
cat("Files copied: ", length(copied), " / 12\n", sep = "")
if (length(missing)) {
  cat("Missing: ", length(missing), "\n", sep = "")
  for (m in missing) cat("  - ", m, "\n", sep = "")
}
cat("=========================================\n")

invisible(NULL)

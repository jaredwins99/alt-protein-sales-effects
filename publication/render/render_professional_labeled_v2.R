#!/usr/bin/env Rscript
# render_professional_labeled_v2.R
# ----------------------------------------------------------------------
# "v2" of render_professional_labeled.R. Same restaurant-color / numbered-
# legend / inline-name treatment as professional_labeled/, but layered on
# top of the WIDE + RECENTERED base (like professional_wide/) instead of
# the plain RR-scale base, and additionally adds:
#   - a small numeric estimate + CI label next to every restaurant-level
#     point in A1-A4 (T1 and T2), positioned to avoid the inline name label
#   - vertical (angle=-90) A2/A4 strip text instead of horizontal, since
#     WIDE mode gives those panels enough height for it
#
# Env switches set: SORT_BY_MEAN=FALSE, LABELED_MODE=TRUE, LABELED_V2=TRUE,
# PUB_RECENTER=TRUE, PUB_WIDE=TRUE.
#
# Output directories:
#   publication/forest_plots/professional_labeled_v2/t1_adj/   (6 PDFs)
#   publication/forest_plots/professional_labeled_v2/t2_adj/   (6 PDFs)
#
# CLI arguments:
#   Arg 1 — PRO_ONLY: restrict to one analysis (A1..A6 or ALL, default ALL)
#   Arg 2 — PRO_TIER: restrict to one tier (T1, T2, or BOTH, default BOTH)
#
# Examples:
#   Rscript render_professional_labeled_v2.R          # render everything
#   Rscript render_professional_labeled_v2.R A3       # only A3 for both tiers
#   Rscript render_professional_labeled_v2.R ALL T2   # all analyses, T2 only
#   Rscript render_professional_labeled_v2.R A1 T1    # A1 for T1 only
# ----------------------------------------------------------------------

suppressPackageStartupMessages({
  library(tidyverse)
})

# Resolve repo root
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

LABELED_DIR_T1 <- "publication/forest_plots/professional_labeled_v2/t1_adj"
LABELED_DIR_T2 <- "publication/forest_plots/professional_labeled_v2/t2_adj"
dir.create(LABELED_DIR_T1, showWarnings = FALSE, recursive = TRUE)
dir.create(LABELED_DIR_T2, showWarnings = FALSE, recursive = TRUE)

# Alphabetical order (SORT_BY_MEAN=FALSE) keeps the same restaurant at the
# same vertical offset across all plots. PUB_RECENTER + PUB_WIDE route the
# sub-renderer output to the "_recentered_wide" suffixed dirs (no "_sorted",
# since SORT_BY_MEAN=FALSE here) — distinct from professional_wide's
# "_sorted_recentered_wide" dirs (SORT_BY_MEAN=TRUE there), so nothing is
# clobbered between the two pipelines.
Sys.setenv(SORT_BY_MEAN  = "FALSE")
Sys.setenv(LABELED_MODE  = "TRUE")
Sys.setenv(LABELED_V2    = "TRUE")
Sys.setenv(PUB_RECENTER  = "TRUE")
Sys.setenv(PUB_WIDE      = "TRUE")

# ADJ_FIXED: read the corrected extraction (forest_data_adj_95ci_fixed.csv,
# posterior medians, exact q16/q84) instead of the retired
# forest_data_adj_95ci.csv, whose restaurant rows are largely raw/unadjusted
# (Bug 1 -- see publication/PIPELINE.md sec 5). This used to be unset here, so
# labeled_v2 was rendering the retired numbers.
# Override with ADJ_FIXED=FALSE to reproduce the old output.
if (!nzchar(Sys.getenv("ADJ_FIXED"))) Sys.setenv(ADJ_FIXED = "TRUE")
.fx <- if (toupper(Sys.getenv("ADJ_FIXED", "FALSE")) == "TRUE") "_fixed" else ""

# The sub-renderers append "_fixed" to their output dir under ADJ_FIXED, so the
# copy step below has to look in the same place or it silently copies stale PDFs.
SOURCE_DIR_T1 <- paste0("archive/forest_plots/total_adjusted/t1_recentered_wide", .fx)
SOURCE_DIR_T2 <- paste0("archive/forest_plots/total_adjusted/t2_recentered_wide", .fx)

# CLI arg 1: optional analysis name
.cli_args <- commandArgs(trailingOnly = TRUE)
.cli  <- toupper(.cli_args[1])
.only <- if (length(.cli) && !is.na(.cli) && nzchar(.cli)) .cli else "ALL"
if (!.only %in% c("ALL", "A1", "A2", "A3", "A4", "A5", "A6"))
  stop("PRO_ONLY must be ALL or A1..A6 (got: ", .only, ")")
Sys.setenv(PRO_ONLY = .only)
if (.only != "ALL") Sys.setenv(PRO_FAST = "TRUE")

# CLI arg 2: optional tier selector
.cli_tier <- toupper(.cli_args[2])
.tier <- if (length(.cli_tier) && !is.na(.cli_tier) && nzchar(.cli_tier)) .cli_tier else "BOTH"
if (!.tier %in% c("BOTH", "T1", "T2"))
  stop("PRO_TIER must be BOTH, T1, or T2 (got: ", .tier, ")")

cat("\n[render_professional_labeled_v2] PRO_ONLY=", .only,
    " PRO_TIER=", .tier,
    " LABELED_MODE=TRUE LABELED_V2=TRUE SORT_BY_MEAN=FALSE",
    " PUB_RECENTER=TRUE PUB_WIDE=TRUE\n", sep = "")

# Decide which sub-renderers to source.
.run_recolored_t1 <- (.tier %in% c("BOTH", "T1")) && (.only %in% c("ALL", "A1", "A2", "A3", "A4"))
.run_recolored_t2 <- (.tier %in% c("BOTH", "T2")) && (.only %in% c("ALL", "A1", "A2", "A3", "A4"))
.run_consolid     <- .only %in% c("ALL", "A5", "A6")

if (.run_recolored_t1) {
  cat("\n[render_professional_labeled_v2] Step 1a: render T1 A1-A4 (labeled v2)\n")
  source("publication/render/create_forest_plots_restaurants_chosen_recolored_adj.R",
         chdir = FALSE)
}

if (.run_recolored_t2) {
  cat("\n[render_professional_labeled_v2] Step 1b: render T2 A1-A4 (labeled v2)\n")
  source("publication/render/create_forest_plots_restaurants_chosen_recolored_adj_t2.R",
         chdir = FALSE)
}

if (.run_consolid) {
  cat("\n[render_professional_labeled_v2] Step 2: render A5/A6 day-level adj (labeled v2, both tiers)\n")
  .tier_saved <- .tier
  source("publication/render/create_customer_day_forest_plots_consolidated.R",
         chdir = FALSE)
  .tier <- .tier_saved
}

# -------------------------------------------------------------------
# File stems for each analysis.
# With SORT_BY_MEAN=FALSE + PUB_RECENTER + PUB_WIDE the renderers write to
# the "_recentered_wide" (no "_sorted") dirs:
#   archive/forest_plots/total_adjusted/t1_recentered_wide/
#   archive/forest_plots/total_adjusted/t2_recentered_wide/
# A5/A6 day-level use the same routing (see .sfx_adj in consolidated.R).
# -------------------------------------------------------------------
EXPECTED_STEMS_ALL <- c(
  A1 = "A1_proportion_forest_restaurants",
  A2 = "A2_proportion_targeted_forest_restaurants",
  A3 = "A3_its_forest_restaurants",
  A4 = "A4_its_targeted_forest_restaurants",
  A5 = "A5_gaussian_iid_day_forest_restaurants_adj",
  A6 = "A6_gaussian_iid_day_targeted_forest_restaurants_adj"
)
# PUB_WIDE also splits T2 A1 (per exposure group) and T2 A3 (animal /
# plant-based) into several pages — see the .splits loops in the T2 renderer.
EXPECTED_STEMS_T1 <- EXPECTED_STEMS_ALL
EXPECTED_STEMS_T2 <- modifyList(as.list(EXPECTED_STEMS_ALL), list(
  A1 = paste0("A1", c("a", "b", "c"), "_proportion_forest_restaurants"),
  A3 = paste0("A3", c("a", "b"),      "_its_forest_restaurants")
))
.stems_for <- function(all) unname(unlist(if (.only == "ALL") all else all[.only]))
EXPECTED_STEMS_T1 <- .stems_for(as.list(EXPECTED_STEMS_T1))
EXPECTED_STEMS_T2 <- .stems_for(EXPECTED_STEMS_T2)

# -------------------------------------------------------------------
# Helper: copy PDFs from source dir to destination dir.
# -------------------------------------------------------------------
copy_pdfs <- function(stems, src_dir, dst_dir, tier_label) {
  copied  <- character(0)
  missing <- character(0)
  cat("\n[render_professional_labeled_v2] Copy PDFs ->", dst_dir, "\n")
  for (stem in stems) {
    src <- file.path(src_dir, paste0(stem, ".pdf"))
    dst <- file.path(dst_dir, paste0(stem, ".pdf"))
    if (file.exists(src)) {
      ok <- file.copy(src, dst, overwrite = TRUE)
      if (ok) {
        copied <- c(copied, dst)
        cat("  [", tier_label, "] copied: ", basename(dst), "\n", sep = "")
      } else {
        missing <- c(missing, dst)
        cat("  [", tier_label, "] FAILED COPY: ", src, "\n", sep = "")
      }
      # PNG counterpart of the same plot, into a png/ subfolder rather than
      # alongside the PDFs, so the tier folder stays a clean list of the
      # deliverable PDFs. Every render writes the .png next to the .pdf in the
      # working tree, so this needs no extra rendering -- only the copy.
      src_png <- file.path(src_dir, paste0(stem, ".png"))
      if (file.exists(src_png)) {
        png_dir <- file.path(dst_dir, "png")
        dir.create(png_dir, showWarnings = FALSE, recursive = TRUE)
        if (file.copy(src_png, file.path(png_dir, paste0(stem, ".png")), overwrite = TRUE))
          cat("  [", tier_label, "] copied: png/", stem, ".png\n", sep = "")
      }
    } else {
      missing <- c(missing, src)
      cat("  [", tier_label, "] MISSING SOURCE: ", src, "\n", sep = "")
    }
  }
  list(copied = copied, missing = missing)
}

# -------------------------------------------------------------------
# Step 3: copy PDFs into professional_labeled_v2/ dirs.
# -------------------------------------------------------------------
all_copied  <- character(0)
all_missing <- character(0)

if (.tier %in% c("BOTH", "T1")) {
  r <- copy_pdfs(EXPECTED_STEMS_T1, SOURCE_DIR_T1, LABELED_DIR_T1, "T1")
  all_copied  <- c(all_copied,  r$copied)
  all_missing <- c(all_missing, r$missing)
}

if (.tier %in% c("BOTH", "T2")) {
  r <- copy_pdfs(EXPECTED_STEMS_T2, SOURCE_DIR_T2, LABELED_DIR_T2, "T2")
  all_copied  <- c(all_copied,  r$copied)
  all_missing <- c(all_missing, r$missing)
}

# -------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------
expected_total <- (if (.tier %in% c("BOTH", "T1")) length(EXPECTED_STEMS_T1) else 0) +
                  (if (.tier %in% c("BOTH", "T2")) length(EXPECTED_STEMS_T2) else 0)
cat("\n=========================================\n")
cat("Professional-labeled-v2 render complete.\n")
if (.tier %in% c("BOTH", "T1")) cat("T1 output dir: ", LABELED_DIR_T1, "\n", sep = "")
if (.tier %in% c("BOTH", "T2")) cat("T2 output dir: ", LABELED_DIR_T2, "\n", sep = "")
cat("Files copied: ", length(all_copied), " / ", expected_total, "\n", sep = "")
if (length(all_missing)) {
  cat("Missing: ", length(all_missing), "\n", sep = "")
  for (m in all_missing) cat("  - ", m, "\n", sep = "")
}
cat("=========================================\n")

invisible(NULL)

#!/usr/bin/env Rscript
# render_professional_recentered.R
# ----------------------------------------------------------------------
# "Recentered" (percentage-scale) counterpart to render_professional.R.
# Produces the same 6 PDFs per tier (A1-A6), but with the RR (rate-ratio)
# x-axis remapped to percentage change relative to 1 (RR=1 -> "0%"),
# via the PUB_RECENTER env-var switch consumed by publication_theme.R and
# the create_*.R sub-renderers.
#
# Output directories:
#   archive/forest_plots/professional_recentered/t1_adj/   (6 PDFs)
#   archive/forest_plots/professional_recentered/t2_adj/   (6 PDFs)
#
# Inputs (sourced for their plotting logic):
#   - create_forest_plots_restaurants_chosen_recolored_adj.R     (T1 A1–A4)
#   - create_forest_plots_restaurants_chosen_recolored_adj_t2.R  (T2 A1–A4)
#   - create_customer_day_forest_plots_consolidated.R            (both A5/A6)
#
# Note: A5/A6 are Gaussian-identity-link plots (demeaned per-transaction
# counts), not rate ratios — there is no RR-to-percent mapping to apply, so
# their appearance is unchanged. Only their output directory is routed to
# the "_recentered" suffix so this script can collect all 6 PDFs per tier.
#
# CLI arguments (same as render_professional.R):
#   Arg 1 — PRO_ONLY: restrict to one analysis (A1..A6 or ALL, default ALL)
#   Arg 2 — PRO_TIER: restrict to one tier (T1, T2, or BOTH, default BOTH)
#
# Examples:
#   Rscript render_professional_recentered.R          # render everything
#   Rscript render_professional_recentered.R A3       # only A3 for both tiers
#   Rscript render_professional_recentered.R ALL T2   # all analyses, T2 only
#   Rscript render_professional_recentered.R A1 T1    # A1 for T1 only
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

PROFESSIONAL_DIR_T1 <- "archive/forest_plots/professional_recentered/t1_adj"
PROFESSIONAL_DIR_T2 <- "archive/forest_plots/professional_recentered/t2_adj"
dir.create(PROFESSIONAL_DIR_T1, showWarnings = FALSE, recursive = TRUE)
dir.create(PROFESSIONAL_DIR_T2, showWarnings = FALSE, recursive = TRUE)

# Professional plots always sort restaurant-level estimates by their mean
# (largest at the top within each outcome). PUB_RECENTER=TRUE switches the
# x-axis/pooled-label formatting to percentage-change and routes the
# sub-renderer output to a "_recentered" suffixed directory.
Sys.setenv(SORT_BY_MEAN = "TRUE", PUB_RECENTER = "TRUE")
SOURCE_DIR_T1 <- "archive/forest_plots/total_adjusted/t1_sorted_recentered"
SOURCE_DIR_T2 <- "archive/forest_plots/total_adjusted/t2_sorted_recentered"

# CLI arg 1: optional analysis name to render only one (e.g. "A3").
# Default: render all 6.  When a single analysis is selected, also enable
# PRO_FAST so the renderer skips PNG, plotly conversion, HTML widget,
# and log-scale overlays — PDF only.  Cuts render time dramatically.
.cli_args <- commandArgs(trailingOnly = TRUE)
.cli  <- toupper(.cli_args[1])
.only <- if (length(.cli) && !is.na(.cli) && nzchar(.cli)) .cli else "ALL"
if (!.only %in% c("ALL", "A1", "A2", "A3", "A4", "A5", "A6"))
  stop("PRO_ONLY must be ALL or A1..A6 (got: ", .only, ")")
Sys.setenv(PRO_ONLY = .only)
if (.only != "ALL") Sys.setenv(PRO_FAST = "TRUE")

# CLI arg 2: optional tier selector (T1, T2, or BOTH). Default: BOTH.
.cli_tier <- toupper(.cli_args[2])
.tier <- if (length(.cli_tier) && !is.na(.cli_tier) && nzchar(.cli_tier)) .cli_tier else "BOTH"
if (!.tier %in% c("BOTH", "T1", "T2"))
  stop("PRO_TIER must be BOTH, T1, or T2 (got: ", .tier, ")")

cat("\n[render_professional_recentered] PRO_ONLY=", .only,
    " PRO_TIER=", .tier,
    " PRO_FAST=", Sys.getenv("PRO_FAST", "FALSE"), "\n", sep = "")

# Decide which sub-renderers to source.  A1-A4 live in recolored_adj.R (per
# tier); A5/A6 day-level live in consolidated.R (produces both tiers at once).
.run_recolored_t1 <- (.tier %in% c("BOTH", "T1")) && (.only %in% c("ALL", "A1", "A2", "A3", "A4"))
.run_recolored_t2 <- (.tier %in% c("BOTH", "T2")) && (.only %in% c("ALL", "A1", "A2", "A3", "A4"))
.run_consolid     <- .only %in% c("ALL", "A5", "A6")

if (.run_recolored_t1) {
  cat("\n[render_professional_recentered] Step 1a: render T1 A1–A4\n")
  source("publication/render/create_forest_plots_restaurants_chosen_recolored_adj.R",
         chdir = FALSE)
}

if (.run_recolored_t2) {
  cat("\n[render_professional_recentered] Step 1b: render T2 A1–A4\n")
  source("publication/render/create_forest_plots_restaurants_chosen_recolored_adj_t2.R",
         chdir = FALSE)
}

if (.run_consolid) {
  cat("\n[render_professional_recentered] Step 2: render A5/A6 day-level adj (both tiers)\n")
  # NOTE: consolidated.R assigns .tier/.step/.cfg/etc. in a for-loop at top
  # level, which pollutes the calling environment.  Save and restore .tier so
  # the copy logic below still sees the user-requested tier.
  .tier_saved <- .tier
  source("publication/render/create_customer_day_forest_plots_consolidated.R",
         chdir = FALSE)
  .tier <- .tier_saved
}

# -------------------------------------------------------------------
# File stems for each analysis. A5/A6 have an _adj suffix in the
# day-level sorted dir.
# -------------------------------------------------------------------
EXPECTED_STEMS_ALL <- c(
  A1 = "A1_proportion_forest_restaurants",
  A2 = "A2_proportion_targeted_forest_restaurants",
  A3 = "A3_its_forest_restaurants",
  A4 = "A4_its_targeted_forest_restaurants",
  A5 = "A5_gaussian_iid_day_forest_restaurants_adj",
  A6 = "A6_gaussian_iid_day_targeted_forest_restaurants_adj"
)
EXPECTED_STEMS <- if (.only == "ALL") EXPECTED_STEMS_ALL else EXPECTED_STEMS_ALL[[.only]]

# -------------------------------------------------------------------
# Helper: copy PDFs from a source dir to a destination dir.
# -------------------------------------------------------------------
copy_pdfs <- function(stems, src_dir, dst_dir, tier_label) {
  copied  <- character(0)
  missing <- character(0)
  cat("\n[render_professional_recentered] Copy PDFs ->", dst_dir, "\n")
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
    } else {
      missing <- c(missing, src)
      cat("  [", tier_label, "] MISSING SOURCE: ", src, "\n", sep = "")
    }
  }
  list(copied = copied, missing = missing)
}

# -------------------------------------------------------------------
# Step 3: copy PDFs into professional_recentered/ dirs.
# -------------------------------------------------------------------
all_copied  <- character(0)
all_missing <- character(0)

if (.tier %in% c("BOTH", "T1")) {
  r <- copy_pdfs(EXPECTED_STEMS, SOURCE_DIR_T1, PROFESSIONAL_DIR_T1, "T1")
  all_copied  <- c(all_copied,  r$copied)
  all_missing <- c(all_missing, r$missing)
}

if (.tier %in% c("BOTH", "T2")) {
  r <- copy_pdfs(EXPECTED_STEMS, SOURCE_DIR_T2, PROFESSIONAL_DIR_T2, "T2")
  all_copied  <- c(all_copied,  r$copied)
  all_missing <- c(all_missing, r$missing)
}

# -------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------
expected_total <- length(EXPECTED_STEMS) * switch(.tier, BOTH = 2, T1 = 1, T2 = 1)
cat("\n=========================================\n")
cat("Professional (recentered) render complete.\n")
if (.tier %in% c("BOTH", "T1")) cat("T1 output dir: ", PROFESSIONAL_DIR_T1, "\n", sep = "")
if (.tier %in% c("BOTH", "T2")) cat("T2 output dir: ", PROFESSIONAL_DIR_T2, "\n", sep = "")
cat("Files copied: ", length(all_copied), " / ", expected_total, "\n", sep = "")
if (length(all_missing)) {
  cat("Missing: ", length(all_missing), "\n", sep = "")
  for (m in all_missing) cat("  - ", m, "\n", sep = "")
}
cat("=========================================\n")

invisible(NULL)

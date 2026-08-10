## estimate_accounting.R -- the funnel from design space to reported effects.
##
## One row per stage, read top to bottom. Six columns: each tier split into
## primary / secondary outcomes plus a tier total.
##
## Primary   = nonvegan, meat, chicken & fish, and every counterpart-specific
##             outcome (breakfast, ground, whole-muscle, chicken, dairy, egg)
## Secondary = vegetarian, vegan
##
## That split is not cosmetic: it is what makes the A1-A4 primary count equal the
## Bonferroni divisor, and primary + secondary equal the reported effect total.
##
## A5/A6 are distinguished by ROW, not by column, so the columns stay purely
## tier x outcome class.
##
## Usage: Rscript publication/scripts/estimate_accounting.R

suppressPackageStartupMessages({library(dplyr); library(stringr)})

CFG <- "publication/config/final_models.csv"
ADJ <- "publication/forest_data_adj_95ci_fixed.csv"
MD  <- "publication/ESTIMATE_ACCOUNTING.md"
TEX <- "publication/tables_final/estimate_accounting.tex"

SECONDARY <- c("vegetarian", "vegan")

cfg <- read.csv(CFG, stringsAsFactors = FALSE) %>%
  mutate(rep = reported %in% c(TRUE, "TRUE", "True"),
         cls = ifelse(outcome_key %in% SECONDARY, "S", "P"),
         blk = ifelse(grepl("a5|a6", table_id), "A5-A6", "A1-A4"))

adj <- read.csv(ADJ, stringsAsFactors = FALSE) %>%
  mutate(tier = ifelse(grepl("^t2_", analysis), "T2", "T1"),
         cls  = ifelse(outcome %in% SECONDARY, "S", "P"))

## ---- cell helpers ------------------------------------------------------------
## Each row of the output is six numbers: T1 P/S/Total, T2 P/S/Total.
## `agg` is applied to a subset; totals are computed on the tier subset directly
## rather than summed, because distinct-count rows (models, denominators) do not
## add across classes.
six <- function(df, agg) {
  g <- function(t, c) {
    x <- if (is.null(c)) df[df$tier == t, ] else df[df$tier == t & df$cls == c, ]
    agg(x)
  }
  c(g("T1","P"), g("T1","S"), g("T1",NULL), g("T2","P"), g("T2","S"), g("T2",NULL))
}

n_rows   <- function(x) nrow(x)
n_fits   <- function(x) length(unique(x$fit_dir))
n_totals <- function(x) length(unique(x$total_dir))

ROWS <- list()
add <- function(section, label, vals, paper = "", note = "") {
  ROWS[[length(ROWS) + 1]] <<- list(section = section, label = label,
                                    vals = vals, paper = paper, note = note)
}

## ---- A. models ---------------------------------------------------------------
## The design space: every outcome crossed with every exposure, before any
## exclusion. Six general outcomes (nonvegan, meat, chicken & fish, vegetarian,
## vegan, total) and six counterpart classes (breakfast, ground, whole-muscle,
## chicken, dairy, egg). Counted as models, so an ITS set contributes one per
## outcome; the level and slope terms it yields are counted lower down.
##   A1 36 (6 general x 6 exposures)   A2 12 (6 classes x 2 exposures)
##   A3  6 (6 general)                 A4  6 (6 classes)
##   A5  6 (6 general)                 A6  6 (6 classes)          = 72
##   primary   18 + 12 + 3 + 6 + 3 + 6 = 48
##   secondary 18 +  0 + 3 + 0 + 3 + 0 = 24
add("Models", "Crossings in the design (A1-A6)", c(48, 24, 72, 48, 24, 72))

## Preregistered counts, from prereg.pdf "All Totals for Models" (pp. 26-27),
## with one arithmetic error corrected: the prereg lists A3 and A5 as 3 models
## each by counting only the primary outcomes, but both draw on A1's full set of
## six exactly as A1 does, so each is 6.
## The remaining gap to the design space is egg, which the prereg drops from A4
## and A6 because no MPBA analog for it was introduced (p. 23), taking both from
## 6 to 5 and the tier total from 72 to 70.
## Primary/secondary is itself preregistered (p. 12): the prereg's worked example
## of "18 coefficients of primary interest" is exactly A1's primary count.
add("Models", "Preregistered models", c(46, 24, 70, 46, 24, 70),
    paper = "prereg pp. 26-27, A3/A5 corrected")

## The prereg reports coefficient counts alongside model counts throughout
## ("3 models, 6 coefficients" for A3, "5 models, 10 coefficients" for A4). An
## ITS model yields two coefficients, a level and a slope; A1 and A2 yield one
## each. Applying the same A3/A5 correction as above, per tier:
##   A1 36 (18 P + 18 S)   A2 12 (12 P)
##   A3 12 ( 6 P +  6 S)   A4 10 (10 P)
##   A5 12 ( 6 P +  6 S)   A6 10 (10 P)                            = 92
##   primary   18 + 12 +  6 + 10 +  6 + 10 = 62
##   secondary 18 +  0 +  6 +  0 +  6 +  0 = 30
add("Models", "Preregistered estimates", c(62, 30, 92, 62, 30, 92),
    paper = "prereg pp. 20-25, A3/A5 corrected")
add("Models", "Outcome models fitted", six(cfg, n_fits))
add("Models", "Total-purchase models (denominators)", six(cfg, n_totals),
    note = "shared across outcome classes, so the tier total is not the sum")
mt <- six(cfg, n_fits) + six(cfg, n_totals) * c(0,0,1,0,0,1)
mt[c(1,2,4,5)] <- NA_integer_
add("Models", "Models fitted, total", mt,
    paper = "Methods: states 63 and 68")

## ---- B. estimates ------------------------------------------------------------
add("Estimates", "Pooled estimates attempted", six(cfg, n_rows))
add("Estimates", "  less: fewer than two restaurants",
    six(cfg %>% filter(!rep, suppress_reason == "fewer than two contributing restaurants"), n_rows))
add("Estimates", "  less: pooled outside restaurant range",
    six(cfg %>% filter(!rep, suppress_reason == "pooled outside both restaurant estimates"), n_rows))
add("Estimates", "Pooled estimates reported, all sets",
    six(cfg %>% filter(rep), n_rows))
add("Estimates", "  of which A1-A4",
    six(cfg %>% filter(rep, blk == "A1-A4"), n_rows),
    paper = "Methods: states 46 and 51")
add("Estimates", "  of which A5-A6",
    six(cfg %>% filter(rep, blk == "A5-A6"), n_rows))

## ---- C. presentation ---------------------------------------------------------
add("Presentation", "Unadjusted RRs in the tables", six(cfg %>% filter(rep), n_rows),
    paper = "Supplement tables")
add("Presentation", "Adjusted RRRs in the figures", six(cfg %>% filter(rep), n_rows),
    paper = "forest plots; diagram")
add("Presentation", "Restaurant-level estimates shown",
    six(adj %>% filter(level == "restaurant", type_fine %in% c("level","slope")), n_rows))

## ---- D. inference ------------------------------------------------------------
## The prereg (p. 12) commits to TWO correction levels, neither of which is the
## divisor the paper currently uses.
prim <- cfg %>% filter(cls == "P") %>% count(tier)
add("Inference", "Bonferroni divisor, across all 12 subanalyses (prereg)",
    c(NA, NA, sum(prim$n), NA, NA, sum(prim$n)),
    paper = "prereg p. 12",
    note = "every primary coefficient in both tiers, so one shared divisor")
div <- cfg %>% filter(rep, blk == "A1-A4", cls == "P") %>% count(tier)
add("Inference", "Bonferroni divisor used in the paper",
    c(div$n[div$tier=="T1"], NA, NA, div$n[div$tier=="T2"], NA, NA),
    paper = "Methods: 30",
    note = "reported primary estimates in A1-A4; matches neither prereg level")

sig <- cfg %>% filter(rep) %>%
  left_join(adj %>% filter(level == "pooled") %>%
              select(fit_dir, gamma_index, q2.5, q97.5),
            by = c("fit_dir", "gamma_index")) %>%
  filter(!is.na(q2.5), q2.5 > 0 | q97.5 < 0)
add("Inference", "Significant, uncorrected", six(sig, n_rows),
    paper = "Results text")
add("Inference", "Significant, after correction", rep(NA_integer_, 6),
    paper = "Results text",
    note = "needs posterior quantiles at alpha/m; the 95% CSV cannot answer this")

## ---- emit --------------------------------------------------------------------
HDR <- c("T1 primary", "T1 secondary", "T1 total",
         "T2 primary", "T2 secondary", "T2 total")
fmt <- function(v) ifelse(is.na(v), "--", format(v))

md <- c("# Estimate accounting", "",
        "From design space to reported effects, one row per stage.", "",
        paste0("**Primary** = nonvegan, meat, chicken & fish, and every ",
               "counterpart-specific outcome. **Secondary** = vegetarian, vegan."), "",
        "Rebuild: `Rscript publication/scripts/estimate_accounting.R`", "",
        paste0("| | ", paste(HDR, collapse = " | "), " | in the paper |"),
        paste0("|---|", paste(rep("---:", 6), collapse = "|"), "|---|"))
cur <- ""
for (r in ROWS) {
  if (r$section != cur) {
    md <- c(md, sprintf("| **%s** | | | | | | |", r$section)); cur <- r$section
  }
  lab <- if (nzchar(r$note)) sprintf("%s <sup>*</sup>", r$label) else r$label
  md  <- c(md, sprintf("| %s | %s | %s |", lab, paste(fmt(r$vals), collapse = " | "),
                       ifelse(nzchar(r$paper), r$paper, "")))
}
notes <- Filter(function(r) nzchar(r$note), ROWS)
if (length(notes)) {
  md <- c(md, "", "<sup>*</sup> Notes:", "")
  for (r in notes) md <- c(md, sprintf("- **%s** — %s", r$label, r$note))
}
writeLines(md, MD)

tex <- c("\\begin{table}[H]", "\\centering",
         "\\caption{Accounting of models and estimates}",
         "\\label{tab:estimate_accounting}",
         "\\begin{tabular}{lrrrrrrl}", "\\toprule",
         paste0(" & ", paste(HDR, collapse = " & "), " & In the paper \\\\"), "\\midrule")
cur <- ""
for (r in ROWS) {
  if (r$section != cur) {
    tex <- c(tex, sprintf("\\multicolumn{8}{l}{\\textit{%s}} \\\\", r$section)); cur <- r$section
  }
  tex <- c(tex, sprintf("\\quad %s & %s & %s \\\\", r$label,
                        paste(fmt(r$vals), collapse = " & "), r$paper))
}
tex <- c(tex, "\\bottomrule", "\\end{tabular}", "\\end{table}")
writeLines(tex, TEX)

message(sprintf("wrote %s and %s (%d rows)", MD, TEX, length(ROWS)))
for (r in ROWS) message(sprintf("  %-44s %s", r$label, paste(fmt(r$vals), collapse = "  ")))

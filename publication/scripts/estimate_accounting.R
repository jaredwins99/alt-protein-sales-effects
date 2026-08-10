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
add <- function(section, label, vals, paper = "", note = "", hl = integer(0)) {
  ROWS[[length(ROWS) + 1]] <<- list(section = section, label = label,
                                    vals = vals, paper = paper, note = note,
                                    hl = hl)
}

## ---- the funnel ---------------------------------------------------------------
## Six rows: design, then what was preregistered, then what is reported. Each
## level is given twice, as outcome-exposure pairings (models) and as estimates,
## because an ITS model yields two estimates -- a level and a slope -- while A1
## and A2 models yield one apiece.

## 1. The design space: every outcome crossed with every exposure, before any
## exclusion. Six general outcomes (nonvegan, meat, chicken & fish, vegetarian,
## vegan, total) and six counterpart classes (breakfast, ground, whole-muscle,
## chicken, dairy, egg).
##   A1 36  A2 12  A3 6  A4 6  A5 6  A6 6                          = 72
##   primary 18 + 12 + 3 + 6 + 3 + 6 = 48;  secondary 18 + 3 + 3   = 24
add("Design", "All possible outcome-exposure pairings (A1-A6)",
    c(48, 24, 72, 48, 24, 72))

## 2-3. Preregistered, from prereg.pdf pp. 20-27, with one arithmetic error
## corrected: the prereg lists A3 and A5 as 3 models each by counting only the
## primary outcomes, but both draw on A1's full set of six exactly as A1 does.
## The gap from 72 to 70 is egg, dropped from A4 and A6 because no MPBA analog
## for it was introduced (p. 23).
## Primary/secondary is itself preregistered (p. 12): the worked example of
## "18 coefficients of primary interest" is exactly A1's primary count.
add("Design", "Preregistered outcome-exposure pairings (A1-A6)",
    c(46, 24, 70, 46, 24, 70), paper = "prereg pp. 26-27")
## The primary analysis sets alone: A1 36 + A2 12 + A3 6 + A4 5 = 59
##   primary 18 + 12 + 3 + 5 = 38;  secondary 18 + 3 = 21
add("Design", "Preregistered outcome-exposure pairings (A1-A4)",
    c(38, 21, 59, 38, 21, 59), paper = "prereg pp. 26-27")
##   A1 36  A2 12  A3 12  A4 10  A5 12  A6 10                      = 92
add("Design", "Preregistered estimates (RRs)", c(62, 30, 92, 62, 30, 92),
    paper = "prereg pp. 20-25")

## 4-6. Reported. Pairings counts the distinct outcome models behind the reported
## estimates; the two estimate rows are equal by construction, since each
## reported RRR is one outcome RR minus its total-purchases RR.
rep_only <- cfg %>% filter(rep)

## The unadjusted and adjusted sides of the funnel count different things.
##
## Unadjusted: every model that contributes a rate ratio, which includes the
## total-purchases models. Those are outcomes in their own right -- the prereg
## lists total dish sales as a secondary outcome of A1 -- and each yields its own
## RR, so they are counted under secondary.
##
## Adjusted: an RRR consumes an outcome RR and a total RR, so an adjusted pairing
## is one outcome model against its denominator. The denominators are shared
## across many outcomes and so stop being counted separately here.
tot_n <- function(t, f) f(rep_only[rep_only$tier == t, ])
mods  <- function(x) n_distinct(x$total_dir)
coefs <- function(x) n_distinct(paste(x$total_dir, x$gamma_index))
## add the tier's own denominator count to that tier's secondary and total cells
add_tot <- function(v, f) {
  v[c(2, 3)] <- v[c(2, 3)] + tot_n("T1", f)
  v[c(5, 6)] <- v[c(5, 6)] + tot_n("T2", f)
  v
}

add("Reported", "Reported outcome-exposure pairings",
    add_tot(six(rep_only, n_fits), mods),
    note = "includes the total-purchases models, counted as secondary outcomes")
add("Reported", "Reported RRs",
    add_tot(six(rep_only, n_rows), coefs),
    paper = "Supplement tables")
add("Reported", "Reported adjusted outcome-exposure pairings",
    six(rep_only, n_fits),
    note = "primary cells are the Bonferroni divisors", hl = c(1, 4))
add("Reported", "Reported estimates (RRRs)", six(rep_only, n_rows),
    paper = "forest plots; diagram")

## ---- what did not survive ------------------------------------------------------
add("Not reported", "Suppressed: fewer than two restaurants",
    six(cfg %>% filter(!rep, suppress_reason == "fewer than two contributing restaurants"), n_rows))
add("Not reported", "Suppressed: pooled outside restaurant range",
    six(cfg %>% filter(!rep, suppress_reason == "pooled outside both restaurant estimates"), n_rows))
add("Not reported", "Reported estimates, A1-A4 only",
    six(cfg %>% filter(rep, blk == "A1-A4"), n_rows),
    paper = "Methods: states 46 and 51")
add("Not reported", "Reported estimates, A5-A6 only",
    six(cfg %>% filter(rep, blk == "A5-A6"), n_rows))

## ---- C. presentation ---------------------------------------------------------
add("Presentation", "Restaurant-level estimates shown",
    six(adj %>% filter(level == "restaurant", type_fine %in% c("level","slope")), n_rows))

## ---- D. inference ------------------------------------------------------------
## The prereg (p. 12) commits to two correction levels: within each subanalysis
## (A1 Tier One would be 18) and across all twelve. The second is the total
## preregistered primary coefficient count, 62 per tier.
add("Inference", "Bonferroni divisor, across all 12 subanalyses (prereg)",
    c(NA, NA, 124, NA, NA, 124),
    paper = "prereg p. 12",
    note = "one shared divisor over both tiers; the paper instead corrects within tier")

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
  v <- fmt(r$vals)
  if (length(r$hl)) v[r$hl] <- sprintf("**%s**", trimws(v[r$hl]))
  md  <- c(md, sprintf("| %s | %s | %s |", lab, paste(v, collapse = " | "),
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
  v <- fmt(r$vals)
  if (length(r$hl)) v[r$hl] <- sprintf("\\textbf{%s}", trimws(v[r$hl]))
  tex <- c(tex, sprintf("\\quad %s & %s & %s \\\\", r$label,
                        paste(v, collapse = " & "), r$paper))
}
tex <- c(tex, "\\bottomrule", "\\end{tabular}", "\\end{table}")
writeLines(tex, TEX)

message(sprintf("wrote %s and %s (%d rows)", MD, TEX, length(ROWS)))
for (r in ROWS) message(sprintf("  %-44s %s", r$label, paste(fmt(r$vals), collapse = "  ")))

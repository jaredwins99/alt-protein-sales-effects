## estimate_accounting.R -- the funnel from design space to what the paper uses.
##
## Five rows, each narrowing the one above:
##   1 All possible (A1-A6)        every outcome x every exposure, nothing excluded
##   2 Preregistered (A1-A6)       drops egg from A4/A6; no MPBA analog was introduced
##   3 Preregistered (A1-A4)       drops the within-customer sensitivity sets
##   4 Reported (A1-A4)            drops outcomes with no fitted counterpart
##   5 Reported, adjusted (A1-A4)  the RRRs the paper uses. Total purchases is
##                                 folded into each estimate as its denominator,
##                                 so it stops being an outcome of its own here,
##                                 and suppressed estimates drop out.
##
## Twelve columns: outcome-exposure pairings in the first six, estimates in the
## second six, each split T1/T2 x primary/secondary/total. An ITS pairing yields
## two estimates, a level and a slope; A1 and A2 pairings yield one apiece.
##
## Primary   = nonvegan, meat, chicken & fish, and the counterpart classes
## Secondary = vegetarian, vegan, total purchases
##
## Usage: Rscript publication/scripts/estimate_accounting.R

suppressPackageStartupMessages({library(dplyr)})

CFG <- "publication/config/final_models.csv"
MD  <- "publication/ESTIMATE_ACCOUNTING.md"
TEX <- "publication/tables_final/estimate_accounting.tex"

SECONDARY <- c("vegetarian", "vegan", "total")

cfg <- read.csv(CFG, stringsAsFactors = FALSE) %>%
  mutate(rep = reported %in% c(TRUE, "TRUE", "True"),
         cls = ifelse(outcome_key %in% SECONDARY, "S", "P")) %>%
  filter(!grepl("a5|a6", table_id))

ROWS <- list()
add <- function(label, pair, est, hl = integer(0)) {
  ROWS[[length(ROWS) + 1]] <<- list(label = label, vals = c(pair, est), hl = hl)
}

## ---- rows 1-3: from the preregistration ----------------------------------------
## Identical across tiers, since the design does not vary by tier -- only which
## restaurants are eligible does.
##
##                     pairings              estimates
##                 P    S  tot          P    S  tot
##   A1 6x6       18   18   36         18   18   36
##   A2 6 cls x2  12    0   12         12    0   12
##   A3 6 out      3    3    6          6    6   12
##   A4 6 cls      6    0    6         12    0   12
##   A5 6 out      3    3    6          6    6   12
##   A6 6 cls      6    0    6         12    0   12
##   -------------------------------------------------
##   A1-A6        48   24   72         66   30   96
##   prereg       46   24   70         62   30   92   (A4/A6 lose egg)
##   prereg A1-A4 38   21   59         46   24   70
add("All possible (A1-A6)",
    c(48, 24, 72, 48, 24, 72), c(66, 30, 96, 66, 30, 96))
add("Preregistered (A1-A6)",
    c(46, 24, 70, 46, 24, 70), c(62, 30, 92, 62, 30, 92))
add("Preregistered (A1-A4)",
    c(38, 21, 59, 38, 21, 59), c(46, 24, 70, 46, 24, 70))

## ---- rows 4-5: from the fits ----------------------------------------------------
six <- function(d, fn) {
  g <- function(t, c) {
    x <- if (is.null(c)) d[d$tier == t, ] else d[d$tier == t & d$cls == c, ]
    fn(x)
  }
  c(g("T1","P"), g("T1","S"), g("T1",NULL), g("T2","P"), g("T2","S"), g("T2",NULL))
}
n_pair <- function(x) n_distinct(x$fit_dir)
n_est  <- function(x) nrow(x)

## Row 4 counts every model fitted, total purchases included as an outcome in its
## own right -- which is what makes A1 come to 6 x 6 = 36.
add("Reported (A1-A4)", six(cfg, n_pair), six(cfg, n_est))

## Row 5 keeps only what survives suppression, and drops total as an outcome
## because it is now the denominator inside each RRR rather than a result.
rep_only <- cfg %>% filter(rep, outcome_key != "total")
add("Reported, adjusted (A1-A4)",
    six(rep_only, n_pair), six(rep_only, n_est), hl = c(7, 10))

## Row 6: the restaurant-level estimates drawn beneath each pooled marker. These
## are shown for every A1-A4 outcome, including ones whose pooled estimate was
## suppressed, so the set is wider than row 5. A pairing here is one model against
## one restaurant.
adj <- read.csv("publication/forest_data_adj_95ci_fixed.csv", stringsAsFactors = FALSE) %>%
  filter(level == "restaurant", type_fine %in% c("level", "slope"),
         !grepl("a5|a6", analysis), outcome != "total") %>%
  mutate(tier = ifelse(grepl("^t2_", analysis), "T2", "T1"),
         cls  = ifelse(outcome %in% SECONDARY, "S", "P"))
n_rest_pair <- function(x) n_distinct(paste(x$fit_dir, x$restaurant))
add("Restaurant-level (reported, adjusted)",
    six(adj, n_rest_pair), six(adj, n_est))

## ---- emit -----------------------------------------------------------------------
## One table per tier: label, then pairings P/S/total, then estimates P/S/total.
## T1 takes vals 1-3 and 7-9; T2 takes 4-6 and 10-12.
IDX <- list(T1 = c(1, 2, 3, 7, 8, 9), T2 = c(4, 5, 6, 10, 11, 12))
SUB <- c("Primary", "Secondary", "Total", "Primary", "Secondary", "Total")
CAP <- c(T1 = "Tier One", T2 = "Tier Two")
fmt <- function(v) ifelse(is.na(v), "--", format(v))

tier_tex <- function(tier) {
  idx <- IDX[[tier]]
  out <- c("\\begin{table}[H]", "\\centering",
           sprintf("\\caption{Accounting of models and estimates, %s}", CAP[[tier]]),
           sprintf("\\label{tab:estimate_accounting_%s}", tolower(tier)),
           "\\begin{tabular}{lrrrrrr}", "\\toprule",
           paste0(" & \\multicolumn{3}{c}{Outcome-exposure pairings}",
                  " & \\multicolumn{3}{c}{Estimates} \\\\"),
           "\\cmidrule(lr){2-4}\\cmidrule(lr){5-7}",
           paste0(" & ", paste(SUB, collapse = " & "), " \\\\"), "\\midrule")
  for (r in ROWS) {
    v <- fmt(r$vals[idx])
    h <- match(r$hl, idx); h <- h[!is.na(h)]
    if (length(h)) v[h] <- sprintf("\\textbf{%s}", trimws(v[h]))
    out <- c(out, sprintf("%s & %s \\\\", r$label, paste(v, collapse = " & ")))
  }
  c(out, "\\bottomrule", "\\end{tabular}",
    paste0("\\par\\smallskip\\footnotesize Pairings are outcome-exposure model ",
           "combinations; estimates count the level and slope terms an interrupted ",
           "time-series pairing yields separately. Total purchases is an outcome in ",
           "the first four rows and is folded into each ratio of rate ratios as its ",
           "denominator in the last. Bold marks the Bonferroni divisor."),
    "\\end{table}")
}

tier_md <- function(tier) {
  idx <- IDX[[tier]]
  out <- c(paste0("| | pairings | | | estimates | | |"),
           paste0("| | ", paste(SUB, collapse = " | "), " |"),
           paste0("|---|", paste(rep("---:", 6), collapse = "|"), "|"))
  for (r in ROWS) {
    v <- fmt(r$vals[idx])
    h <- match(r$hl, idx); h <- h[!is.na(h)]
    if (length(h)) v[h] <- sprintf("**%s**", trimws(v[h]))
    out <- c(out, sprintf("| %s | %s |", r$label, paste(v, collapse = " | ")))
  }
  out
}

for (tier in c("T1", "T2"))
  writeLines(tier_tex(tier),
             sprintf("publication/tables_final/estimate_accounting_%s.tex", tolower(tier)))

md <- c("# Estimate accounting", "",
        "Each row narrows the one above. Outcome-exposure pairings on the left,",
        "estimates on the right -- an interrupted time-series pairing yields two",
        "estimates, a level and a slope, while A1 and A2 pairings yield one apiece.", "",
        "**Primary** = nonvegan, meat, chicken & fish, and the counterpart classes.  ",
        "**Secondary** = vegetarian, vegan, total purchases.", "",
        "Total purchases is an outcome in the first four rows; in the last it is",
        "folded into each RRR as the denominator rather than reported in its own",
        "right. Bold marks the Bonferroni divisor.", "",
        "Rebuild: `Rscript publication/scripts/estimate_accounting.R`", "", "---", "")
for (tier in c("T1", "T2")) {
  md <- c(md, sprintf("## %s", CAP[[tier]]), "", tier_md(tier), "",
          "```latex", tier_tex(tier), "```", "")
}
writeLines(md, MD)

message(sprintf("wrote %s and two per-tier .tex files", MD))
for (r in ROWS)
  message(sprintf("  %-28s T1 %-20s T2 %s", r$label,
                  paste(fmt(r$vals[IDX$T1]), collapse = " "),
                  paste(fmt(r$vals[IDX$T2]), collapse = " ")))

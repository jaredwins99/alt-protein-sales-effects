## final_tables.R -- Supplement result tables.
##
## The tables report the UNADJUSTED rate ratio (RR) for each estimate: the raw
## outcome-model mu_gamma, undifferenced. The forest plots report the ADJUSTED
## ratio of rate ratios (RRR) for the same estimates, so the two carry different
## information about the same underlying construct and the reader can see both.
##
## WHICH estimates appear, and in WHAT order, is not decided here -- it comes from
## publication/config/final_models.csv, built by build_final_models.R from the
## renderers' own rules. Tables and figures therefore cannot disagree on membership.
##
## RR values are read from two places, keyed on (fit_dir, gamma_index):
##   publication/forest_data_rr_95ci.csv  -- refit generations (extract_rr_95ci.R)
##   publication/forest_data_95ci.csv     -- everything not refit since May
##
## Usage: Rscript publication/scripts/final_tables.R

suppressPackageStartupMessages({library(dplyr); library(stringr); library(tidyr)})

CFG    <- "publication/config/final_models.csv"
RR_NEW <- "publication/forest_data_rr_95ci.csv"
RR_OLD <- "publication/forest_data_95ci.csv"
OUT    <- "publication/tables_final"
dir.create(OUT, showWarnings = FALSE)

if (!file.exists(CFG)) stop("missing ", CFG, " -- run build_final_models.R first")
cfg <- read.csv(CFG, stringsAsFactors = FALSE) %>% filter(reported)

## ---- assemble the RR lookup --------------------------------------------------
rr <- tibble(fit_dir = character(), gamma_index = integer(),
             median = numeric(), q2.5 = numeric(), q97.5 = numeric(),
             rr_source = character())

if (file.exists(RR_OLD)) {
  old <- read.csv(RR_OLD, stringsAsFactors = FALSE) %>%
    filter(type_fine == "pooled_mu_gamma") %>%
    mutate(gamma_index = as.integer(str_extract(variable, "\\d+")),
           rr_source = "forest_data_95ci.csv") %>%
    select(fit_dir, gamma_index, median, q2.5, q97.5, rr_source)
  rr <- bind_rows(rr, old)
}
if (file.exists(RR_NEW)) {
  new <- read.csv(RR_NEW, stringsAsFactors = FALSE) %>%
    mutate(rr_source = "forest_data_rr_95ci.csv") %>%
    select(fit_dir, gamma_index, median, q2.5, q97.5, rr_source)
  # the refit extraction wins wherever both carry a fit
  rr <- bind_rows(new, rr %>% anti_join(new, by = c("fit_dir", "gamma_index")))
} else {
  message("NOTE: ", RR_NEW, " absent -- refit generations will render as TBD.\n",
          "      Produce it on Windows with: Rscript publication/scripts/extract_rr_95ci.R")
}
rr <- rr %>% distinct(fit_dir, gamma_index, .keep_all = TRUE)

## ---- join and transform ------------------------------------------------------
## exp(x) except the A1 proportion exposure, which is a 10-percentage-point step.
## Presence is a 0/1 indicator, so plain exp. A5/A6 use an identity link.
tf <- function(x, k) ifelse(k == "identity", x, ifelse(k == "exp_p10", exp(0.1 * x), exp(x)))

dat <- cfg %>%
  left_join(rr, by = c("fit_dir", "gamma_index")) %>%
  mutate(cell = ifelse(is.na(median), "TBD",
                       sprintf("%.3f [%.3f, %.3f]",
                               tf(median, transform), tf(q2.5, transform),
                               tf(q97.5, transform))))

miss <- dat %>% filter(cell == "TBD")
if (nrow(miss)) {
  message(sprintf("%d of %d reported cells have no RR yet:", nrow(miss), nrow(dat)))
  miss %>% count(table_id, name = "n") %>%
    mutate(l = sprintf("   %-6s %d", table_id, n)) %>% pull(l) %>% cat(sep = "\n")
  cat("\n")
}

CAPTION <- c(t1_a1="Tier One A1", t1_a2="Tier One A2", t1_a3="Tier One A3",
             t1_a4="Tier One A4", t2_a1="Tier Two A1", t2_a2="Tier Two A2",
             t2_a3="Tier Two A3", t2_a4="Tier Two A4", t1_a5="Tier One A5",
             t1_a6="Tier One A6", t2_a5="Tier Two A5", t2_a6="Tier Two A6")
TAG <- c(t1_a1="tab:rr_t1_a1", t1_a2="tab:rr_t1_a2", t1_a3="tab:rr_t1_a3",
         t1_a4="tab:rr_t1_a4", t2_a1="tab:rr_t2_a1", t2_a2="tab:rr_t2_a2",
         t2_a3="tab:rr_t2_a3", t2_a4="tab:rr_t2_a4", t1_a5="tab:a5_mu_gamma",
         t1_a6="tab:a6_mu_gamma", t2_a5="tab:t2_a5_mu_gamma", t2_a6="tab:t2_a6_mu_gamma")

tex_escape <- function(s) gsub("&", "\\\\&", s, fixed = FALSE)

emit <- function(tid) {
  x <- dat %>% filter(table_id == tid)
  if (!nrow(x)) { message(sprintf("  %-6s EMPTY", tid)); return(invisible(NULL)) }
  by_expo <- any(!is.na(x$exposure) & nzchar(x$exposure))
  cols <- x %>% distinct(column, column_order) %>% arrange(column_order) %>% pull(column)

  keys <- c("outcome_label", "outcome_order", if (by_expo) "exposure")
  dup  <- x %>% count(across(all_of(c(keys, "column")))) %>% filter(n > 1)
  if (nrow(dup)) stop(sprintf("%s: %d duplicated cells", tid, nrow(dup)))

  w <- x %>% select(all_of(keys), column, cell) %>%
    pivot_wider(names_from = column, values_from = cell)
  for (cc in cols) if (!cc %in% names(w)) w[[cc]] <- NA_character_
  w <- w %>%
    mutate(across(all_of(cols), ~ifelse(is.na(.x), "---", .x))) %>%
    arrange(if (by_expo) factor(exposure,
              levels = c("Alt-Protein-Modifiable","Vegan","Vegetarian")) else outcome_order,
            outcome_order)

  ocols <- c("outcome_label", if (by_expo) "exposure", cols)
  hdr   <- c("Outcome", if (by_expo) "Exposure", cols)
  algn  <- paste0(if (by_expo) "ll" else "l", strrep("c", length(cols)))
  body  <- apply(w[, ocols], 1, function(r)
                   paste0(paste(tex_escape(r), collapse = " & "), " \\\\"))

  unit <- if (tid %in% c("t1_a1","t2_a1"))
    " Count: per additional menu item; Proportion: per 10-percentage-point increase." else ""
  scale_note <- if (grepl("a5|a6", tid))
    "Pooled unadjusted customer-level effects (identity link) with 95\\% credible intervals."
  else
    "Pooled unadjusted rate ratios with 95\\% credible intervals."
  note <- paste0(scale_note, unit,
    " These are the outcome-model effects on their own; the corresponding figures show them",
    " adjusted for total purchases, as ratios of rate ratios. Estimates backed by fewer than",
    " two contributing restaurants are not pooled and are shown as ---.")

  tex <- c("\\begin{table}[H]", "\\centering",
           sprintf("\\caption{Pooled unadjusted rate ratios, %s}", CAPTION[[tid]]),
           sprintf("\\label{%s}", TAG[[tid]]),
           sprintf("\\begin{tabular}{%s}", algn), "\\toprule",
           paste0(paste(hdr, collapse = " & "), " \\\\"), "\\midrule",
           body, "\\bottomrule", "\\end{tabular}",
           sprintf("\\par\\smallskip\\footnotesize %s", note), "\\end{table}")
  writeLines(tex, file.path(OUT, paste0(tid, ".tex")))
  message(sprintf("  %-6s %d rows", tid, nrow(w)))
  invisible(w)
}

invisible(lapply(names(CAPTION), emit))

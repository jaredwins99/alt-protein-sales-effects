## final_tables.R -- Supplement result tables, generated under the SAME rules the
## forest plots use, so the tables and figures can never disagree.
##
## Source: publication/forest_data_adj_95ci_fixed.csv (the file the plots read).
## Every value is a ratio of rate ratios (RRR): the outcome-model effect minus the
## total-purchases effect, differenced draw-by-draw.
##
## Rules copied from create_forest_plots_restaurants_chosen_recolored_adj{,_t2}.R:
##   * point estimate is the posterior MEDIAN                       (plots use exp(median))
##   * pooled estimate suppressed when n_rest <= 1                  (renderer L759/L1184/L1727)
##   * T1 A2 breakfast-style meat / presence pooled suppressed      (renderer L1187)
##   * outcome order and labels taken from the renderers' `outcomes`/`all_outcomes`
##   * whole-muscle (textured) is not shown in A2 in either tier    (renderer L1047/L1120)
##
## Usage: Rscript publication/scripts/final_tables.R

suppressPackageStartupMessages({library(dplyr); library(stringr); library(tidyr)})

CSV <- "publication/forest_data_adj_95ci_fixed.csv"
OUT <- "publication/tables_final"
dir.create(OUT, showWarnings = FALSE)

d <- read.csv(CSV, stringsAsFactors = FALSE)

## ---- derive the exposure/effect column each row belongs to -------------------
d <- d %>%
  mutate(
    slug = sub("^.*/", "", fit_dir),
    col  = case_when(
      str_detect(slug, "_prop$")     ~ "Proportion",
      str_detect(slug, "_count$")    ~ "Count",
      str_detect(slug, "_presence$") ~ "Presence",
      type_fine == "level"           ~ "Level change",
      type_fine == "slope"           ~ "Slope change",
      TRUE                           ~ NA_character_
    ),
    # A1 additionally splits by which menu exposure drives the model
    expo = case_when(
      str_detect(slug, "^mpbamod")    ~ "Alt-Protein-Modifiable",
      str_detect(slug, "^vegan")      ~ "Vegan",
      str_detect(slug, "^vegetarian") ~ "Vegetarian",
      TRUE                            ~ NA_character_
    )
  ) %>%
  filter(!is.na(col), type_fine %in% c("level", "slope"))

## A1/A2 carry level+slope rows for the same fit; the menu-availability designs
## report the level term only.
d <- d %>% filter(!(analysis %in% c("a1_proportion", "t2_a1_proportion",
                                    "a2_proportion_t", "t2_a2_proportion_t") &
                    type_fine == "slope"))

## ---- suppression: pooled needs >= 2 contributing restaurants -----------------
n_rest <- d %>%
  filter(level == "restaurant") %>%
  group_by(analysis, outcome, col, expo) %>%
  summarise(n_rest = n_distinct(restaurant), .groups = "drop")

pooled <- d %>%
  filter(level == "pooled") %>%
  left_join(n_rest, by = c("analysis", "outcome", "col", "expo")) %>%
  filter(!is.na(n_rest), n_rest >= 2) %>%
  # renderer L1187: two contributing restaurants, both atypical on the control
  # series, so the pooled sits outside both restaurant estimates.
  filter(!(analysis == "a2_proportion_t" & outcome == "breakfast_p" &
           col == "Presence"))

## ---- display transform -------------------------------------------------------
## exp(x) everywhere except the A1 proportion exposure, which is a
## 10-percentage-point step. Presence is a 0/1 indicator -> plain exp.
## A5/A6 use an identity link (demeaned per-customer outcome), so no transform.
tf <- function(x, col, analysis) {
  ifelse(str_detect(analysis, "customer"), x,
    ifelse(col == "Proportion", exp(0.1 * x), exp(x)))
}

pooled <- pooled %>%
  mutate(est = tf(median, col, analysis),
         lo  = tf(q2.5,   col, analysis),
         hi  = tf(q97.5,  col, analysis),
         cell = sprintf("%.3f [%.3f, %.3f]", est, lo, hi))

## ---- outcome order and labels, copied from the renderers ---------------------
GEN <- c(nonvegan = "Nonvegan", meat = "Meat", chicken_fish = "Chicken \\& fish",
         vegetarian = "Vegetarian", vegan = "Vegan")
A2  <- c(breakfast_p = "Breakfast-style meat", untextured_p = "Ground meat",
         chicken_p = "Chicken", dairy_p = "Dairy", egg_p = "Egg")
A4T1 <- c(breakfast = "Breakfast-style meat", untextured = "Ground meat",
          textured = "Whole-muscle meat")
A4T2 <- c(breakfast_t2 = "Breakfast-style meat", dairy_t2 = "Dairy",
          textured_t2 = "Whole-muscle meat", untextured_t2 = "Ground meat")

SPEC <- list(
  list(id="t1_a1", an="a1_proportion",       lab=GEN,  cols=c("Count","Proportion"),
       by_expo=TRUE,  cap="Tier One A1",  tag="tab:rr_t1_a1"),
  list(id="t1_a2", an="a2_proportion_t",     lab=A2,   cols=c("Count","Presence"),
       by_expo=FALSE, cap="Tier One A2",  tag="tab:rr_t1_a2"),
  list(id="t1_a3", an="a3_its",              lab=GEN,  cols=c("Level change","Slope change"),
       by_expo=FALSE, cap="Tier One A3",  tag="tab:rr_t1_a3"),
  list(id="t1_a4", an="a4_its_t",            lab=A4T1, cols=c("Level change","Slope change"),
       by_expo=FALSE, cap="Tier One A4",  tag="tab:rr_t1_a4"),
  list(id="t2_a1", an="t2_a1_proportion",    lab=GEN,  cols=c("Count","Proportion"),
       by_expo=TRUE,  cap="Tier Two A1",  tag="tab:rr_t2_a1"),
  list(id="t2_a2", an="t2_a2_proportion_t",  lab=A2,   cols=c("Count","Presence"),
       by_expo=FALSE, cap="Tier Two A2",  tag="tab:rr_t2_a2"),
  list(id="t2_a3", an="t2_a3_its",           lab=GEN,  cols=c("Level change","Slope change"),
       by_expo=FALSE, cap="Tier Two A3",  tag="tab:rr_t2_a3"),
  list(id="t2_a4", an="t2_a4_its_t",         lab=A4T2, cols=c("Level change","Slope change"),
       by_expo=FALSE, cap="Tier Two A4",  tag="tab:rr_t2_a4"),
  list(id="t1_a5", an="a5_customer_day",     lab=GEN,  cols=c("Level change","Slope change"),
       by_expo=FALSE, cap="Tier One A5",  tag="tab:a5_mu_gamma"),
  list(id="t1_a6", an="a6_customer_t_day",   lab=A4T1, cols=c("Level change","Slope change"),
       by_expo=FALSE, cap="Tier One A6",  tag="tab:a6_mu_gamma"),
  list(id="t2_a5", an="t2_a5_customer_day",  lab=GEN,  cols=c("Level change","Slope change"),
       by_expo=FALSE, cap="Tier Two A5",  tag="tab:t2_a5_mu_gamma"),
  list(id="t2_a6", an="t2_a6_customer_t_day",lab=A4T2, cols=c("Level change","Slope change"),
       by_expo=FALSE, cap="Tier Two A6",  tag="tab:t2_a6_mu_gamma")
)

emit <- function(s) {
  x <- pooled %>% filter(analysis == s$an, outcome %in% names(s$lab), col %in% s$cols)
  if (!nrow(x)) { message(sprintf("  %-6s EMPTY", s$id)); return(invisible(NULL)) }
  x <- x %>% mutate(Outcome = factor(unname(s$lab[outcome]), levels = unname(s$lab)),
                    col = factor(col, levels = s$cols))
  # guard: a1/a3 carry rows under both mu_gamma_total and mu_gamma_total_subset.
  # They are disjoint today; if that ever changes, pivot_wider would silently
  # build list-columns instead of failing, so assert one row per cell.
  dup <- x %>% count(Outcome, col, expo) %>% filter(n > 1)
  if (nrow(dup)) stop(sprintf("%s: %d duplicated cells", s$id, nrow(dup)))

  keys <- if (s$by_expo) c("Outcome", "expo") else "Outcome"
  w <- x %>% select(all_of(keys), col, cell) %>%
    pivot_wider(names_from = col, values_from = cell) %>%
    arrange(if (s$by_expo) factor(expo, levels=c("Alt-Protein-Modifiable","Vegan","Vegetarian")) else Outcome,
            Outcome)
  for (cc in s$cols) if (!cc %in% names(w)) w[[cc]] <- NA_character_
  w <- w %>% mutate(across(all_of(s$cols), ~ifelse(is.na(.x), "---", .x)))

  hdr  <- if (s$by_expo) c("Outcome","Exposure",s$cols) else c("Outcome",s$cols)
  algn <- paste0(if (s$by_expo) "ll" else "l", strrep("c", length(s$cols)))
  body <- apply(w[, if (s$by_expo) c("Outcome","expo",s$cols) else c("Outcome",s$cols)], 1,
                function(r) paste0(paste(r, collapse = " & "), " \\\\"))

  note <- if (grepl("customer", s$an))
    "Pooled customer-level effects (identity link) with 95\\% credible intervals, adjusted for total purchases. Outcomes with fewer than two contributing restaurants have no pooled estimate and are omitted."
  else if (s$id %in% c("t1_a1","t2_a1"))
    "Ratios of rate ratios with 95\\% credible intervals, adjusted for total purchases. Count: per additional menu item; Proportion: per 10-percentage-point increase. Outcomes with fewer than two contributing restaurants have no pooled estimate and are omitted."
  else
    "Ratios of rate ratios with 95\\% credible intervals, adjusted for total purchases. Outcomes with fewer than two contributing restaurants have no pooled estimate and are omitted."

  tex <- c("\\begin{table}[H]", "\\centering",
           sprintf("\\caption{Pooled adjusted effects, %s}", s$cap),
           sprintf("\\label{%s}", s$tag),
           sprintf("\\begin{tabular}{%s}", algn), "\\toprule",
           paste0(paste(hdr, collapse = " & "), " \\\\"), "\\midrule",
           body, "\\bottomrule", "\\end{tabular}",
           sprintf("\\par\\smallskip\\footnotesize %s", note), "\\end{table}")
  writeLines(tex, file.path(OUT, paste0(s$id, ".tex")))
  message(sprintf("  %-6s %d rows -> %s/%s.tex", s$id, nrow(w), OUT, s$id))
  invisible(w)
}

invisible(lapply(SPEC, emit))

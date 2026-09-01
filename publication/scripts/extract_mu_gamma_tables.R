## Extract pooled mu_gamma rate ratios -> wide CSV + LaTeX tables.
##
## Reads publication/forest_data_95ci.csv and, under ADJ_FIXED=TRUE,
## publication/forest_data_adj_95ci_fixed.csv (the same source
## the forest plots render from), so tables, ordering, and values are
## guaranteed to match the published forest plots.
##
## For each analysis A1..A6 across T1 and T2, writes both:
##   publication/A<n>[_t2]_mu_gamma.{csv,tex}      (unadjusted, base)
##   publication/A<n>[_t2]_mu_gamma_adj.{csv,tex}  (total-adjusted)
##
## Outcome ordering matches the forest plot scripts exactly. T1 adjusted
## tables drop "total" (diff = 0 by construction; mirrors publication
## adj forest plots). T2 adjusted tables keep total.

# --- project root ---
find_project_root <- function(start = getwd()) {
  path <- normalizePath(start, mustWork = TRUE)
  repeat {
    if (file.exists(file.path(path, "README.md"))) return(path)
    parent <- dirname(path)
    if (parent == path) return(start)
    path <- parent
  }
}
setwd(find_project_root())

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(readr)
  library(tibble)
})

NONADJ_CSV <- "publication/forest_data_95ci.csv"
# Default ADJ_FIXED=TRUE, matching render_professional_labeled_v2.R. Under FALSE
# this reads the RETIRED extraction, whose restaurant rows are largely
# raw/unadjusted (Bug 1) -- that default silently produced the stale
# *_t2_mu_gamma_adj tables that were committed before 2026-09-01.
if (!nzchar(Sys.getenv("ADJ_FIXED"))) Sys.setenv(ADJ_FIXED = "TRUE")
ADJ_CSV    <- if (toupper(Sys.getenv("ADJ_FIXED","FALSE")) == "TRUE")
                "publication/forest_data_adj_95ci_fixed.csv" else
                "archive/superseded_forest_data/forest_data_adj_95ci.csv"

# --- ordering (matches forest plot scripts) ---
ORDER <- list(
  a1     = c("total","nonvegan","meat","chicken_fish","vegetarian","vegan"),
  a1_adj = c("nonvegan","meat","chicken_fish","vegetarian","vegan"),       # T1 adj drops total
  a1_t2  = c("total","nonvegan","meat","chicken_fish","vegetarian","vegan"),
  a2     = c("breakfast_p","chicken_p","dairy_p","egg_p","untextured_p"),
  a2_t2  = c("breakfast_p","chicken_p","dairy_p","egg_p","textured_p","untextured_p"),
  a3     = c("total","nonvegan","meat","chicken_fish","vegetarian","vegan"),
  a3_adj = c("nonvegan","meat","chicken_fish","vegetarian","vegan"),
  a3_t2  = c("total","nonvegan","meat","chicken_fish","vegetarian","vegan"),
  a4     = c("breakfast","textured","untextured"),
  a4_t2  = c("breakfast_t2","dairy_t2","textured_t2","untextured_t2"),
  a5     = c("total","nonvegan","meat","chicken_fish","vegan","vegetarian"),
  a5_adj = c("nonvegan","meat","chicken_fish","vegan","vegetarian"),
  a5_t2  = c("total","nonvegan","meat","chicken_fish","vegan","vegetarian"),
  a6     = c("breakfast","untextured"),
  a6_t2  = c("breakfast_t2","dairy_t2","textured_t2","untextured_t2")
)

EXPOSURE_GROUPS <- c("mpbamod","vegan","vegetarian")
EXPOSURE_GROUPS_LABELS <- c("Mpbamod","Vegan","Vegetarian")

# --- helpers ---
fmt    <- function(x, d = 3) formatC(x, format = "f", digits = d)
fmt_ci <- function(m, lo, hi, d = 3) {
  ifelse(is.na(m), "---",
         paste0(fmt(m, d), " [", fmt(lo, d), ", ", fmt(hi, d), "]"))
}

# parse a fit_dir into (analysis, outcome, exposure_or_NA).
# fit_dir = .../<root>/<analysis>/<outcome>[/<exposure>]
parse_fit_dir <- function(fit_dir) {
  parts <- str_split(fit_dir, "/", simplify = TRUE)
  n <- ncol(parts)
  # find the analysis column: the one immediately following the root dir.
  # roots are finalized_redone_trunc[_cp[2]]; analysis is one of a1.., t2_a1.., etc.
  ana_col <- which(grepl("^(t2_)?(a1_proportion|a2_proportion_t|a3_its|a4_its_t|a5_customer_day|a6_customer_t_day)$",
                         parts[1, ]))[1]
  if (is.na(ana_col)) return(tibble(analysis = NA, outcome = NA, exposure = NA))
  analysis <- parts[1, ana_col]
  outcome  <- if (ana_col + 1 <= n) parts[1, ana_col + 1] else NA
  exposure <- if (ana_col + 2 <= n && nzchar(parts[1, ana_col + 2])) parts[1, ana_col + 2] else NA
  tibble(analysis = analysis, outcome = outcome, exposure = exposure)
}

# vectorized version
parse_fit_dirs <- function(fit_dirs) {
  do.call(rbind, lapply(fit_dirs, parse_fit_dir))
}

# --- load CSVs and pre-parse paths ---
nonadj <- read_csv(NONADJ_CSV, show_col_types = FALSE)
adj    <- read_csv(ADJ_CSV,    show_col_types = FALSE)
# the ADJ_FIXED extraction omits the MCMC diagnostic columns; they are written
# to the CSV outputs only and never appear in the LaTeX, so backfill as NA
for (.c in c("rhat","ess_bulk","ess_tail")) if (!.c %in% names(adj)) adj[[.c]] <- NA_real_

cat("Loaded nonadj:", nrow(nonadj), "rows; adj:", nrow(adj), "rows\n")

nonadj <- bind_cols(nonadj, parse_fit_dirs(nonadj$fit_dir))
adj    <- adj %>% mutate(exposure = {
  parsed <- parse_fit_dirs(fit_dir)
  parsed$exposure
})

# Point estimate: median(exp(param)) = exp(median(param)) for monotonic exp.
# CI: 2.5/97.5 quantiles of exp(param) = exp of the same quantiles of param.
# So the column we report is the median of the rate-ratio scale.
#
#   nonadj: type_fine == "pooled_mu_gamma"; variable encodes index.
#           CSV has raw `median` column from fit$summary; transform it.
#   adj   : level    == "pooled";          gamma_index encodes index.
#           Adj rows are computed by normal-approx algebra on log scale
#           (mean of difference; combined variance), so mean == median by
#           construction. exp(mean) == exp(median) for those.
nonadj_pooled <- nonadj %>%
  filter(type_fine == "pooled_mu_gamma") %>%
  # the CSV's `transform` column tags presence exposures exp_p10, but presence is a
  # 0/1 indicator, not a 10-percentage-point step -- same bug as the adj branch
  mutate(transform = if_else(str_detect(fit_dir, "presence"), "exp", transform)) %>%
  mutate(gamma_index = as.integer(str_extract(variable, "\\d+")),
         Median_t = case_when(
           transform == "exp"      ~ exp(median),
           transform == "exp_p10"  ~ exp(0.1 * median),
           transform == "identity" ~ median,
           TRUE                    ~ NA_real_
         ),
         # recompute bounds from the raw quantiles rather than trusting the CSV's
         # precomputed q*_t, which were built with the uncorrected transform
         Q2.5_lo = case_when(
           transform == "exp"      ~ exp(q2.5),
           transform == "exp_p10"  ~ exp(0.1 * q2.5),
           transform == "identity" ~ q2.5,
           TRUE                    ~ NA_real_
         ),
         Q97.5_hi = case_when(
           transform == "exp"      ~ exp(q97.5),
           transform == "exp_p10"  ~ exp(0.1 * q97.5),
           transform == "identity" ~ q97.5,
           TRUE                    ~ NA_real_
         )) %>%
  transmute(analysis, outcome, exposure, gamma_index,
            Median_t = Median_t, Q2.5_t = Q2.5_lo, Q97.5_t = Q97.5_hi,
            rhat = rhat, transform = transform)

adj_pooled <- adj %>%
  filter(level == "pooled") %>%
  # carry `median` through when present: the ADJ_FIXED extraction reports the true
  # posterior median, and dropping it here silently forced the exp(mean) fallback
  transmute(analysis, outcome, exposure, gamma_index,
            mean = mean, median = if ("median" %in% names(.)) median else mean,
            q2.5 = q2.5, q97.5 = q97.5,
            rhat = rhat)

# Apply transform for adj rows. A1 distinguishes _count vs _prop; A2 distinguishes
# _count vs _presence. Only _prop takes the 10-percentage-point transform.
apply_adj_transform <- function(df, transform_kind) {
  # Prefer the posterior median when the extraction supplies it: the forest plots
  # plot exp(median), and the older normal-approx assumption mean == median does
  # not hold for the ADJ_FIXED extraction. Falls back to mean when absent.
  pt <- if ("median" %in% names(df)) df$median else df$mean
  if (transform_kind == "exp") {
    df %>% mutate(Median_t = exp(pt), Q2.5_t = exp(q2.5), Q97.5_t = exp(q97.5))
  } else if (transform_kind == "exp_p10") {
    df %>% mutate(Median_t = exp(0.1 * pt),
                  Q2.5_t   = exp(0.1 * q2.5),
                  Q97.5_t  = exp(0.1 * q97.5))
  } else { # identity
    df %>% mutate(Median_t = pt, Q2.5_t = q2.5, Q97.5_t = q97.5)
  }
}

# --- build wide tables per analysis layout ---

# A1 / A1_T2 layout: row = (Outcome, Exposure_Group); col = Count, Proportion
# Only mu_gamma[1] is the level effect for A1; [2] is a variance hyperparameter.
build_a1 <- function(rows, outcome_order, exposure_order = EXPOSURE_GROUPS) {
  rows <- rows %>%
    filter(gamma_index == 1) %>%
    mutate(
      exposure_group = str_match(exposure, "^(.*)_dishes_(count|prop)$")[, 2],
      exposure_type  = str_match(exposure, "^(.*)_dishes_(count|prop)$")[, 3],
      ci             = fmt_ci(Median_t, Q2.5_t, Q97.5_t)
    ) %>%
    filter(!is.na(exposure_group),
           outcome %in% outcome_order,
           exposure_group %in% exposure_order)

  long <- rows %>%
    transmute(Outcome = outcome, Exposure_Group = exposure_group,
              Exposure_Type = exposure_type,
              Median_t, Q2.5_t, Q97.5_t, Rhat = rhat, ci)

  wide <- long %>%
    select(Outcome, Exposure_Group, Exposure_Type, ci) %>%
    pivot_wider(names_from = Exposure_Type, values_from = ci) %>%
    rename(Count = count, Proportion = prop)

  long <- long %>%
    mutate(Outcome        = factor(Outcome, levels = outcome_order),
           Exposure_Group = factor(Exposure_Group, levels = exposure_order)) %>%
    arrange(Outcome, Exposure_Group) %>%
    mutate(Outcome = as.character(str_to_title(str_replace_all(Outcome, "_", " "))),
           Exposure_Group = as.character(str_to_title(Exposure_Group)))

  wide <- wide %>%
    mutate(.o_idx = match(Outcome, outcome_order),
           .e_idx = match(Exposure_Group, exposure_order)) %>%
    arrange(.o_idx, .e_idx) %>%
    mutate(Outcome        = str_to_title(str_replace_all(Outcome, "_", " ")),
           Exposure_Group = str_to_title(Exposure_Group)) %>%
    select(-.o_idx, -.e_idx)

  list(long = long, wide = wide)
}

# A2 / A2_T2 layout: row = Outcome (e.g., breakfast_p); col = Count, Presence
# Only mu_gamma[1] is the level effect for A2.
build_a2 <- function(rows, outcome_order) {
  rows <- rows %>%
    filter(gamma_index == 1) %>%
    mutate(
      exposure_type = str_match(exposure, "^[^/]+_dishes_(count|presence)$")[, 2],
      ci            = fmt_ci(Median_t, Q2.5_t, Q97.5_t)
    ) %>%
    filter(!is.na(exposure_type), outcome %in% outcome_order)

  long <- rows %>%
    transmute(Outcome = outcome, Exposure_Type = exposure_type,
              Median_t, Q2.5_t, Q97.5_t, Rhat = rhat, ci) %>%
    mutate(Outcome = factor(Outcome, levels = outcome_order)) %>%
    arrange(Outcome, Exposure_Type) %>%
    mutate(Outcome = as.character(Outcome),
           Outcome_Label = str_to_title(str_replace(Outcome, "_p$", "")))

  wide <- long %>%
    select(Outcome_Label, Exposure_Type, ci) %>%
    pivot_wider(names_from = Exposure_Type, values_from = ci) %>%
    rename(Outcome = Outcome_Label, Count = count, Presence = presence)

  list(long = long %>% select(-Outcome_Label), wide = wide)
}

# A3 / A4 / A5 / A6 layout: row = Outcome; col = Level, Slope (gamma_index 1, 2)
build_levels_slope <- function(rows, outcome_order) {
  rows <- rows %>%
    filter(outcome %in% outcome_order, gamma_index %in% c(1, 2)) %>%
    mutate(Effect = if_else(gamma_index == 1, "Level", "Slope"),
           ci     = fmt_ci(Median_t, Q2.5_t, Q97.5_t))

  long <- rows %>%
    transmute(Outcome = outcome, Effect, Median_t, Q2.5_t, Q97.5_t, Rhat = rhat, ci) %>%
    mutate(Outcome = factor(Outcome, levels = outcome_order)) %>%
    arrange(Outcome, Effect) %>%
    mutate(Outcome = as.character(Outcome),
           Outcome_Label = str_to_title(str_replace_all(Outcome, "_", " ")))

  wide <- long %>%
    select(Outcome_Label, Effect, ci) %>%
    pivot_wider(names_from = Effect, values_from = ci) %>%
    rename(Outcome = Outcome_Label)

  list(long = long %>% select(-Outcome_Label), wide = wide)
}

# --- table writers ---
write_tex <- function(filepath, caption, label, col_spec, header, rows, footnote) {
  lines <- c(
    "\\begin{table}[H]",
    "\\centering",
    paste0("\\caption{", caption, "}"),
    paste0("\\label{", label, "}"),
    paste0("\\begin{tabular}{", col_spec, "}"),
    "\\toprule",
    paste0(header, " \\\\"),
    "\\midrule",
    rows,
    "\\bottomrule",
    "\\end{tabular}",
    paste0("\\par\\smallskip\\footnotesize ", footnote),
    "\\end{table}"
  )
  writeLines(lines, filepath)
}

emit_a1 <- function(wide, path_stub, caption, label, foot) {
  if (!"Count"      %in% names(wide)) wide$Count      <- NA_character_
  if (!"Proportion" %in% names(wide)) wide$Proportion <- NA_character_
  body <- wide %>%
    mutate(row = paste(Outcome, "&", Exposure_Group, "&",
                       coalesce(Count, "---"), "&",
                       coalesce(Proportion, "---"), "\\\\")) %>%
    pull(row)
  write_tex(paste0(path_stub, ".tex"), caption, label, "llcc",
            "Outcome & Exposure & Count & Proportion", body, foot)
}

emit_a2 <- function(wide, path_stub, caption, label, foot) {
  if (!"Count"    %in% names(wide)) wide$Count    <- NA_character_
  if (!"Presence" %in% names(wide)) wide$Presence <- NA_character_
  body <- wide %>%
    mutate(row = paste(Outcome, "&",
                       coalesce(Count, "---"), "&",
                       coalesce(Presence, "---"), "\\\\")) %>%
    pull(row)
  write_tex(paste0(path_stub, ".tex"), caption, label, "lcc",
            "Outcome & Count & Presence", body, foot)
}

emit_levels_slope <- function(wide, path_stub, caption, label, foot) {
  if (!"Level" %in% names(wide)) wide$Level <- NA_character_
  if (!"Slope" %in% names(wide)) wide$Slope <- NA_character_
  body <- wide %>%
    mutate(row = paste(Outcome, "&",
                       coalesce(Level, "---"), "&",
                       coalesce(Slope, "---"), "\\\\")) %>%
    pull(row)
  write_tex(paste0(path_stub, ".tex"), caption, label, "lcc",
            "Outcome & Level change & Slope change", body, foot)
}

# --- per-analysis (analysis_name, outcome_order, transform_kind) ---
ANALYSIS_SPECS <- list(
  list(key = "a1",     analysis = "a1_proportion",     ord = ORDER$a1,     kind = "a1"),
  list(key = "a1_t2",  analysis = "t2_a1_proportion",  ord = ORDER$a1_t2,  kind = "a1"),
  list(key = "a2",     analysis = "a2_proportion_t",   ord = ORDER$a2,     kind = "a2"),
  list(key = "a2_t2",  analysis = "t2_a2_proportion_t",ord = ORDER$a2_t2,  kind = "a2"),
  list(key = "a3",     analysis = "a3_its",            ord = ORDER$a3,     kind = "exp"),
  list(key = "a3_t2",  analysis = "t2_a3_its",         ord = ORDER$a3_t2,  kind = "exp"),
  list(key = "a4",     analysis = "a4_its_t",          ord = ORDER$a4,     kind = "exp"),
  list(key = "a4_t2",  analysis = "t2_a4_its_t",       ord = ORDER$a4_t2,  kind = "exp"),
  list(key = "a5",     analysis = "a5_customer_day",   ord = ORDER$a5,     kind = "identity"),
  list(key = "a5_t2",  analysis = "t2_a5_customer_day",ord = ORDER$a5_t2,  kind = "identity"),
  list(key = "a6",     analysis = "a6_customer_t_day", ord = ORDER$a6,     kind = "identity"),
  list(key = "a6_t2",  analysis = "t2_a6_customer_t_day",ord = ORDER$a6_t2, kind = "identity")
)

# Adj T1 publication drops "total". For T2 adj, keep total.
adj_outcome_order <- function(spec) {
  if (spec$key == "a1")     return(ORDER$a1_adj)
  if (spec$key == "a3")     return(ORDER$a3_adj)
  if (spec$key == "a5")     return(ORDER$a5_adj)
  spec$ord
}

build_one <- function(spec, source = c("nonadj","adj")) {
  source <- match.arg(source)
  pooled <- if (source == "nonadj") nonadj_pooled else adj_pooled
  rows <- pooled %>% filter(analysis == spec$analysis)

  # For nonadj, mean_t/q2.5_t/q97.5_t already transformed.
  # For adj, transform here based on kind + exposure suffix.
  if (source == "adj") {
    if (spec$kind == "a1") {
      rows <- rows %>%
        mutate(.t = case_when(
          str_ends(exposure, "_count") ~ "exp",
          str_ends(exposure, "_prop")  ~ "exp_p10",
          TRUE ~ NA_character_)) %>%
        filter(!is.na(.t))
      rows <- bind_rows(
        apply_adj_transform(filter(rows, .t == "exp"),     "exp"),
        apply_adj_transform(filter(rows, .t == "exp_p10"), "exp_p10"))
    } else if (spec$kind == "a2") {
      rows <- rows %>%
        mutate(.t = case_when(
          str_ends(exposure, "_count")    ~ "exp",
          str_ends(exposure, "_presence") ~ "exp",   # 0/1 indicator, not a 10pp step
          TRUE ~ NA_character_)) %>%
        filter(!is.na(.t))
      rows <- bind_rows(
        apply_adj_transform(filter(rows, .t == "exp"),     "exp"),
        apply_adj_transform(filter(rows, .t == "exp_p10"), "exp_p10"))
    } else {
      rows <- apply_adj_transform(rows, spec$kind)  # exp or identity
    }
  }

  outcome_order <- if (source == "adj") adj_outcome_order(spec) else spec$ord

  if (spec$kind == "a1") {
    return(build_a1(rows, outcome_order))
  } else if (spec$kind == "a2") {
    return(build_a2(rows, outcome_order))
  } else {
    return(build_levels_slope(rows, outcome_order))
  }
}

# --- captions / footnotes per analysis ---
ratio_foot <- function(extra = "") paste0(
  "Posterior median rate ratios with 95\\% credible intervals", extra, ".")
identity_foot <- function() paste0(
  "Posterior median with 95\\% credible intervals. Identity link; values on the original scale.")

CAP <- list(
  a1     = list(c="Pooled exposure effects on menu composition ($\\mu_{\\gamma_1}$)",         l="tab:a1_mu_gamma",     f=ratio_foot(" Count: $\\exp(\\mu_{\\gamma_1})$; Proportion: $\\exp(0.1 \\cdot \\mu_{\\gamma_1})$")),
  a1_t2  = list(c="Pooled T2 exposure effects on menu composition ($\\mu_{\\gamma_1}$)",      l="tab:a1_t2_mu_gamma",  f=ratio_foot(" Count: $\\exp(\\mu_{\\gamma_1})$; Proportion: $\\exp(0.1 \\cdot \\mu_{\\gamma_1})$")),
  a2     = list(c="Pooled exposure effects on targeted animal product categories ($\\mu_{\\gamma_1}$)",    l="tab:a2_mu_gamma",    f=ratio_foot(" Count: $\\exp(\\mu_{\\gamma_1})$; Presence: $\\exp(0.1 \\cdot \\mu_{\\gamma_1})$")),
  a2_t2  = list(c="Pooled T2 exposure effects on targeted animal product categories ($\\mu_{\\gamma_1}$)", l="tab:a2_t2_mu_gamma", f=ratio_foot(" Count: $\\exp(\\mu_{\\gamma_1})$; Presence: $\\exp(0.1 \\cdot \\mu_{\\gamma_1})$")),
  a3     = list(c="Pooled ITS exposure effects ($\\mu_\\gamma$)",                            l="tab:a3_mu_gamma",     f=ratio_foot(" Level: $\\exp(\\mu_{\\gamma_1})$; Slope: $\\exp(\\mu_{\\gamma_2})$")),
  a3_t2  = list(c="Pooled T2 ITS exposure effects ($\\mu_\\gamma$)",                         l="tab:a3_t2_mu_gamma",  f=ratio_foot(" Level: $\\exp(\\mu_{\\gamma_1})$; Slope: $\\exp(\\mu_{\\gamma_2})$")),
  a4     = list(c="Pooled targeted ITS exposure effects ($\\mu_\\gamma$)",                   l="tab:a4_mu_gamma",     f=ratio_foot(" Level: $\\exp(\\mu_{\\gamma_1})$; Slope: $\\exp(\\mu_{\\gamma_2})$")),
  a4_t2  = list(c="Pooled T2 targeted ITS exposure effects ($\\mu_\\gamma$)",                l="tab:a4_t2_mu_gamma",  f=ratio_foot(" Level: $\\exp(\\mu_{\\gamma_1})$; Slope: $\\exp(\\mu_{\\gamma_2})$")),
  a5     = list(c="Pooled customer-level exposure effects ($\\mu_\\gamma$, identity link)",   l="tab:a5_mu_gamma",     f=identity_foot()),
  a5_t2  = list(c="Pooled T2 customer-level exposure effects ($\\mu_\\gamma$, identity link)",l="tab:a5_t2_mu_gamma",  f=identity_foot()),
  a6     = list(c="Pooled targeted customer-level exposure effects ($\\mu_\\gamma$, identity link)",     l="tab:a6_mu_gamma",     f=identity_foot()),
  a6_t2  = list(c="Pooled T2 targeted customer-level exposure effects ($\\mu_\\gamma$, identity link)",  l="tab:a6_t2_mu_gamma",  f=identity_foot())
)

stub_for <- function(key, source) {
  base <- if (key == "a6")    "publication/tables/A6_mu_gamma"        # T1 stays as A6_*
          else if (key == "a6_t2") "publication/tables/A6_t2_mu_gamma"
          else paste0("publication/tables/", str_replace(toupper(key), "_T2", "_t2"), "_mu_gamma")
  if (source == "adj") paste0(base, "_adj") else base
}

# --- run ---
for (spec in ANALYSIS_SPECS) {
  for (src in c("nonadj","adj")) {
    res  <- build_one(spec, src)
    stub <- stub_for(spec$key, src)
    cap  <- CAP[[spec$key]]
    cap_text <- if (src == "adj") paste0(cap$c, ", total-adjusted") else cap$c
    label    <- if (src == "adj") paste0(cap$l, "_adj") else cap$l

    if (spec$kind == "a1") {
      emit_a1(res$wide, stub, cap_text, label, cap$f)
    } else if (spec$kind == "a2") {
      emit_a2(res$wide, stub, cap_text, label, cap$f)
    } else {
      emit_levels_slope(res$wide, stub, cap_text, label, cap$f)
    }
    write_csv(res$long, paste0(stub, ".csv"))
    cat(sprintf("  %s [%s]: %d rows -> %s.{csv,tex}\n",
                spec$key, src, nrow(res$wide), stub))
  }
}

cat("Done.\n")

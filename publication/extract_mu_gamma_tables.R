## Extract mu_gamma pooled estimates → wide-format LaTeX tables with 95% CI
## Applies same transformations as forest plots (exp for rate ratios, identity for A5)
## Requires samples.rds in each model directory

# Find project root dynamically
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

library(tidyverse)
source("model_scripts/ci95_helpers.R")

BASE     <- "model_fits/finalized_redone_trunc"
BASE_CP  <- "model_fits/finalized_redone_trunc_cp2"
BASE_CP2 <- "model_fits/finalized_redone_trunc_cp2"

# ─── Helper: prefer _cp2 > _cp > base, extract mu_gamma with 95% CI from samples ───
#     Falls back to summ.rds (q5/q95) if samples.rds not found
get_model_path <- function(path_within_base) {
  cp2_path  <- file.path(BASE_CP2, path_within_base)
  cp_path   <- file.path(BASE_CP,  path_within_base)
  base_path <- file.path(BASE,     path_within_base)
  # Prefer newer _cp2, then _cp, then base
  if (file.exists(file.path(cp2_path, "summ.rds"))) return(cp2_path)
  if (file.exists(file.path(cp_path,  "summ.rds"))) return(cp_path)
  base_path
}

read_mu_gamma <- function(path_within_base, indices = c(1, 2)) {
  model_path <- get_model_path(path_within_base)

  # Try samples.rds first for true 95% CI
  result <- tryCatch(
    compute_mu_gamma_95ci(model_path, gamma_indices = indices),
    error = function(e) NULL
  )
  if (!is.null(result) && nrow(result) > 0) return(result)

  # Fallback: read summ.rds and use q5/q95 as approximate CI
  summ_file <- file.path(model_path, "summ.rds")
  if (!file.exists(summ_file)) return(NULL)
  summ <- readRDS(summ_file)

  gamma_names <- paste0("mu_gamma[", indices, "]")
  rows <- summ %>% filter(variable %in% gamma_names)
  if (nrow(rows) == 0) return(NULL)

  rows %>%
    mutate(
      mean_exp     = exp(mean),
      mean_exp_p10 = exp(0.1 * mean),
      q2.5  = q5,
      q97.5 = q95
    ) %>%
    select(variable, mean, mean_exp, mean_exp_p10, median, sd, q2.5, q97.5, rhat, ess_bulk)
}

fmt  <- function(x, d = 3) formatC(x, format = "f", digits = d)

# Format: "mean [q2.5, q97.5]"
fmt_ci <- function(mean, q2.5, q97.5, d = 3) {
  paste0(fmt(mean, d), " [", fmt(q2.5, d), ", ", fmt(q97.5, d), "]")
}

# ─────────────────────────────────────────────
#  A1: Proportion — exp(mu_gamma[1]) for count, exp(0.1*mu_gamma[1]) for prop
#  Wide: Count and Prop on same row
# ─────────────────────────────────────────────
outcomes_a1     <- c("total","nonvegan","meat","chicken_fish","vegetarian","vegan")
exposure_groups <- c("mpbamod","vegan","vegetarian")
exposure_types  <- c("count","prop")

a1_rows <- list()
for (out in outcomes_a1) {
  for (eg in exposure_groups) {
    for (et in exposure_types) {
      exposure <- paste0(eg, "_dishes_", et)
      mg <- read_mu_gamma(file.path("proportion", out, exposure), indices = 1)
      if (!is.null(mg)) {
        row <- mg[1, ]
        if (et == "count") {
          # exp() transform: mean_exp for point estimate, exp(quantile) for CI
          a1_rows[[length(a1_rows) + 1]] <- tibble(
            Outcome = out, Exposure_Group = eg, Exposure_Type = et,
            Mean_t = row$mean_exp, Q2.5_t = exp(row$q2.5), Q97.5_t = exp(row$q97.5),
            Rhat = row$rhat)
        } else {
          # exp(0.1*x) transform: mean_exp_p10 for point estimate, exp(0.1*quantile) for CI
          a1_rows[[length(a1_rows) + 1]] <- tibble(
            Outcome = out, Exposure_Group = eg, Exposure_Type = et,
            Mean_t = row$mean_exp_p10, Q2.5_t = exp(0.1 * row$q2.5), Q97.5_t = exp(0.1 * row$q97.5),
            Rhat = row$rhat)
        }
      }
    }
  }
}
a1 <- bind_rows(a1_rows) %>%
  mutate(ci = fmt_ci(Mean_t, Q2.5_t, Q97.5_t),
         Outcome = str_to_title(str_replace_all(Outcome, "_", " ")),
         Exposure_Group = str_to_title(Exposure_Group))

a1_wide <- a1 %>%
  select(Outcome, Exposure_Group, Exposure_Type, ci) %>%
  pivot_wider(names_from = Exposure_Type, values_from = ci) %>%
  rename(Count = count, Proportion = prop)

# ─────────────────────────────────────────────
#  A2: Proportion Targeted — same transforms as A1
#  Wide: Count and Presence on same row
# ─────────────────────────────────────────────
outcomes_a2 <- c("breakfast_p","chicken_p","dairy_p","egg_p","untextured_p")
labels_a2   <- c("Breakfast","Chicken","Dairy","Egg","Untextured")
exp_types_a2 <- c("count","presence")

a2_rows <- list()
for (i in seq_along(outcomes_a2)) {
  dish_base <- str_replace(outcomes_a2[i], "_p$", "")
  for (et in exp_types_a2) {
    exposure <- paste0(dish_base, "_dishes_", et)
    mg <- read_mu_gamma(file.path("proportion_targeted", outcomes_a2[i], exposure), indices = 1)
    if (!is.null(mg)) {
      row <- mg[1, ]
      if (et == "count") {
        a2_rows[[length(a2_rows) + 1]] <- tibble(
          Outcome = labels_a2[i], Exposure_Type = et,
          Mean_t = row$mean_exp, Q2.5_t = exp(row$q2.5), Q97.5_t = exp(row$q97.5),
          Rhat = row$rhat)
      } else {
        # presence uses same 0.1 scaling as prop
        a2_rows[[length(a2_rows) + 1]] <- tibble(
          Outcome = labels_a2[i], Exposure_Type = et,
          Mean_t = row$mean_exp_p10, Q2.5_t = exp(0.1 * row$q2.5), Q97.5_t = exp(0.1 * row$q97.5),
          Rhat = row$rhat)
      }
    }
  }
}
a2 <- bind_rows(a2_rows) %>%
  mutate(ci = fmt_ci(Mean_t, Q2.5_t, Q97.5_t))

a2_wide <- a2 %>%
  select(Outcome, Exposure_Type, ci) %>%
  pivot_wider(names_from = Exposure_Type, values_from = ci) %>%
  rename(Count = count, Presence = presence)

# ─────────────────────────────────────────────
#  A3: ITS — exp() for both level and slope
#  Wide: Level and Slope on same row
# ─────────────────────────────────────────────
outcomes_a3 <- c("total","nonvegan","meat","chicken_fish","vegetarian","vegan")

a3_rows <- list()
for (out in outcomes_a3) {
  mg <- read_mu_gamma(file.path("its", out), indices = c(1, 2))
  if (!is.null(mg)) {
    for (idx in 1:2) {
      row <- mg %>% filter(variable == paste0("mu_gamma[", idx, "]"))
      if (nrow(row) > 0) {
        a3_rows[[length(a3_rows) + 1]] <- tibble(
          Outcome = out, Effect = if (idx == 1) "Level" else "Slope",
          Mean_t = row$mean_exp, Q2.5_t = exp(row$q2.5), Q97.5_t = exp(row$q97.5),
          Rhat = row$rhat)
      }
    }
  }
}
a3 <- bind_rows(a3_rows) %>%
  mutate(ci = fmt_ci(Mean_t, Q2.5_t, Q97.5_t),
         Outcome = str_to_title(str_replace_all(Outcome, "_", " ")))

a3_wide <- a3 %>%
  select(Outcome, Effect, ci) %>%
  pivot_wider(names_from = Effect, values_from = ci)

# ─────────────────────────────────────────────
#  A4: ITS Targeted — exp() for both level and slope
# ─────────────────────────────────────────────
outcomes_a4 <- c("breakfast","textured","untextured")

a4_rows <- list()
for (out in outcomes_a4) {
  mg <- read_mu_gamma(file.path("its_targeted", out), indices = c(1, 2))
  if (!is.null(mg)) {
    for (idx in 1:2) {
      row <- mg %>% filter(variable == paste0("mu_gamma[", idx, "]"))
      if (nrow(row) > 0) {
        a4_rows[[length(a4_rows) + 1]] <- tibble(
          Outcome = out, Effect = if (idx == 1) "Level" else "Slope",
          Mean_t = row$mean_exp, Q2.5_t = exp(row$q2.5), Q97.5_t = exp(row$q97.5),
          Rhat = row$rhat)
      }
    }
  }
}
a4 <- bind_rows(a4_rows) %>%
  mutate(ci = fmt_ci(Mean_t, Q2.5_t, Q97.5_t),
         Outcome = str_to_title(Outcome))

a4_wide <- a4 %>%
  select(Outcome, Effect, ci) %>%
  pivot_wider(names_from = Effect, values_from = ci)

# ─────────────────────────────────────────────
#  A5: Customer Gaussian IID — identity link, NO transformation
# ─────────────────────────────────────────────
outcomes_a5 <- c("total","nonvegan","meat","chicken_fish","vegetarian","vegan")

a5_rows <- list()
for (out in outcomes_a5) {
  mg <- read_mu_gamma(file.path("customer_gaussian_iid_transaction", out), indices = c(1, 2))
  if (!is.null(mg)) {
    for (idx in 1:2) {
      row <- mg %>% filter(variable == paste0("mu_gamma[", idx, "]"))
      if (nrow(row) > 0) {
        # Identity link: raw values, no exp()
        a5_rows[[length(a5_rows) + 1]] <- tibble(
          Outcome = out, Effect = if (idx == 1) "Level" else "Slope",
          Mean_t = row$mean, Q2.5_t = row$q2.5, Q97.5_t = row$q97.5,
          Rhat = row$rhat)
      }
    }
  }
}
a5 <- bind_rows(a5_rows) %>%
  mutate(ci = fmt_ci(Mean_t, Q2.5_t, Q97.5_t),
         Outcome = str_to_title(str_replace_all(Outcome, "_", " ")))

a5_wide <- a5 %>%
  select(Outcome, Effect, ci) %>%
  pivot_wider(names_from = Effect, values_from = ci)

# ─────────────────────────────────────────────
#  A1_T2: T2 Proportion — exp(mu_gamma[1]) for count, exp(0.1*mu_gamma[1]) for prop
#  Wide: Count and Prop on same row
# ─────────────────────────────────────────────
outcomes_a1_t2     <- c("total","nonvegan","meat","chicken_fish","vegetarian","vegan")
exposure_groups_t2 <- c("mpbamod","vegan","vegetarian")
exposure_types_t2  <- c("count","prop")

a1_t2_rows <- list()
for (out in outcomes_a1_t2) {
  for (eg in exposure_groups_t2) {
    for (et in exposure_types_t2) {
      exposure <- paste0(eg, "_dishes_", et)
      mg <- read_mu_gamma(file.path("t2_proportion", out, exposure), indices = 1)
      if (!is.null(mg)) {
        row <- mg[1, ]
        if (et == "count") {
          a1_t2_rows[[length(a1_t2_rows) + 1]] <- tibble(
            Outcome = out, Exposure_Group = eg, Exposure_Type = et,
            Mean_t = row$mean_exp, Q2.5_t = exp(row$q2.5), Q97.5_t = exp(row$q97.5),
            Rhat = row$rhat)
        } else {
          a1_t2_rows[[length(a1_t2_rows) + 1]] <- tibble(
            Outcome = out, Exposure_Group = eg, Exposure_Type = et,
            Mean_t = row$mean_exp_p10, Q2.5_t = exp(0.1 * row$q2.5), Q97.5_t = exp(0.1 * row$q97.5),
            Rhat = row$rhat)
        }
      }
    }
  }
}
a1_t2 <- bind_rows(a1_t2_rows) %>%
  mutate(ci = fmt_ci(Mean_t, Q2.5_t, Q97.5_t),
         Outcome = str_to_title(str_replace_all(Outcome, "_", " ")),
         Exposure_Group = str_to_title(Exposure_Group))

a1_t2_wide <- a1_t2 %>%
  select(Outcome, Exposure_Group, Exposure_Type, ci) %>%
  pivot_wider(names_from = Exposure_Type, values_from = ci) %>%
  rename(Count = count, Proportion = prop)

# ─────────────────────────────────────────────
#  A2_T2: T2 Proportion Targeted — same transforms as A2
#  Wide: Count and Presence on same row
# ─────────────────────────────────────────────
outcomes_a2_t2 <- c("breakfast_p","chicken_p","dairy_p","egg_p","textured_p","untextured_p")
labels_a2_t2   <- c("Breakfast","Chicken","Dairy","Egg","Textured","Untextured")
exp_types_a2_t2 <- c("count","presence")

a2_t2_rows <- list()
for (i in seq_along(outcomes_a2_t2)) {
  dish_base <- str_replace(outcomes_a2_t2[i], "_p$", "")
  for (et in exp_types_a2_t2) {
    exposure <- paste0(dish_base, "_dishes_", et)
    mg <- read_mu_gamma(file.path("t2_proportion_targeted", outcomes_a2_t2[i], exposure), indices = 1)
    if (!is.null(mg)) {
      row <- mg[1, ]
      if (et == "count") {
        a2_t2_rows[[length(a2_t2_rows) + 1]] <- tibble(
          Outcome = labels_a2_t2[i], Exposure_Type = et,
          Mean_t = row$mean_exp, Q2.5_t = exp(row$q2.5), Q97.5_t = exp(row$q97.5),
          Rhat = row$rhat)
      } else {
        a2_t2_rows[[length(a2_t2_rows) + 1]] <- tibble(
          Outcome = labels_a2_t2[i], Exposure_Type = et,
          Mean_t = row$mean_exp_p10, Q2.5_t = exp(0.1 * row$q2.5), Q97.5_t = exp(0.1 * row$q97.5),
          Rhat = row$rhat)
      }
    }
  }
}
a2_t2 <- bind_rows(a2_t2_rows) %>%
  mutate(ci = fmt_ci(Mean_t, Q2.5_t, Q97.5_t))

a2_t2_wide <- a2_t2 %>%
  select(Outcome, Exposure_Type, ci) %>%
  pivot_wider(names_from = Exposure_Type, values_from = ci) %>%
  rename(Count = count, Presence = presence)

# ─────────────────────────────────────────────
#  A3_T2: T2 ITS — exp() for both level and slope
#  Wide: Level and Slope on same row
# ─────────────────────────────────────────────
outcomes_a3_t2 <- c("total","nonvegan","meat","chicken_fish","vegetarian","vegan")

a3_t2_rows <- list()
for (out in outcomes_a3_t2) {
  mg <- read_mu_gamma(file.path("t2_its", out), indices = c(1, 2))
  if (!is.null(mg)) {
    for (idx in 1:2) {
      row <- mg %>% filter(variable == paste0("mu_gamma[", idx, "]"))
      if (nrow(row) > 0) {
        a3_t2_rows[[length(a3_t2_rows) + 1]] <- tibble(
          Outcome = out, Effect = if (idx == 1) "Level" else "Slope",
          Mean_t = row$mean_exp, Q2.5_t = exp(row$q2.5), Q97.5_t = exp(row$q97.5),
          Rhat = row$rhat)
      }
    }
  }
}
a3_t2 <- bind_rows(a3_t2_rows) %>%
  mutate(ci = fmt_ci(Mean_t, Q2.5_t, Q97.5_t),
         Outcome = str_to_title(str_replace_all(Outcome, "_", " ")))

a3_t2_wide <- a3_t2 %>%
  select(Outcome, Effect, ci) %>%
  pivot_wider(names_from = Effect, values_from = ci)

# ─────────────────────────────────────────────
#  A4_T2: T2 ITS Targeted — exp() for both level and slope
# ─────────────────────────────────────────────
outcomes_a4_t2 <- c("breakfast","chicken","dairy","textured","untextured")

a4_t2_rows <- list()
for (out in outcomes_a4_t2) {
  mg <- read_mu_gamma(file.path("t2_its_targeted", paste0(out, "_t2")), indices = c(1, 2))
  if (!is.null(mg)) {
    for (idx in 1:2) {
      row <- mg %>% filter(variable == paste0("mu_gamma[", idx, "]"))
      if (nrow(row) > 0) {
        a4_t2_rows[[length(a4_t2_rows) + 1]] <- tibble(
          Outcome = out, Effect = if (idx == 1) "Level" else "Slope",
          Mean_t = row$mean_exp, Q2.5_t = exp(row$q2.5), Q97.5_t = exp(row$q97.5),
          Rhat = row$rhat)
      }
    }
  }
}
a4_t2 <- bind_rows(a4_t2_rows) %>%
  mutate(ci = fmt_ci(Mean_t, Q2.5_t, Q97.5_t),
         Outcome = str_to_title(Outcome))

a4_t2_wide <- a4_t2 %>%
  select(Outcome, Effect, ci) %>%
  pivot_wider(names_from = Effect, values_from = ci)

# ─────────────────────────────────────────────
#  A5_T2: T2 Customer Gaussian IID (day-level) — identity link, NO transformation
# ─────────────────────────────────────────────
outcomes_a5_t2 <- c("total","vegan","vegetarian","nonvegan","meat","chicken_fish")

a5_t2_rows <- list()
for (out in outcomes_a5_t2) {
  mg <- read_mu_gamma(file.path("t2_customer_gaussian_iid_day", out), indices = c(1, 2))
  if (!is.null(mg)) {
    for (idx in 1:2) {
      row <- mg %>% filter(variable == paste0("mu_gamma[", idx, "]"))
      if (nrow(row) > 0) {
        a5_t2_rows[[length(a5_t2_rows) + 1]] <- tibble(
          Outcome = out, Effect = if (idx == 1) "Level" else "Slope",
          Mean_t = row$mean, Q2.5_t = row$q2.5, Q97.5_t = row$q97.5,
          Rhat = row$rhat)
      }
    }
  }
}
a5_t2 <- bind_rows(a5_t2_rows) %>%
  mutate(ci = fmt_ci(Mean_t, Q2.5_t, Q97.5_t),
         Outcome = str_to_title(str_replace_all(Outcome, "_", " ")))

a5_t2_wide <- a5_t2 %>%
  select(Outcome, Effect, ci) %>%
  pivot_wider(names_from = Effect, values_from = ci)

# ─────────────────────────────────────────────
#  A6_T1: T1 Customer Targeted Gaussian IID (day-level) — identity link
# ─────────────────────────────────────────────
outcomes_a6_t1 <- c("breakfast","untextured")

a6_t1_rows <- list()
for (out in outcomes_a6_t1) {
  mg <- read_mu_gamma(file.path("customer_targeted_gaussian_iid_day", out), indices = c(1, 2))
  if (!is.null(mg)) {
    for (idx in 1:2) {
      row <- mg %>% filter(variable == paste0("mu_gamma[", idx, "]"))
      if (nrow(row) > 0) {
        a6_t1_rows[[length(a6_t1_rows) + 1]] <- tibble(
          Outcome = out, Effect = if (idx == 1) "Level" else "Slope",
          Mean_t = row$mean, Q2.5_t = row$q2.5, Q97.5_t = row$q97.5,
          Rhat = row$rhat)
      }
    }
  }
}
a6_t1 <- bind_rows(a6_t1_rows) %>%
  mutate(ci = fmt_ci(Mean_t, Q2.5_t, Q97.5_t),
         Outcome = str_to_title(Outcome))

a6_t1_wide <- a6_t1 %>%
  select(Outcome, Effect, ci) %>%
  pivot_wider(names_from = Effect, values_from = ci)

# ─────────────────────────────────────────────
#  A6_T2: T2 Customer Targeted Gaussian IID (day-level) — identity link
# ─────────────────────────────────────────────
outcomes_a6_t2 <- c("breakfast","untextured","chicken","dairy","textured")

a6_t2_rows <- list()
for (out in outcomes_a6_t2) {
  mg <- read_mu_gamma(file.path("t2_customer_targeted_gaussian_iid_day", paste0(out, "_t2")), indices = c(1, 2))
  if (!is.null(mg)) {
    for (idx in 1:2) {
      row <- mg %>% filter(variable == paste0("mu_gamma[", idx, "]"))
      if (nrow(row) > 0) {
        a6_t2_rows[[length(a6_t2_rows) + 1]] <- tibble(
          Outcome = out, Effect = if (idx == 1) "Level" else "Slope",
          Mean_t = row$mean, Q2.5_t = row$q2.5, Q97.5_t = row$q97.5,
          Rhat = row$rhat)
      }
    }
  }
}
if (length(a6_t2_rows) > 0) {
  a6_t2 <- bind_rows(a6_t2_rows) %>%
    mutate(ci = fmt_ci(Mean_t, Q2.5_t, Q97.5_t),
           Outcome = str_to_title(Outcome))
  a6_t2_wide <- a6_t2 %>%
    select(Outcome, Effect, ci) %>%
    pivot_wider(names_from = Effect, values_from = ci)
} else {
  a6_t2      <- tibble(Outcome = character(), Effect = character(),
                       Mean_t = numeric(), Q2.5_t = numeric(), Q97.5_t = numeric(),
                       Rhat = numeric(), ci = character())
  a6_t2_wide <- tibble(Outcome = character(), Level = character(), Slope = character())
}

# ─────────────────────────────────────────────
#  LaTeX — Nature style: booktabs, no vertical lines, [H] placement
# ─────────────────────────────────────────────

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

# --- A1 ---
a1_header <- "Outcome & Exposure & Count & Proportion"
a1_body <- a1_wide %>%
  mutate(row = paste(Outcome, "&", Exposure_Group, "&",
                     replace_na(Count, "---"), "&",
                     replace_na(Proportion, "---"), "\\\\")) %>%
  pull(row)
write_tex("publication/A1_mu_gamma.tex",
  "Pooled exposure effects on menu composition ($\\mu_{\\gamma_1}$)",
  "tab:a1_mu_gamma", "llcc", a1_header, a1_body,
  "Rate ratios with 95\\% credible intervals. Count: $\\exp(\\mu_{\\gamma_1})$; Proportion: $\\exp(0.1 \\cdot \\mu_{\\gamma_1})$.")

# --- A2 ---
a2_header <- "Outcome & Count & Presence"
a2_body <- a2_wide %>%
  mutate(row = paste(Outcome, "&",
                     replace_na(Count, "---"), "&",
                     replace_na(Presence, "---"), "\\\\")) %>%
  pull(row)
write_tex("publication/A2_mu_gamma.tex",
  "Pooled exposure effects on targeted animal product categories ($\\mu_{\\gamma_1}$)",
  "tab:a2_mu_gamma", "lcc", a2_header, a2_body,
  "Rate ratios with 95\\% credible intervals. Count: $\\exp(\\mu_{\\gamma_1})$; Presence: $\\exp(0.1 \\cdot \\mu_{\\gamma_1})$.")

# --- A3 ---
a3_header <- "Outcome & Level change & Slope change"
a3_body <- a3_wide %>%
  mutate(row = paste(Outcome, "&",
                     replace_na(Level, "---"), "&",
                     replace_na(Slope, "---"), "\\\\")) %>%
  pull(row)
write_tex("publication/A3_mu_gamma.tex",
  "Pooled ITS exposure effects ($\\mu_\\gamma$)",
  "tab:a3_mu_gamma", "lcc", a3_header, a3_body,
  "Rate ratios with 95\\% credible intervals. Level: $\\exp(\\mu_{\\gamma_1})$; Slope: $\\exp(\\mu_{\\gamma_2})$.")

# --- A4 ---
a4_header <- "Outcome & Level change & Slope change"
a4_body <- a4_wide %>%
  mutate(row = paste(Outcome, "&",
                     replace_na(Level, "---"), "&",
                     replace_na(Slope, "---"), "\\\\")) %>%
  pull(row)
write_tex("publication/A4_mu_gamma.tex",
  "Pooled targeted ITS exposure effects ($\\mu_\\gamma$)",
  "tab:a4_mu_gamma", "lcc", a4_header, a4_body,
  "Rate ratios with 95\\% credible intervals. Level: $\\exp(\\mu_{\\gamma_1})$; Slope: $\\exp(\\mu_{\\gamma_2})$.")

# --- A5 ---
a5_header <- "Outcome & Level change & Slope change"
a5_body <- a5_wide %>%
  mutate(row = paste(Outcome, "&",
                     replace_na(Level, "---"), "&",
                     replace_na(Slope, "---"), "\\\\")) %>%
  pull(row)
write_tex("publication/A5_mu_gamma.tex",
  "Pooled customer-level exposure effects ($\\mu_\\gamma$, identity link)",
  "tab:a5_mu_gamma", "lcc", a5_header, a5_body,
  "Posterior mean with 95\\% credible intervals. Identity link; values are on the original scale (no exponentiation).")

# --- A1_T2 ---
a1_t2_header <- "Outcome & Exposure & Count & Proportion"
a1_t2_body <- a1_t2_wide %>%
  mutate(row = paste(Outcome, "&", Exposure_Group, "&",
                     replace_na(Count, "---"), "&",
                     replace_na(Proportion, "---"), "\\\\")) %>%
  pull(row)
write_tex("publication/A1_t2_mu_gamma.tex",
  "Pooled T2 exposure effects on menu composition ($\\mu_{\\gamma_1}$)",
  "tab:a1_t2_mu_gamma", "llcc", a1_t2_header, a1_t2_body,
  "Rate ratios with 95\\% credible intervals. Count: $\\exp(\\mu_{\\gamma_1})$; Proportion: $\\exp(0.1 \\cdot \\mu_{\\gamma_1})$.")

# --- A2_T2 ---
a2_t2_header <- "Outcome & Count & Presence"
a2_t2_body <- a2_t2_wide %>%
  mutate(row = paste(Outcome, "&",
                     replace_na(Count, "---"), "&",
                     replace_na(Presence, "---"), "\\\\")) %>%
  pull(row)
write_tex("publication/A2_t2_mu_gamma.tex",
  "Pooled T2 exposure effects on targeted animal product categories ($\\mu_{\\gamma_1}$)",
  "tab:a2_t2_mu_gamma", "lcc", a2_t2_header, a2_t2_body,
  "Rate ratios with 95\\% credible intervals. Count: $\\exp(\\mu_{\\gamma_1})$; Presence: $\\exp(0.1 \\cdot \\mu_{\\gamma_1})$.")

# --- A3_T2 ---
a3_t2_header <- "Outcome & Level change & Slope change"
a3_t2_body <- a3_t2_wide %>%
  mutate(row = paste(Outcome, "&",
                     replace_na(Level, "---"), "&",
                     replace_na(Slope, "---"), "\\\\")) %>%
  pull(row)
write_tex("publication/A3_t2_mu_gamma.tex",
  "Pooled T2 ITS exposure effects ($\\mu_\\gamma$)",
  "tab:a3_t2_mu_gamma", "lcc", a3_t2_header, a3_t2_body,
  "Rate ratios with 95\\% credible intervals. Level: $\\exp(\\mu_{\\gamma_1})$; Slope: $\\exp(\\mu_{\\gamma_2})$.")

# --- A4_T2 ---
a4_t2_header <- "Outcome & Level change & Slope change"
a4_t2_body <- a4_t2_wide %>%
  mutate(row = paste(Outcome, "&",
                     replace_na(Level, "---"), "&",
                     replace_na(Slope, "---"), "\\\\")) %>%
  pull(row)
write_tex("publication/A4_t2_mu_gamma.tex",
  "Pooled T2 targeted ITS exposure effects ($\\mu_\\gamma$)",
  "tab:a4_t2_mu_gamma", "lcc", a4_t2_header, a4_t2_body,
  "Rate ratios with 95\\% credible intervals. Level: $\\exp(\\mu_{\\gamma_1})$; Slope: $\\exp(\\mu_{\\gamma_2})$.")

# --- A5_T2 ---
a5_t2_header <- "Outcome & Level change & Slope change"
a5_t2_body <- a5_t2_wide %>%
  mutate(row = paste(Outcome, "&",
                     replace_na(Level, "---"), "&",
                     replace_na(Slope, "---"), "\\\\")) %>%
  pull(row)
write_tex("publication/A5_t2_mu_gamma.tex",
  "Pooled T2 customer-level exposure effects ($\\mu_\\gamma$, identity link)",
  "tab:a5_t2_mu_gamma", "lcc", a5_t2_header, a5_t2_body,
  "Posterior mean with 95\\% credible intervals. Identity link; values are on the original scale (no exponentiation).")

# --- A6_T1 ---
a6_t1_header <- "Outcome & Level change & Slope change"
a6_t1_body <- a6_t1_wide %>%
  mutate(row = paste(Outcome, "&",
                     replace_na(Level, "---"), "&",
                     replace_na(Slope, "---"), "\\\\")) %>%
  pull(row)
write_tex("publication/A6_mu_gamma.tex",
  "Pooled targeted customer-level exposure effects ($\\mu_\\gamma$, identity link)",
  "tab:a6_mu_gamma", "lcc", a6_t1_header, a6_t1_body,
  "Posterior mean with 95\\% credible intervals. Identity link; values are on the original scale (no exponentiation).")

# --- A6_T2 ---
a6_t2_header <- "Outcome & Level change & Slope change"
a6_t2_body <- a6_t2_wide %>%
  mutate(row = paste(Outcome, "&",
                     replace_na(Level, "---"), "&",
                     replace_na(Slope, "---"), "\\\\")) %>%
  pull(row)
write_tex("publication/A6_t2_mu_gamma.tex",
  "Pooled T2 targeted customer-level exposure effects ($\\mu_\\gamma$, identity link)",
  "tab:a6_t2_mu_gamma", "lcc", a6_t2_header, a6_t2_body,
  "Posterior mean with 95\\% credible intervals. Identity link; values are on the original scale (no exponentiation).")

# ─── CSVs ───
write_csv(a1, "publication/A1_mu_gamma.csv")
write_csv(a2, "publication/A2_mu_gamma.csv")
write_csv(a3, "publication/A3_mu_gamma.csv")
write_csv(a4, "publication/A4_mu_gamma.csv")
write_csv(a5, "publication/A5_mu_gamma.csv")
write_csv(a1_t2, "publication/A1_t2_mu_gamma.csv")
write_csv(a2_t2, "publication/A2_t2_mu_gamma.csv")
write_csv(a3_t2, "publication/A3_t2_mu_gamma.csv")
write_csv(a4_t2, "publication/A4_t2_mu_gamma.csv")
write_csv(a5_t2, "publication/A5_t2_mu_gamma.csv")
write_csv(a6_t1, "publication/A6_mu_gamma.csv")
write_csv(a6_t2, "publication/A6_t2_mu_gamma.csv")

cat("Done. Written 12 .tex + 12 .csv to publication/\n")
cat("T1 — A1:", nrow(a1_wide), "| A2:", nrow(a2_wide), "| A3:", nrow(a3_wide),
    "| A4:", nrow(a4_wide), "| A5:", nrow(a5_wide), "| A6:", nrow(a6_t1_wide), "rows\n")
cat("T2 — A1:", nrow(a1_t2_wide), "| A2:", nrow(a2_t2_wide), "| A3:", nrow(a3_t2_wide),
    "| A4:", nrow(a4_t2_wide), "| A5:", nrow(a5_t2_wide), "| A6:", nrow(a6_t2_wide), "rows\n")

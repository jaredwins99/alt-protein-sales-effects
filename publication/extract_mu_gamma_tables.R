## Extract mu_gamma pooled estimates and produce LaTeX tables
## Outputs to publication/ folder

library(tidyverse)

BASE    <- "model_fits/finalized_redone_trunc"
BASE_CP <- "model_fits/finalized_redone_trunc_cp"

# Helper: read mu_gamma rows from summ.rds, preferring _cp if it exists
read_mu_gamma <- function(path_within_base) {
  cp_path   <- file.path(BASE_CP, path_within_base, "summ.rds")
  base_path <- file.path(BASE,    path_within_base, "summ.rds")

  summ_file <- if (file.exists(cp_path)) cp_path else base_path
  if (!file.exists(summ_file)) return(NULL)

  summ <- readRDS(summ_file)
  src  <- if (file.exists(cp_path)) "cp" else "trunc"

  summ %>%
    filter(str_detect(variable, "mu_gamma")) %>%
    mutate(source = src)
}

fmt <- function(x, d = 3) formatC(x, format = "f", digits = d)

# ─────────────────────────────────────────────
#  A1: Proportion  (mu_gamma[1] only)
# ─────────────────────────────────────────────
outcomes_a1 <- c("total","nonvegan","meat","chicken_fish","vegetarian","vegan")
exposure_groups <- c("mpbamod","vegan","vegetarian")
exposure_types  <- c("count","prop")

a1_rows <- list()
for (out in outcomes_a1) {
  for (eg in exposure_groups) {
    for (et in exposure_types) {
      exposure <- paste0(eg, "_dishes_", et)
      path <- file.path("proportion", out, exposure)
      mg <- read_mu_gamma(path)
      if (!is.null(mg)) {
        row <- mg %>% filter(variable == "mu_gamma[1]")
        if (nrow(row) > 0) {
          a1_rows[[length(a1_rows) + 1]] <- tibble(
            Outcome = str_to_title(str_replace_all(out, "_", " ")),
            Exposure_Group = str_to_title(eg),
            Exposure_Type = str_to_title(et),
            Mean = row$mean,
            Rhat = row$rhat,
            Source = row$source
          )
        }
      }
    }
  }
}
a1 <- bind_rows(a1_rows)

# ─────────────────────────────────────────────
#  A2: Proportion Targeted  (mu_gamma[1] only)
# ─────────────────────────────────────────────
outcomes_a2 <- c("breakfast_p","chicken_p","dairy_p","egg_p","untextured_p")
labels_a2   <- c("Breakfast","Chicken","Dairy","Egg","Untextured")
exp_types_a2 <- c("count","presence")

a2_rows <- list()
for (i in seq_along(outcomes_a2)) {
  out <- outcomes_a2[i]
  dish_base <- str_replace(out, "_p$", "")
  for (et in exp_types_a2) {
    exposure <- paste0(dish_base, "_dishes_", et)
    path <- file.path("proportion_targeted", out, exposure)
    mg <- read_mu_gamma(path)
    if (!is.null(mg)) {
      row <- mg %>% filter(variable == "mu_gamma[1]")
      if (nrow(row) > 0) {
        a2_rows[[length(a2_rows) + 1]] <- tibble(
          Outcome = labels_a2[i],
          Exposure_Type = str_to_title(et),
          Mean = row$mean,
          Rhat = row$rhat,
          Source = row$source
        )
      }
    }
  }
}
a2 <- bind_rows(a2_rows)

# ─────────────────────────────────────────────
#  A3: ITS  (mu_gamma[1] = level, mu_gamma[2] = slope)
# ─────────────────────────────────────────────
outcomes_a3 <- c("total","nonvegan","meat","chicken_fish","vegetarian","vegan")

a3_rows <- list()
for (out in outcomes_a3) {
  path <- file.path("its", out)
  mg <- read_mu_gamma(path)
  if (!is.null(mg)) {
    for (idx in 1:2) {
      vname <- paste0("mu_gamma[", idx, "]")
      row <- mg %>% filter(variable == vname)
      if (nrow(row) > 0) {
        a3_rows[[length(a3_rows) + 1]] <- tibble(
          Outcome = str_to_title(str_replace_all(out, "_", " ")),
          Effect = if (idx == 1) "Level" else "Slope",
          Mean = row$mean,
          Rhat = row$rhat,
          Source = row$source
        )
      }
    }
  }
}
a3 <- bind_rows(a3_rows)

# ─────────────────────────────────────────────
#  A4: ITS Targeted  (mu_gamma[1] = level, mu_gamma[2] = slope)
# ─────────────────────────────────────────────
outcomes_a4 <- c("breakfast","textured","untextured")

a4_rows <- list()
for (out in outcomes_a4) {
  path <- file.path("its_targeted", out)
  mg <- read_mu_gamma(path)
  if (!is.null(mg)) {
    for (idx in 1:2) {
      vname <- paste0("mu_gamma[", idx, "]")
      row <- mg %>% filter(variable == vname)
      if (nrow(row) > 0) {
        a4_rows[[length(a4_rows) + 1]] <- tibble(
          Outcome = str_to_title(out),
          Effect = if (idx == 1) "Level" else "Slope",
          Mean = row$mean,
          Rhat = row$rhat,
          Source = row$source
        )
      }
    }
  }
}
a4 <- bind_rows(a4_rows)

# ─────────────────────────────────────────────
#  A5: Customer Gaussian IID  (mu_gamma[1] = level, mu_gamma[2] = slope)
# ─────────────────────────────────────────────
outcomes_a5 <- c("total","nonvegan","meat","chicken_fish","vegetarian","vegan")

a5_rows <- list()
for (out in outcomes_a5) {
  path <- file.path("customer_gaussian_iid", out)
  mg <- read_mu_gamma(path)
  if (!is.null(mg)) {
    for (idx in 1:2) {
      vname <- paste0("mu_gamma[", idx, "]")
      row <- mg %>% filter(variable == vname)
      if (nrow(row) > 0) {
        a5_rows[[length(a5_rows) + 1]] <- tibble(
          Outcome = str_to_title(str_replace_all(out, "_", " ")),
          Effect = if (idx == 1) "Level" else "Slope",
          Mean = row$mean,
          Rhat = row$rhat,
          Source = row$source
        )
      }
    }
  }
}
a5 <- bind_rows(a5_rows)

# ─────────────────────────────────────────────
#  LaTeX generation
# ─────────────────────────────────────────────

latex_header <- function(caption, label, cols, col_names) {
  col_spec <- paste(cols, collapse = "")
  header <- paste(col_names, collapse = " & ")
  paste0(
    "\\begin{table}[htbp]\n",
    "\\centering\n",
    "\\caption{", caption, "}\n",
    "\\label{", label, "}\n",
    "\\begin{tabular}{", col_spec, "}\n",
    "\\hline\n",
    header, " \\\\\n",
    "\\hline\n"
  )
}

latex_footer <- function(note = NULL) {
  out <- "\\hline\n\\end{tabular}\n"
  if (!is.null(note)) {
    out <- paste0(out, "\\par\\smallskip\\footnotesize ", note, "\n")
  }
  paste0(out, "\\end{table}\n")
}

latex_row <- function(...) {
  vals <- c(...)
  paste0(paste(vals, collapse = " & "), " \\\\")
}

# --- A1 table ---
a1_tex <- latex_header(
  "A1: Proportion analysis --- pooled exposure effects ($\\mu_\\gamma[1]$)",
  "tab:a1_mu_gamma",
  c("l","l","l","r","r"),
  c("Outcome", "Exposure", "Type", "Mean", "$\\hat{R}$")
)
for (i in seq_len(nrow(a1))) {
  r <- a1[i, ]
  a1_tex <- paste0(a1_tex, latex_row(
    r$Outcome, r$Exposure_Group, r$Exposure_Type,
    fmt(r$Mean), fmt(r$Rhat, 2)
  ), "\n")
}
a1_tex <- paste0(a1_tex, latex_footer("Log-scale coefficients. Exponentiate for rate ratios."))

# --- A2 table ---
a2_tex <- latex_header(
  "A2: Targeted proportion analysis --- pooled exposure effects ($\\mu_\\gamma[1]$)",
  "tab:a2_mu_gamma",
  c("l","l","r","r"),
  c("Outcome", "Type", "Mean", "$\\hat{R}$")
)
for (i in seq_len(nrow(a2))) {
  r <- a2[i, ]
  a2_tex <- paste0(a2_tex, latex_row(
    r$Outcome, r$Exposure_Type,
    fmt(r$Mean), fmt(r$Rhat, 2)
  ), "\n")
}
a2_tex <- paste0(a2_tex, latex_footer("Log-scale coefficients. Exponentiate for rate ratios."))

# --- A3 table ---
a3_tex <- latex_header(
  "A3: ITS analysis --- pooled exposure effects ($\\mu_\\gamma$)",
  "tab:a3_mu_gamma",
  c("l","l","r","r"),
  c("Outcome", "Effect", "Mean", "$\\hat{R}$")
)
for (i in seq_len(nrow(a3))) {
  r <- a3[i, ]
  a3_tex <- paste0(a3_tex, latex_row(
    r$Outcome, r$Effect,
    fmt(r$Mean), fmt(r$Rhat, 2)
  ), "\n")
}
a3_tex <- paste0(a3_tex, latex_footer("Level = $\\mu_\\gamma[1]$; Slope = $\\mu_\\gamma[2]$. Log-scale."))

# --- A4 table ---
a4_tex <- latex_header(
  "A4: Targeted ITS analysis --- pooled exposure effects ($\\mu_\\gamma$)",
  "tab:a4_mu_gamma",
  c("l","l","r","r"),
  c("Outcome", "Effect", "Mean", "$\\hat{R}$")
)
for (i in seq_len(nrow(a4))) {
  r <- a4[i, ]
  a4_tex <- paste0(a4_tex, latex_row(
    r$Outcome, r$Effect,
    fmt(r$Mean), fmt(r$Rhat, 2)
  ), "\n")
}
a4_tex <- paste0(a4_tex, latex_footer("Level = $\\mu_\\gamma[1]$; Slope = $\\mu_\\gamma[2]$. Log-scale."))

# --- A5 table ---
a5_tex <- latex_header(
  "A5: Customer-level Gaussian IID analysis --- pooled exposure effects ($\\mu_\\gamma$)",
  "tab:a5_mu_gamma",
  c("l","l","r","r"),
  c("Outcome", "Effect", "Mean", "$\\hat{R}$")
)
for (i in seq_len(nrow(a5))) {
  r <- a5[i, ]
  a5_tex <- paste0(a5_tex, latex_row(
    r$Outcome, r$Effect,
    fmt(r$Mean), fmt(r$Rhat, 2)
  ), "\n")
}
a5_tex <- paste0(a5_tex, latex_footer("Identity link (no exponentiation). Level = $\\mu_\\gamma[1]$; Slope = $\\mu_\\gamma[2]$."))

# ─────────────────────────────────────────────
#  Write outputs
# ─────────────────────────────────────────────
writeLines(a1_tex, "publication/A1_mu_gamma.tex")
writeLines(a2_tex, "publication/A2_mu_gamma.tex")
writeLines(a3_tex, "publication/A3_mu_gamma.tex")
writeLines(a4_tex, "publication/A4_mu_gamma.tex")
writeLines(a5_tex, "publication/A5_mu_gamma.tex")

write_csv(a1, "publication/A1_mu_gamma.csv")
write_csv(a2, "publication/A2_mu_gamma.csv")
write_csv(a3, "publication/A3_mu_gamma.csv")
write_csv(a4, "publication/A4_mu_gamma.csv")
write_csv(a5, "publication/A5_mu_gamma.csv")

cat("Written 5 .tex and 5 .csv files to publication/\n")
cat("\nA1:", nrow(a1), "rows")
cat("\nA2:", nrow(a2), "rows")
cat("\nA3:", nrow(a3), "rows")
cat("\nA4:", nrow(a4), "rows")
cat("\nA5:", nrow(a5), "rows\n")

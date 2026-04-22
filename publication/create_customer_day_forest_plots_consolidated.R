# Consolidated customer day-level forest plots for A5 and A6, T1 and T2,
# non-adjusted and adjusted. Driven entirely by the two publication CSVs:
#   publication/forest_data_95ci.csv      (non-adj)
#   publication/forest_data_adj_95ci.csv  (adj)
#
# Writes PNG + PDF + HTML for each of the 8 combos into the 4 general folders:
#   forest_plots/forest_plots_restaurants_trunc_recolored{,_t2,_adj,_adj_t2}
#
# Also renames the existing transaction-level A5 (A5_gaussian_iid_forest_*)
# to z_A5_transaction_* so the day-level A5/A6 sort first alphabetically.

suppressPackageStartupMessages({
  library(tidyverse)
  library(plotly)
  library(htmlwidgets)
})

NON_ADJ_CSV <- "publication/forest_data_95ci.csv"
ADJ_CSV     <- "publication/forest_data_adj_95ci.csv"

OUT_T1     <- "forest_plots/forest_plots_restaurants_trunc_recolored"
OUT_T2     <- "forest_plots/forest_plots_restaurants_trunc_recolored_t2"
OUT_T1_ADJ <- "forest_plots/forest_plots_restaurants_trunc_recolored_adj"
OUT_T2_ADJ <- "forest_plots/forest_plots_restaurants_trunc_recolored_adj_t2"

for (d in c(OUT_T1, OUT_T2, OUT_T1_ADJ, OUT_T2_ADJ)) dir.create(d, showWarnings = FALSE, recursive = TRUE)

# ─────────────────────────────────────────────
#  Theme + forest builder
# ─────────────────────────────────────────────

forest_theme <- function() {
  theme_minimal(base_size = 11) +
    theme(
      plot.background   = element_rect(fill = "white", color = NA),
      panel.background  = element_rect(fill = "white", color = NA),
      panel.grid.minor  = element_blank(),
      strip.background  = element_rect(fill = "gray90", color = NA),
      strip.text        = element_text(face = "bold"),
      plot.title        = element_text(face = "bold", size = 14),
      plot.subtitle     = element_text(size = 9, color = "gray40"),
      axis.text.y       = element_text(size = 9),
      legend.position   = "bottom",
      panel.spacing.x   = unit(0, "lines"))
}

format_label <- function(x) x %>% str_replace_all("_", " ") %>% str_to_title()

# Build a 3-facet forest plot (Level / Slope / Gender x Level).
# df columns required:
#   outcome, restaurant, effect_type, series, estimate, ci_lower, ci_upper
build_forest <- function(df, title, subtitle, outcome_levels, out_prefix,
                         x_label, width = 14, height = 9) {

  facet_order <- c("Level Change", "Slope Change", "Gender x Level")
  df$effect_type <- factor(df$effect_type, levels = facet_order)
  df$outcome     <- factor(df$outcome, levels = rev(outcome_levels))

  # Stable y within each (outcome, effect_type): pooled row first, then restaurants.
  df <- df %>%
    group_by(outcome, effect_type, series) %>%
    arrange(restaurant, .by_group = TRUE) %>%
    mutate(row_in_group = row_number()) %>%
    ungroup()

  n_per_outcome <- df %>%
    group_by(outcome, effect_type) %>%
    summarize(n = n(), .groups = "drop") %>%
    summarize(max_n = max(n), .groups = "drop") %>%
    pull(max_n)

  Y_SPREAD <- 4.5
  df <- df %>%
    mutate(is_pooled = restaurant == "pooled") %>%
    group_by(outcome, effect_type, series) %>%
    mutate(
      n_rest_in_series = sum(!is_pooled),
      rest_rank = ifelse(is_pooled, NA_integer_,
                         rank(restaurant, ties.method = "first"))
    ) %>%
    ungroup() %>%
    mutate(
      series_offset = case_when(
        series == "Male"   ~ -0.25,
        series == "Female" ~  0.25,
        TRUE               ~  0.0
      ),
      # Male rest dots stack below Male pooled; Female rest dots stack above
      # Female pooled so the two gender clusters don't overlap.
      rest_direction = case_when(
        series == "Female" ~  1,
        TRUE               ~ -1
      ),
      step_size = 0.14,
      y_numeric = as.numeric(outcome) * Y_SPREAD + series_offset +
                  ifelse(is_pooled, 0, rest_direction * step_size * rest_rank)
    )

  series_colors <- c("Base" = "steelblue", "Male" = "#1f77b4", "Female" = "#d62728")

  all_vals <- c(df$estimate, df$ci_lower, df$ci_upper)
  max_abs  <- max(abs(all_vals[is.finite(all_vals)]), na.rm = TRUE)
  if (!is.finite(max_abs) || max_abs == 0) max_abs <- 1
  xb <- min(max_abs * 1.2, 5)
  xlim <- c(-xb, xb)

  df <- df %>%
    mutate(
      clipped  = estimate < xlim[1] | estimate > xlim[2],
      val_disp = pmin(pmax(estimate, xlim[1]), xlim[2]),
      lo_disp  = pmax(ci_lower, xlim[1]),
      hi_disp  = pmin(ci_upper, xlim[2])
    )

  df_rest   <- df %>% filter(!is_pooled)
  df_pooled <- df %>% filter(is_pooled)

  p <- ggplot() +
    geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
    {if (nrow(df_rest))
      geom_errorbarh(data = df_rest,
                     aes(xmin = lo_disp, xmax = hi_disp, y = y_numeric, color = series),
                     height = 0.06, alpha = 0.4, linewidth = 0.3)} +
    {if (nrow(df_rest))
      geom_point(data = df_rest,
                 aes(x = val_disp, y = y_numeric, shape = clipped, color = series,
                     text = paste0(restaurant, "<br>", effect_type,
                                   "<br>mean=", round(estimate, 3),
                                   " [", round(ci_lower, 3), ", ", round(ci_upper, 3), "]")),
                 size = 1.2, alpha = 0.5)} +
    geom_errorbarh(data = df_pooled,
                   aes(xmin = lo_disp, xmax = hi_disp, y = y_numeric, color = series),
                   height = 0.15, linewidth = 0.8) +
    geom_point(data = df_pooled,
               aes(x = val_disp, y = y_numeric, shape = clipped, color = series,
                   text = paste0("POOLED<br>", effect_type,
                                 "<br>mean=", round(estimate, 3),
                                 " [", round(ci_lower, 3), ", ", round(ci_upper, 3), "]")),
               size = 2.5) +
    scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 17), guide = "none") +
    scale_color_manual(values = series_colors, breaks = c("Base", "Male", "Female"),
                       name = "Series") +
    facet_wrap(~ effect_type, ncol = 3) +
    scale_x_continuous(limits = xlim, oob = scales::squish) +
    scale_y_continuous(breaks = seq_along(outcome_levels) * Y_SPREAD,
                       labels = format_label(rev(outcome_levels)),
                       expand = expansion(mult = c(0.08, 0.05))) +
    labs(title = title, subtitle = subtitle, x = x_label, y = "Outcome") +
    forest_theme()

  ggsave(paste0(out_prefix, ".png"), p, width = width, height = height, dpi = 300, bg = "white")
  ggsave(paste0(out_prefix, ".pdf"), p, width = width, height = height, bg = "white")
  try({
    pl <- plotly::ggplotly(p, tooltip = "text")
    saveWidget(pl, paste0(out_prefix, ".html"), selfcontained = FALSE)
  }, silent = TRUE)
  cat("  wrote: ", out_prefix, ".{png,pdf,html}\n", sep = "")

  # Data CSV alongside the plot
  write.csv(df %>% select(outcome, restaurant, effect_type, series,
                           estimate, ci_lower, ci_upper),
            paste0(out_prefix, "_data.csv"), row.names = FALSE)
  invisible(p)
}

# ─────────────────────────────────────────────
#  Non-adj reshape: forest_data_95ci.csv → long
# ─────────────────────────────────────────────

build_nonadj_df <- function(nonadj, analysis_regex) {
  sub <- nonadj %>% filter(str_detect(fit_dir, analysis_regex))
  if (!nrow(sub)) return(NULL)

  # Outcome name = basename(dirname(fit_dir-last-segment)) — actually
  # fit_dir looks like .../<analysis>/<outcome>. Grab the last path segment.
  sub <- sub %>% mutate(outcome = basename(fit_dir))

  # mu_gamma rows: param 1 = level, 2 = slope, 3 = male, 4 = female
  mu <- sub %>%
    filter(str_starts(variable, "mu_gamma")) %>%
    mutate(
      idx = as.integer(str_extract(variable, "\\d+")),
      effect_type = case_when(idx == 1 ~ "Level Change",
                              idx == 2 ~ "Slope Change",
                              idx %in% c(3,4) ~ "Gender x Level",
                              TRUE ~ NA_character_),
      series = case_when(idx == 3 ~ "Male",
                         idx == 4 ~ "Female",
                         TRUE ~ "Base"),
      restaurant = "pooled"
    ) %>%
    filter(!is.na(effect_type)) %>%
    transmute(outcome, restaurant, effect_type, series,
              estimate = mean, ci_lower = q2.5, ci_upper = q97.5)

  # beta rows (per-restaurant). type_fine tells us the facet.
  beta <- sub %>%
    filter(str_starts(variable, "beta\\[")) %>%
    mutate(
      effect_type = case_when(
        type_fine == "gender_male"   ~ "Gender x Level",
        type_fine == "gender_female" ~ "Gender x Level",
        type_fine == "slope"         ~ "Slope Change",
        TRUE                         ~ "Level Change"
      ),
      series = case_when(
        type_fine == "gender_male"   ~ "Male",
        type_fine == "gender_female" ~ "Female",
        TRUE                          ~ "Base"
      )
    ) %>%
    transmute(outcome, restaurant, effect_type, series,
              estimate = mean, ci_lower = q2.5, ci_upper = q97.5)

  bind_rows(mu, beta)
}

# ─────────────────────────────────────────────
#  Adj reshape: forest_data_adj_95ci.csv → long
# ─────────────────────────────────────────────

build_adj_df <- function(adj, analysis_name) {
  sub <- adj %>% filter(analysis == analysis_name)
  if (!nrow(sub)) return(NULL)
  has_tf <- "type_fine" %in% colnames(sub)
  sub %>%
    mutate(
      tf = if (has_tf) type_fine else NA_character_,
      effect_type = case_when(
        !is.na(tf) & tf == "level"         ~ "Level Change",
        !is.na(tf) & tf == "slope"         ~ "Slope Change",
        !is.na(tf) & tf == "gender_male"   ~ "Gender x Level",
        !is.na(tf) & tf == "gender_female" ~ "Gender x Level",
        # fallback for old-schema pooled rows
        gamma_index == 1 ~ "Level Change",
        gamma_index == 2 ~ "Slope Change",
        gamma_index %in% c(3,4) ~ "Gender x Level",
        level == "restaurant" ~ "Level Change",
        TRUE ~ NA_character_
      ),
      series = case_when(
        !is.na(tf) & tf == "gender_male"   ~ "Male",
        !is.na(tf) & tf == "gender_female" ~ "Female",
        gamma_index == 3 ~ "Male",
        gamma_index == 4 ~ "Female",
        TRUE ~ "Base"
      ),
      restaurant = ifelse(level == "pooled", "pooled", restaurant)
    ) %>%
    filter(!is.na(effect_type)) %>%
    transmute(outcome, restaurant, effect_type, series,
              estimate = mean, ci_lower = q2.5, ci_upper = q97.5)
}

# ─────────────────────────────────────────────
#  Load CSVs
# ─────────────────────────────────────────────

nonadj <- read.csv(NON_ADJ_CSV, stringsAsFactors = FALSE)
adj    <- read.csv(ADJ_CSV,     stringsAsFactors = FALSE)

cat("Loaded non-adj: ", nrow(nonadj), " rows\n", sep = "")
cat("Loaded adj:     ", nrow(adj),    " rows\n", sep = "")

# Outcome orderings
A5_ORDER <- c("total", "nonvegan", "meat", "chicken_fish", "vegan", "vegetarian")
A6_T1_ORDER <- c("breakfast", "untextured")
A6_T2_ORDER <- c("breakfast_t2", "chicken_t2", "dairy_t2", "textured_t2", "untextured_t2")

# ─────────────────────────────────────────────
#  Build all 8 plots
# ─────────────────────────────────────────────

plots <- list(
  list(df_fn = build_nonadj_df, arg = "/a5_customer_day/",
       order = A5_ORDER, out_dir = OUT_T1,
       stem = "A5_gaussian_iid_day_forest_restaurants",
       title = "T1 A5 Day-Level (Gaussian IID, Demeaned) — Per-Restaurant + Pooled",
       x = "Effect on Demeaned Outcome"),
  list(df_fn = build_nonadj_df, arg = "/t2_a5_customer_day/",
       order = A5_ORDER, out_dir = OUT_T2,
       stem = "A5_gaussian_iid_day_forest_restaurants",
       title = "T2 A5 Day-Level (Gaussian IID, Demeaned) — Per-Restaurant + Pooled",
       x = "Effect on Demeaned Outcome"),
  list(df_fn = build_nonadj_df, arg = "/a6_customer_t_day/",
       order = A6_T1_ORDER, out_dir = OUT_T1,
       stem = "A6_gaussian_iid_day_targeted_forest_restaurants",
       title = "T1 A6 Day-Level Targeted (Gaussian IID, Demeaned) — Per-Restaurant + Pooled",
       x = "Effect on Demeaned Outcome"),
  list(df_fn = build_nonadj_df, arg = "/t2_a6_customer_t_day/",
       order = A6_T2_ORDER, out_dir = OUT_T2,
       stem = "A6_gaussian_iid_day_targeted_forest_restaurants",
       title = "T2 A6 Day-Level Targeted (Gaussian IID, Demeaned) — Per-Restaurant + Pooled",
       x = "Effect on Demeaned Outcome"),
  list(df_fn = build_adj_df, arg = "a5_customer_day",
       order = A5_ORDER, out_dir = OUT_T1_ADJ,
       stem = "A5_gaussian_iid_day_forest_restaurants_adj",
       title = "T1 A5 Day-Level Adjusted (outcome − total draws) — Per-Restaurant + Pooled",
       x = "Adjusted Effect (outcome − total)"),
  list(df_fn = build_adj_df, arg = "t2_a5_customer_day",
       order = A5_ORDER, out_dir = OUT_T2_ADJ,
       stem = "A5_gaussian_iid_day_forest_restaurants_adj",
       title = "T2 A5 Day-Level Adjusted (outcome − total draws) — Per-Restaurant + Pooled",
       x = "Adjusted Effect (outcome − total)"),
  list(df_fn = build_adj_df, arg = "a6_customer_t_day",
       order = A6_T1_ORDER, out_dir = OUT_T1_ADJ,
       stem = "A6_gaussian_iid_day_targeted_forest_restaurants_adj",
       title = "T1 A6 Day-Level Targeted Adjusted — Per-Restaurant + Pooled",
       x = "Adjusted Effect (outcome − total)"),
  list(df_fn = build_adj_df, arg = "t2_a6_customer_t_day",
       order = A6_T2_ORDER, out_dir = OUT_T2_ADJ,
       stem = "A6_gaussian_iid_day_targeted_forest_restaurants_adj",
       title = "T2 A6 Day-Level Targeted Adjusted — Per-Restaurant + Pooled",
       x = "Adjusted Effect (outcome − total)")
)

for (pl in plots) {
  cat("\n=== ", pl$stem, " -> ", pl$out_dir, " ===\n", sep = "")
  df <- if (identical(pl$df_fn, build_nonadj_df)) build_nonadj_df(nonadj, pl$arg)
        else                                       build_adj_df(adj,    pl$arg)
  if (is.null(df) || !nrow(df)) { cat("  no rows — skipped\n"); next }

  # Filter to known outcomes, keep ordering
  df <- df %>% filter(outcome %in% pl$order)
  if (!nrow(df)) { cat("  no matching outcomes — skipped\n"); next }
  out_levels <- intersect(pl$order, unique(df$outcome))

  n_out <- length(out_levels)
  height <- max(7, n_out * 4.2)

  build_forest(df,
               title = pl$title,
               subtitle = "Points = posterior mean | Bars = 95% CrI (q2.5–q97.5)",
               outcome_levels = out_levels,
               out_prefix = file.path(pl$out_dir, pl$stem),
               x_label = pl$x,
               width = 14, height = height)
}

# ─────────────────────────────────────────────
#  Rename existing transaction-level A5 so day-level A5/A6 sort first.
# ─────────────────────────────────────────────

rename_transaction_a5 <- function(dir, old_stem, new_stem) {
  files <- list.files(dir, pattern = paste0("^", old_stem), full.names = TRUE)
  if (!length(files)) return(invisible(NULL))
  for (f in files) {
    new_f <- file.path(dir, sub(paste0("^", old_stem), new_stem, basename(f)))
    if (f != new_f && !file.exists(new_f)) {
      ok <- file.rename(f, new_f)
      cat("  rename: ", basename(f), " -> ", basename(new_f), "\n", sep = "")
    }
  }
}

cat("\n=== renaming transaction A5 ===\n")
rename_transaction_a5(OUT_T1,     "A5_gaussian_iid_forest_restaurants",    "z_A5_transaction_gaussian_iid_forest_restaurants")
rename_transaction_a5(OUT_T1,     "A5_gaussian_iid_restaurants_data",      "z_A5_transaction_gaussian_iid_restaurants_data")
rename_transaction_a5(OUT_T2,     "A5_gaussian_iid_forest_restaurants",    "z_A5_transaction_gaussian_iid_forest_restaurants")
rename_transaction_a5(OUT_T2,     "A5_gaussian_iid_restaurants_data",      "z_A5_transaction_gaussian_iid_restaurants_data")
rename_transaction_a5(OUT_T2_ADJ, "A5_gaussian_iid_forest_restaurants_adj","z_A5_transaction_gaussian_iid_forest_restaurants_adj")
rename_transaction_a5(OUT_T2_ADJ, "A5_gaussian_iid_restaurants_adj_data",  "z_A5_transaction_gaussian_iid_restaurants_adj_data")

cat("\nDone.\n")

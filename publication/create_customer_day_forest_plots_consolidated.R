# Consolidated customer day-level forest plots for A5 and A6, T1 and T2,
# non-adjusted and adjusted. Driven entirely by the two publication CSVs:
#   publication/forest_data_95ci.csv      (non-adj)
#   publication/forest_data_adj_95ci.csv  (adj)
#
# Writes PNG + PDF + HTML for each of the 8 combos into the 4 general folders:
#   forest_plots/trunc_recolored{,_t2,_adj,_adj_t2}
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

source("publication/present_helpers.R")
# Publication-quality theme + palette (T1 total-adjusted plots only).
source("publication/publication_theme.R")
SORT_BY_MEAN <- Sys.getenv("SORT_BY_MEAN", "FALSE") == "TRUE"
.sfx <- if (SORT_BY_MEAN) "_sorted" else ""
OUT_T1     <- present_path(paste0("forest_plots/base/t1", .sfx))
OUT_T2     <- present_path(paste0("forest_plots/base/t2", .sfx))
OUT_T1_ADJ <- present_path(paste0("forest_plots/total_adjusted/t1", .sfx))
OUT_T2_ADJ <- present_path(paste0("forest_plots/total_adjusted/t2", .sfx))

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
      axis.text.y       = element_text(size = 10),
      legend.position   = "bottom",
      panel.spacing.x   = unit(0, "lines"))
}

format_label <- function(x) {
  x %>% str_replace("_t2$", "") %>% str_replace_all("_", " ") %>% str_to_title()
}

# Build a 3-facet forest plot (Level / Slope / Gender x Level).
# df columns required:
#   outcome, restaurant, effect_type, series, estimate, ci_lower, ci_upper
build_forest <- function(df, title, subtitle, outcome_levels, out_prefix,
                         x_label, width = 14, height = 9, y_spread = 6.5,
                         publication = FALSE) {

  facet_order <- c("Level Change", "Slope Change", "Gender x Level")
  facet_labels <- if (publication) c("level change", "slope change", "gender x level") else facet_order
  df$effect_type <- factor(df$effect_type, levels = facet_order, labels = facet_labels)
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

  Y_SPREAD <- y_spread
  df <- df %>%
    mutate(is_pooled = restaurant == "pooled") %>%
    group_by(outcome, effect_type, series) %>%
    mutate(
      n_rest_in_series = sum(!is_pooled),
      rest_rank = if (SORT_BY_MEAN)
                    ifelse(is_pooled, NA_integer_,
                           as.integer(rank(-estimate, ties.method = "first")))
                  else
                    ifelse(is_pooled, NA_integer_,
                           as.integer(rank(restaurant, ties.method = "first")))
    ) %>%
    ungroup() %>%
    mutate(
      series_offset = 0.0,
      rest_direction = -1,
      step_size = 0.32,
      y_numeric = as.numeric(outcome) * Y_SPREAD + series_offset +
                  ifelse(is_pooled, 0, rest_direction * step_size * rest_rank)
    )

  # Color mapping matching A1–A4: outcome category drives Base color;
  # Male/Female keep their distinct colors in the Gender x Level facet.
  cat_color <- function(o) {
    s <- sub("_t2$", "", o)
    if (s == "total") "steelblue"
    else if (s %in% c("vegan", "vegetarian")) "forestgreen"
    else "firebrick"
  }
  df$color_key <- ifelse(df$series == "Male", "Male",
                  ifelse(df$series == "Female", "Female",
                         vapply(as.character(df$outcome), cat_color, character(1))))
  df$color_key_inner <- paste0(df$color_key, "_inner")
  # T1 total-adjusted: use the publication palette (muted, print-friendly).
  # All other panels: keep the legacy steelblue/firebrick/forestgreen so T2
  # and non-adjusted output is visually unchanged.
  series_colors <- if (publication) PUB_COLORS_LEGACY_ALL else c(
    "steelblue"   = "steelblue",
    "firebrick"   = "firebrick",
    "forestgreen" = "forestgreen",
    "Male"        = "#1f77b4",
    "Female"      = "#d62728"
  )

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
      hi_disp  = pmin(ci_upper, xlim[2]),
      # Inner ~1 SD (68% CrI) bounds, additive (identity-link Gaussian here).
      sd1      = (ci_upper - ci_lower) / (2 * 1.96),
      lo1_disp = pmax(estimate - sd1, xlim[1]),
      hi1_disp = pmin(estimate + sd1, xlim[2])
    )

  df_rest   <- df %>% filter(!is_pooled)
  df_pooled <- df %>% filter(is_pooled)

  # Size / alpha tuning: when publication=TRUE, bump pooled dots, drop
  # error-bar T-caps, strengthen restaurant contrast; otherwise preserve the
  # prior (non-adj / T2) look exactly.
  rest_point_size    <- if (publication) 1.4  else 1.2
  rest_bar_lw        <- if (publication) 0.35 else 0.3
  rest_bar_height    <- if (publication) 0.04 else 0.06
  rest_bar_alpha_gx  <- if (publication) 0.22 else 0.22
  rest_bar_alpha_reg <- if (publication) 0.55 else 0.4
  rest_pt_alpha_gx   <- if (publication) 0.32 else 0.28
  rest_pt_alpha_reg  <- if (publication) 0.6  else 0.5
  rest_pt_stroke     <- if (publication) 0    else 0.5
  pooled_point_size  <- if (publication) 3.1  else 2.5
  pooled_bar_lw      <- if (publication) 0.9  else 0.8
  pooled_bar_height  <- if (publication) 0    else 0.15
  pooled_pt_stroke   <- if (publication) 0    else 0.5
  vline_color        <- if (publication) "grey55" else "gray50"
  vline_lw           <- if (publication) 0.4 else 0.5

  p <- ggplot() +
    geom_vline(xintercept = 0, linetype = "dashed", color = vline_color,
               linewidth = vline_lw) +
    # Lower alpha in Gender x Level facet so overlapping male/female (same y) stay readable.
    # Outer 95% restaurant bar — wash tint under publication, category color
    # under non-publication. Publication-only inner 1SD bar follows, in the
    # strong category color.
    {if (nrow(df_rest))
      geom_errorbarh(data = df_rest,
                     aes(xmin = lo_disp, xmax = hi_disp, y = y_numeric,
                         color = if (publication) color_key_inner else color_key,
                         alpha = ifelse(effect_type == "Gender x Level",
                                        rest_bar_alpha_gx, rest_bar_alpha_reg)),
                     height = rest_bar_height, linewidth = rest_bar_lw)} +
    {if (publication && nrow(df_rest))
      geom_errorbarh(data = df_rest,
                     aes(xmin = lo1_disp, xmax = hi1_disp, y = y_numeric, color = color_key,
                         alpha = ifelse(effect_type == "Gender x Level",
                                        rest_bar_alpha_gx, rest_bar_alpha_reg)),
                     height = rest_bar_height, linewidth = rest_bar_lw)} +
    {if (nrow(df_rest))
      geom_point(data = df_rest,
                 aes(x = val_disp, y = y_numeric, shape = clipped, color = color_key,
                     customdata = pred_path,
                     alpha = ifelse(effect_type == "Gender x Level",
                                    rest_pt_alpha_gx, rest_pt_alpha_reg),
                     text = paste0(restaurant, "<br>", effect_type,
                                   "<br>mean=", round(estimate, 3),
                                   " [", round(ci_lower, 3), ", ", round(ci_upper, 3), "]")),
                 size = rest_point_size, stroke = rest_pt_stroke)} +
    # Pooled CI publication: outer 95% = wash tint, inner 1SD = strong category
    # color. Same thickness both, very small end-cap on each. Non-publication
    # keeps the single bar.
    {if (publication)
      geom_errorbarh(data = df_pooled,
                     aes(xmin = lo_disp, xmax = hi_disp, y = y_numeric, color = color_key_inner,
                         alpha = ifelse(effect_type == "Gender x Level", 0.7, 1.0)),
                     height = 0.08, linewidth = 1.8)} +
    {if (publication)
      geom_errorbarh(data = df_pooled,
                     aes(xmin = lo1_disp, xmax = hi1_disp, y = y_numeric, color = color_key,
                         alpha = ifelse(effect_type == "Gender x Level", 0.65, 1.0)),
                     height = 0.08, linewidth = 1.8)} +
    {if (!publication)
      geom_errorbarh(data = df_pooled,
                     aes(xmin = lo_disp, xmax = hi_disp, y = y_numeric, color = color_key,
                         alpha = ifelse(effect_type == "Gender x Level", 0.55, 1.0)),
                     height = pooled_bar_height, linewidth = pooled_bar_lw)} +
    geom_point(data = df_pooled,
               aes(x = val_disp, y = y_numeric, shape = clipped, color = color_key,
                   customdata = pred_path,
                   alpha = ifelse(effect_type == "Gender x Level", 0.65, 1.0),
                   text = paste0("POOLED<br>", effect_type,
                                 "<br>mean=", round(estimate, 3),
                                 " [", round(ci_lower, 3), ", ", round(ci_upper, 3), "]")),
               size = pooled_point_size, stroke = pooled_pt_stroke) +
    scale_alpha_identity() +
    scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 17), guide = "none") +
    scale_color_manual(values = series_colors, guide = "none",
                       na.value = "gray50") +
    facet_wrap(~ effect_type, ncol = 3) +
    scale_x_continuous(limits = xlim, oob = scales::squish) +
    scale_y_continuous(breaks = seq_along(outcome_levels) * Y_SPREAD,
                       labels = format_label(rev(outcome_levels)),
                       expand = expansion(mult = c(0.08, 0.05))) +
    labs(title = title,
         subtitle = if (publication) "Posterior mean; 95% CrI" else subtitle,
         x = x_label, y = "Outcome") +
    (if (publication) publication_forest_theme(base_size = 12) else forest_theme())

  if (publication) {
    pub_ggsave_png(paste0(out_prefix, ".png"), p, width = width, height = height)
    pub_ggsave_pdf(paste0(out_prefix, ".pdf"), p, width = width, height = height)
  } else {
    ggsave(paste0(out_prefix, ".png"), p, width = width, height = height, dpi = 300, bg = "white")
    ggsave(paste0(out_prefix, ".pdf"), p, width = width, height = height, bg = "white")
  }
  try({
    pl <- plotly::ggplotly(p, tooltip = "text")
    pl <- add_click_handler(pl)
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
       title = "A5: Customer ITS Analysis",
       x = "Effect on Customer Item Purchases per Transaction, Demeaned"),
  list(df_fn = build_nonadj_df, arg = "/t2_a5_customer_day/",
       order = A5_ORDER, out_dir = OUT_T2,
       stem = "A5_gaussian_iid_day_forest_restaurants",
       title = "A5: Customer ITS Analysis",
       x = "Effect on Customer Item Purchases per Transaction, Demeaned"),
  list(df_fn = build_nonadj_df, arg = "/a6_customer_t_day/",
       order = A6_T1_ORDER, out_dir = OUT_T1,
       stem = "A6_gaussian_iid_day_targeted_forest_restaurants",
       title = "A6: Customer ITS Analysis (Targeted)",
       x = "Effect on Customer Item Purchases per Transaction, Demeaned"),
  list(df_fn = build_nonadj_df, arg = "/t2_a6_customer_t_day/",
       order = A6_T2_ORDER, out_dir = OUT_T2,
       stem = "A6_gaussian_iid_day_targeted_forest_restaurants",
       title = "A6: Customer ITS Analysis (Targeted)",
       x = "Effect on Customer Item Purchases per Transaction, Demeaned"),
  list(df_fn = build_adj_df, arg = "a5_customer_day",
       order = A5_ORDER, out_dir = OUT_T1_ADJ,
       stem = "A5_gaussian_iid_day_forest_restaurants_adj",
       title = "A5: Customer ITS Analysis (Adjusted)",
       x = "Difference in Effect on Customer Item Purchases per Transaction, Demeaned"),
  list(df_fn = build_adj_df, arg = "t2_a5_customer_day",
       order = A5_ORDER, out_dir = OUT_T2_ADJ,
       stem = "A5_gaussian_iid_day_forest_restaurants_adj",
       title = "A5: Customer ITS Analysis (Adjusted)",
       x = "Difference in Effect on Customer Item Purchases per Transaction, Demeaned"),
  list(df_fn = build_adj_df, arg = "a6_customer_t_day",
       order = A6_T1_ORDER, out_dir = OUT_T1_ADJ,
       stem = "A6_gaussian_iid_day_targeted_forest_restaurants_adj",
       title = "A6: Customer ITS Analysis (Targeted, Adjusted)",
       x = "Difference in Effect on Customer Item Purchases per Transaction, Demeaned"),
  list(df_fn = build_adj_df, arg = "t2_a6_customer_t_day",
       order = A6_T2_ORDER, out_dir = OUT_T2_ADJ,
       stem = "A6_gaussian_iid_day_targeted_forest_restaurants_adj",
       title = "A6: Customer ITS Analysis (Targeted, Adjusted)",
       x = "Difference in Effect on Customer Item Purchases per Transaction, Demeaned")
)

for (pl in plots) {
  cat("\n=== ", pl$stem, " -> ", pl$out_dir, " ===\n", sep = "")
  df <- if (identical(pl$df_fn, build_nonadj_df)) build_nonadj_df(nonadj, pl$arg)
        else                                       build_adj_df(adj,    pl$arg)
  if (is.null(df) || !nrow(df)) { cat("  no rows — skipped\n"); next }

  # Adj reference row: "total" outcome — dropped for T1 publication plots
  # (is_adj && !is_t2) since diff=0 by construction and adds no information.
  # Kept for T2 adj where the reference line is still useful.
  .is_t2  <- grepl("t2_", pl$arg, fixed = TRUE)
  .is_adj <- identical(pl$df_fn, build_adj_df)
  .publication <- .is_adj && !.is_t2
  if (.is_adj && !.publication) {
    ref_rows <- tibble(
      outcome     = rep("total", 4),
      restaurant  = rep("pooled", 4),
      effect_type = c("Level Change", "Slope Change", "Gender x Level", "Gender x Level"),
      series      = c("Base", "Base", "Male", "Female"),
      estimate    = 0, ci_lower = 0, ci_upper = 0
    )
    df <- dplyr::bind_rows(df, ref_rows)
  }

  # Ensure "total" is included at the top of the order for adj plots (except pub)
  order_adj <- if (.is_adj && !.publication && !"total" %in% pl$order)
                 c("total", pl$order) else pl$order

  # Attach pred_path for click-to-open in PRESENT_MODE
  .analysis_name <- gsub("^/|/$", "", pl$arg)
  df <- df %>% rowwise() %>% mutate(
    pred_path = {
      rid <- if (restaurant == "pooled") NULL
             else sub("_\\d+_gender(male|female)$", "", restaurant)
      pred_path_rel("finalized_redone_trunc_cp", .analysis_name,
                    as.character(outcome), NULL, rid)
    }
  ) %>% ungroup()

  # Filter to known outcomes, keep ordering
  df <- df %>% filter(outcome %in% order_adj)
  if (!nrow(df)) { cat("  no matching outcomes — skipped\n"); next }
  out_levels <- intersect(order_adj, unique(df$outcome))

  n_out <- length(out_levels)
  is_t2  <- grepl("t2_", pl$arg, fixed = TRUE)
  is_adj <- identical(pl$df_fn, build_adj_df)
  # Publication-quality PNG/PDF only for T1 total-adjusted plots (per the
  # manuscript-figure task). T2 and non-adj keep the existing look.
  publication <- is_adj && !is_t2
  # Publication: compact height so outcomes don't read as over-spread.
  height <- if (publication) max(5, n_out * 1.5) else max(7, n_out * 4.2)
  build_forest(df,
               title = pl$title,
               subtitle = "Points = posterior mean | Bars = 95% CrI (q2.5–q97.5)",
               outcome_levels = out_levels,
               out_prefix = file.path(pl$out_dir, pl$stem),
               x_label = pl$x,
               width = 14, height = height,
               y_spread = if (is_t2) 8.5 else if (publication) 3.0 else 6.5,
               publication = publication)
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

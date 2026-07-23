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
  if (toupper(Sys.getenv("PRO_FAST", "FALSE")) != "TRUE") {
    library(plotly)
    library(htmlwidgets)
  }
})

NON_ADJ_CSV <- "publication/forest_data_95ci.csv"
ADJ_CSV     <- "publication/forest_data_adj_95ci.csv"

source("publication/scripts/present_helpers.R")
# Publication-quality theme + palette (T1 total-adjusted plots only).
source("publication/config/publication_theme.R")
source("publication/config/plot_config.R")
source("publication/config/publication_config.R")
SORT_BY_MEAN <- Sys.getenv("SORT_BY_MEAN", "FALSE") == "TRUE"
# LABELED_MODE=TRUE: per-restaurant colors + numbered legend; pooled stays unchanged.
LABELED_MODE <- toupper(Sys.getenv("LABELED_MODE", "FALSE")) == "TRUE"
# LABELED_V2=TRUE (implies LABELED_MODE): adds per-restaurant numeric estimate
# + CI text labels next to every restaurant-level point (A5/A6 are on the
# identity-link scale, not RR, so labels use raw "%.2f" values, no % sign).
LABELED_V2 <- toupper(Sys.getenv("LABELED_V2", "FALSE")) == "TRUE"
.sfx <- if (SORT_BY_MEAN) "_sorted" else ""

# Per-restaurant color palette (LABELED_MODE) — same 7-entry mapping as T1/T2
LABELED_REST_IDS <- c(
  "VLZX7K2M9QD4T",
  "SRQS8F7JWA9MZ",
  "2HRX9P6HKXA8V",
  "JHDN7CF1C03X5",
  "L69HYJ4Y3TR91",
  "ED5J990H5VAZT",
  "W8T41JZK0ZMEP",
  "EMBVNVD207CC6",
  "C0BE4NDSW26QN",
  "75WYSXR9QBK5M",
  "V3Q26BHF3SE2H",
  "LBZEEFSBJNB3Z",
  "SAFK7ND1HR6XS",
  "CB2KHY1C2G9PT",
  "S8MT0YGD2KTN9",
  "LFZFT3VASXPED",
  "1SQPTEGYPH0GA",
  "9XKJD8DQTH559",
  "LQ5EH4BKGV61T",
  "78AY09MVJVTYE"
)
LABELED_REST_LABELS <- c(
  "1. Greek rotisserie chain",
  "2. Fast-food burger chain location 1",
  "3. German sausage gastropub",
  "4. Salad and smoothie shop",
  "5. Breakfast café",
  "6. Coffee shop",
  "7. Juice bar",
  "8. Craft brewery pizza kitchen",
  "9. Craft brewery gastropub",
  "10. Kimchi taco joint",
  "11. Bagel-and-espresso café",
  "12. Sweet-and-savory waffle house",
  "13. American-Mexican taquería",
  "14. Fast-food burger chain location 2",
  "15. Stacked-meat burger chain",
  "16. Hot chicken and smash burger chain",
  "17. Italian pasta house",
  "18. Chinese-pizza fusion kitchen",
  "19. Food truck",
  "20. Halfsmoke and chili shop"
)
LABELED_REST_COLORS <- c(
  "#1B9E77",
  "#D95F02",
  "#7570B3",
  "#E7298A",
  "#66A61E",
  "#E6AB02",
  "#A6761D",
  "#1F77B4",
  "#FF7F0E",
  "#2CA02C",
  "#D62728",
  "#9467BD",
  "#8C564B",
  "#E377C2",
  "#7F7F7F",
  "#BCBD22",
  "#17BECF",
  "#AEC7E8",
  "#FFBB78",
  "#98DF8A"
)
names(LABELED_REST_COLORS) <- LABELED_REST_IDS
LABELED_COLORS_ALL <- c(PUB_COLORS_LEGACY_ALL, LABELED_REST_COLORS)

# Compute canonical ordering for LABELED_MODE: canonical restaurants 1–7 in
# LABELED_REST_IDS order; non-canonical get positions 8+ alphabetically.
labeled_rank_fn <- function(ids) {
  canonical_pos <- match(ids, LABELED_REST_IDS)
  non_canon <- is.na(canonical_pos)
  non_canon_ids <- ids[non_canon]
  alpha_rank_nc <- if (any(non_canon)) {
    r <- rank(non_canon_ids, ties.method = "first")
    setNames(r, non_canon_ids)
  } else {
    integer(0)
  }
  result <- ifelse(non_canon,
                   length(LABELED_REST_IDS) + alpha_rank_nc[ids],
                   canonical_pos)
  as.integer(result)
}

.sfx_adj <- paste0(.sfx, if (PUB_RECENTER) "_recentered" else "", if (PUB_WIDE) "_wide" else "")
OUT_T1     <- present_path(paste0("forest_plots/base/t1", .sfx))
OUT_T2     <- present_path(paste0("forest_plots/base/t2", .sfx))
OUT_T1_ADJ <- present_path(paste0("forest_plots/total_adjusted/t1", .sfx_adj))
OUT_T2_ADJ <- present_path(paste0("forest_plots/total_adjusted/t2", .sfx_adj))

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
                         n_rest_max = 0,
                         step_size = 0.32,
                         publication = FALSE,
                         html_height = NULL,
                         cap_pooled = 0.15,
                         cap_rest = 0.075,
                         pooled_bar_lw_pub = 1.4,
                         rest_bar_lw_pub = 0.35,
                         expand_below = 0.08,
                         expand_above = 0.05) {

  facet_order <- c("Level Change", "Slope Change", "Gender x Level")
  facet_labels <- c("level change", "slope change", "gender x level")
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
  .step_size <- step_size
  df <- df %>%
    mutate(is_pooled = restaurant == "pooled") %>%
    group_by(outcome, effect_type, series) %>%
    mutate(
      n_rest_in_series = sum(!is_pooled),
      rest_rank = if (SORT_BY_MEAN)
                    ifelse(is_pooled, NA_integer_,
                           as.integer(rank(-estimate, ties.method = "first")))
                  else if (LABELED_MODE)
                    ifelse(is_pooled, NA_integer_,
                           labeled_rank_fn(restaurant))
                  else
                    ifelse(is_pooled, NA_integer_,
                           as.integer(rank(restaurant, ties.method = "first")))
    ) %>%
    ungroup()

  .packed <- PUB_WIDE && publication
  .lvls   <- levels(df$outcome)
  .n_out  <- df %>%
    dplyr::filter(!is_pooled) %>%
    dplyr::count(outcome, effect_type, series, name = "n") %>%
    dplyr::group_by(outcome) %>%
    dplyr::summarize(n = max(n), .groups = "drop")
  .n_lookup <- setNames(rep(0L, length(.lvls)), .lvls)
  .n_lookup[as.character(.n_out$outcome)] <- .n_out$n
  .gap  <- .step_size * 3
  .ypos <- setNames(numeric(length(.lvls)), .lvls)
  if (length(.lvls) >= 2) for (.i in 2:length(.lvls))
    .ypos[.i] <- .ypos[.i - 1] + .step_size * .n_lookup[.i] + .gap
  .y_breaks <- if (.packed) unname(.ypos) else seq_along(outcome_levels) * Y_SPREAD

  df <- df %>%
    mutate(
      series_offset = 0.0,
      rest_direction = -1,
      step_size = .step_size,
      y_numeric = (if (.packed) unname(.ypos[as.character(outcome)])
                   else as.numeric(outcome) * Y_SPREAD) + series_offset +
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
  df$color_key_inner     <- paste0(df$color_key, "_inner")
  df$color_key_innerdark <- paste0(df$color_key, "_innerdark")
  df$color_key_restwash  <- paste0(df$color_key, "_restwash")
  # Palette selection happens inside .build_p() so PNG and HTML can diverge:
  # PNG follows the caller's publication flag; HTML always uses the legacy
  # palette to keep the interactive widget's look stable.

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
      # Clamped to the 95% CI first: when the estimate sits near one end the
      # symmetric 1-SD band would otherwise overshoot its own end cap.
      lo1_disp = pmax(pmax(estimate - sd1, ci_lower), xlim[1]),
      hi1_disp = pmin(pmin(estimate + sd1, ci_upper), xlim[2])
    )

  # Half-step ticks inside the integer ticks, mirroring A1-A4's 0.25 RR steps.
  .x_breaks <- seq(-floor(xlim[2] * 2) / 2, floor(xlim[2] * 2) / 2, 0.5)

  df_rest   <- df %>% filter(!is_pooled)
  df_pooled <- df %>% filter(is_pooled)
  # LABELED_MODE: use per-restaurant ID as color key for restaurant-level geoms
  df_rest$rest_color_key      <- if (LABELED_MODE) df_rest$restaurant else df_rest$color_key
  df_rest$rest_color_key_wash <- if (LABELED_MODE) df_rest$restaurant else df_rest$color_key_restwash

  # Build one ggplot under the given publication flag. PNG/PDF use the
  # caller-requested flag; HTML always uses pub_flag = FALSE so the
  # interactive widget keeps the base (non-publication) look regardless.
  .build_p <- function(pub_flag) {
    # Size / alpha tuning: when pub_flag=TRUE, bump pooled dots, drop
    # error-bar T-caps, strengthen restaurant contrast; otherwise preserve the
    # prior (non-adj / T2) look exactly.
    rest_point_size    <- if (pub_flag) pub_cfg("rest_point_size", 1.4)         else 1.2
    rest_bar_lw        <- if (pub_flag) rest_bar_lw_pub     else 0.3
    # Publication: visible cap on restaurant outer SD2 bar. Scaled so A5/A6 ticks
    # actually read at the typical rendered DPI.
    rest_bar_height    <- cap_rest
    rest_bar_alpha_gx  <- if (pub_flag) 0.22 else 0.22
    rest_bar_alpha_reg <- if (pub_flag) pub_cfg("rest_bar_alpha_outer", 0.55)   else 0.4
    rest_pt_alpha_gx   <- if (pub_flag) 0.32 else 0.28
    rest_pt_alpha_reg  <- if (pub_flag) pub_cfg("rest_point_alpha", 0.6)        else 0.5
    rest_pt_stroke     <- if (pub_flag) pub_cfg("rest_point_stroke", 0)         else 0.5
    pooled_point_size  <- if (pub_flag) pub_cfg("pooled_point_size", 3.1)       else 2.5
    pooled_bar_lw      <- if (pub_flag) pooled_bar_lw_pub else 0.8
    pooled_bar_height  <- if (pub_flag) 0    else cap_pooled
    pooled_pt_stroke   <- if (pub_flag) pub_cfg("pooled_point_stroke", 0)       else 0.5
    vline_color        <- if (pub_flag) pub_cfg("vline_color", "grey55")        else "gray50"
    vline_lw           <- if (pub_flag) pub_cfg("vline_linewidth", 0.4)         else 0.5

    # Facet labels are lowercase universally (pub + non-pub) so PNG and HTML
    # match regardless of pub_flag.
    .facet_labels <- if (pub_flag && PUB_WIDE)
                       c("Level change", "Slope change", "Gender x level")
                     else c("level change", "slope change", "gender x level")
    df_loc        <- df
    df_rest_loc   <- df_rest
    df_pooled_loc <- df_pooled
    df_loc$effect_type        <- factor(as.character(df_loc$effect_type),        levels = facet_labels, labels = .facet_labels)
    df_rest_loc$effect_type   <- factor(as.character(df_rest_loc$effect_type),   levels = facet_labels, labels = .facet_labels)
    df_pooled_loc$effect_type <- factor(as.character(df_pooled_loc$effect_type), levels = facet_labels, labels = .facet_labels)

    .series_colors <- if (pub_flag) PUB_COLORS_LEGACY_ALL else c(
      "steelblue"   = "steelblue",
      "firebrick"   = "firebrick",
      "forestgreen" = "forestgreen",
      "Male"        = "#1f77b4",
      "Female"      = "#d62728"
    )

    ggplot() +
      geom_vline(xintercept = 0, linetype = "dashed", color = vline_color,
                 linewidth = vline_lw) +
      # Lower alpha in Gender x Level facet so overlapping male/female (same y) stay readable.
      # Outer 95% restaurant bar — medium wash (restwash) under publication, raw
      # category color under non-publication. Publication-only inner SD1 bar
      # follows, in the strong category color, with no cap (per spec).
      {if (nrow(df_rest_loc))
        geom_errorbarh(data = df_rest_loc,
                       aes(xmin = lo_disp, xmax = hi_disp, y = y_numeric,
                           color = if (pub_flag) rest_color_key_wash else color_key,
                           alpha = ifelse(effect_type == .facet_labels[3],
                                          rest_bar_alpha_gx, rest_bar_alpha_reg)),
                       height = rest_bar_height, linewidth = rest_bar_lw)} +
      {if (pub_flag && nrow(df_rest_loc))
        geom_errorbarh(data = df_rest_loc,
                       aes(xmin = lo1_disp, xmax = hi1_disp, y = y_numeric, color = rest_color_key,
                           alpha = ifelse(effect_type == .facet_labels[3],
                                          rest_bar_alpha_gx, rest_bar_alpha_reg)),
                       height = 0, linewidth = rest_bar_lw)} +
      {if (nrow(df_rest_loc))
        geom_point(data = df_rest_loc,
                   aes(x = val_disp, y = y_numeric, shape = clipped, color = rest_color_key,
                       customdata = pred_path,
                       alpha = ifelse(effect_type == .facet_labels[3],
                                      rest_pt_alpha_gx, rest_pt_alpha_reg),
                       text = paste0(restaurant, "<br>", effect_type,
                                     "<br>mean=", round(estimate, 3),
                                     " [", round(ci_lower, 3), ", ", round(ci_upper, 3), "]")),
                   size = rest_point_size, stroke = rest_pt_stroke)} +
      # Pooled CI publication: outer 95% = darker wash (innerdark), inner SD1 =
      # strong category color. Same thickness. Visible end-cap on outer only
      # (inner has no cap per spec). Non-publication keeps the single bar.
      {if (pub_flag)
        geom_errorbarh(data = df_pooled_loc,
                       aes(xmin = lo_disp, xmax = hi_disp, y = y_numeric, color = color_key_innerdark,
                           alpha = ifelse(effect_type == .facet_labels[3], 0.7, 1.0)),
                       height = cap_pooled, linewidth = pooled_bar_lw)} +
      {if (pub_flag)
        geom_errorbarh(data = df_pooled_loc,
                       aes(xmin = lo1_disp, xmax = hi1_disp, y = y_numeric, color = color_key,
                           alpha = ifelse(effect_type == .facet_labels[3], 0.65, 1.0)),
                       height = 0, linewidth = pooled_bar_lw)} +
      {if (!pub_flag)
        geom_errorbarh(data = df_pooled_loc,
                       aes(xmin = lo_disp, xmax = hi_disp, y = y_numeric, color = color_key,
                           alpha = ifelse(effect_type == .facet_labels[3], 0.55, 1.0)),
                       height = pooled_bar_height, linewidth = pooled_bar_lw)} +
      geom_point(data = df_pooled_loc,
                 aes(x = val_disp, y = y_numeric, shape = clipped, color = color_key,
                     customdata = pred_path,
                     alpha = ifelse(effect_type == .facet_labels[3], 0.65, 1.0),
                     text = paste0("POOLED<br>", effect_type,
                                   "<br>mean=", round(estimate, 3),
                                   " [", round(ci_lower, 3), ", ", round(ci_upper, 3), "]")),
                 size = pooled_point_size, stroke = pooled_pt_stroke) +
      {if (pub_flag && PUB_WIDE && !LABELED_MODE && nrow(df_pooled_loc) > 0)
        list(
          geom_errorbarh(data = df_pooled_loc[rep(1, 4), ] %>%
                           mutate(.lg = c("firebrick", "forestgreen", "Male", "Female")),
                         aes(xmin = val_disp, xmax = val_disp, y = y_numeric, color = .lg),
                         height = 0, linewidth = 0, alpha = 0, show.legend = TRUE),
          geom_point(data = df_pooled_loc[rep(1, 4), ] %>%
                       mutate(.lg = c("firebrick", "forestgreen", "Male", "Female")),
                     aes(x = val_disp, y = y_numeric, color = .lg),
                     alpha = 0, size = 0.001, show.legend = TRUE))
      else list()} +
      scale_alpha_identity() +
      scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 17), guide = "none") +
      (if (LABELED_MODE && pub_flag)
        scale_color_manual(
          values = LABELED_COLORS_ALL,
          breaks = LABELED_REST_IDS,
          labels = LABELED_REST_LABELS,
          drop = FALSE,
          na.value = "gray50",
          guide = guide_legend(title = "Restaurant", ncol = 4,
                              override.aes = list(shape = 16, alpha = 1, size = 2.5)))
      else if (pub_flag && PUB_WIDE)
        # Same legend as A1-A4, plus the two gender series that only appear
        # in the third facet. limits = union so a key is drawn even when a
        # series is absent from this plot's data.
        scale_color_manual(values = .series_colors,
          breaks = c("firebrick", "forestgreen", "Male", "Female"),
          labels = c("Animal-based", "Plant-based", "Male", "Female"),
          limits = function(x) union(x, c("firebrick", "forestgreen", "Male", "Female")),
          na.value = "gray50",
          guide = guide_legend(title = NULL,
                               override.aes = list(linewidth = 2.5, alpha = 1, size = 3)))
      else
        scale_color_manual(values = .series_colors, guide = "none",
                           na.value = "gray50")) +
      facet_wrap(~ effect_type, ncol = 3) +
      scale_x_continuous(limits = xlim, oob = scales::squish,
                         breaks = if (pub_flag && PUB_WIDE) .x_breaks else waiver(),
                         labels = if (pub_flag && PUB_WIDE) pub_x_labels_num_plain else waiver()) +
      scale_y_continuous(breaks = .y_breaks,
                         labels = if (pub_flag && PUB_WIDE) pub_outcome_label(rev(outcome_levels))
                                  else format_label(rev(outcome_levels)),
                         expand = expansion(mult = c(expand_below, expand_above))) +
      labs(title = title,
           subtitle = if (pub_flag) NULL else subtitle,
           x = x_label, y = "Outcome") +
      coord_cartesian(clip = "off") +
      {if (pub_flag && LABELED_MODE && nrow(df_rest_loc) > 0) {
        .top_outcome <- levels(df_loc$outcome)[nlevels(df_loc$outcome)]
        .right_facet <- .facet_labels[length(.facet_labels)]
        .df_lbl <- df_rest_loc %>%
          filter(as.character(outcome) == .top_outcome,
                 as.character(effect_type) == .right_facet)
        if (nrow(.df_lbl) == 0) {
          .top_outcome <- df_rest_loc %>%
            dplyr::filter(as.character(effect_type) == .right_facet) %>%
            dplyr::pull(outcome) %>% as.character() %>%
            { levels(df_loc$outcome)[max(match(., levels(df_loc$outcome)), na.rm = TRUE)] }
          .df_lbl <- df_rest_loc %>%
            filter(as.character(outcome) == .top_outcome,
                   as.character(effect_type) == .right_facet)
        }
        if (nrow(.df_lbl) > 0)
          geom_text(data = .df_lbl %>%
                      mutate(.lbl = LABELED_REST_LABELS[match(restaurant, LABELED_REST_IDS)],
                             .lbl = ifelse(is.na(.lbl), restaurant, .lbl)),
                    aes(x = hi_disp + 0.03 * diff(range(xlim)),
                        y = y_numeric, label = .lbl, color = rest_color_key),
                    hjust = 0, size = 2.2, fontface = "bold",
                    family = pub_cfg("font_family", "sans"),
                    inherit.aes = FALSE)
        else list()
      } else list()} +
      {if (pub_flag && LABELED_MODE && LABELED_V2 && nrow(df_rest_loc) > 0) {
        # A5/A6 numbers: LEFT of lower CI. Restricted to the level-change /
        # slope-change facets, which have room. The "gender x level" facet
        # stacks Male + Female restaurant estimates within the same tight
        # y-cluster near x=0 for every restaurant, which is already dense
        # with inline name labels (top outcome) — adding numbers there
        # produced unreadable overlapping text, so it's skipped per the
        # spec's "if it turns messy, skip" allowance.
        .df_num <- df_rest_loc %>%
          filter(as.character(effect_type) != .facet_labels[3]) %>%
          mutate(.num = paste0(sprintf("%.2f", estimate),
                                sprintf(" [%.2f, %.2f]", ci_lower, ci_upper)))
        if (nrow(.df_num) > 0)
          geom_text(data = .df_num,
                    aes(x = lo_disp - 0.02 * diff(range(xlim)),
                        y = y_numeric, label = .num),
                    hjust = 1, size = 1.8, color = "gray40",
                    family = pub_cfg("font_family", "sans"),
                    inherit.aes = FALSE)
        else list()
      } else list()} +
      (if (pub_flag) publication_forest_theme(base_size = 12) else forest_theme()) +
      {if (pub_flag && PUB_WIDE) pub_x_axis_ticks_theme(.x_breaks) else list()}
  }

  p_png  <- .build_p(publication)
  p_html <- .build_p(FALSE)

  if (publication) {
    pub_ggsave_png(paste0(out_prefix, ".png"), p_png, width = width, height = height)
    pub_ggsave_pdf(paste0(out_prefix, ".pdf"), p_png, width = width, height = height)
  } else {
    ggsave(paste0(out_prefix, ".png"), p_png, width = width, height = height, dpi = 300, bg = "white")
    ggsave(paste0(out_prefix, ".pdf"), p_png, width = width, height = height, bg = "white")
  }
  try({
    .html_px <- if (!is.null(html_height)) html_height else {
      .n_out_local <- length(unique(df$outcome))
      round(pmin(3600, pmax(700, .n_out_local * n_rest_max * 1.2 * 40 + 180)))
    }
    pl <- plotly::ggplotly(p_html, tooltip = "text", height = .html_px)
    pl <- add_click_handler(pl)
    saveWidget(pl, paste0(out_prefix, ".html"), selfcontained = FALSE)
  }, silent = TRUE)
  cat("  wrote: ", out_prefix, ".{png,pdf,html}\n", sep = "")

  # Data CSV alongside the plot
  write.csv(df %>% select(outcome, restaurant, effect_type, series,
                           estimate, ci_lower, ci_upper),
            paste0(out_prefix, "_data.csv"), row.names = FALSE)
  invisible(p_png)
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

# Canonical outcome order for the publication figures: A1/A3's axis order
# (Vegetarian above Vegan) then A2/A4's product order. Applied per plot below
# so the non-publication base plots keep their own ordering.
PUB_OUTCOME_ORDER <- c("total", "nonvegan", "meat", "chicken_fish", "vegetarian", "vegan",
                       "breakfast", "untextured", "textured", "chicken", "dairy", "egg")

# ─────────────────────────────────────────────
#  Build all 8 plots
# ─────────────────────────────────────────────

plots <- list(
  list(df_fn = build_nonadj_df, arg = "/a5_customer_day/",
       order = A5_ORDER, out_dir = OUT_T1,
       stem = "A5_gaussian_iid_day_forest_restaurants",
       title = "Customer ITS Analysis",
       x = "Effect on customer item purchases per transaction, demeaned"),
  list(df_fn = build_nonadj_df, arg = "/t2_a5_customer_day/",
       order = A5_ORDER, out_dir = OUT_T2,
       stem = "A5_gaussian_iid_day_forest_restaurants",
       title = "Customer ITS Analysis",
       x = "Effect on customer item purchases per transaction, demeaned"),
  list(df_fn = build_nonadj_df, arg = "/a6_customer_t_day/",
       order = A6_T1_ORDER, out_dir = OUT_T1,
       stem = "A6_gaussian_iid_day_targeted_forest_restaurants",
       title = "Customer ITS Analysis (Targeted)",
       x = "Effect on customer item purchases per transaction, demeaned"),
  list(df_fn = build_nonadj_df, arg = "/t2_a6_customer_t_day/",
       order = A6_T2_ORDER, out_dir = OUT_T2,
       stem = "A6_gaussian_iid_day_targeted_forest_restaurants",
       title = "Customer ITS Analysis (Targeted)",
       x = "Effect on customer item purchases per transaction, demeaned"),
  list(df_fn = build_adj_df, arg = "a5_customer_day",
       order = A5_ORDER, out_dir = OUT_T1_ADJ,
       stem = "A5_gaussian_iid_day_forest_restaurants_adj",
       title = "Customer ITS Analysis (Adjusted)",
       x = "Difference in effect on customer item purchases per transaction, demeaned"),
  list(df_fn = build_adj_df, arg = "t2_a5_customer_day",
       order = A5_ORDER, out_dir = OUT_T2_ADJ,
       stem = "A5_gaussian_iid_day_forest_restaurants_adj",
       title = "Customer ITS Analysis (Adjusted)",
       x = "Difference in effect on customer item purchases per transaction, demeaned"),
  list(df_fn = build_adj_df, arg = "a6_customer_t_day",
       order = A6_T1_ORDER, out_dir = OUT_T1_ADJ,
       stem = "A6_gaussian_iid_day_targeted_forest_restaurants_adj",
       title = "Customer ITS Analysis (Targeted, Adjusted)",
       x = "Difference in effect on customer item purchases per transaction, demeaned"),
  list(df_fn = build_adj_df, arg = "t2_a6_customer_t_day",
       order = A6_T2_ORDER, out_dir = OUT_T2_ADJ,
       stem = "A6_gaussian_iid_day_targeted_forest_restaurants_adj",
       title = "Customer ITS Analysis (Targeted, Adjusted)",
       x = "Difference in effect on customer item purchases per transaction, demeaned")
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
  # T2 adj plots stayed on the legacy look; in the wide (paper) pipeline they
  # get the same publication styling as T1. Other pipelines are unchanged.
  .publication <- .is_adj && (!.is_t2 || PUB_WIDE)
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
  if (PUB_WIDE && .publication)
    order_adj <- order_adj[order(match(sub("_t2$", "", order_adj), PUB_OUTCOME_ORDER))]

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
  publication <- is_adj && (!is_t2 || PUB_WIDE)
  # Principled spacing: step_size fixed, Y_SPREAD scales with the biggest
  # restaurant-cloud height in the df so outcomes don't bleed into each other.
  n_rest_max <- df %>%
    dplyr::filter(restaurant != "pooled") %>%
    dplyr::count(outcome, effect_type, series) %>%
    dplyr::pull(n) %>% { if (length(.)) max(.) else 0 }
  # Per-plot overrides from publication/plot_config.R (keyed by tier + analysis).
  .tier <- if (is_t2) "T2" else "T1"
  .ana  <- if (grepl("a5", pl$arg)) "A5" else "A6"
  .cfg  <- get_plot_cfg(.tier, .ana)
  .step   <- cfg_val(.cfg, "step_size",      0.50)
  .margin <- cfg_val(.cfg, "margin_mult",    1.2)
  .floor  <- cfg_val(.cfg, "y_spread_floor", if (is_t2) 8.5 else if (publication) 3.0 else 6.5)
  .y_spread <- max(n_rest_max * .step * .margin, .floor)
  .png_w  <- cfg_val(.cfg, "png_w", 14)
  .png_h  <- cfg_val(.cfg, "png_h", min(49, max(4, n_out * n_rest_max * 0.12)))
  .cap_pooled <- cfg_val(.cfg, "cap_pooled", 0.15)
  .cap_rest   <- cfg_val(.cfg, "cap_rest",   0.075)
  .pooled_lw  <- plot_or_pub(.cfg, "pooled_bar_linewidth", 1.4)
  .rest_lw    <- plot_or_pub(.cfg, "rest_bar_linewidth",   0.35)
  .exp_below  <- cfg_val(.cfg, "expand_below", 0.08)
  .exp_above  <- cfg_val(.cfg, "expand_above", 0.05)
  .html_px <- round(pmin(3600, pmax(700, n_out * n_rest_max * 1.2 * 40 + 180)))
  .title <- if (PUB_WIDE && publication) {
    if (.ana == "A5")
      "A5: Introduction of new alternative proteins and general meat purchases per customer"
    else
      "A6: Introduction of new alternative proteins and counterpart-specific meat purchases per customer"
  } else pl$title
  build_forest(df,
               title = .title,
               subtitle = NULL,
               outcome_levels = out_levels,
               out_prefix = file.path(pl$out_dir, pl$stem),
               x_label = pl$x,
               width = .png_w, height = .png_h,
               y_spread = .y_spread,
               n_rest_max = n_rest_max,
               step_size = .step,
               publication = publication,
               html_height = .html_px,
               cap_pooled = .cap_pooled,
               cap_rest = .cap_rest,
               pooled_bar_lw_pub = .pooled_lw,
               rest_bar_lw_pub  = .rest_lw,
               expand_below = .exp_below,
               expand_above = .exp_above)
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

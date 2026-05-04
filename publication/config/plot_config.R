# Per-plot PNG layout overrides. Edit any value in place to tune that plot only.
# Applies to PNG/PDF only — HTML widget height uses the shared unified formula.
#
# Keys are "<tier>_<analysis>" — 12 total:
#   T1_A1, T1_A2, T1_A3, T1_A4, T1_A5, T1_A6
#   T2_A1, T2_A2, T2_A3, T2_A4, T2_A5, T2_A6
#
# All fields are listed explicitly so you don't have to remember defaults:
#   png_w                   plot width in inches
#   png_h                   plot height in inches
#   step_size               y-units between restaurant dots
#   margin_mult             .y_spread = max(n_rest_max * step_size * margin_mult, y_spread_floor)
#   y_spread_floor          minimum y-gap between outcomes (only binds for tiny plots)
#   cap_pooled              pooled CI end-cap (T-tick) height in y-units
#   cap_rest                restaurant CI end-cap height in y-units
#   pooled_bar_linewidth    pooled-estimate bar thickness (1.4 default in publication_config)
#   rest_bar_linewidth      restaurant-estimate bar thickness (0.35 default)
#   expand_below            extra space below the y-axis range (multiplier of range).
#                           Lower = less bottom padding.  e.g., 0.05 = 5%.
#   expand_above            extra space above the y-axis range. Lower = less top padding.

PLOT_CONFIG <- list(

  # --- Tier 1 ---
  T1_A1 = list(
    png_w = 10,
    step_size = 0.32, margin_mult = 2.0, y_spread_floor = 1.0,
    cap_pooled = 0.15, cap_rest = 0.075,
    pooled_bar_linewidth = 1.4, rest_bar_linewidth = 0.35,
    expand_below = 0.02, expand_above = 0.02
  ),
  T1_A2 = list(
    png_w = 10,
    step_size = 0.50, margin_mult = 1.2, y_spread_floor = 1.0,
    cap_pooled = 0.15, cap_rest = 0.075,
    pooled_bar_linewidth = 1.4, rest_bar_linewidth = 0.35,
    expand_below = 0.20, expand_above = 0.10
  ),
  T1_A3 = list(
    png_w = 10,
    step_size = 0.50, margin_mult = 1.2, y_spread_floor = 1.0,
    cap_pooled = 0.15, cap_rest = 0.075,
    pooled_bar_linewidth = 1.4, rest_bar_linewidth = 0.35,
    expand_below = 0.20, expand_above = 0.10
  ),
  T1_A4 = list(
    png_w = 10,
    step_size = 0.50, margin_mult = 1.2, y_spread_floor = 1.0,
    cap_pooled = 0.15, cap_rest = 0.075,
    pooled_bar_linewidth = 1.4, rest_bar_linewidth = 0.35,
    expand_below = 0.25, expand_above = 0.15
  ),
  T1_A5 = list(
    png_w = 14, png_h = 8,
    step_size = 0.50, margin_mult = 1.2, y_spread_floor = 3.0,
    cap_pooled = 0.15, cap_rest = 0.075,
    pooled_bar_linewidth = 1.4, rest_bar_linewidth = 0.35,
    expand_below = 0.08, expand_above = 0.05
  ),
  T1_A6 = list(
    png_w = 14, png_h = 6,
    step_size = 0.50, margin_mult = 1.2, y_spread_floor = 3.0,
    cap_pooled = 0.15, cap_rest = 0.075,
    pooled_bar_linewidth = 1.4, rest_bar_linewidth = 0.35,
    expand_below = 0.08, expand_above = 0.05
  ),

  # --- Tier 2 ---
  T2_A1 = list(
    png_w = 11, png_h = 40,
    step_size = 0.50, margin_mult = 1.2, y_spread_floor = 2.5,
    cap_pooled = 0.15, cap_rest = 0.075,
    pooled_bar_linewidth = 1.4, rest_bar_linewidth = 0.35,
    expand_below = 0.02, expand_above = 0.02
  ),
  T2_A2 = list(
    png_w = 10, png_h = 24,
    step_size = 0.50, margin_mult = 1.2, y_spread_floor = 1.0,
    cap_pooled = 0.15, cap_rest = 0.075,
    pooled_bar_linewidth = 1.4, rest_bar_linewidth = 0.35,
    expand_below = 0.20, expand_above = 0.10
  ),
  T2_A3 = list(
    png_w = 10, png_h = 26,
    step_size = 0.50, margin_mult = 1.2, y_spread_floor = 1.0,
    cap_pooled = 0.15, cap_rest = 0.075,
    pooled_bar_linewidth = 1.4, rest_bar_linewidth = 0.35,
    expand_below = 0.20, expand_above = 0.10
  ),
  T2_A4 = list(
    png_w = 10, png_h = 20,
    step_size = 0.50, margin_mult = 1.2, y_spread_floor = 1.0,
    cap_pooled = 0.15, cap_rest = 0.075,
    pooled_bar_linewidth = 1.4, rest_bar_linewidth = 0.35,
    expand_below = 0.25, expand_above = 0.15
  ),
  T2_A5 = list(
    png_w = 14, png_h = 26,
    step_size = 0.50, margin_mult = 1.2, y_spread_floor = 8.5,
    cap_pooled = 0.15, cap_rest = 0.075,
    pooled_bar_linewidth = 1.4, rest_bar_linewidth = 0.35,
    expand_below = 0.08, expand_above = 0.05
  ),
  T2_A6 = list(
    png_w = 14, png_h = 20,
    step_size = 0.50, margin_mult = 1.2, y_spread_floor = 8.5,
    cap_pooled = 0.15, cap_rest = 0.075,
    pooled_bar_linewidth = 1.4, rest_bar_linewidth = 0.35,
    expand_below = 0.08, expand_above = 0.05
  )
)

# ----- helpers (don't edit unless the scripts need a new field) -----

#' Look up a plot config by tier + analysis.
#' Returns an empty list if the key is missing.
get_plot_cfg <- function(tier, analysis) {
  key <- paste0(tier, "_", analysis)
  cfg <- PLOT_CONFIG[[key]]
  if (is.null(cfg)) list() else cfg
}

#' Pull a config field with a fallback default.
cfg_val <- function(cfg, field, default) {
  if (!is.null(cfg[[field]])) cfg[[field]] else default
}

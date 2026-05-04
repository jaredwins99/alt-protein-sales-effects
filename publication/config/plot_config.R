# Per-plot PNG layout overrides. Edit any entry to tune that plot only.
# Missing fields -> script falls back to its default formula.
# Applies to PNG/PDF only — HTML widget height uses the shared unified formula.
#
# Keys are "<tier>_<analysis>" — 12 total:
#   T1_A1, T1_A2, T1_A3, T1_A4, T1_A5, T1_A6
#   T2_A1, T2_A2, T2_A3, T2_A4, T2_A5, T2_A6
#
# Each entry may contain ANY of:
#   png_w           plot width in inches
#   png_h           plot height in inches (or use "auto" for n_out*n_rest*0.12 formula)
#   step_size       y-units between restaurant dots
#   margin_mult     .y_spread = max(n_rest_max * step_size * margin_mult, y_spread_floor)
#   y_spread_floor  minimum y-gap between outcomes
#   cap_pooled      pooled CI end-cap height in y-units
#   cap_rest        restaurant CI end-cap height in y-units
#
# Setting these overrides the script's default. Unset fields use the default.

PLOT_CONFIG <- list(

  # --- Tier 1 ---
  T1_A1 = list(
    png_w = 11, png_h = 12,
    step_size = 0.32, margin_mult = 2.0, y_spread_floor = 1.0,
    cap_pooled = 0.15, cap_rest = 0.075
  ),
  T1_A2 = list(
    png_w = 10, png_h = 7,
    step_size = 0.50, margin_mult = 1.2, y_spread_floor = 1.0,
    cap_pooled = 0.15, cap_rest = 0.075
  ),
  T1_A3 = list(
    png_w = 10, png_h = 8,
    step_size = 0.50, margin_mult = 1.2, y_spread_floor = 1.0,
    cap_pooled = 0.15, cap_rest = 0.075
  ),
  T1_A4 = list(
    png_w = 10, png_h = 6,
    step_size = 0.50, margin_mult = 1.2, y_spread_floor = 1.0,
    cap_pooled = 0.15, cap_rest = 0.075
  ),
  T1_A5 = list(
    png_w = 14, png_h = 8,
    step_size = 0.50, margin_mult = 1.2, y_spread_floor = 3.0,
    cap_pooled = 0.15, cap_rest = 0.075
  ),
  T1_A6 = list(
    png_w = 14, png_h = 6,
    step_size = 0.50, margin_mult = 1.2, y_spread_floor = 3.0,
    cap_pooled = 0.15, cap_rest = 0.075
  ),

  # --- Tier 2 ---
  T2_A1 = list(
    png_w = 11, png_h = 40,
    step_size = 0.50, margin_mult = 1.2, y_spread_floor = 2.5,
    cap_pooled = 0.15, cap_rest = 0.075
  ),
  T2_A2 = list(
    png_w = 10, png_h = 24,
    step_size = 0.50, margin_mult = 1.2, y_spread_floor = 1.0,
    cap_pooled = 0.15, cap_rest = 0.075
  ),
  T2_A3 = list(
    png_w = 10, png_h = 26,
    step_size = 0.50, margin_mult = 1.2, y_spread_floor = 1.0,
    cap_pooled = 0.15, cap_rest = 0.075
  ),
  T2_A4 = list(
    png_w = 10, png_h = 20,
    step_size = 0.50, margin_mult = 1.2, y_spread_floor = 1.0,
    cap_pooled = 0.15, cap_rest = 0.075
  ),
  T2_A5 = list(
    png_w = 14, png_h = 26,
    step_size = 0.50, margin_mult = 1.2, y_spread_floor = 8.5,
    cap_pooled = 0.15, cap_rest = 0.075
  ),
  T2_A6 = list(
    png_w = 14, png_h = 20,
    step_size = 0.50, margin_mult = 1.2, y_spread_floor = 8.5,
    cap_pooled = 0.15, cap_rest = 0.075
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

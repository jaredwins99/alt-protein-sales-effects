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

# Shared T1-adjusted config. Edit this ONE block to retune all four
# T1 A1-A4 plots simultaneously. T1_A1 = T1_A2 = T1_A3 = T1_A4 = T1_ADJ_BASE.
T1_ADJ_BASE <- list(
  png_w = 10,                    # png_h computed dynamically from y_per_inch
  step_size = 0.35, margin_mult = 1.2, y_spread_floor = 1.0,
  cap_pooled = 0.4, cap_rest = 0.125,
  pooled_bar_linewidth = 1.3, rest_bar_linewidth = 0.75,
  # Top expand bumped so the 2-line pooled-estimate label clears the
  # panel top for the topmost outcome.
  expand_below = 0.10, expand_above = 0.15
)

PLOT_CONFIG <- list(

  # --- Tier 1 (all four share T1_ADJ_BASE — edit it above to retune all) ---
  # A1 is a 3-row x 2-col facet grid (3 exposure_groups x 2 exposure_types).
  # 2 cols at standard width (like A2-A4), but height triples since the
  # five outcomes are repeated across 3 panel rows.
  T1_A1 = modifyList(T1_ADJ_BASE, list(png_w = 10, png_h = 15)),
  T1_A2 = T1_ADJ_BASE,
  T1_A3 = T1_ADJ_BASE,
  T1_A4 = modifyList(T1_ADJ_BASE, list(step_size = 0.50)),
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
    cap_pooled = 0.40, cap_rest = 0.20,
    pooled_bar_linewidth = 1.4, rest_bar_linewidth = 0.45,
    expand_below = 0.02, expand_above = 0.02
  ),
  T2_A2 = list(
    png_w = 10, png_h = 24,
    step_size = 0.50, margin_mult = 1.2, y_spread_floor = 1.0,
    cap_pooled = 0.18, cap_rest = 0.09,
    pooled_bar_linewidth = 1.4, rest_bar_linewidth = 0.45,
    expand_below = 0.20, expand_above = 0.10
  ),
  T2_A3 = list(
    png_w = 10, png_h = 26,
    step_size = 0.50, margin_mult = 1.2, y_spread_floor = 1.0,
    cap_pooled = 0.30, cap_rest = 0.15,
    pooled_bar_linewidth = 1.4, rest_bar_linewidth = 0.45,
    expand_below = 0.20, expand_above = 0.10
  ),
  T2_A4 = list(
    png_w = 10, png_h = 20,
    step_size = 0.50, margin_mult = 1.2, y_spread_floor = 1.0,
    cap_pooled = 0.26, cap_rest = 0.13,
    pooled_bar_linewidth = 1.4, rest_bar_linewidth = 0.45,
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

# ----------------------------------------------------------------------
# PUB_WIDE overrides: applied only when the PUB_WIDE env-var switch (see
# publication_theme.R) is TRUE. Widens the "compressed" plots vertically
# without touching the default config used by professional/ and
# professional_recentered/. Inert by default.
#
# Cap sizes are in y-data-units, but the wide variant fixes png_h
# regardless of the plot's y-range, so inches-per-y-unit varies a lot
# between plots. The cap_* overrides below re-tune each plot so caps
# render at roughly the same PHYSICAL size (~0.125in pooled, ~0.09in
# restaurant) as the "just right" reference cases (A1 pooled, A3 rest).
# ----------------------------------------------------------------------
WIDE_OVERRIDES <- list(
  T1_A2 = list(png_h = 12, cap_pooled = 0.10, cap_rest = 0.075),
  T1_A3 = list(png_h = 12, cap_pooled = 0.16),                    # rest 0.125 already right
  T1_A4 = list(png_h = 12, cap_pooled = 0.10, cap_rest = 0.075),
  T2_A2 = list(png_h = 32),
  T2_A3 = list(png_h = 36),
  # T2_A4 expand_below reduced: with free_y facets the 25% per-panel bottom
  # expansion let the Ground meat panel's range dip below the Whole-muscle
  # break (y=6), rendering that axis label in two panels.
  T2_A4 = list(png_h = 32, expand_below = 0.06)
)
# A1 wide keeps its default png_h; restaurant caps upsized (0.125 y-units
# renders ~0.04in at A1's dense y-range — too small), and expand_above
# trimmed — the base 0.15 leaves too much whitespace above the top outcome;
# 0.06 still clears the pooled numeric label at y+0.40 without clipping.
WIDE_OVERRIDES$T1_A1 <- list(cap_rest = 0.28, expand_above = 0.06)

# ----- helpers (don't edit unless the scripts need a new field) -----

#' Look up a plot config by tier + analysis.
#' Returns an empty list if the key is missing.
#' When PUB_WIDE=TRUE (env-var switch) and a WIDE_OVERRIDES entry exists
#' for this tier/analysis, its fields are merged over the base config.
get_plot_cfg <- function(tier, analysis) {
  key <- paste0(tier, "_", analysis)
  cfg <- PLOT_CONFIG[[key]]
  if (is.null(cfg)) cfg <- list()
  if (toupper(Sys.getenv("PUB_WIDE", "FALSE")) == "TRUE" && !is.null(WIDE_OVERRIDES[[key]])) {
    cfg <- modifyList(cfg, WIDE_OVERRIDES[[key]])
  }
  cfg
}

#' Pull a config field with a fallback default.
cfg_val <- function(cfg, field, default) {
  if (!is.null(cfg[[field]])) cfg[[field]] else default
}

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
#   pooled_label_dy         y-offset (data units) of the pooled numeric label above the
#                           pooled point/dot. Default 0.40. In wide plots the y-scale is
#                           stretched, so 0.40 reads as a much bigger visual gap than in
#                           a non-wide plot -- tune down per-plot via WIDE_OVERRIDES.

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
# between plots. Every cap_* value below is set so the tick renders at one
# PHYSICAL length across the whole set -- 0.091in pooled, 0.065in restaurant
# (the T1 A1-A4 values). With PUB_WIDE_BARS fixing the bar weights too, the
# tick-length-to-linewidth ratio is then identical everywhere: ~2.35 pooled,
# ~2.8 restaurant. Re-measure with scratchpad/geom.py after changing png_h,
# step_size or any expand_*, since those all move inches-per-y-unit.
# ----------------------------------------------------------------------
WIDE_OVERRIDES <- list(
  # step_size reduced in A2/A4 so restaurant estimates pack tighter
  # (between the base spacing and A1's density).
  # T1_A2 wide uses proportional panel heights (no force_panelsizes): panel
  # height tracks span = step*n + outcome_gap, so the y-scale is uniform
  # across panels and a no-pooled outcome gets a tight box. step/caps/dy are
  # therefore on a different scale than the other wide entries.
  T1_A2 = list(png_h = 10, step_size = 0.55, cap_pooled = 0.162, cap_rest = 0.113,
               pooled_label_dy = 0.35, expand_below = 0.02, expand_above = 0.02),
  # A3 expands trimmed to match A1 physical padding (single tall panel:
  # mult applies to the FULL range, so small values).
  T1_A3 = list(png_h = 12, cap_pooled = 0.168, cap_rest = 0.122,
               expand_below = 0.02, expand_above = 0.015),
  # T1_A4/T2_A4: proportional layout, params mirror the tier's A2; png_h
  # picked so the y-scale (inches per step) matches it.
  T1_A4 = list(png_h = 7, step_size = 0.55, cap_pooled = 0.151, cap_rest = 0.107,
               pooled_label_dy = 0.35, expand_below = 0.02, expand_above = 0.02),
  # caps carry the /k rescale for the A1a/b/c png_h change (14 -> 10.0).
  T2_A1 = list(cap_pooled = 0.5615, cap_rest = 0.4089),  # parent of the A1a/b/c splits
  # T2_A2: same proportional-height layout as T1_A2. Small expansion is
  # required — the base 0.20/0.10 mult of the large T2 spans overlaps
  # neighboring panels' ranges and duplicates their outcome labels.
  T2_A2 = list(png_h = 20.34, step_size = 0.28, cap_pooled = 0.08225, cap_rest = 0.05849,
               pooled_label_dy = 0.22, expand_below = 0.02, expand_above = 0.02),
  T2_A3 = list(png_h = 36, expand_below = 0.005, expand_above = 0.005),
  # T2 A1/A3 are split into one page per exposure group (A1a/A1b/A1c) and per
  # outcome category (A3a animal-based, A3b plant-based) — see the .splits
  # loops in the T2 renderer. Heights are the parent page's share of the
  # split; everything else is inherited from T2_A1 / T2_A3.
  T2_A1a = list(png_h = 10.73, expand_below = 0.014),
  T2_A1b = list(png_h = 10.73, expand_below = 0.014),
  T2_A1c = list(png_h = 10.73, expand_below = 0.014),
  T2_A3a = list(png_h = 15.80, expand_below = 0.0074, expand_above = 0.0066, cap_pooled = 0.2420, cap_rest = 0.1746),
  T2_A3b = list(png_h = 11.36, expand_below = 0.011, expand_above = 0.0090, cap_pooled = 0.2407, cap_rest = 0.1770),
  # png_h cut from 22: with the gap now proportional to step the block
  # spacing shrinks, and this height puts the row pitch at T1 A4's 0.338in.
  T2_A4 = list(png_h = 18.09, step_size = 0.38, cap_pooled = 0.1022, cap_rest = 0.0726,
               pooled_label_dy = 0.22, expand_below = 0.02, expand_above = 0.02),
  # A5/A6 (identity scale, facet_wrap by effect type — same shape as A3):
  # tighter restaurant rows, padding trimmed to A1's, caps rescaled to the
  # same physical size. y_spread_floor lowered so the tighter step actually
  # binds instead of the floor.
  T1_A5 = list(png_h = 7,  step_size = 0.35, y_spread_floor = 2.4,
               cap_pooled = 0.270, cap_rest = 0.191, expand_below = 0.033, expand_above = 0.064),
  T1_A6 = list(png_h = 5,  step_size = 0.35, y_spread_floor = 2.4,
               cap_pooled = 0.115, cap_rest = 0.084, expand_below = 0.059, expand_above = 0.108),
  T2_A5 = list(png_h = 18.86, step_size = 0.35, y_spread_floor = 6.0,
               cap_pooled = 0.2716, cap_rest = 0.1917, expand_below = 0.009, expand_above = 0.016),
  T2_A6 = list(png_h = 15.86, step_size = 0.35, y_spread_floor = 6.0,
               cap_pooled = 0.1159, cap_rest = 0.0824, expand_below = 0.018, expand_above = 0.032)
)
# A1 wide keeps its default png_h; restaurant caps upsized (0.125 y-units
# renders ~0.04in at A1's dense y-range — too small), and expand_above
# trimmed — the base 0.15 leaves too much whitespace above the top outcome;
# 0.06 still clears the pooled numeric label at y+0.40 without clipping.
WIDE_OVERRIDES$T1_A1 <- list(cap_pooled = 0.390, cap_rest = 0.2875,
                             expand_above = 0.06, expand_below = 0.04)

# Bar weights are physical (linewidth is in mm, independent of png_h or the
# y-range), so one pair of values gives every wide plot the same CI bar
# thickness — and, with the cap_* values below tuned to a common physical
# length, the same end-tick-length-to-linewidth ratio throughout. These are
# the T1 A1-A4 weights; T2 A1-A4 previously ran at 1.4/0.45 (visibly thinner
# restaurant bars) and A5/A6 at 1.4/0.35.
PUB_WIDE_BARS <- list(pooled_bar_linewidth = 1.3, rest_bar_linewidth = 0.75)
WIDE_OVERRIDES <- lapply(WIDE_OVERRIDES, modifyList, val = PUB_WIDE_BARS)

# ----------------------------------------------------------------------
# WIDE_LABELED overrides: layered on top of WIDE_OVERRIDES for the
# wide_labeled/ pipeline only (professional_labeled_v2/ is unaffected).
#
# That pipeline prints a restaurant name and a numeric estimate + CI on every
# row, so a row has to be tall enough to seat a line of text -- roughly
# 0.15in at the label sizes in use. Only the plots whose wide row pitch is
# below that need an entry; the rest already have room and inherit the wide
# layout unchanged. Caps scale with png_h, so any plot that changes height
# needs its cap_* rescaled by the same factor to hold the common tick length.
# ----------------------------------------------------------------------
LABELED_OVERRIDES <- list(
  # Row pitch in the wide set: T1 A1 0.082in, A5 0.118in, T2 A1x 0.113in,
  # A5 0.127in -- all below a text line, so labels there collide. Everything
  # else (0.19-0.34in) already clears and is left alone.
  T1_A1  = list(png_h = 26,   cap_pooled = 0.213, cap_rest = 0.157,
                 expand_above = 0.033, expand_below = 0.023),
  T1_A5  = list(png_h = 8.4,  cap_pooled = 0.213, cap_rest = 0.150),
  T2_A1  = list(cap_pooled = 0.304, cap_rest = 0.223),   # parent of the splits
  T2_A1a = list(png_h = 22),
  T2_A1b = list(png_h = 22),
  T2_A1c = list(png_h = 22),
  T2_A5  = list(png_h = 23.2, cap_pooled = 0.211, cap_rest = 0.152)
)

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
  if (toupper(Sys.getenv("WIDE_LABELED", "FALSE")) == "TRUE" && !is.null(LABELED_OVERRIDES[[key]])) {
    cfg <- modifyList(cfg, LABELED_OVERRIDES[[key]])
  }
  cfg
}

#' Pull a config field with a fallback default.
cfg_val <- function(cfg, field, default) {
  if (!is.null(cfg[[field]])) cfg[[field]] else default
}

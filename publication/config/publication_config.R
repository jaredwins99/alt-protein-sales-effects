# Publication PNG styling knobs. Tunes every plot that goes through the
# publication code path (forest_plots/total_adjusted/t1/ + present/ mirror).
# Per-plot layout (step_size, margins, cap heights) lives in plot_config.R.
# This file is for styling that applies uniformly to all publication plots.
#
# Edit any field; the next render will pick it up. Missing fields fall back
# to the defaults baked into publication_theme.R / adj.R / consolidated.

PUBLICATION_CONFIG <- list(

  # ----- Typography -----
  base_size           = 12,      # base font size (pt)
  title_size_rel      = 1.20,    # plot title, multiplier of base_size
  subtitle_size_rel   = 0.78,
  axis_title_size_rel = 0.95,
  axis_text_size_rel  = 0.78,
  axis_text_y_rel     = 0.82,
  strip_text_size_rel = 0.85,
  font_family         = "Nimbus Sans",  # "sans" fallback if not installed

  # ----- Category palette (strong/dots/inner-SD1-bar) -----
  color_total   = "#3B6EA5",
  color_animal  = "#C44E52",
  color_plant   = "#4C9F70",
  color_male    = "#56A0CE",
  color_female  = "#D65670",

  # ----- Wash palette — OUTER 95% CrI bar (lighter than strong) -----
  color_total_wash   = "#A7BED8",
  color_animal_wash  = "#E4AEB0",
  color_plant_wash   = "#AED4BA",
  color_male_wash    = "#A9C9E2",
  color_female_wash  = "#EDA8B3",

  # ----- Restaurant outer "medium" wash -----
  color_total_restwash   = "#96AFC8",
  color_animal_restwash  = "#DAA1A2",
  color_plant_restwash   = "#9EC7AB",
  color_male_restwash    = "#7FB2D9",
  color_female_restwash  = "#E27F8D",

  # ----- Pooled outer "dark" wash -----
  color_total_innerdark   = "#85A0BD",
  color_animal_innerdark  = "#CF9194",
  color_plant_innerdark   = "#8DBA9C",
  color_male_innerdark    = "#2C5F85",
  color_female_innerdark  = "#8C2D3D",

  # ----- Pooled bar aesthetics -----
  pooled_bar_linewidth   = 1.4,
  pooled_bar_alpha_outer = 1.0,
  pooled_bar_alpha_inner = 1.0,

  # ----- Restaurant bar aesthetics -----
  rest_bar_linewidth     = 0.35,
  rest_bar_alpha_outer   = 0.55,
  rest_bar_alpha_inner   = 0.55,

  # ----- Points -----
  pooled_point_size    = 3.1,
  pooled_point_stroke  = 0,
  rest_point_size      = 1.4,
  rest_point_alpha     = 0.6,
  rest_point_stroke    = 0,

  # ----- Panels / spacing -----
  panel_spacing_y_lines = 0,      # 0 = stacked facet rows touch
  panel_spacing_x_lines = 0.8,
  plot_margin_px        = c(t = 14, r = 18, b = 10, l = 14),

  # ----- Reference line (x=0/x=1) -----
  vline_color     = "grey55",
  vline_linewidth = 0.4,

  # ----- Cross-plot visual consistency -----
  # Number of y-axis data units per inch of plot height. Smaller value =
  # taller plot per outcome row. By computing png_h dynamically from this,
  # cap_pooled, cap_rest, step_size, etc. (all measured in y-units) translate
  # to the same physical size on EVERY plot. Tweak here to scale all plots
  # at once; per-plot png_h in plot_config.R still wins if explicitly set.
  y_per_inch = 4
)

# Pull a config field with a fallback default.
pub_cfg <- function(field, default = NULL) {
  v <- PUBLICATION_CONFIG[[field]]
  if (is.null(v)) default else v
}

# Resolve a config value with per-plot override priority:
#   per-plot (plot_config.R entry) -> uniform (publication_config.R) -> default.
# Use this in the renderer when a knob should be tweakable per-plot.
plot_or_pub <- function(cfg, field, default = NULL) {
  if (!is.null(cfg) && !is.null(cfg[[field]])) return(cfg[[field]])
  pub_cfg(field, default)
}

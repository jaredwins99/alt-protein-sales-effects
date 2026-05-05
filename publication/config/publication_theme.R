# Publication-quality theme + palette for T1 total-adjusted forest plots.
# Target venues: Nature Food / Nature Comms level figures (clean, legible,
# colourblind-safe, print-friendly).
#
# Used by:
#   - create_forest_plots_restaurants_chosen_recolored_adj.R   (A1–A4)
#   - publication/create_customer_day_forest_plots_consolidated.R (A5/A6)
#
# Keep this file small — it is sourced into both scripts and both paths must
# still produce working plotly HTMLs (click-to-open handlers).

suppressPackageStartupMessages({
  library(ggplot2)
  library(grid)
  library(systemfonts)
})

source("publication/config/publication_config.R")

# ------------------------------------------------------------------
# Palette
# ------------------------------------------------------------------
# Muted, colour-blind-safe trio chosen from ColorBrewer "Dark2" plus a
# desaturated blue. Distinct in grayscale conversion and in 2.5D-deuter/prot
# simulations; prints well on matte stock. Mapped to the three category roles:
#   Total  -> slate blue   (neutral reference)
#   Animal -> warm red     (vermilion, from Wong palette)
#   Plant  -> teal green   (Dark2 green, less saturated than forestgreen)
# Male / Female (for the Gender x Level facet in A5/A6) use Wong blue/orange
# so they do not clash with the category palette.
PUB_COLORS <- c(
  "Total"       = pub_cfg("color_total",  "#3B6EA5"),  # muted slate blue
  "Animal"      = pub_cfg("color_animal", "#C44E52"),  # muted brick red
  "Plant-based" = pub_cfg("color_plant",  "#4C9F70"),  # teal/forest green
  "Male"        = pub_cfg("color_male",   "#56A0CE"),  # matplotlib blue (user preferred over Wong #0072B2)
  "Female"      = pub_cfg("color_female", "#D65670")   # matplotlib red (user preferred over Wong vermilion / burnt orange)
)

# Legacy aliases used by build_forest() in the consolidated script (it feeds
# raw "steelblue"/"firebrick"/"forestgreen" strings through a named-vector
# scale_color_manual). Map the old names to the new publication colours so the
# downstream scale_color_manual lookup still resolves.
PUB_COLORS_LEGACY <- c(
  "steelblue"   = unname(PUB_COLORS["Total"]),
  "firebrick"   = unname(PUB_COLORS["Animal"]),
  "forestgreen" = unname(PUB_COLORS["Plant-based"]),
  "Male"        = unname(PUB_COLORS["Male"]),
  "Female"      = unname(PUB_COLORS["Female"])
)

# Outer (2 SD / 95% CrI) "wash" variant: category color mixed ~55% toward white
# so the wide CrI reads as a pale backdrop; the inner 1-SD band in full
# saturation sits on top as the crisp "point estimate" region. Kept under the
# _INNER name for backwards compatibility with the downstream scale lookups —
# semantically these are OUTER/wash colours, and build_forest maps the aes
# accordingly (see *_inner column usage in adj.R / consolidated).
PUB_COLORS_INNER <- c(
  "Total"       = pub_cfg("color_total_wash",  "#A7BED8"),  # soft slate wash
  "Animal"      = pub_cfg("color_animal_wash", "#E4AEB0"),  # soft brick wash
  "Plant-based" = pub_cfg("color_plant_wash",  "#AED4BA"),  # soft sage wash
  "Male"        = pub_cfg("color_male_wash",   "#A9C9E2"),  # soft matplotlib-blue wash
  "Female"      = pub_cfg("color_female_wash", "#EDA8B3")   # soft matplotlib-red wash
)
PUB_COLORS_LEGACY_INNER <- c(
  "steelblue"   = unname(PUB_COLORS_INNER["Total"]),
  "firebrick"   = unname(PUB_COLORS_INNER["Animal"]),
  "forestgreen" = unname(PUB_COLORS_INNER["Plant-based"]),
  "Male"        = unname(PUB_COLORS_INNER["Male"]),
  "Female"      = unname(PUB_COLORS_INNER["Female"])
)
# Three ordered wash tiers from lightest to darkest:
#   PUB_COLORS_INNER       — lightest wash (no longer used directly; kept for
#                            back-compat with any stale consumer)
#   PUB_COLORS_REST_WASH   — MEDIUM wash, used for restaurant-level SD2 outer
#   PUB_COLORS_INNER_DARK  — DARKER wash, used for pooled-level SD2 outer
# Full-saturation PUB_COLORS sits above all these and is used for the inner
# SD1 bar (and dots). So the visual order from light to dark is
#   rest-outer < pooled-outer < everyone's inner-SD1.

PUB_COLORS_REST_WASH <- c(
  "Total"       = pub_cfg("color_total_restwash",  "#96AFC8"),  # between INNER #A7BED8 and INNER_DARK #85A0BD
  "Animal"      = pub_cfg("color_animal_restwash", "#DAA1A2"),
  "Plant-based" = pub_cfg("color_plant_restwash",  "#9EC7AB"),
  "Male"        = pub_cfg("color_male_restwash",   "#7FB2D9"),  # matplotlib-blue mid wash
  "Female"      = pub_cfg("color_female_restwash", "#E27F8D")   # matplotlib-red mid wash
)

PUB_COLORS_INNER_DARK <- c(
  "Total"       = pub_cfg("color_total_innerdark",  "#85A0BD"),
  "Animal"      = pub_cfg("color_animal_innerdark", "#CF9194"),
  "Plant-based" = pub_cfg("color_plant_innerdark",  "#8DBA9C"),
  "Male"        = pub_cfg("color_male_innerdark",   "#2C5F85"),  # matplotlib-blue darker wash
  "Female"      = pub_cfg("color_female_innerdark", "#8C2D3D")   # matplotlib-red darker wash
)
PUB_COLORS_LEGACY_REST_WASH <- c(
  "steelblue"   = unname(PUB_COLORS_REST_WASH["Total"]),
  "firebrick"   = unname(PUB_COLORS_REST_WASH["Animal"]),
  "forestgreen" = unname(PUB_COLORS_REST_WASH["Plant-based"]),
  "Male"        = unname(PUB_COLORS_REST_WASH["Male"]),
  "Female"      = unname(PUB_COLORS_REST_WASH["Female"])
)
PUB_COLORS_LEGACY_INNER_DARK <- c(
  "steelblue"   = unname(PUB_COLORS_INNER_DARK["Total"]),
  "firebrick"   = unname(PUB_COLORS_INNER_DARK["Animal"]),
  "forestgreen" = unname(PUB_COLORS_INNER_DARK["Plant-based"]),
  "Male"        = unname(PUB_COLORS_INNER_DARK["Male"]),
  "Female"      = unname(PUB_COLORS_INNER_DARK["Female"])
)

# Combined scales: a single scale_color_manual(values = PUB_COLORS_ALL) resolves
# all four aes mappings: strong, inner (legacy), restwash, innerdark.
PUB_COLORS_ALL <- c(
  PUB_COLORS,
  setNames(PUB_COLORS_INNER,      paste0(names(PUB_COLORS_INNER),      "_inner")),
  setNames(PUB_COLORS_REST_WASH,  paste0(names(PUB_COLORS_REST_WASH),  "_restwash")),
  setNames(PUB_COLORS_INNER_DARK, paste0(names(PUB_COLORS_INNER_DARK), "_innerdark"))
)
PUB_COLORS_LEGACY_ALL <- c(
  PUB_COLORS_LEGACY,
  setNames(PUB_COLORS_LEGACY_INNER,      paste0(names(PUB_COLORS_LEGACY_INNER),      "_inner")),
  setNames(PUB_COLORS_LEGACY_REST_WASH,  paste0(names(PUB_COLORS_LEGACY_REST_WASH),  "_restwash")),
  setNames(PUB_COLORS_LEGACY_INNER_DARK, paste0(names(PUB_COLORS_LEGACY_INNER_DARK), "_innerdark"))
)

# ------------------------------------------------------------------
# Typography helpers
# ------------------------------------------------------------------
# Use a sans-serif family that is available both on Linux (Liberation Sans,
# DejaVu Sans) and Windows/Mac (Arial/Helvetica). ggplot's default "" family
# resolves to the device default, which for cairo is DejaVu Sans. Setting
# "sans" explicitly makes ggsave() consistent across devices.
# Nimbus Sans is a Helvetica clone (URW, metrically identical). Journals that
# specify Helvetica/Arial accept it in practice, and Cairo devices render it
# cleanly on Linux without needing msttcorefonts. Falls back to "sans" if the
# font isn't installed.
.pub_preferred_font <- pub_cfg("font_family", "Nimbus Sans")
PUB_FONT_FAMILY <- if (any(grepl(.pub_preferred_font, systemfonts::system_fonts()$family,
                                 ignore.case = TRUE))) .pub_preferred_font else "sans"

# ------------------------------------------------------------------
# Theme
# ------------------------------------------------------------------
#' Publication forest-plot theme.
#'
#' Differences from the previous theme_minimal(11) used in the adj scripts:
#'   - base size 12 (default), consistent sans family
#'   - title 14pt bold, subtitle small & de-emphasised, axis titles 11pt bold
#'   - facet strips: neutral light grey, bold but not oversized
#'   - no minor gridlines; no y gridlines (rows are labelled)
#'   - subtle x gridline, pale grey
#'   - generous plot.margin and panel.spacing for manuscript breathing room
#'
#' @param base_size base font size (default 12).
#' @param y_grid whether to draw a light horizontal gridline per row
#'   (kept off by default — labels already identify rows).
publication_forest_theme <- function(base_size = pub_cfg("base_size", 12),
                                     y_grid = FALSE) {
  .pm <- pub_cfg("plot_margin_px", c(t = 14, r = 18, b = 10, l = 14))
  th <- theme_minimal(base_size = base_size, base_family = PUB_FONT_FAMILY) +
    theme(
      # Titles
      plot.title        = element_text(face = "bold",
                                       size = rel(pub_cfg("title_size_rel", 1.20)),
                                       margin = margin(b = 4)),
      plot.subtitle     = element_text(size = rel(pub_cfg("subtitle_size_rel", 0.78)),
                                       color = "grey35",
                                       margin = margin(b = 10)),
      plot.title.position = "plot",
      # Axes
      axis.title.x      = element_text(face = "bold",
                                       size = rel(pub_cfg("axis_title_size_rel", 0.95)),
                                       margin = margin(t = 10)),
      axis.title.y      = element_text(face = "bold",
                                       size = rel(pub_cfg("axis_title_size_rel", 0.95)),
                                       margin = margin(r = 10)),
      axis.text         = element_text(size = rel(pub_cfg("axis_text_size_rel", 0.78)),
                                       color = "grey20"),
      axis.text.y       = element_text(size = rel(pub_cfg("axis_text_y_rel", 0.82)),
                                       color = "grey15"),
      axis.ticks.x      = element_line(color = "grey60", linewidth = 0.3),
      axis.ticks.y      = element_blank(),
      axis.line.x       = element_line(color = "grey40", linewidth = 0.4),
      # Panels / grid
      panel.grid.minor        = element_blank(),
      panel.grid.major.y      = if (y_grid) element_line(color = "grey92",
                                                         linewidth = 0.3)
                                else element_blank(),
      panel.grid.major.x      = element_line(color = "grey88", linewidth = 0.25),
      panel.background        = element_rect(fill = "white", color = NA),
      panel.border            = element_rect(color = "grey75", fill = NA, linewidth = 0.4),
      plot.background         = element_rect(fill = "white", color = NA),
      panel.spacing.x         = unit(pub_cfg("panel_spacing_x_lines", 0.8), "lines"),
      # Tight vertical packing so stacked exposure-group facets read as one
      # continuous column without a gap between groups.
      panel.spacing.y         = unit(pub_cfg("panel_spacing_y_lines", 0), "lines"),
      # Strips
      strip.background  = element_rect(fill = "grey94", color = NA),
      strip.text        = element_text(face = "bold",
                                       size = rel(pub_cfg("strip_text_size_rel", 0.85)),
                                       color = "grey15",
                                       margin = margin(t = 4, b = 4, l = 6, r = 6)),
      # Legend (usually hidden in these plots but kept consistent)
      legend.title      = element_blank(),
      legend.text       = element_text(size = rel(0.8)),
      legend.position   = "bottom",
      legend.background = element_rect(fill = alpha("white", 0.8),
                                       color = "grey85", linewidth = 0.25),
      legend.key        = element_rect(fill = "white", color = NA),
      # Outer margin
      plot.margin       = margin(.pm[["t"]], .pm[["r"]], .pm[["b"]], .pm[["l"]])
    )
  th
}

# ------------------------------------------------------------------
# ggsave helpers that use cairo_pdf for reliable font embedding.
# PNG path uses device = "png" with type = "cairo" so anti-aliasing matches.
# ------------------------------------------------------------------
pub_ggsave_png <- function(filename, plot, width, height, dpi = 320) {
  ggplot2::ggsave(filename, plot,
                  width = width, height = height, dpi = dpi,
                  bg = "white",
                  device = grDevices::png, type = "cairo-png")
}

pub_ggsave_pdf <- function(filename, plot, width, height) {
  # cairo_pdf embeds fonts (vs default pdf() device which does not).
  ggplot2::ggsave(filename, plot,
                  width = width, height = height,
                  bg = "white",
                  device = grDevices::cairo_pdf)
}

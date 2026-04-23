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
  "Total"       = "#3B6EA5",  # muted slate blue
  "Animal"      = "#C44E52",  # muted brick red
  "Plant-based" = "#4C9F70",  # teal/forest green
  "Male"        = "#0072B2",  # Wong blue
  "Female"      = "#D55E00"   # Wong vermilion
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
PUB_FONT_FAMILY <- if (any(grepl("Nimbus Sans", systemfonts::system_fonts()$family,
                                 ignore.case = TRUE))) "Nimbus Sans" else "sans"

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
publication_forest_theme <- function(base_size = 12, y_grid = FALSE) {
  th <- theme_minimal(base_size = base_size, base_family = PUB_FONT_FAMILY) +
    theme(
      # Titles
      plot.title        = element_text(face = "bold", size = rel(1.20),
                                       margin = margin(b = 4)),
      plot.subtitle     = element_text(size = rel(0.78), color = "grey35",
                                       margin = margin(b = 10)),
      plot.title.position = "plot",
      # Axes
      axis.title.x      = element_text(face = "bold", size = rel(0.95),
                                       margin = margin(t = 10)),
      axis.title.y      = element_text(face = "bold", size = rel(0.95),
                                       margin = margin(r = 10)),
      axis.text         = element_text(size = rel(0.78), color = "grey20"),
      axis.text.y       = element_text(size = rel(0.82), color = "grey15"),
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
      plot.background         = element_rect(fill = "white", color = NA),
      panel.spacing.x         = unit(0.8, "lines"),
      # Tight vertical packing so stacked exposure-group facets read as one
      # continuous column without a gap between groups.
      panel.spacing.y         = unit(0.05, "lines"),
      # Strips
      strip.background  = element_rect(fill = "grey94", color = NA),
      strip.text        = element_text(face = "bold", size = rel(0.85),
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
      plot.margin       = margin(14, 18, 10, 14)
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

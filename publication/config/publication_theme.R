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
      # Axes. Wide variant: outcome tick labels bold + larger, both axis
      # titles larger (equal-sized). Wide keys checked FIRST — the base
      # keys are set in publication_config.R, so a pub_cfg default on the
      # base key can never fire.
      axis.title.x      = element_text(face = "bold",
                                       size = rel(if (PUB_WIDE) pub_cfg("axis_title_size_rel_wide", 1.10)
                                                  else pub_cfg("axis_title_size_rel", 0.95)),
                                       margin = margin(t = 10)),
      axis.title.y      = element_text(face = "bold",
                                       size = rel(if (PUB_WIDE) pub_cfg("axis_title_size_rel_wide", 1.10)
                                                  else pub_cfg("axis_title_size_rel", 0.95)),
                                       margin = margin(r = 10)),
      axis.text         = element_text(size = rel(pub_cfg("axis_text_size_rel", 0.78)),
                                       color = "grey20"),
      axis.text.y       = element_text(size = rel(if (PUB_WIDE) pub_cfg("axis_text_y_rel_wide", 0.95)
                                                  else pub_cfg("axis_text_y_rel", 0.82)),
                                       color = "grey15"),
      axis.ticks.x      = element_line(color = "grey60", linewidth = 0.3),
      axis.ticks.y      = element_blank(),
      axis.line.x       = element_line(color = "grey40", linewidth = 0.4),
      # Panels / grid
      panel.grid.minor.x      = element_line(color = "grey94", linewidth = 0.15),
      panel.grid.minor.y      = element_blank(),
      panel.grid.major.y      = if (y_grid) element_line(color = "grey92",
                                                         linewidth = 0.3)
                                else element_blank(),
      panel.grid.major.x      = element_line(color = "grey94", linewidth = 0.15),
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
# Mixed-size x-axis labels: integer breaks at full size, .25/.5/.75 at
# smaller size. Used with element_markdown() on axis.text.x.
# ------------------------------------------------------------------
# ------------------------------------------------------------------
# plotmath vs plotly.
#
# The mixed-size axis labels below are plotmath expressions: the PDF/PNG
# devices evaluate them, rendering the intermediate ticks in a smaller face.
# ggplotly does NOT evaluate plotmath -- it stringifies the call, so the axis
# comes out reading  -100%scriptstyle("-75%")scriptstyle("-50%")...  which is
# what the interactive present/ bundle was showing.
#
# So under PRESENT_MODE the helpers fall back to plain character labels. The
# only thing lost is the size hierarchy between integer and fractional ticks;
# the PDF path is untouched.
# ------------------------------------------------------------------
.PUB_PLAIN_LABELS <- toupper(Sys.getenv("PRESENT_MODE", "FALSE")) == "TRUE"

# The plotly canvas height is sized from the number of outcomes x restaurants.
# That is tuned for the PDF, where the extra room is padding; in the HTML the
# bottom legend is pinned to the base of the canvas, so the slack shows up as a
# dead gap between the x-axis title and the legend. Tightened for the
# interactive build only.
.PUB_HTML_H <- function(px) if (.PUB_PLAIN_LABELS) max(560L, as.integer(round(px * 0.72))) else px

pub_x_labels_mixed <- function(x) {
  if (.PUB_PLAIN_LABELS)
    return(ifelse(is.na(x), NA_character_, format(x, drop0trailing = TRUE, trim = TRUE)))
  parts <- vapply(x, function(v) {
    if (is.na(v)) return(NA_character_)
    if (v %% 1 == 0) deparse(bquote(.(as.integer(v))))
    else deparse(bquote(scriptstyle(.(format(v, drop0trailing = TRUE)))))
  }, character(1))
  parse(text = parts)
}

# ------------------------------------------------------------------
# PUB_RECENTER: env-var switch for the "recentered" (percentage-scale)
# variant of the pub forest plots. Default FALSE — leaves all existing
# professional/, professional_labeled/, present/ outputs unchanged.
# When TRUE, RR ticks/labels are displayed as (RR - 1) * 100 %, centered
# at 0% (RR = 1), instead of the RR scale centered at 1.
# ------------------------------------------------------------------
PUB_RECENTER <- toupper(Sys.getenv("PUB_RECENTER", "FALSE")) == "TRUE"

# ------------------------------------------------------------------
# PUB_WIDE: env-var switch for the "wide" variant of the pub forest
# plots. Default FALSE — leaves all existing professional/,
# professional_recentered/, professional_labeled/, present/ outputs
# unchanged. When TRUE, A2/A3/A4 get a taller png_h override (see
# WIDE_PNG_H in plot_config.R) and sub-renderer output directories get
# an additional "_wide" suffix appended after any existing "_sorted"/
# "_recentered" suffix.
# ------------------------------------------------------------------
PUB_WIDE <- toupper(Sys.getenv("PUB_WIDE", "FALSE")) == "TRUE"

# WIDE_LABELED: the wide_labeled/ pipeline — same content as
# professional_labeled_v2/ (restaurant names + per-row numeric estimates) but
# with the layout loosened so every label is readable. It implies PUB_WIDE and
# LABELED_V2; it only adds a distinct output path and a config layer
# (LABELED_OVERRIDES in plot_config.R) so labeled_v2/ is never overwritten.
WIDE_LABELED <- toupper(Sys.getenv("WIDE_LABELED", "FALSE")) == "TRUE"

# ------------------------------------------------------------------
# Mixed-size x-axis labels on the percentage-change scale: each RR break
# v is displayed as (v - 1) * 100 with a trailing "%". Same integer-vs-
# fractional hierarchy as pub_x_labels_mixed (RR-integer ticks big,
# RR-fractional ticks in scriptstyle).
# ------------------------------------------------------------------
pub_x_labels_pct <- function(x) {
  if (.PUB_PLAIN_LABELS) return(pub_x_labels_pct_plain(x))
  parts <- vapply(x, function(v) {
    if (is.na(v)) return(NA_character_)
    lbl <- sprintf("%.0f%%", (v - 1) * 100)
    if (v %% 1 == 0) deparse(bquote(.(lbl)))
    else deparse(bquote(scriptstyle(.(lbl))))
  }, character(1))
  parse(text = parts)
}

# Plain-text percent labels (no plotmath). Used with a vectorized
# axis.text.x element (per-tick size + colour) in the wide variant, where
# plotmath's coarse scriptstyle steps can't be fine-tuned.
pub_x_labels_pct_plain <- function(x) {
  ifelse(is.na(x), NA_character_, sprintf("%.0f%%", (x - 1) * 100))
}

# Plain-text numeric labels for identity-scale axes (A5/A6). Whole numbers
# print without a decimal; half-steps keep one.
pub_x_labels_num_plain <- function(x) {
  ifelse(is.na(x), NA_character_,
         ifelse(x %% 1 == 0, sprintf("%.0f", x), sprintf("%.1f", x)))
}

# Per-tick size/colour theme override, given the exact break vector: whole
# numbers full-size grey20, in-between ticks smaller and greyer.
# Vectorized element_text (unofficial but stable here: every break is
# inside the extended limits, so tick count matches the vector).
pub_x_axis_ticks_theme <- function(brks, base_size = 12) {
  big <- brks %% 1 == 0
  theme(axis.text.x = element_text(
    size   = ifelse(big, 0.78 * base_size, 0.52 * base_size),
    colour = ifelse(big, "grey20", "grey45")))
}

# A1-A4 (rate-ratio scale): 0.25-step ticks between the RR integers.
pub_x_axis_wide_theme <- function(xlim, base_size = 12)
  pub_x_axis_ticks_theme(seq(0, xlim[2], 0.25), base_size)

# Fraction of the x-range that clipped CI bars extend past the axis limits so
# they reach the panel border instead of stopping at the last gridline.
# A1-A4 define this locally; A5/A6 read it from here.
PUB_OVERSHOOT <- 0.045

# Placement for the per-row numeric labels in the labeled pipelines. Prefers
# just right of the upper CI end; if the text would run past the panel it
# tries just left of the lower end; if the CI spans the panel it sits above
# the point instead. Expects a `.num` column and the *_disp columns, and adds
# .num_x / .num_hj / .num_dy for use in aes().
# Approximate width of one character of a size-1.8 numeric label, as a fraction
# of the x-axis span. Used by every "does this label fit?" test so they all
# agree.
#
# Measured off the rendered PDF rather than guessed: on A3 (span 300, panel
# 418 px at 110 dpi) the 15-character label "70% [-43%,362%]" occupies ~88 px
# = ~63 axis units, i.e. ~4.2 units per character = 0.014 of the span. A
# 14-character label on the Level facet measures the same 0.014. The previous
# 0.0075 underestimated width by ~45%, which is why long labels
# ("-13% [-44%,80%]", "-58% [-97%,300%]") passed the fit test and then
# overflowed the panel edge.
#
# Erring high is safe: it only ever moves a label to the above-point fallback,
# never further out.
.PUB_CHAR_W <- 0.014

pub_add_num_pos <- function(df, xlim, dy = 0.4, char_w = .PUB_CHAR_W, pad = 0.012) {
  span  <- xlim[2] - xlim[1]
  w     <- nchar(df$.num) * char_w * span
  gap   <- 0.02 * span
  fit_r <- df$q97.5_disp + gap + w <= xlim[2] - pad * span
  fit_l <- df$q2.5_disp  - gap - w >= xlim[1] + pad * span
  df$.num_x  <- ifelse(fit_r, df$q97.5_disp + gap,
                ifelse(fit_l, df$q2.5_disp  - gap, df$mean_disp))
  df$.num_hj <- ifelse(fit_r, 0, ifelse(fit_l, 1, 0.5))
  df$.num_dy <- ifelse(fit_r | fit_l, 0, dy)
  df
}

# ------------------------------------------------------------------
# Pooled numeric labels
# ------------------------------------------------------------------
# The label pair (bold point estimate + bracketed interval) is anchored on
# the point estimate, so a pooled estimate sitting near the right edge — a
# clipped CI — runs its interval text off the panel. Returns the leftward
# shift needed to keep the whole pair inside the panel, and 0 for labels that
# already fit, so nothing that currently renders correctly moves.
pub_pooled_label_shift <- function(mean_disp, mean_orig, q2.5_orig, q97.5_orig,
                                   xlim, char_w = 0.007, pad = 0.012) {
  span   <- xlim[2] - xlim[1]
  n_mean <- nchar(if (PUB_RECENTER) sprintf("%.0f%%", (mean_orig - 1) * 100)
                  else              sprintf("%.2f", mean_orig))
  n_ci   <- nchar(if (PUB_RECENTER)
                    sprintf(" [%.0f%%, %.0f%%]", (q2.5_orig - 1) * 100, (q97.5_orig - 1) * 100)
                  else sprintf(" [%.2f, %.2f]", q2.5_orig, q97.5_orig))
  off    <- (0.020 + char_w * pmax(n_mean - 2, 0)) * span
  pmax(0, (mean_disp + off + char_w * n_ci * span) - (xlim[2] - pad * span))
}

# ------------------------------------------------------------------
# Outcome axis labels
# ------------------------------------------------------------------
# Shared raw-outcome -> display-label map so A5/A6 read the same as A1-A4
# ("chicken_fish" -> "Chicken & fish", "untextured" -> "Ground meat").
# A "_t2" suffix is stripped before lookup; unmapped names fall back to
# title case.
PUB_OUTCOME_LABELS <- c(
  total        = "Total",
  nonvegan     = "Nonvegan",
  meat         = "Meat",
  chicken_fish = "Chicken & fish",
  vegetarian   = "Vegetarian",
  vegan        = "Vegan",
  breakfast    = "Breakfast-style meat",
  untextured   = "Ground meat",
  textured     = "Whole-muscle meat",
  chicken      = "Chicken",
  dairy        = "Dairy",
  egg          = "Egg"
)
pub_outcome_label <- function(x) {
  key <- sub("_t2$", "", as.character(x))
  out <- unname(PUB_OUTCOME_LABELS[key])
  fallback <- tools::toTitleCase(gsub("_", " ", key))
  ifelse(is.na(out), fallback, out)
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

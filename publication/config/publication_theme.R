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

# CI end-cap length for the interactive build.
#
# Caps are geom_segments sized in DATA units (cap_rest / cap_pooled), so their
# apparent length is purely a function of how many pixels one data unit
# occupies. The plotly canvas gives more pixels per unit than the PDF page, so
# the same value rendered as a much longer tick -- the "huge end ticks" on
# T1 A2. Scaled down for PRESENT_MODE only; the PDF keeps its tuned values.
.PUB_CAP_SCALE <- as.numeric(Sys.getenv("PUB_CAP_SCALE", "0.3"))

# The interactive build used to take the NON-publication layer set: a single
# flat 95% bar per row, no 1SD/2SD tiers, no pooled value labels, and
# theme_minimal instead of the publication theme. That is why the HTML never
# looked like the PDF -- it was a different plot, not a lossy conversion of the
# same one. Under PRESENT_MODE the HTML is built from the publication layers,
# so the two-tier CI (wash 95% under full-saturation 1SD), the labels and the
# theme carry straight over.
.PUB_HTML_PUB_STYLE <- .PUB_PLAIN_LABELS

# Hover-card percentage. The rate-ratio plots are drawn on a "percentage change
# relative to total sales" axis, so the ratio in the hover card is the one
# number on it the reader has to convert in their head. Give them both.
pub_pct_hover <- function(x) {
  ifelse(is.na(x), "n/a", sprintf("%+.1f%%", (as.numeric(x) - 1) * 100))
}

# ggplotly does not draw our geom_segment caps -- it converts geom_errorbarh
# into plotly error_x objects and draws its OWN end caps, sized in PIXELS via
# error_x$width (11-18 px here, hence the oversized ticks on T1 A2). Scaling the
# ggplot-side cap geoms therefore changes nothing visible; the width has to be
# set on the built plotly object.
# ggplotly drops facet_grid(space = "free_y"): it hands every row panel an
# equal share of the canvas, so a two-row exposure group is stretched to the
# same height as a four-row one and the leading gap above the top outcome
# opens up. Re-cut the panel domains in proportion to each panel's own data
# range -- which is what space = "free_y" does in the PDF -- and carry every
# paper-space shape and annotation (the facet strips) through the same remap.
.pub_plotly_free_y <- function(p) {
  lay  <- p$x$layout
  keys <- grep("^yaxis[0-9]*$", names(lay), value = TRUE)
  keys <- Filter(function(k) {
    a <- lay[[k]]
    is.list(a) && length(a$domain) == 2L && length(a$range) == 2L
  }, keys)
  if (length(keys) < 2L) return(p)

  lo   <- vapply(keys, function(k) as.numeric(lay[[k]]$domain[[1]]), numeric(1))
  hi   <- vapply(keys, function(k) as.numeric(lay[[k]]$domain[[2]]), numeric(1))
  span <- vapply(keys, function(k) abs(diff(as.numeric(unlist(lay[[k]]$range)))), numeric(1))
  if (any(!is.finite(c(lo, hi, span))) || any(span <= 0) || any(hi <= lo)) return(p)

  o <- order(lo); keys <- keys[o]; lo <- lo[o]; hi <- hi[o]; span <- span[o]
  # Fixed scales (all panels share a range) already come out proportional.
  dens <- span / (hi - lo)
  if (max(dens) / min(dens) < 1.01) return(p)

  gaps  <- c(lo[1], lo[-1] - hi[-length(hi)], 1 - hi[length(hi)])
  avail <- 1 - sum(gaps)
  if (avail <= 0 || any(gaps < 0)) return(p)
  h <- avail * span / sum(span)

  n <- length(h); new_lo <- numeric(n); new_hi <- numeric(n); cur <- gaps[1]
  for (i in seq_len(n)) {
    new_lo[i] <- cur
    new_hi[i] <- cur + h[i]
    cur <- new_hi[i] + gaps[i + 1L]
  }

  old_b <- c(0, as.numeric(rbind(lo, hi)), 1)
  new_b <- c(0, as.numeric(rbind(new_lo, new_hi)), 1)
  remap <- function(y) {
    if (!is.numeric(y) || length(y) != 1L || !is.finite(y)) return(y)
    y <- min(max(y, 0), 1)
    j <- max(which(old_b <= y))
    if (j >= length(old_b)) return(new_b[length(new_b)])
    w <- old_b[j + 1L] - old_b[j]
    if (w <= 0) return(new_b[j])
    new_b[j] + (y - old_b[j]) / w * (new_b[j + 1L] - new_b[j])
  }

  for (i in seq_len(n)) p$x$layout[[keys[i]]]$domain <- c(new_lo[i], new_hi[i])
  for (fld in c("shapes", "annotations")) {
    items <- p$x$layout[[fld]]
    if (is.null(items)) next
    for (i in seq_along(items)) {
      if (!identical(items[[i]]$yref, "paper")) next
      for (nm in c("y", "y0", "y1")) {
        v <- items[[i]][[nm]]
        if (!is.null(v)) items[[i]][[nm]] <- remap(v)
      }
    }
    p$x$layout[[fld]] <- items
  }
  p
}

# The right-hand facet strips carry horizontal text (strip.text.y angle = 0),
# and ggplotly sizes their box by the text's HEIGHT, as if it were still
# rotated: an 19px strip holding a 130px label, so every exposure name is
# clipped at the canvas edge. Widen the strip boxes and the right margin to
# the widest label, and centre the text in the box the way the PDF does.
.pub_plotly_row_strips <- function(p) {
  lay <- p$x$layout
  is_ann <- function(a) identical(a$xref, "paper") && identical(a$xanchor, "left") &&
    is.numeric(a$x) && isTRUE(all.equal(as.numeric(a$x), 1)) &&
    (is.null(a$textangle) || isTRUE(all.equal(as.numeric(a$textangle), 0)))
  is_box <- function(s) identical(s$xsizemode, "pixel") && is.numeric(s$x0) &&
    isTRUE(all.equal(as.numeric(s$x0), 0)) && is.numeric(s$xanchor) &&
    isTRUE(all.equal(as.numeric(s$xanchor), 1))

  anns <- if (is.null(lay$annotations)) list() else lay$annotations
  shps <- if (is.null(lay$shapes))      list() else lay$shapes
  ai <- which(vapply(anns, is_ann, logical(1)))
  si <- which(vapply(shps, is_box, logical(1)))
  if (!length(ai) || !length(si)) return(p)

  need <- 0
  for (i in ai) {
    a  <- lay$annotations[[i]]
    sz <- if (is.null(a$font$size)) 11 else as.numeric(a$font$size)
    for (line in strsplit(as.character(a$text), "<br */?>")[[1]])
      need <- max(need, nchar(line) * sz * 0.56)
  }
  w <- need + 12
  if (w <= max(vapply(si, function(i) as.numeric(lay$shapes[[i]]$x1), numeric(1)))) return(p)

  for (i in si) p$x$layout$shapes[[i]]$x1 <- w
  for (i in ai) {
    p$x$layout$annotations[[i]]$xanchor <- "center"
    p$x$layout$annotations[[i]]$xshift  <- w / 2
  }
  cur_r <- if (is.null(p$x$layout$margin$r)) 0 else as.numeric(p$x$layout$margin$r)
  p$x$layout$margin$r <- max(cur_r, w)
  p
}

# Column strips get the mirror-image of the row-strip bug: ggplotly gives the
# grey box a 1px height, so the "Form: Presence" band that the PDF draws behind
# the label simply is not there. Size the box to the label instead.
.pub_plotly_col_strips <- function(p) {
  lay  <- p$x$layout
  anns <- if (is.null(lay$annotations)) list() else lay$annotations
  shps <- if (is.null(lay$shapes))      list() else lay$shapes
  is_ann <- function(a) identical(a$yref, "paper") && identical(a$yanchor, "bottom") &&
    is.numeric(a$y) && isTRUE(all.equal(as.numeric(a$y), 1))
  is_box <- function(s) identical(s$ysizemode, "pixel") && is.numeric(s$y0) &&
    isTRUE(all.equal(as.numeric(s$y0), 0)) && is.numeric(s$yanchor) &&
    isTRUE(all.equal(as.numeric(s$yanchor), 1)) && is.numeric(s$y1) && s$y1 <= 2

  ai <- which(vapply(anns, is_ann, logical(1)))
  si <- which(vapply(shps, is_box, logical(1)))
  if (!length(ai) || !length(si)) return(p)

  sz <- max(vapply(ai, function(i) {
    f <- anns[[i]]$font$size
    if (is.null(f)) 11 else as.numeric(f)
  }, numeric(1)))
  h <- sz * 1.9 + 4
  for (i in si) p$x$layout$shapes[[i]]$y1 <- h
  cur_t <- if (is.null(p$x$layout$margin$t)) 0 else as.numeric(p$x$layout$margin$t)
  p$x$layout$margin$t <- max(cur_t, h + 8)
  p
}

# The pooled estimate carries two geom_text layers in the PDF -- a bold mean
# over the point and the [lo, hi] range beside it. On paper that is the only
# way to read an exact value; in the browser the hover card gives it, and the
# labels just sit on top of the estimates they describe. Dropped for the
# interactive build. The labelled bundle's per-restaurant names and numbers are
# NOT dropped -- they are the whole point of that bundle.
.pub_plotly_drop_pooled_labels <- function(p) {
  dat <- p$x$data
  txt_of <- function(t) as.character(unlist(t$text))
  is_val <- function(t) {
    if (is.null(t$mode) || !grepl("text", t$mode)) return(FALSE)
    tx <- txt_of(t)
    if (!length(tx) || !is.character(tx)) return(FALSE)
    # "-8%", "1.04", " [-34%, 25%]", " [0.66, 1.25]" -- a bare number or a
    # bracketed pair, nothing else. Restaurant name labels never match.
    all(grepl("^\\s*-?[0-9.]+%?\\s*$", tx) | grepl("^\\s*\\[[^]]*\\]\\s*$", tx))
  }
  idx <- which(vapply(dat, is_val, logical(1)))
  if (length(idx)) p$x$data <- p$x$data[-idx]
  p
}

# ggplotly hard-codes the R device's font family into every text element. That
# resolves to whatever URW clone the render box happens to have ("Nimbus
# Sans"), which no reader's machine has, so the browser silently falls back --
# usually to a serif. Hand the page a real web stack instead, and nudge the
# sizes up: the PDF is read at page size, the HTML at tile size.
.PUB_HTML_FONT  <- '-apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif'
.PUB_FONT_SCALE <- as.numeric(Sys.getenv("PUB_FONT_SCALE", "1.12"))

.pub_plotly_fonts <- function(p) {
  fix <- function(f) {
    if (is.null(f) || !is.list(f)) return(f)
    f$family <- .PUB_HTML_FONT
    if (!is.null(f$size) && is.numeric(f$size)) f$size <- f$size * .PUB_FONT_SCALE
    f
  }
  lay <- p$x$layout
  lay$font <- fix(if (is.null(lay$font)) list(size = 12) else lay$font)
  if (is.list(lay$title)) lay$title$font <- fix(lay$title$font)
  if (is.list(lay$legend)) lay$legend$font <- fix(lay$legend$font)
  if (is.list(lay$hoverlabel)) lay$hoverlabel$font <- fix(lay$hoverlabel$font)
  for (k in grep("^[xy]axis[0-9]*$", names(lay), value = TRUE)) {
    lay[[k]]$tickfont <- fix(lay[[k]]$tickfont)
    if (is.list(lay[[k]]$title)) lay[[k]]$title$font <- fix(lay[[k]]$title$font)
  }
  for (i in seq_along(lay$annotations)) lay$annotations[[i]]$font <- fix(lay$annotations[[i]]$font)
  p$x$layout <- lay
  for (i in seq_along(p$x$data)) {
    p$x$data[[i]]$textfont <- fix(p$x$data[[i]]$textfont)
    if (is.list(p$x$data[[i]]$hoverlabel))
      p$x$data[[i]]$hoverlabel$font <- fix(p$x$data[[i]]$hoverlabel$font)
  }
  p
}

# CI end caps are drawn in DATA units (geom_segment, height in y-units), so
# their on-screen length is whatever the plot's rows-per-pixel happens to be:
# measured across the T1 bundle the restaurant cap ranged 2.1px (A1, 1166px
# tall, many rows) to 11.1px (A4, 560px tall, few) -- a 5x spread between tiles
# sitting side by side. Rescale every cap by one per-plot factor so the largest
# lands on PUB_CAP_PX, which keeps the pooled-vs-restaurant proportion the plot
# intends while making the ticks identical from plot to plot. Plots whose caps
# come from plotly error_x objects instead are sized directly, in pixels.
.PUB_CAP_PX <- as.numeric(Sys.getenv("PUB_CAP_PX", "9"))

.pub_plotly_uniform_caps <- function(p) {
  lay <- p$x$layout
  H <- lay$height
  if (is.null(H) || !is.numeric(H)) return(p)
  ph <- H - (if (is.null(lay$margin$t)) 0 else lay$margin$t) -
             (if (is.null(lay$margin$b)) 0 else lay$margin$b)
  if (!is.finite(ph) || ph <= 0) return(p)

  ax_of <- function(t) {
    a <- if (is.null(t$yaxis)) "y" else t$yaxis
    k <- sub("^y", "yaxis", a)
    if (identical(k, "yaxis") || !is.null(lay[[k]])) lay[[k]] else NULL
  }
  ppu_of <- function(a) {
    if (is.null(a) || length(a$domain) != 2L || length(a$range) != 2L) return(NA_real_)
    span <- abs(diff(as.numeric(unlist(a$range))))
    if (!is.finite(span) || span <= 0) return(NA_real_)
    (a$domain[[2]] - a$domain[[1]]) * ph / span
  }

  # Vertical runs in a line trace, skipping the NA separators ggplotly writes
  # between segments.
  #
  # The reference vline is also a vertical run, and it used to be told apart by
  # length -- anything over a third of the panel was assumed to be it. That
  # misfires on short panels: T1 A2's three-row outcomes have a span of ~1.07
  # against a 0.4-unit pooled cap, so the cap tripped the test, was skipped, and
  # shipped at 38px next to the 9px caps in the taller panels. geom_vline draws
  # dashed and the caps draw solid, which is exact, so use that instead and let
  # the caps be any length they like.
  runs_of <- function(t) {
    if (is.null(t$mode) || !grepl("lines", t$mode)) return(NULL)
    if (!is.null(t$line$dash) && !identical(t$line$dash, "solid")) return(NULL)
    x <- suppressWarnings(as.numeric(unlist(t$x)))
    y <- suppressWarnings(as.numeric(unlist(t$y)))
    if (length(x) < 2L || length(x) != length(y)) return(NULL)
    a <- ax_of(t); if (is.null(a) || length(a$range) != 2L) return(NULL)
    out <- integer(0); len <- numeric(0)
    for (i in seq_len(length(x) - 1L)) {
      if (anyNA(c(x[i], x[i + 1L], y[i], y[i + 1L]))) next
      if (!isTRUE(all.equal(x[i], x[i + 1L]))) next
      d <- abs(y[i + 1L] - y[i])
      if (d <= 0) next
      out <- c(out, i); len <- c(len, d)
    }
    if (!length(out)) NULL else list(i = out, len = len, ppu = ppu_of(a))
  }

  # Two tick sizes across the whole grid, not a per-plot rescale of whatever
  # ratio that plot happened to use: T1 draws its restaurant cap at 31% of the
  # pooled one and T2 at 50%, so a plain rescale still left a T1 tile and a T2
  # tile with visibly different ticks. Pooled (the long class) lands on
  # PUB_CAP_PX, everything shorter on half that.
  info <- lapply(p$x$data, runs_of)
  px   <- unlist(lapply(info, function(r) if (is.null(r) || !is.finite(r$ppu)) NULL else r$len * r$ppu))
  if (length(px)) {
    top <- max(px)
    for (j in seq_along(info)) {
      r <- info[[j]]; if (is.null(r) || !is.finite(r$ppu) || r$ppu <= 0) next
      y <- suppressWarnings(as.numeric(unlist(p$x$data[[j]]$y)))
      for (k in seq_along(r$i)) {
        i      <- r$i[k]
        target <- if (r$len[k] * r$ppu >= 0.7 * top) .PUB_CAP_PX else .PUB_CAP_PX / 2
        mid    <- (y[i] + y[i + 1L]) / 2
        h      <- sign(y[i + 1L] - y[i]) * (target / r$ppu) / 2
        y[i]   <- mid - h; y[i + 1L] <- mid + h
      }
      p$x$data[[j]]$y <- y
    }
  }

  # Where the caps come from plotly error_x objects instead of segments they are
  # already in pixels, but still sized off the panel: A5 shipped 2.0/4.0px and
  # A6 3.4/6.7px, against the 9px the segment-drawn plots land on. One factor
  # again, so the inner/outer proportion survives.
  ew <- unlist(lapply(p$x$data, function(t) {
    w <- t$error_x$width
    if (!is.null(w) && is.numeric(w) && w > 0) w else NULL
  }))
  if (length(ew)) {
    top <- max(ew)
    for (i in seq_along(p$x$data)) {
      w <- p$x$data[[i]]$error_x$width
      if (!is.null(w) && is.numeric(w) && w > 0)
        p$x$data[[i]]$error_x$width <- if (w >= 0.7 * top) .PUB_CAP_PX else .PUB_CAP_PX / 2
    }
  }
  p
}

# ggplot reserves headroom at the top of each panel for the pooled value label
# (expand_above, plus the label's own dy). With the labels dropped that reserve
# is just blank: on A2 the top row sat about a row and a half below the panel
# edge. Trim each panel to a half-row of padding around its actual content.
# Shrink-only -- a panel whose range is already tight is left alone.
.pub_plotly_trim_headroom <- function(p) {
  lay <- p$x$layout
  keys <- grep("^yaxis[0-9]*$", names(lay), value = TRUE)
  keys <- Filter(function(k) is.list(lay[[k]]) && length(lay[[k]]$range) == 2L, keys)
  if (!length(keys)) return(p)

  span_of <- function(k) abs(diff(as.numeric(unlist(lay[[k]]$range))))
  rows <- setNames(vector("list", length(keys)), keys)

  for (t in p$x$data) {
    k <- sub("^y", "yaxis", if (is.null(t$yaxis)) "y" else t$yaxis)
    if (!k %in% keys) next
    if (is.null(t$mode) || !grepl("markers", t$mode)) next
    v <- suppressWarnings(as.numeric(unlist(t$y)))
    v <- v[is.finite(v)]
    if (length(v)) rows[[k]] <- c(rows[[k]], v)
  }

  # Measure the POINT ESTIMATES only. Bars are horizontal and end caps are
  # rescaled after this runs, so including either would reserve room for
  # something that is not there at the size it is not there at.
  steps <- vapply(keys, function(k) {
    u <- sort(unique(round(rows[[k]], 6)))
    if (length(u) > 1L) stats::median(diff(u)) else NA_real_
  }, numeric(1))
  gstep <- suppressWarnings(stats::median(steps, na.rm = TRUE))
  if (!is.finite(gstep) || gstep <= 0) return(p)

  for (k in keys) {
    v <- rows[[k]]
    if (!length(v)) next
    # The outcome tick sits at the pooled row's slot even for outcomes whose
    # pooled row was dropped, so it can land above every point in the panel.
    # Trimming to the points alone pushed those labels outside the range and
    # they stopped being drawn -- keep the tick inside.
    tv <- suppressWarnings(as.numeric(unlist(lay[[k]]$tickvals)))
    tv <- tv[is.finite(tv)]
    r  <- as.numeric(unlist(lay[[k]]$range))
    tv <- tv[tv >= min(r) & tv <= max(r)]
    ext  <- c(v, tv)
    step <- if (is.finite(steps[[k]]) && steps[[k]] > 0) steps[[k]] else gstep
    pad  <- 0.55 * step
    p$x$layout[[k]]$range <- c(max(min(r), min(ext) - pad), min(max(r), max(ext) + pad))
  }
  p
}

# The x breaks are every 25 percentage points, which the PDF fits at page width
# and the HTML canvas does not: "-100%-75%" runs together. Keep every other
# label when the full set cannot fit the axis.
.pub_plotly_thin_xticks <- function(p) {
  lay <- p$x$layout
  W <- lay$width
  if (is.null(W) || !is.numeric(W)) W <- 1400
  avail <- W - (if (is.null(lay$margin$l)) 0 else lay$margin$l) -
                (if (is.null(lay$margin$r)) 0 else lay$margin$r)
  for (k in grep("^xaxis[0-9]*$", names(lay), value = TRUE)) {
    a <- lay[[k]]
    if (!is.list(a) || is.null(a$ticktext) || is.null(a$tickvals)) next
    tv <- unlist(a$tickvals); tt <- as.character(unlist(a$ticktext))
    n  <- length(tv)
    if (n < 4L || length(tt) != n) next
    dom <- if (length(a$domain) == 2L) a$domain[[2]] - a$domain[[1]] else 1
    sz  <- if (is.null(a$tickfont$size)) 11 else as.numeric(a$tickfont$size)
    need <- max(nchar(tt)) * sz * 0.56 + 6
    if (need * n <= avail * dom) next
    keep <- seq(1L, n, by = 2L)
    p$x$layout[[k]]$tickvals <- tv[keep]
    p$x$layout[[k]]$ticktext <- tt[keep]
  }
  p
}

# The hover cards prefix the exposure with "Exposure: ", but for the analyses
# whose exposure_group already carries that prefix the card reads "Exposure:
# Exposure: Alt-Protein-Modifiable". Cheaper and safer to clean the rendered
# string than to unpick which of the sixteen hover blocks double up.
.pub_plotly_hover_text <- function(p) {
  clean <- function(v) {
    if (is.null(v)) return(v)
    if (is.character(v)) gsub("Exposure: Exposure: ", "Exposure: ", v, fixed = TRUE) else v
  }
  for (i in seq_along(p$x$data)) {
    p$x$data[[i]]$text      <- clean(p$x$data[[i]]$text)
    p$x$data[[i]]$hovertext <- clean(p$x$data[[i]]$hovertext)
  }
  p
}

# The headroom trim pads each panel by half a row, which is the right look but
# not necessarily enough room: on A1 the top row ended up 4px from the panel
# edge, and a pooled dot plus its end cap is taller than that, so the first
# estimate was clipped. Guarantee just enough for the marker and the cap and no
# more. Re-proportions the panels after adjusting, which shifts the scale
# slightly, so it settles over a few passes.
.pub_plotly_min_gap_px <- function(p, iters = 4L) {
  for (it in seq_len(iters)) {
    lay <- p$x$layout
    H <- lay$height
    if (is.null(H) || !is.numeric(H)) return(p)
    ph <- H - (if (is.null(lay$margin$t)) 0 else lay$margin$t) -
               (if (is.null(lay$margin$b)) 0 else lay$margin$b)
    if (!is.finite(ph) || ph <= 0) return(p)

    keys <- grep("^yaxis[0-9]*$", names(lay), value = TRUE)
    keys <- Filter(function(k) is.list(lay[[k]]) && length(lay[[k]]$range) == 2L &&
                     length(lay[[k]]$domain) == 2L, keys)
    if (!length(keys)) return(p)

    changed <- FALSE
    for (k in keys) {
      a <- lay[[k]]
      r <- as.numeric(unlist(a$range))
      span <- abs(diff(r))
      if (!is.finite(span) || span <= 0) next
      ppu <- (a$domain[[2]] - a$domain[[1]]) * ph / span
      if (!is.finite(ppu) || ppu <= 0) next

      ys <- numeric(0); rad <- 0
      for (t in p$x$data) {
        if (sub("^y", "yaxis", if (is.null(t$yaxis)) "y" else t$yaxis) != k) next
        if (is.null(t$mode) || !grepl("markers", t$mode)) next
        v <- suppressWarnings(as.numeric(unlist(t$y)))
        v <- v[is.finite(v)]
        if (!length(v)) next
        ys <- c(ys, v)
        sz <- suppressWarnings(as.numeric(unlist(t$marker$size)))
        sz <- sz[is.finite(sz)]
        if (length(sz)) rad <- max(rad, max(sz) / 2)
      }
      if (!length(ys)) next

      need <- (max(rad, 2) + .PUB_CAP_PX / 2 + 1.5) / ppu
      if (max(r) - max(ys) < need - 1e-9) { r[2] <- max(ys) + need; changed <- TRUE }
      if (min(ys) - min(r) < need - 1e-9) { r[1] <- min(ys) - need; changed <- TRUE }
      p$x$layout[[k]]$range <- r
    }
    if (!changed) break
    p <- .pub_plotly_free_y(p)
  }
  p
}

# A1 packs every restaurant into one panel: 101 rows in T1 and 281 in T2, which
# at the PDF-derived canvas height leaves 7px between estimates. The PDF can
# afford that at print resolution; on screen the rows read as a solid block.
# Give dense plots a taller canvas so the rows have some air. Height only, so
# nothing about the estimates or the layout changes, and only upward, so the
# plots that already have room (A3 sits at 24px) are untouched.
.PUB_MIN_PITCH_PX <- as.numeric(Sys.getenv("PUB_MIN_PITCH_PX", "10"))
.PUB_MAX_HTML_H   <- as.numeric(Sys.getenv("PUB_MAX_HTML_H", "4000"))

.pub_plotly_row_pitch <- function(p) {
  lay <- p$x$layout
  H <- lay$height
  if (is.null(H) || !is.numeric(H)) return(p)
  mt <- if (is.null(lay$margin$t)) 0 else lay$margin$t
  mb <- if (is.null(lay$margin$b)) 0 else lay$margin$b
  ph <- H - mt - mb
  if (!is.finite(ph) || ph <= 0) return(p)

  keys <- grep("^yaxis[0-9]*$", names(lay), value = TRUE)
  pitches <- numeric(0)
  for (k in keys) {
    a <- lay[[k]]
    if (!is.list(a) || length(a$domain) != 2L || length(a$range) != 2L) next
    span <- abs(diff(as.numeric(unlist(a$range))))
    if (!is.finite(span) || span <= 0) next
    ppu <- (a$domain[[2]] - a$domain[[1]]) * ph / span
    ys <- numeric(0)
    for (t in p$x$data) {
      if (sub("^y", "yaxis", if (is.null(t$yaxis)) "y" else t$yaxis) != k) next
      if (is.null(t$mode) || !grepl("markers", t$mode)) next
      v <- suppressWarnings(as.numeric(unlist(t$y)))
      ys <- c(ys, v[is.finite(v)])
    }
    u <- sort(unique(round(ys, 6)))
    if (length(u) > 1L) pitches <- c(pitches, stats::median(diff(u)) * ppu)
  }
  if (!length(pitches)) return(p)

  cur <- stats::median(pitches)
  if (!is.finite(cur) || cur <= 0 || cur >= .PUB_MIN_PITCH_PX) return(p)
  newH <- min(.PUB_MAX_HTML_H, mt + mb + ph * (.PUB_MIN_PITCH_PX / cur))
  if (newH > H) p$x$layout$height <- newH
  p
}

pub_plotly_polish <- function(p) {
  if (!.PUB_PLAIN_LABELS) return(p)
  p <- plotly::plotly_build(p)
  # Order matters. Fonts first, so the strip boxes are sized against the sizes
  # that actually ship. Labels before the headroom trim, or their y (a row
  # above the point) is what the trim measures. Ranges before the domains, and
  # domains before the caps, which are scaled off pixels-per-data-unit.
  p <- .pub_plotly_fonts(p)
  p <- .pub_plotly_row_pitch(p)
  p <- .pub_plotly_drop_pooled_labels(p)
  p <- .pub_plotly_trim_headroom(p)
  p <- .pub_plotly_free_y(p)
  p <- .pub_plotly_min_gap_px(p)
  p <- .pub_plotly_uniform_caps(p)
  p <- .pub_plotly_row_strips(p)
  p <- .pub_plotly_col_strips(p)
  p <- .pub_plotly_thin_xticks(p)
  p <- .pub_plotly_hover_text(p)
  p
}

# Plotly canvas height for the interactive build.
#
# The PDF-tuned height leaves slack that the PDF uses as padding; in the HTML
# the bottom legend is pinned to the base of the canvas, so the slack shows as
# a dead gap between the x-axis title and the legend, and the tiles inherit it
# as whitespace. Trimmed for the interactive build only.
#
# Matching the PDF's own page aspect was tried and is worse: the measured
# content is shorter than the canvas it produces, so the tiles gained MORE
# whitespace, not less. The flat trim is what actually reads cleanly.
.PUB_HTML_H <- function(px, png_w = NULL, png_h = NULL) {
  if (!.PUB_PLAIN_LABELS) return(px)
  max(560L, as.integer(round(px * 0.72)))
}

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

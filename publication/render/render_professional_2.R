# =============================================================================
# render_professional_2.R
#
# Publication-quality forest plots for A1, A2, A3, A4 (Tier 1, total-adjusted).
# Self-contained: reads publication/forest_data_adj_95ci.csv and writes 4 PDFs
# to publication/forest_plots/z_precursors/professional_2/.
#
# Aesthetic: clean Nature/PNAS-style; quiet typography, generous whitespace,
# two-shade per-outcome palette (dark = pooled / inner 1SD; light = outer 95%).
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(stringr)
  library(ggplot2)
  library(grid)
  library(scales)
  library(patchwork)
})

# ---- project root ----------------------------------------------------------
find_project_root <- function(start = getwd()) {
  d <- normalizePath(start, mustWork = TRUE)
  repeat {
    if (file.exists(file.path(d, "publication", "forest_data_adj_95ci.csv"))) return(d)
    parent <- dirname(d)
    if (parent == d) stop("Could not find project root containing publication/forest_data_adj_95ci.csv")
    d <- parent
  }
}
ROOT <- find_project_root()
setwd(ROOT)

DATA_PATH <- "publication/forest_data_adj_95ci.csv"
OUT_DIR   <- "publication/forest_plots/z_precursors/professional_2"
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# ---- palette ---------------------------------------------------------------
# Each outcome gets one base hue; we derive a darker (pooled / 1SD inner)
# and a lighter (95% outer) shade. Hand-picked, muted, print-friendly.
OUTCOME_PALETTE <- list(
  # A1 / A3: animal-product gradient (warm -> cool plant-forward)
  nonvegan      = list(dark = "#8C3A2B", light = "#E5B7A8"),
  meat          = list(dark = "#B0432B", light = "#EFC1B0"),
  chicken_fish  = list(dark = "#C97A2E", light = "#F2D6B3"),
  vegetarian    = list(dark = "#3F7A55", light = "#BBD8C2"),
  vegan         = list(dark = "#2E5E8A", light = "#B6CCDD"),

  # A2: targeted protein components (distinct, food-evocative hues)
  breakfast_p   = list(dark = "#A65A2A", light = "#EAC8AB"),
  chicken_p     = list(dark = "#B58B2A", light = "#ECDAA9"),
  dairy_p       = list(dark = "#5C7A8C", light = "#C2CDD6"),
  egg_p         = list(dark = "#C9A227", light = "#EEDFA3"),
  untextured_p  = list(dark = "#6E5A8A", light = "#CFC4DD"),

  # A4: targeted ITS
  breakfast     = list(dark = "#A65A2A", light = "#EAC8AB"),
  textured      = list(dark = "#3F6F4A", light = "#BCD3BD"),
  untextured    = list(dark = "#6E5A8A", light = "#CFC4DD")
)

# Pretty outcome labels
OUTCOME_LABEL <- c(
  nonvegan = "Non-vegan", meat = "Meat", chicken_fish = "Chicken & fish",
  vegetarian = "Vegetarian", vegan = "Vegan",
  breakfast_p = "Breakfast", chicken_p = "Chicken", dairy_p = "Dairy",
  egg_p = "Egg", untextured_p = "Untextured",
  breakfast = "Breakfast", textured = "Textured", untextured = "Untextured"
)

# ---- read & prep -----------------------------------------------------------
raw <- read_csv(DATA_PATH, show_col_types = FALSE)

# Identify exposure_type ("count" vs "prop"/"presence") and exposure group
# from the trailing path of fit_dir. Robust to absent variants.
parse_fit_dir <- function(fit_dir) {
  base <- basename(fit_dir)
  has_dishes <- grepl("_dishes_", base)
  parts <- str_split_fixed(base, "_dishes_", 2)
  exposure_group <- ifelse(has_dishes, parts[, 1], NA_character_)
  exposure_type  <- ifelse(has_dishes, parts[, 2], NA_character_)
  tibble(exposure_group = exposure_group, exposure_type = exposure_type)
}

dat <- raw %>%
  filter(analysis %in% c("a1_proportion", "a2_proportion_t", "a3_its", "a4_its_t")) %>%
  bind_cols(parse_fit_dir(.$fit_dir)) %>%
  # drop the "total" outcome explicitly per spec
  filter(outcome != "total" | is.na(outcome)) %>%
  mutate(
    sd_log = (q97.5 - q2.5) / (2 * 1.96),
    lo1_log = mean - sd_log,
    hi1_log = mean + sd_log
  )

# Apply transform per row.
# A1 + A2: count -> exp(x); prop/presence -> exp(0.1 * x).
# A3 + A4: exp(x).
apply_transform <- function(df) {
  df %>% mutate(
    transform = case_when(
      analysis %in% c("a3_its", "a4_its_t") ~ "exp",
      analysis %in% c("a1_proportion", "a2_proportion_t") & exposure_type == "count" ~ "exp",
      analysis %in% c("a1_proportion", "a2_proportion_t") & exposure_type %in% c("prop", "presence") ~ "exp_p10",
      TRUE ~ "exp"
    ),
    point  = if_else(transform == "exp", exp(mean),    exp(0.1 * mean)),
    lo95   = if_else(transform == "exp", exp(q2.5),    exp(0.1 * q2.5)),
    hi95   = if_else(transform == "exp", exp(q97.5),   exp(0.1 * q97.5)),
    lo1sd  = if_else(transform == "exp", exp(lo1_log), exp(0.1 * lo1_log)),
    hi1sd  = if_else(transform == "exp", exp(hi1_log), exp(0.1 * hi1_log))
  )
}

dat <- apply_transform(dat)

# For A3/A4: facet by type_fine (level / slope). Pooled rows have type_fine
# already set; restaurant rows too. Good.
# For A1: gamma_index == 1 only.
# For A2: gamma_index == 1 only (restaurant rows have gamma_index NA — keep all).
keep_gamma1 <- function(df) {
  df %>% filter(level == "restaurant" | gamma_index == 1)
}

# ---- ordering / labeling helpers ------------------------------------------
order_restaurants <- function(df) {
  # Within each outcome (and facet), order restaurants by their point estimate
  # so the forest reads like a clean ladder.
  df %>%
    group_by(outcome, .add = TRUE) %>%
    mutate(rest_order = rank(point, ties.method = "first")) %>%
    ungroup()
}

# ---- core plot builder -----------------------------------------------------
# Builds a single-facet forest plot (one column of panels stacked by outcome).
# Multi-facet plots are assembled by combining single-facet plots via
# patchwork — that gives each facet its own independent y axis, which
# facet_grid in stock ggplot2 can't do.
#
# `df` must already be filtered to a single facet value.
# `show_y_labels` controls whether axis text and outcome strips appear; only
# the leftmost sub-plot in a multi-facet figure should show them.
build_forest_panel <- function(df, outcome_levels,
                               xlim, x_breaks,
                               panel_title = NULL,
                               show_y_labels = TRUE,
                               show_outcome_strip = TRUE) {

  df <- df %>%
    mutate(outcome = factor(outcome, levels = outcome_levels))

  # Sequential per-restaurant labels (R1..Rn) within each outcome.
  rest_ranks <- df %>%
    filter(!is_pooled) %>%
    group_by(outcome) %>%
    mutate(rest_seq = as.integer(rank(-point, ties.method = "first"))) %>%
    ungroup() %>%
    select(outcome, restaurant, rest_seq)
  df <- df %>%
    left_join(rest_ranks, by = c("outcome", "restaurant")) %>%
    mutate(row_label = if_else(is_pooled, "Pooled", paste0("R", rest_seq)))

  # Globally-unique row_id factor used as the y aesthetic. Within each
  # outcome we want top-to-bottom order: Pooled, R1 (highest point),
  # R2, ..., Rn (lowest point). ggplot's discrete y draws the FIRST factor
  # level at the BOTTOM, so we arrange in REVERSE display order: lowest
  # restaurant first (= bottom), then ascending, with Pooled LAST (= top).
  df <- df %>%
    arrange(outcome, is_pooled, point) %>%   # restaurants ascending, pooled last
    group_by(outcome) %>%
    mutate(local_idx = row_number()) %>%
    ungroup() %>%
    mutate(row_id = paste(as.integer(outcome), local_idx, sep = "_")) %>%
    select(-local_idx)
  level_order <- df %>%
    arrange(outcome, is_pooled, point) %>%
    pull(row_id) %>% unique()
  df$row_id <- factor(df$row_id, levels = level_order)
  df$y <- df$row_id

  label_map <- df %>%
    select(row_id, row_label) %>% distinct() %>% arrange(row_id)
  rid_labels <- setNames(label_map$row_label, as.character(label_map$row_id))

  # Use linewidth and size aesthetics on the FULL data frame so all geom
  # layers see every level — splitting via `data = filter(df, ...)` reorders
  # the discrete y axis under `space = "free_y"`.
  df <- df %>% mutate(
    lw_outer = if_else(is_pooled, 4.0, 2.6),
    lw_inner = if_else(is_pooled, 2.0, 1.2),
    pt_size  = if_else(is_pooled, 3.6, 1.9),
    pt_shape = if_else(is_pooled, 23L, 21L),
    pt_stroke = if_else(is_pooled, 0.4, 0.25)
  )

  p <- ggplot(df) +
    geom_vline(xintercept = 1, linetype = "22", color = "grey55", linewidth = 0.35) +
    geom_segment(aes(x = lo95, xend = hi95, y = y, yend = y,
                     color = color_light, linewidth = lw_outer),
                 lineend = "butt") +
    geom_segment(aes(x = lo1sd, xend = hi1sd, y = y, yend = y,
                     color = color_dark, linewidth = lw_inner),
                 lineend = "butt") +
    geom_point(aes(x = lo95, y = y, color = color_light), shape = "|",
               size = 2.2, alpha = 0.9) +
    geom_point(aes(x = hi95, y = y, color = color_light), shape = "|",
               size = 2.2, alpha = 0.9) +
    geom_point(aes(x = point, y = y, fill = color_dark,
                   shape = pt_shape, size = pt_size),
               stroke = 0.3, color = "white") +
    scale_linewidth_identity() +
    scale_size_identity() +
    scale_shape_identity() +
    scale_color_identity() +
    scale_fill_identity() +
    scale_x_continuous(breaks = x_breaks, limits = xlim,
                       expand = expansion(mult = c(0.01, 0.02))) +
    scale_y_discrete(labels = rid_labels,
                     expand = expansion(add = c(0.6, 0.6))) +
    facet_grid(outcome ~ ., scales = "free_y", space = "free_y", switch = "y") +
    labs(title = panel_title, x = NULL, y = NULL) +
    theme_minimal(base_size = 10, base_family = "sans") +
    theme(
      plot.title = element_text(face = "bold", size = 11, color = "grey25",
                                hjust = 0.5, margin = margin(b = 6)),
      panel.grid.major.x = element_line(color = "grey92", linewidth = 0.3),
      panel.grid.minor.x = element_blank(),
      panel.grid.major.y = element_blank(),
      panel.grid.minor.y = element_blank(),
      panel.spacing.y = unit(6, "pt"),
      strip.placement = "outside",
      strip.background = element_blank(),
      strip.text.y.left = if (show_outcome_strip) {
        element_text(angle = 0, hjust = 1, face = "bold", size = 10,
                     color = "grey20", margin = margin(r = 8))
      } else element_blank(),
      axis.text.y = if (show_y_labels) {
        element_text(size = 8, color = "grey40")
      } else element_blank(),
      axis.ticks.y = element_blank(),
      axis.text.x = element_text(size = 9, color = "grey20"),
      axis.ticks.x = element_line(color = "grey75", linewidth = 0.3),
      axis.ticks.length.x = unit(3, "pt"),
      panel.border = element_blank(),
      axis.line.x = element_line(color = "grey60", linewidth = 0.3),
      plot.margin = margin(2, 6, 2, 2)
    )
  p
}

# ---- per-analysis preparation ---------------------------------------------
attach_palette <- function(df) {
  df %>% mutate(
    color_dark  = vapply(outcome, function(o) OUTCOME_PALETTE[[o]]$dark,  character(1)),
    color_light = vapply(outcome, function(o) OUTCOME_PALETTE[[o]]$light, character(1))
  )
}

prep_a1 <- function() {
  d <- dat %>%
    filter(analysis == "a1_proportion") %>%
    keep_gamma1() %>%
    mutate(
      facet = case_when(
        exposure_type == "count" ~ "count",
        exposure_type == "prop"  ~ "prop",
        TRUE ~ exposure_type
      ),
      is_pooled = level == "pooled"
    ) %>%
    attach_palette()
  d
}

prep_a2 <- function() {
  d <- dat %>%
    filter(analysis == "a2_proportion_t") %>%
    keep_gamma1() %>%
    mutate(
      facet = case_when(
        exposure_type == "count"    ~ "count",
        exposure_type == "presence" ~ "presence",
        TRUE ~ exposure_type
      ),
      is_pooled = level == "pooled"
    ) %>%
    attach_palette()
  d
}

prep_a3a4 <- function(an) {
  d <- dat %>%
    filter(analysis == an) %>%
    mutate(
      facet = type_fine,                        # "level" or "slope"
      is_pooled = level == "pooled"
    ) %>%
    filter(facet %in% c("level", "slope")) %>%
    attach_palette()
  d
}

# ---- render each ----------------------------------------------------------
PRETTY_FACET <- c(count = "Count exposure",
                  prop = "Proportion exposure",
                  presence = "Presence exposure",
                  level = "Level shift", slope = "Slope change")

label_facets <- function(df) {
  df %>% mutate(
    facet = factor(PRETTY_FACET[as.character(facet)],
                   levels = PRETTY_FACET[unique(as.character(facet))])
  )
}

render_one <- function(df, outcome_levels, fname, title, subtitle, xlim) {
  facet_present <- unique(as.character(df$facet))
  facet_keys <- intersect(names(PRETTY_FACET), facet_present)
  facet_pretty <- unname(PRETTY_FACET[facet_keys])

  # x breaks
  if (xlim[2] == 3)      x_breaks <- c(0, 0.5, 1, 1.5, 2, 2.5, 3)
  else if (xlim[2] == 5) x_breaks <- c(0, 1, 2, 3, 4, 5)
  else                   x_breaks <- pretty(xlim)

  # Build one sub-plot per facet
  panels <- lapply(seq_along(facet_keys), function(i) {
    fk <- facet_keys[i]
    sub <- df %>% filter(facet == fk)
    is_first <- i == 1
    build_forest_panel(
      sub, outcome_levels = outcome_levels,
      xlim = xlim, x_breaks = x_breaks,
      panel_title = if (length(facet_keys) > 1) facet_pretty[i] else NULL,
      show_y_labels = is_first,
      show_outcome_strip = is_first
    )
  })

  combined <- if (length(panels) == 1) {
    panels[[1]]
  } else {
    # Equal-width panels; first is wider to accommodate strip labels
    widths <- c(1.05, rep(1, length(panels) - 1))
    Reduce(`+`, panels) + plot_layout(widths = widths)
  }

  combined <- combined +
    plot_annotation(
      title = title, subtitle = subtitle,
      theme = theme(
        plot.title = element_text(face = "bold", size = 13,
                                  margin = margin(b = 2)),
        plot.subtitle = element_text(color = "grey35", size = 10,
                                     margin = margin(b = 8))
      )
    ) &
    labs(x = "Rate ratio") &
    theme(axis.title.x = element_text(size = 10, color = "grey20",
                                      margin = margin(t = 6)))

  rows_per_outcome <- df %>%
    filter(facet == facet_keys[1]) %>%
    group_by(outcome) %>%
    summarize(n = n_distinct(paste(restaurant, is_pooled)),
              .groups = "drop")
  total_rows <- sum(rows_per_outcome$n)
  height <- max(6.5, 1.6 + 0.22 * total_rows + 0.45 * length(outcome_levels))
  width  <- if (length(facet_keys) >= 2) 11 else 8.5

  out_path <- file.path(OUT_DIR, fname)
  ggsave(out_path, combined, width = width, height = height, units = "in",
         device = "pdf")
  message(sprintf("  wrote %s  (%.1f x %.1f in, %d rows, %d facets)",
                  out_path, width, height, total_rows, length(facet_keys)))
  invisible(combined)
}

# ---- A1 --------------------------------------------------------------------
message("Rendering A1 ...")
a1 <- prep_a1()
# A1 has 3 exposure groups (mpbamod, vegan, vegetarian). The CSV currently
# contains only mpbamod_dishes_count, so we render whatever is present.
# When multiple exposure groups exist, distinguish them in the facet axis.
if (length(unique(a1$exposure_group)) > 1) {
  a1 <- a1 %>% mutate(facet = paste(exposure_group, facet, sep = " | "))
}
render_one(a1,
           outcome_levels = c("nonvegan", "meat", "chicken_fish",
                              "vegetarian", "vegan"),
           fname = "A1_proportion_forest_restaurants.pdf",
           title = "A1: Menu proportion outcomes",
           subtitle = "Pooled and per-restaurant rate ratios; inner band = 1 SD, outer = 95% CI",
           xlim = c(0, 3))

# ---- A2 --------------------------------------------------------------------
message("Rendering A2 ...")
a2 <- prep_a2()
render_one(a2,
           outcome_levels = c("breakfast_p", "chicken_p", "dairy_p",
                              "egg_p", "untextured_p"),
           fname = "A2_proportion_targeted_forest_restaurants.pdf",
           title = "A2: Targeted menu-component proportions",
           subtitle = "Pooled and per-restaurant rate ratios; inner band = 1 SD, outer = 95% CI",
           xlim = c(0, 5))

# ---- A3 --------------------------------------------------------------------
message("Rendering A3 ...")
a3 <- prep_a3a4("a3_its")
render_one(a3,
           outcome_levels = c("nonvegan", "meat", "chicken_fish",
                              "vegetarian", "vegan"),
           fname = "A3_its_forest_restaurants.pdf",
           title = "A3: Interrupted time series, menu-wide outcomes",
           subtitle = "Level shift and slope change; inner band = 1 SD, outer = 95% CI",
           xlim = c(0, 3))

# ---- A4 --------------------------------------------------------------------
message("Rendering A4 ...")
a4 <- prep_a3a4("a4_its_t")
render_one(a4,
           outcome_levels = c("breakfast", "textured", "untextured"),
           fname = "A4_its_targeted_forest_restaurants.pdf",
           title = "A4: Interrupted time series, targeted outcomes",
           subtitle = "Level shift and slope change; inner band = 1 SD, outer = 95% CI",
           xlim = c(0, 5))

message("Done. Files in: ", normalizePath(OUT_DIR))

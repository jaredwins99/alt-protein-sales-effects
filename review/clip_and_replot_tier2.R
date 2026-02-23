# Clip and Replot - Tier 2 Restaurants
# Generates BOTH unclipped and clipped overlap plots for tier2
# Covers: proportion (A1_T2), proportion_targeted (A2_T2), its (A3_T2), its_targeted (A4_T2)
#
# Usage: Rscript review/clip_and_replot_tier2.R CHUNK_NUMBER
# Chunks 1-6:  Proportion (one exposure type per chunk)
# Chunk 7:     Proportion Targeted (all categories)
# Chunk 8:     ITS (meat, vegan, vegetarian)
# Chunk 9:     ITS (nonvegan, total, chicken_fish)
# Chunk 10:    ITS Targeted (all categories)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) stop("Usage: Rscript review/clip_and_replot_tier2.R CHUNK_NUMBER")
chunk <- as.integer(args[1])
cat(paste0("\n=== Chunk ", chunk, " started ===\n"))

library(arrow)
library(ggplot2)
library(dplyr)
library(patchwork)

# ─────────────────────────────────────────────────────────────
# T1 restaurants (excluded from tier2 plots)
# ─────────────────────────────────────────────────────────────

tier1_restaurants <- c("VLZX7K2M9QD4T", "SRQS8F7JWA9MZ", "2HRX9P6HKXA8V", "JHDN7CF1C03X5",
                       "L69HYJ4Y3TR91", "ED5J990H5VAZT", "W8T41JZK0ZMEP")

# ─────────────────────────────────────────────────────────────
# T2-only restaurant lists per analysis type
# ─────────────────────────────────────────────────────────────

# A1_T2 Proportion (12 T2-only restaurants)
tier2_proportion <- c("EMBVNVD207CC6", "C0BE4NDSW26QN", "V3Q26BHF3SE2H",
                      "LBZEEFSBJNB3Z", "SAFK7ND1HR6XS", "CB2KHY1C2G9PT",
                      "S8MT0YGD2KTN9", "LFZFT3VASXPED", "1SQPTEGYPH0GA",
                      "9XKJD8DQTH559", "LQ5EH4BKGV61T", "78AY09MVJVTYE")

# A3_T2 ITS (10 T2-only; CB2KHY1C2G9PT and LFZFT3VASXPED excluded)
tier2_its <- c("EMBVNVD207CC6", "C0BE4NDSW26QN", "V3Q26BHF3SE2H",
               "LBZEEFSBJNB3Z", "SAFK7ND1HR6XS",
               "S8MT0YGD2KTN9", "1SQPTEGYPH0GA", "9XKJD8DQTH559",
               "LQ5EH4BKGV61T", "78AY09MVJVTYE")

# A2_T2 Proportion Targeted (T2-only per category)
tier2_prop_targeted <- list(
  breakfast_p = c("78AY09MVJVTYE", "9XKJD8DQTH559", "CB2KHY1C2G9PT",
                  "EMBVNVD207CC6", "LBZEEFSBJNB3Z", "LQ5EH4BKGV61T",
                  "SAFK7ND1HR6XS", "V3Q26BHF3SE2H"),
  chicken_p = c("9XKJD8DQTH559", "LBZEEFSBJNB3Z", "SAFK7ND1HR6XS", "V3Q26BHF3SE2H"),
  dairy_p = c("9XKJD8DQTH559", "C0BE4NDSW26QN", "EMBVNVD207CC6",
              "LBZEEFSBJNB3Z", "LFZFT3VASXPED", "SAFK7ND1HR6XS", "V3Q26BHF3SE2H"),
  egg_p = c("LBZEEFSBJNB3Z", "78AY09MVJVTYE", "V3Q26BHF3SE2H"),
  textured_p = c("9XKJD8DQTH559", "SAFK7ND1HR6XS"),
  untextured_p = c("1SQPTEGYPH0GA", "9XKJD8DQTH559", "C0BE4NDSW26QN",
                    "CB2KHY1C2G9PT", "EMBVNVD207CC6", "LFZFT3VASXPED",
                    "LQ5EH4BKGV61T", "S8MT0YGD2KTN9", "SAFK7ND1HR6XS")
)

# A4_T2 ITS Targeted (T2-only per category)
tier2_its_targeted <- list(
  breakfast = c("78AY09MVJVTYE", "V3Q26BHF3SE2H"),
  chicken = c("V3Q26BHF3SE2H"),
  dairy = c("EMBVNVD207CC6", "9XKJD8DQTH559"),
  textured = c("SAFK7ND1HR6XS"),
  untextured = c("C0BE4NDSW26QN", "S8MT0YGD2KTN9", "9XKJD8DQTH559",
                  "LQ5EH4BKGV61T", "1SQPTEGYPH0GA")
)

# ─────────────────────────────────────────────────────────────
# T2 Boundary Clips (from 1_data_ingarch.R general filtering)
# ─────────────────────────────────────────────────────────────

clip_dates_t2 <- list(
  "EMBVNVD207CC6" = list(start = "2016-06-01", end = "2022-09-01"),
  "LBZEEFSBJNB3Z" = list(start = "2021-09-01", end = "2023-07-01"),
  "CB2KHY1C2G9PT" = list(start = "2020-06-01", end = "2023-04-01"),
  "LFZFT3VASXPED" = list(start = "2021-10-01", end = "2022-11-01"),
  "SAFK7ND1HR6XS" = list(start = "2019-04-18", end = "2020-03-25")
)

get_clip_dates <- function(restaurant) {
  if (restaurant %in% names(clip_dates_t2)) {
    return(clip_dates_t2[[restaurant]])
  }
  return(list(start = NULL, end = NULL))
}

clip_restaurant_data <- function(rest_df, clips) {
  if (!is.null(clips$start)) {
    rest_df <- rest_df %>% filter(date > as.Date(clips$start))
  }
  if (!is.null(clips$end)) {
    rest_df <- rest_df %>% filter(date < as.Date(clips$end))
  }
  return(rest_df)
}

# ─────────────────────────────────────────────────────────────
# Exposure Label Helper
# ─────────────────────────────────────────────────────────────

get_exposure_label <- function(exp_col) {
  prefix_map <- list(
    "mpbamod" = "Modern Plant Based Analog Modifiable",
    "vegan" = "Vegan",
    "vegetarian" = "Vegetarian",
    "breakfast" = "Breakfast",
    "chicken" = "Chicken",
    "dairy" = "Dairy",
    "egg" = "Egg",
    "textured" = "Textured",
    "untextured" = "Untextured"
  )
  if (grepl("_count$", exp_col)) {
    type_label <- "Menu Count of"
  } else if (grepl("_prop$", exp_col)) {
    type_label <- "Menu Proportion of"
  } else if (grepl("_presence$", exp_col)) {
    type_label <- "Menu Presence of"
  } else {
    return(tools::toTitleCase(gsub("_", " ", exp_col)))
  }
  prefix <- sub("_dishes_.*$", "", exp_col)
  if (prefix %in% names(prefix_map)) {
    name <- prefix_map[[prefix]]
  } else {
    name <- tools::toTitleCase(gsub("_", " ", prefix))
  }
  paste0(type_label, " ", name, " Dishes")
}

get_outcome_label <- function(outcome_key) {
  labels <- list(
    meat = "Meat", vegan = "Vegan", vegetarian = "Vegetarian",
    nonvegan = "Non-Vegan", total = "Total", chicken_fish = "Chicken & Fish",
    breakfast = "Breakfast", chicken = "Chicken", dairy = "Dairy",
    egg = "Egg", textured = "Textured", untextured = "Untextured"
  )
  if (outcome_key %in% names(labels)) return(labels[[outcome_key]])
  return(tools::toTitleCase(gsub("_", " ", outcome_key)))
}

# ─────────────────────────────────────────────────────────────
# Plot Generation (Pretty Format)
# ─────────────────────────────────────────────────────────────

generate_plot <- function(rest_df, rest_id, title_str, subtitle_str,
                          outcome_col, exp_col_name, output_dir) {
  if (nrow(rest_df) == 0) return(NULL)
  if (!outcome_col %in% names(rest_df)) return(NULL)
  if (!exp_col_name %in% names(rest_df)) return(NULL)
  if (all(is.na(rest_df[[outcome_col]]))) return(NULL)

  outcome_vals <- rest_df[[outcome_col]]
  exposure_vals <- rest_df[[exp_col_name]]
  outcome_max <- max(outcome_vals, na.rm = TRUE)
  exposure_max <- max(exposure_vals, na.rm = TRUE)
  if (outcome_max == 0) outcome_max <- 1
  if (exposure_max == 0) exposure_max <- 1
  outcome_scaled <- (outcome_vals / outcome_max) * exposure_max

  plot_df <- rest_df %>%
    mutate(
      exposure = .data[[exp_col_name]],
      outcome = .data[[outcome_col]],
      outcome_scaled = outcome_scaled
    )

  p1 <- ggplot(plot_df, aes(x = date)) +
    geom_line(aes(y = exposure, color = "Exposure"), linewidth = 0.6) +
    geom_line(aes(y = outcome_scaled, color = "Outcome (scaled)"), linewidth = 0.3) +
    scale_color_manual(values = c("Exposure" = "#4A90D9", "Outcome (scaled)" = "#E8725C"), name = "") +
    labs(title = rest_id, subtitle = subtitle_str, x = "Date", y = "Value") +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 14, hjust = 0.5),
      plot.subtitle = element_text(size = 10, hjust = 0.5),
      legend.position = "bottom",
      panel.border = element_rect(colour = "black", fill = NA, linewidth = 0.5)
    )

  p2 <- ggplot(plot_df, aes(x = factor(exposure), y = outcome)) +
    geom_boxplot(fill = "lightblue") +
    labs(x = "Exposure Level", y = "Outcome") +
    theme_minimal() +
    theme(
      panel.border = element_rect(colour = "black", fill = NA, linewidth = 0.5)
    )

  combined <- p1 + p2 + plot_layout(widths = c(2, 1))

  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
  ggsave(file.path(output_dir, paste0(rest_id, ".png")), combined,
         width = 12, height = 5, dpi = 150)
  return(TRUE)
}

# ─────────────────────────────────────────────────────────────
# ITS Exposure Helper: compute total exposure for one restaurant
# ─────────────────────────────────────────────────────────────

compute_its_exposure <- function(df, restaurant) {
  exp_cols <- grep(paste0("^exposure_", restaurant, "_"), names(df), value = TRUE)
  if (length(exp_cols) == 0) return(rep(0, nrow(df)))
  return(rowSums(df[, exp_cols, drop = FALSE]))
}

# ─────────────────────────────────────────────────────────────
# Configuration: Proportion
# ─────────────────────────────────────────────────────────────

proportion_outcomes <- list(
  meat = "meat_outcome",
  vegan = "vegan_outcome",
  vegetarian = "vegetarian_outcome",
  nonvegan = "nonvegan_outcome",
  total = "total_outcome",
  chicken_fish = "chicken_fish_outcome"
)

proportion_exposures <- c(
  "mpbamod_dishes_count", "mpbamod_dishes_prop",
  "vegan_dishes_count", "vegan_dishes_prop",
  "vegetarian_dishes_count", "vegetarian_dishes_prop"
)

# ─────────────────────────────────────────────────────────────
# Configuration: Proportion Targeted
# ─────────────────────────────────────────────────────────────

proportion_targeted_config <- list(
  breakfast_p = list(outcome = "breakfast_outcome",
                     exposures = c("breakfast_dishes_count", "breakfast_dishes_presence")),
  chicken_p = list(outcome = "chicken_outcome_p",
                   exposures = c("chicken_dishes_count", "chicken_dishes_presence")),
  dairy_p = list(outcome = "dairy_outcome_p",
                 exposures = c("dairy_dishes_count", "dairy_dishes_presence")),
  egg_p = list(outcome = "egg_outcome_p",
               exposures = c("egg_dishes_count", "egg_dishes_presence")),
  textured_p = list(outcome = "textured_outcome",
                    exposures = c("textured_dishes_count", "textured_dishes_presence")),
  untextured_p = list(outcome = "untextured_outcome",
                      exposures = c("untextured_dishes_count", "untextured_dishes_presence"))
)

# ─────────────────────────────────────────────────────────────
# Configuration: ITS
# ─────────────────────────────────────────────────────────────

its_outcomes <- list(
  meat = "meat_outcome",
  vegan = "vegan_outcome",
  vegetarian = "vegetarian_outcome",
  nonvegan = "nonvegan_outcome",
  total = "total_outcome",
  chicken_fish = "chicken_fish_outcome"
)

# ─────────────────────────────────────────────────────────────
# Configuration: ITS Targeted
# ─────────────────────────────────────────────────────────────

its_targeted_outcomes <- list(
  breakfast = "breakfast_t2_outcome",
  chicken = "chicken_t2_outcome",
  dairy = "dairy_t2_outcome",
  textured = "textured_t2_outcome",
  untextured = "untextured_t2_outcome"
)

# =============================================================
# Process Functions
# =============================================================

process_proportion <- function(exposure_idx) {
  exp_type <- proportion_exposures[exposure_idx]
  cat(paste0("\n--- Proportion: ", exp_type, " ---\n"))

  data_file <- file.path("data/4_data_parquet_modeling/proportion",
                         paste0("finalized_", exp_type, ".parquet"))
  if (!file.exists(data_file)) {
    cat(paste0("  File not found: ", data_file, "\n"))
    return()
  }
  df <- read_parquet(data_file)

  for (out_name in names(proportion_outcomes)) {
    outcome_col <- proportion_outcomes[[out_name]]
    out_label <- get_outcome_label(out_name)
    exp_label <- get_exposure_label(exp_type)
    subtitle <- paste0(out_label, " \u2014 ", exp_label)

    for (rest in tier2_proportion) {
      rest_df <- df %>% filter(location_id == rest) %>% arrange(date)
      if (nrow(rest_df) == 0) next
      if (!exp_type %in% names(rest_df)) next

      # Unclipped
      out_dir_unclipped <- file.path("review/overlap_plots/proportion", out_name, exp_type, "tier2")
      generate_plot(rest_df, rest, rest, subtitle, outcome_col, exp_type, out_dir_unclipped)

      # Clipped
      clips <- get_clip_dates(rest)
      rest_df_clipped <- clip_restaurant_data(rest_df, clips)
      if (nrow(rest_df_clipped) == 0) next
      out_dir_clipped <- file.path("review/overlap_plots_clipped_pretty/proportion", out_name, exp_type, "tier2")
      generate_plot(rest_df_clipped, rest, rest, subtitle, outcome_col, exp_type, out_dir_clipped)

      cat(paste0("  ", rest, " / ", out_name, " / ", exp_type, "\n"))
    }
  }
}

process_proportion_targeted <- function() {
  cat("\n--- Proportion Targeted ---\n")

  for (cat_name in names(proportion_targeted_config)) {
    config <- proportion_targeted_config[[cat_name]]
    outcome_col <- config$outcome
    restaurants <- tier2_prop_targeted[[cat_name]]
    if (is.null(restaurants) || length(restaurants) == 0) next

    # Derive category label from cat_name (e.g., "breakfast_p" -> "Breakfast")
    cat_key <- sub("_p$", "", cat_name)
    cat_label <- get_outcome_label(cat_key)

    for (exp_type in config$exposures) {
      data_file <- file.path("data/4_data_parquet_modeling/proportion_targeted",
                             paste0("finalized_", exp_type, ".parquet"))
      if (!file.exists(data_file)) {
        cat(paste0("  File not found: ", data_file, "\n"))
        next
      }
      df <- read_parquet(data_file)
      exp_label <- get_exposure_label(exp_type)
      subtitle <- paste0(cat_label, " \u2014 ", exp_label)

      for (rest in restaurants) {
        rest_df <- df %>% filter(location_id == rest) %>% arrange(date)
        if (nrow(rest_df) == 0) next
        if (!exp_type %in% names(rest_df)) next

        # Unclipped
        out_dir_unclipped <- file.path("review/overlap_plots/proportion_targeted", cat_name, exp_type, "tier2")
        generate_plot(rest_df, rest, rest, subtitle, outcome_col, exp_type, out_dir_unclipped)

        # Clipped
        clips <- get_clip_dates(rest)
        rest_df_clipped <- clip_restaurant_data(rest_df, clips)
        if (nrow(rest_df_clipped) == 0) next
        out_dir_clipped <- file.path("review/overlap_plots_clipped_pretty/proportion_targeted", cat_name, exp_type, "tier2")
        generate_plot(rest_df_clipped, rest, rest, subtitle, outcome_col, exp_type, out_dir_clipped)

        cat(paste0("  ", rest, " / ", cat_name, " / ", exp_type, "\n"))
      }
    }
  }
}

process_its <- function(outcome_names) {
  cat(paste0("\n--- ITS: ", paste(outcome_names, collapse = ", "), " ---\n"))

  data_file <- "data/4_data_parquet_modeling/its/finalized.parquet"
  if (!file.exists(data_file)) {
    cat(paste0("  File not found: ", data_file, "\n"))
    return()
  }
  df <- read_parquet(data_file)

  for (out_name in outcome_names) {
    outcome_col <- its_outcomes[[out_name]]
    out_label <- get_outcome_label(out_name)
    subtitle <- paste0(out_label, " \u2014 MPBA Interventions")

    for (rest in tier2_its) {
      rest_df <- df %>% filter(location_id == rest) %>% arrange(date)
      if (nrow(rest_df) == 0) next

      # Compute total ITS exposure for this restaurant
      rest_df$its_exposure <- compute_its_exposure(rest_df, rest)

      # Unclipped
      out_dir_unclipped <- file.path("review/overlap_plots/its", out_name, "tier2")
      generate_plot(rest_df, rest, rest, subtitle, outcome_col, "its_exposure", out_dir_unclipped)

      # Clipped
      clips <- get_clip_dates(rest)
      rest_df_clipped <- clip_restaurant_data(rest_df, clips)
      if (nrow(rest_df_clipped) == 0) next
      out_dir_clipped <- file.path("review/overlap_plots_clipped_pretty/its", out_name, "tier2")
      generate_plot(rest_df_clipped, rest, rest, subtitle, outcome_col, "its_exposure", out_dir_clipped)

      cat(paste0("  ", rest, " / ", out_name, "\n"))
    }
  }
}

process_its_targeted <- function() {
  cat("\n--- ITS Targeted ---\n")

  data_file <- "data/4_data_parquet_modeling/its/finalized.parquet"
  if (!file.exists(data_file)) {
    cat(paste0("  File not found: ", data_file, "\n"))
    return()
  }
  df <- read_parquet(data_file)

  for (cat_name in names(its_targeted_outcomes)) {
    outcome_col <- its_targeted_outcomes[[cat_name]]
    restaurants <- tier2_its_targeted[[cat_name]]
    if (is.null(restaurants) || length(restaurants) == 0) next

    cat_label <- get_outcome_label(cat_name)
    subtitle <- paste0(cat_label, " \u2014 MPBA Interventions")

    for (rest in restaurants) {
      rest_df <- df %>% filter(location_id == rest) %>% arrange(date)
      if (nrow(rest_df) == 0) next

      # Compute total ITS exposure
      rest_df$its_exposure <- compute_its_exposure(rest_df, rest)

      # Unclipped
      out_dir_unclipped <- file.path("review/overlap_plots/its_targeted", cat_name, "tier2")
      generate_plot(rest_df, rest, rest, subtitle, outcome_col, "its_exposure", out_dir_unclipped)

      # Clipped
      clips <- get_clip_dates(rest)
      rest_df_clipped <- clip_restaurant_data(rest_df, clips)
      if (nrow(rest_df_clipped) == 0) next
      out_dir_clipped <- file.path("review/overlap_plots_clipped_pretty/its_targeted", cat_name, "tier2")
      generate_plot(rest_df_clipped, rest, rest, subtitle, outcome_col, "its_exposure", out_dir_clipped)

      cat(paste0("  ", rest, " / ", cat_name, "\n"))
    }
  }
}

# =============================================================
# Chunk Dispatch
# =============================================================

if (chunk >= 1 && chunk <= 6) {
  process_proportion(chunk)
} else if (chunk == 7) {
  process_proportion_targeted()
} else if (chunk == 8) {
  process_its(c("meat", "vegan", "vegetarian"))
} else if (chunk == 9) {
  process_its(c("nonvegan", "total", "chicken_fish"))
} else if (chunk == 10) {
  process_its_targeted()
} else {
  stop(paste0("Invalid chunk number: ", chunk, ". Must be 1-10."))
}

cat(paste0("\n=== Chunk ", chunk, " done ===\n"))

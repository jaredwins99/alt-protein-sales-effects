source("publication/scripts/forest_fallback.R")
source("publication/scripts/adj_fallback.R")
source("publication/config/plot_config.R")
# Forest Plot Generation Script - T2 ADJUSTED VERSION (Outcome RR / Total RR)
# Creates horizontal forest plots showing adjusted rate ratios - T2 (Tier 2) restaurant set
# Adjusted = outcome samples - total samples in log space per MCMC draw
# Prefers finalized_redone_trunc_cp where fits exist; falls back to finalized_redone_trunc
# Based on create_forest_plots_restaurants_chosen_recolored_adj.R

library(tidyverse)
library(ggplot2)
library(patchwork)
.user_lib <- path.expand("~/R/library")
if (dir.exists(.user_lib) && !.user_lib %in% .libPaths()) .libPaths(c(.user_lib, .libPaths()))
suppressPackageStartupMessages(library(ggh4x))
# htmlwidgets + plotly are only needed for the interactive HTML widget.
# When PRO_FAST=TRUE we skip HTML output entirely, so don't pay the load cost.
if (toupper(Sys.getenv("PRO_FAST", "FALSE")) != "TRUE") {
  library(htmlwidgets)
  library(plotly)
}

source("model_scripts/view_params_funcs.R")
source("model_scripts/ci95_helpers.R")
# Publication-quality theme + palette. Used for PNG/PDF output only.
source("publication/config/publication_theme.R")

# ─────────────────────────────────────
#         Configuration - EDIT HERE
# ─────────────────────────────────────

DEFAULT_MODEL_PATH <- "finalized_redone_trunc"

# T2 override strategy: prefer finalized_redone_trunc_cp where the T2 fit exists,
# else fall back to DEFAULT_MODEL_PATH (finalized_redone_trunc).

# A1 proportion overrides (T2)
A1_OVERRIDES <- list(
  "total" = "finalized_redone_trunc_cp",
  "nonvegan" = "finalized_redone_trunc_cp",
  "meat" = "finalized_redone_trunc_cp",
  "chicken_fish" = "finalized_redone_trunc_cp"
  # vegan, vegetarian -> default (finalized_redone_trunc)
)

# A2 a2_proportion_t overrides (T2)
#
# t2_a2_proportion_t HAS now been re-fit into finalized_uncontaminated2 (all six
# outcomes, verified present), and adj_fixed_pairs.csv points there, so the rows
# in forest_data_adj_95ci_fixed.csv are keyed to that path. The renderer looks
# CSV rows up BY PATH, so this override has to name the same generation the
# manifest does or nothing matches.
#
# This override has now caused the same crash twice, from opposite directions:
#   1. pointing at a generation with no t2_a2_proportion_t (the earlier bug),
#   2. being left empty after the fits moved into one (this bug).
# Either way the paths resolve to nothing, df_all comes back empty, the facet
# variable has zero levels, and ggplot fails with
#   "combine_vars(): Faceting variables must have at least one value".
# Because the T2 renderer runs A2 regardless of PRO_ONLY, it takes every T2
# plot down with it, not just A2.
#
# RULE: whenever adj_fixed_pairs.csv moves an outcome to a new generation, this
# list must move with it. Check with:
#   grep t2_a2_proportion_t publication/scripts/adj_fixed_pairs.csv | cut -d, -f3
A2_OVERRIDES <- list(
  "breakfast_p"  = "finalized_uncontaminated2",
  "chicken_p"    = "finalized_uncontaminated2",
  "dairy_p"      = "finalized_uncontaminated2",
  "egg_p"        = "finalized_uncontaminated2",
  "textured_p"   = "finalized_uncontaminated2",
  "untextured_p" = "finalized_uncontaminated2"
)

# A3 its overrides (T2): _cp fits exist only for meat, nonvegan, total; rest default.
# "total" lives ONLY in _cp; the default-path total dir has no fit.rds.
A3_OVERRIDES <- list(
  "total" = "finalized_redone_trunc_cp",
  "nonvegan" = "finalized_redone_trunc_cp",
  "meat" = "finalized_redone_trunc_cp"
)

# A4 a4_its_t overrides (T2)
A4_OVERRIDES <- list(
  # breakfast / untextured / dairy previously pointed at
  # finalized_uncontaminated. That batch re-fit the TIER-1 a4_its_t models
  # only -- there is no model_fits/finalized_uncontaminated/t2_a4_its_t at all,
  # so those three outcomes resolved to nothing and rendered as empty panels
  # (the plot showed a single restaurant on one of four outcome rows).
  # Only finalized_redone_trunc and finalized_redone_trunc_cp hold t2_a4_its_t.
  #
  # Highest available per outcome, matching what adj_fixed_pairs.csv resolves:
  #   breakfast_t2, untextured_t2, textured_t2 -> _cp
  #   dairy_t2, chicken_t2                     -> default (finalized_redone_trunc,
  #                                               _cp has no dairy_t2/chicken_t2)
  "breakfast"  = "finalized_redone_trunc_cp",
  "untextured" = "finalized_redone_trunc_cp",
  "textured"   = "finalized_redone_trunc_cp"
  # dairy, chicken -> default (finalized_redone_trunc)
)

# A5 Gaussian IID (transaction-level, pre-period demeaned, identity link) - T2
A5GI_MODEL_PATH <- "finalized_redone_trunc_cp"
A5GI_ANALYSIS   <- "t2_a5_customer_day"

SORT_BY_MEAN <- Sys.getenv("SORT_BY_MEAN", "FALSE") == "TRUE"
# PRO_FAST=TRUE skips PNG + plotly/HTML output (PDF only) for fast iteration.
.PRO_FAST <- toupper(Sys.getenv("PRO_FAST", "FALSE")) == "TRUE"
# LABELED_MODE=TRUE: per-restaurant colors + numbered legend; pooled stays unchanged.
LABELED_MODE <- toupper(Sys.getenv("LABELED_MODE", "FALSE")) == "TRUE"
# LABELED_V2=TRUE (implies LABELED_MODE): adds per-restaurant numeric estimate
# + CI text labels next to every restaurant-level point in A1-A4, on top of
# everything LABELED_MODE already draws. Placement is chosen per-analysis to
# avoid the inline restaurant-name labels (see each create_* function).
LABELED_V2 <- toupper(Sys.getenv("LABELED_V2", "FALSE")) == "TRUE"

#' Format a restaurant-level numeric estimate + CI label, single string.
#' Mirrors the pooled-estimate label formatting (percentage-change when
#' PUB_RECENTER, RR/raw otherwise), but combined mean+CI on one line since
#' restaurant labels are small and don't need the bold-mean / plain-CI split.
rest_num_label <- function(mean_orig, q2.5_orig, q97.5_orig) {
  if (PUB_RECENTER) {
    paste0(sprintf("%.0f%%", (mean_orig - 1) * 100),
           sprintf(" [%.0f%%, %.0f%%]", (q2.5_orig - 1) * 100, (q97.5_orig - 1) * 100))
  } else {
    paste0(sprintf("%.2f", mean_orig),
           sprintf(" [%.2f, %.2f]", q2.5_orig, q97.5_orig))
  }
}
source("publication/scripts/present_helpers.R")
OUTPUT_DIR_BASE      <- present_path(paste0("forest_plots/total_adjusted/t2", if (SORT_BY_MEAN) "_sorted" else "", if (PUB_RECENTER) "_recentered" else "", if (PUB_WIDE) "_wide" else "", if (WIDE_LABELED) "_lbl" else "", if (toupper(Sys.getenv("ADJ_FIXED","FALSE"))=="TRUE") "_fixed" else ""))
LOG_OUTPUT_DIR_BASE  <- present_path(paste0("forest_plots/z_log_and_overlay/t2_adj", if (SORT_BY_MEAN) "_sorted" else "", if (PUB_RECENTER) "_recentered" else "", if (PUB_WIDE) "_wide" else "", if (WIDE_LABELED) "_lbl" else "", if (toupper(Sys.getenv("ADJ_FIXED","FALSE"))=="TRUE") "_fixed" else ""))

# Per-restaurant color palette (LABELED_MODE) — same 7-entry mapping as T1
LABELED_REST_IDS <- c(
  "VLZX7K2M9QD4T",
  "SRQS8F7JWA9MZ",
  "2HRX9P6HKXA8V",
  "JHDN7CF1C03X5",
  "L69HYJ4Y3TR91",
  "ED5J990H5VAZT",
  "W8T41JZK0ZMEP",
  "EMBVNVD207CC6",
  "C0BE4NDSW26QN",
  "75WYSXR9QBK5M",
  "V3Q26BHF3SE2H",
  "LBZEEFSBJNB3Z",
  "SAFK7ND1HR6XS",
  "CB2KHY1C2G9PT",
  "S8MT0YGD2KTN9",
  "LFZFT3VASXPED",
  "1SQPTEGYPH0GA",
  "9XKJD8DQTH559",
  "LQ5EH4BKGV61T",
  "78AY09MVJVTYE"
)
LABELED_REST_LABELS <- c(
  "1. Greek rotisserie chain",
  "2. Fast-food burger chain location 1",
  "3. German sausage grill",
  "4. Salad and panini shop",
  "5. Breakfast café",
  "6. Coffee shop",
  "7. Juice bar",
  "8. Craft brewery pizza kitchen",
  "9. Craft brewery gastropub",
  "10. Kimchi taco joint",
  "11. Bagel-and-espresso café",
  "12. Sweet-and-savory waffle house",
  "13. American-Mexican taquería",
  "14. Fast-food burger chain location 2",
  "15. Stacked-meat burger chain",
  "16. Hot chicken and smash burger chain",
  "17. Italian pasta house",
  "18. Chinese-pizza fusion kitchen",
  "19. Food truck",
  "20. Halfsmoke and chili shop"
)
LABELED_REST_COLORS <- c(
  "#1B9E77",
  "#D95F02",
  "#7570B3",
  "#E7298A",
  "#66A61E",
  "#E6AB02",
  "#A6761D",
  "#1F77B4",
  "#FF7F0E",
  "#2CA02C",
  "#D62728",
  "#9467BD",
  "#8C564B",
  "#E377C2",
  "#7F7F7F",
  "#BCBD22",
  "#17BECF",
  "#AEC7E8",
  "#FFBB78",
  "#98DF8A"
)
names(LABELED_REST_COLORS) <- LABELED_REST_IDS
LABELED_COLORS_ALL <- c(PUB_COLORS_ALL, LABELED_REST_COLORS)

# Compute canonical ordering for LABELED_MODE: canonical restaurants 1–7 in
# LABELED_REST_IDS order; non-canonical get positions 8+ alphabetically.
labeled_rank_fn <- function(ids) {
  canonical_pos <- match(ids, LABELED_REST_IDS)
  non_canon <- is.na(canonical_pos)
  non_canon_ids <- ids[non_canon]
  alpha_rank_nc <- if (any(non_canon)) {
    r <- rank(non_canon_ids, ties.method = "first")
    setNames(r, non_canon_ids)
  } else {
    integer(0)
  }
  result <- ifelse(non_canon,
                   length(LABELED_REST_IDS) + alpha_rank_nc[ids],
                   canonical_pos)
  as.integer(result)
}

# ─────────────────────────────────────
#    Adjusted Estimate Helper Functions
# ─────────────────────────────────────

# Environment-based caches to avoid re-reading files
.samples_cache <- new.env(parent = emptyenv())
.beta_map_cache <- new.env(parent = emptyenv())

read_samples_cached <- function(model_path) {
  key <- model_path
  if (exists(key, envir = .samples_cache)) {
    return(get(key, envir = .samples_cache))
  }
  samples <- read_samples(model_path)
  if (!is.null(samples)) {
    assign(key, samples, envir = .samples_cache)
  }
  return(samples)
}

#' Compute Adjusted mu_gamma: outcome - total in log space per MCMC draw
#' @param outcome_path Path to outcome model directory
#' @param total_path Path to total model directory
#' @param gamma_index Which gamma index (1 or 2)
#' @return A list with mean, median, sd, q2.5, q97.5, rhat, ess_bulk
compute_adjusted_mu_gamma <- function(outcome_path, total_path, gamma_index = 1) {
  # Prefer precomputed CSV — keeps rendering RAM-light and avoids
  # touching multi-GB samples.rds at plot time.
  fb <- tryCatch(adj_mu_gamma_from_csv(outcome_path, gamma_index), error = function(e) NULL)
  if (!is.null(fb)) return(fb)

  samples_outcome <- read_samples_cached(outcome_path)
  samples_total <- read_samples_cached(total_path)

  if (is.null(samples_outcome) || is.null(samples_total)) {
    warning(paste("Missing samples for adjusted computation and no CSV fallback:",
                  if (is.null(samples_outcome)) outcome_path else total_path))
    return(NULL)
  }

  param_name <- paste0("mu_gamma[", gamma_index, "]")

  if (!(param_name %in% names(samples_outcome))) {
    warning(paste("Parameter", param_name, "not found in outcome samples:", outcome_path))
    return(NULL)
  }
  if (!(param_name %in% names(samples_total))) {
    warning(paste("Parameter", param_name, "not found in total samples:", total_path))
    return(NULL)
  }

  outcome_draws <- samples_outcome[[param_name]]
  total_draws <- samples_total[[param_name]]

  # Truncate to min length if sample counts differ
  n <- min(length(outcome_draws), length(total_draws))
  diff_draws <- outcome_draws[1:n] - total_draws[1:n]

  # Get rhat and ess_bulk from outcome model's summ.rds
  summ_path <- file.path(outcome_path, "summ.rds")
  rhat_val <- NA_real_
  ess_val <- NA_real_
  if (file.exists(summ_path)) {
    summ <- read_summ_fallback(dirname(summ_path))
    summ_row <- summ[summ$variable == param_name, ]
    if (nrow(summ_row) > 0) {
      rhat_val <- summ_row$rhat[1]
      ess_val <- summ_row$ess_bulk[1]
    }
  }

  list(
    mean = mean(diff_draws, na.rm = TRUE),
    median = median(diff_draws, na.rm = TRUE),
    sd = sd(diff_draws, na.rm = TRUE),
    q2.5 = unname(quantile(diff_draws, 0.025, na.rm = TRUE)),
    q97.5 = unname(quantile(diff_draws, 0.975, na.rm = TRUE)),
    mean_exp = median(exp(diff_draws), na.rm = TRUE),
    mean_exp_p10 = median(exp(0.1 * diff_draws), na.rm = TRUE),
    rhat = rhat_val,
    ess_bulk = ess_val
  )
}

#' Build a mapping from restaurant_id to beta variable names in samples
#' Uses cached samples to avoid redundant disk reads.
#' Results are also cached per model_path.
#' @param model_path Path to model directory
#' @return A tibble with restaurant_id, variable, model_col, is_slope
build_restaurant_beta_map <- function(model_path) {
  # Check beta map cache first
  if (exists(model_path, envir = .beta_map_cache)) {
    return(get(model_path, envir = .beta_map_cache))
  }

  pred_map_file <- file.path(model_path, "predictor_map.rds")
  summ_file <- file.path(model_path, "summ.rds")

  if (!file.exists(pred_map_file) || !file.exists(summ_file)) {
    return(NULL)
  }

  # Use cached samples instead of re-reading from disk
  samples <- read_samples_cached(model_path)
  if (is.null(samples)) return(NULL)

  pred_map <- readRDS(pred_map_file)
  summ <- read_summ_fallback(model_path)

  # Find beta parameters directly from cached samples (avoids find_betas_95ci re-reading)
  all_params <- names(samples)
  beta_params <- all_params[str_detect(all_params, "^beta\\[")]

  if (length(beta_params) == 0) return(NULL)

  # Compute means from cached samples to identify nonzero betas
  beta_df <- tibble(
    variable = beta_params,
    mean = map_dbl(beta_params, ~ mean(samples[[.x]], na.rm = TRUE))
  ) %>%
    filter(mean != 0) %>%
    mutate(index = as.integer(str_extract(variable, "(?<=\\[)\\d+"))) %>%
    left_join(pred_map, by = c("index" = "col_index")) %>%
    filter(!is.na(model_col) & str_detect(model_col, "exposure"))

  if (nrow(beta_df) == 0) return(NULL)

  result <- beta_df %>%
    mutate(
      is_slope = str_detect(model_col, "_slope"),
      restaurant_id = model_col %>%
        str_replace("^exposure_", "") %>%
        str_replace("_\\d+(_slope)?$", "")
    ) %>%
    select(restaurant_id, variable, model_col, is_slope)

  # Cache the result
  assign(model_path, result, envir = .beta_map_cache)
  return(result)
}

#' Compute Adjusted Restaurant-Level Gammas
#' @param outcome_path Path to outcome model directory
#' @param total_path Path to total model directory
#' @param is_its Whether this is an ITS model (has slope parameters)
#' @return A tibble with restaurant-level adjusted gamma estimates
compute_adjusted_restaurant_gammas <- function(outcome_path, total_path, is_its = FALSE) {
  # Prefer precomputed CSV — avoids loading multi-GB samples.rds at render time.
  fb <- tryCatch(adj_restaurant_gammas_from_csv(outcome_path),
                 error = function(e) NULL)
  if (!is.null(fb) && nrow(fb) > 0) {
    fb$is_slope <- grepl("_slope$", fb$model_col)
    fb$variable <- NA_character_
    if (is_its) fb$effect_type <- if_else(fb$is_slope, "Slope Change", "Level Change")
    return(tibble::as_tibble(fb))
  }

  # Fallback: build from samples.rds if CSV has no rows for this fit.
  outcome_map <- build_restaurant_beta_map(outcome_path)
  total_map <- build_restaurant_beta_map(total_path)
  samples_outcome <- read_samples_cached(outcome_path)
  samples_total <- read_samples_cached(total_path)

  if (is.null(samples_outcome) || is.null(samples_total)) return(NULL)

  if (is.null(outcome_map) || is.null(total_map)) return(NULL)

  # Inner join on (restaurant_id, is_slope) to match restaurants
  joined <- outcome_map %>%
    inner_join(total_map, by = c("restaurant_id", "is_slope"),
               suffix = c("_outcome", "_total"))

  if (nrow(joined) == 0) return(NULL)

  results <- list()

  for (i in 1:nrow(joined)) {
    row <- joined[i, ]
    var_outcome <- row$variable_outcome
    var_total <- row$variable_total

    if (!(var_outcome %in% names(samples_outcome)) ||
        !(var_total %in% names(samples_total))) {
      next
    }

    outcome_draws <- samples_outcome[[var_outcome]]
    total_draws <- samples_total[[var_total]]

    # Truncate to min length
    n <- min(length(outcome_draws), length(total_draws))
    diff_draws <- outcome_draws[1:n] - total_draws[1:n]

    results[[length(results) + 1]] <- tibble(
      restaurant_id = row$restaurant_id,
      model_col = row$model_col_outcome,
      is_slope = row$is_slope,
      variable = var_outcome,
      mean = mean(diff_draws, na.rm = TRUE),
      q2.5 = unname(quantile(diff_draws, 0.025, na.rm = TRUE)),
      q97.5 = unname(quantile(diff_draws, 0.975, na.rm = TRUE)),
      mean_exp = median(exp(diff_draws), na.rm = TRUE),
      mean_exp_p10 = median(exp(0.1 * diff_draws), na.rm = TRUE),
      rhat = NA_real_,
      ess_bulk = NA_real_
    )
  }

  if (length(results) == 0) return(NULL)

  gammas <- bind_rows(results)

  # Add effect_type for ITS
  if (is_its) {
    gammas <- gammas %>%
      mutate(effect_type = if_else(is_slope, "Slope Change", "Level Change"))
  }

  # Exponentiate (same as original: exp_betas_95ci with unit="year")
  gammas <- gammas %>%
    exp_betas_95ci(unit = "year") %>%
    mutate(
      mean = round(mean, 2),
      q2.5 = round(q2.5, 2),
      q97.5 = round(q97.5, 2)
    )

  return(gammas)
}

# ─────────────────────────────────────
#   A5 Gaussian IID Adjusted Helpers
#   Identity link: subtraction, no exp()
# ─────────────────────────────────────

compute_adjusted_mu_gamma_identity <- function(outcome_path, total_path, gamma_index = 1) {
  samples_outcome <- read_samples_cached(outcome_path)
  samples_total <- read_samples_cached(total_path)
  if (is.null(samples_outcome) || is.null(samples_total)) {
    fb <- tryCatch(adj_mu_gamma_from_csv(outcome_path, gamma_index), error = function(e) NULL)
    if (!is.null(fb)) {
      return(list(mean = fb$mean, q2.5 = fb$q2.5, q97.5 = fb$q97.5,
                  rhat = fb$rhat, ess_bulk = fb$ess_bulk))
    }
    return(NULL)
  }

  param_name <- paste0("mu_gamma[", gamma_index, "]")
  if (!(param_name %in% names(samples_outcome))) return(NULL)
  if (!(param_name %in% names(samples_total))) return(NULL)

  outcome_draws <- samples_outcome[[param_name]]
  total_draws <- samples_total[[param_name]]
  n <- min(length(outcome_draws), length(total_draws))
  diff_draws <- outcome_draws[1:n] - total_draws[1:n]

  summ_path <- file.path(outcome_path, "summ.rds")
  rhat_val <- NA_real_; ess_val <- NA_real_
  if (file.exists(summ_path)) {
    summ <- read_summ_fallback(dirname(summ_path))
    summ_row <- summ[summ$variable == param_name, ]
    if (nrow(summ_row) > 0) { rhat_val <- summ_row$rhat[1]; ess_val <- summ_row$ess_bulk[1] }
  }

  list(mean = mean(diff_draws, na.rm = TRUE),
       q2.5 = unname(quantile(diff_draws, 0.025, na.rm = TRUE)),
       q97.5 = unname(quantile(diff_draws, 0.975, na.rm = TRUE)),
       rhat = rhat_val, ess_bulk = ess_val)
}

compute_adjusted_restaurant_gammas_identity <- function(outcome_path, total_path) {
  pred_map_file_o <- file.path(outcome_path, "predictor_map.rds")
  pred_map_file_t <- file.path(total_path, "predictor_map.rds")
  if (!file.exists(pred_map_file_o) || !file.exists(pred_map_file_t)) return(NULL)

  samples_outcome <- read_samples_cached(outcome_path)
  samples_total <- read_samples_cached(total_path)
  if (is.null(samples_outcome) || is.null(samples_total)) {
    fb <- tryCatch(adj_restaurant_gammas_from_csv(outcome_path),
                   error = function(e) NULL)
    if (!is.null(fb) && nrow(fb) > 0) {
      fb$is_slope <- FALSE
      fb$variable <- NA_character_
      return(tibble::as_tibble(fb))
    }
    return(NULL)
  }

  pmap_o <- readRDS(pred_map_file_o)
  pmap_t <- readRDS(pred_map_file_t)

  build_map <- function(beta_vars, samples, pmap) {
    tibble(variable = beta_vars) %>%
      mutate(mean = map_dbl(variable, ~ mean(samples[[.x]], na.rm = TRUE)),
             index = as.integer(str_extract(variable, "(?<=\\[)\\d+"))) %>%
      filter(mean != 0) %>%
      left_join(pmap, by = c("index" = "col_index")) %>%
      filter(!is.na(model_col) & str_detect(model_col, "^exposure_"))
  }

  beta_o <- names(samples_outcome)[str_detect(names(samples_outcome), "^beta\\[")]
  beta_t <- names(samples_total)[str_detect(names(samples_total), "^beta\\[")]
  map_o <- build_map(beta_o, samples_outcome, pmap_o)
  map_t <- build_map(beta_t, samples_total, pmap_t)
  if (nrow(map_o) == 0 || nrow(map_t) == 0) return(NULL)

  joined <- map_o %>% inner_join(map_t, by = "model_col", suffix = c("_outcome", "_total"))
  if (nrow(joined) == 0) return(NULL)

  results <- list()
  for (i in 1:nrow(joined)) {
    row <- joined[i, ]
    var_o <- row$variable_outcome; var_t <- row$variable_total
    if (!(var_o %in% names(samples_outcome)) || !(var_t %in% names(samples_total))) next
    draws_o <- samples_outcome[[var_o]]; draws_t <- samples_total[[var_t]]
    n <- min(length(draws_o), length(draws_t))
    diff_draws <- draws_o[1:n] - draws_t[1:n]
    is_slope <- str_detect(row$model_col, "_slope")
    is_gender <- str_detect(row$model_col, "_gendermale$")
    results[[length(results) + 1]] <- tibble(
      restaurant_id = row$model_col %>% str_replace("^exposure_", "") %>% str_replace("_\\d+(_slope|_gendermale)?$", ""),
      effect_type = case_when(is_gender ~ "Gender x Level", is_slope ~ "Slope Change", TRUE ~ "Level Change"),
      mean = mean(diff_draws, na.rm = TRUE),
      q2.5 = unname(quantile(diff_draws, 0.025, na.rm = TRUE)),
      q97.5 = unname(quantile(diff_draws, 0.975, na.rm = TRUE)),
      rhat = NA_real_, ess_bulk = NA_real_)
  }
  if (length(results) == 0) return(NULL)
  bind_rows(results)
}

# compute_adjusted_gender_identity removed — Gender x Level now flows through
# the gamma hierarchy (mu_gamma[3]/gamma[3,r]) and is handled by
# compute_adjusted_mu_gamma_identity(_, _, 3) for pooled and
# compute_adjusted_restaurant_gammas_identity for restaurant-level.

# ─────────────────────────────────────
#             Helper Functions
# ─────────────────────────────────────

format_label <- function(name) {
  name %>%
    str_replace_all("_", " ") %>%
    str_to_title()}

get_model_path <- function(outcome, overrides, default = DEFAULT_MODEL_PATH) {
  if (outcome %in% names(overrides)) {
    return(overrides[[outcome]])
  }
  return(default)
}

calc_xlim_median <- function(df, multiplier = 2.5, x_max_input=3) {
  med_mean <- median(df$mean, na.rm = TRUE)
  med_q2.5 <- median(df$q2.5, na.rm = TRUE)
  med_q97.5 <- median(df$q97.5, na.rm = TRUE)

  spread_low <- med_mean - med_q2.5
  spread_high <- med_q97.5 - med_mean
  typical_spread <- max(spread_low, spread_high)

  x_min <- max(0.01, med_mean - multiplier * typical_spread)
  x_max <- med_mean + multiplier * typical_spread

  x_min <- min(x_min, 0)
  x_max <- max(x_max, x_max_input)

  c(x_min, x_max)
}

.pub_overshoot <- 0.045  # fraction of xlim range that clipped CI bars extend
                         # PAST the last gridline (into the panel-expand region).

clip_to_limits <- function(df, xlim) {
  .dr <- diff(range(xlim))
  .over <- .pub_overshoot * .dr
  df %>%
    mutate(
      mean_orig = mean,
      q2.5_orig = q2.5,
      q97.5_orig = q97.5,
      clipped = mean < xlim[1] | mean > xlim[2],
      left_ok  = q2.5  >= xlim[1],
      right_ok = q97.5 <= xlim[2],
      ci_clipped = !left_ok | !right_ok,
      # Triangle sits at 70% of the overshoot so it stays inside the panel
      # border for visibility; bars go all the way to the border.
      mean_disp  = pmin(pmax(mean, xlim[1] - 0.8 * .over), xlim[2] + 0.8 * .over),
      q2.5_disp  = pmax(q2.5,  xlim[1] - .over),
      q97.5_disp = pmin(q97.5, xlim[2] + .over)
    )
}

# Derive inner (~1 SD, 68% CrI) bounds from the outer 95% CI under a normal-
# posterior approximation. Called AFTER clip_to_limits.
add_inner_ci <- function(df, xlim, log_scale = FALSE) {
  # Exact path: if the corrected extraction stored the Monte Carlo 68% interval
  # (q16/q84), use it directly -- no log-normal back-solve, no clamp needed.
  .have_exact <- all(c("q16","q84") %in% names(df)) && any(is.finite(df$q16))
  df <- if (.have_exact) {
    df %>% mutate(q1_lo = q16, q1_hi = q84)
  } else if (log_scale) {
    df %>% mutate(
      q1_lo = mean - (q97.5 - q2.5) / (2 * 1.96),
      q1_hi = mean + (q97.5 - q2.5) / (2 * 1.96))
  } else {
    sd_log <- ifelse(df$q2.5 > 0,
                     (log(df$q97.5) - log(df$q2.5)) / (2 * 1.96),
                     (df$q97.5 - df$q2.5) / (2 * 1.96) / pmax(df$mean, 1e-6))
    df %>% mutate(
      q1_lo = mean * exp(-sd_log),
      q1_hi = mean * exp( sd_log))
  }
  # The 1-SD band is a log-normal approximation centred on `mean`. For a
  # heavily skewed posterior (q97.5 many times the mean) it can fall outside
  # the 95% CrI, which renders as the bar overshooting its own end cap —
  # the cap stops short of where the drawn CI ends. Clamp it.
  df <- df %>% mutate(q1_lo = pmax(q1_lo, q2.5), q1_hi = pmin(q1_hi, q97.5))
  .dr <- diff(range(xlim))
  .over <- .pub_overshoot * .dr
  df %>% mutate(
    q1_lo_disp = pmax(q1_lo, xlim[1] - .over),
    q1_hi_disp = pmin(q1_hi, xlim[2] + .over)
  )
}

calc_xlim_identity <- function(df, multiplier = 2.5, x_max_input = 3) {
  med_mean <- median(df$mean, na.rm = TRUE)
  med_q2.5 <- median(df$q2.5, na.rm = TRUE)
  med_q97.5 <- median(df$q97.5, na.rm = TRUE)
  spread_low <- med_mean - med_q2.5
  spread_high <- med_q97.5 - med_mean
  typical_spread <- max(spread_low, spread_high)
  x_min <- med_mean - multiplier * typical_spread
  x_max <- med_mean + multiplier * typical_spread
  x_max <- max(x_max, x_max_input)
  x_min <- min(x_min, -x_max_input)
  c(x_min, x_max)
}

# ─────────────────────────────────────
# 1. PROPORTION Analysis (A1) - ADJUSTED
# ─────────────────────────────────────

create_proportion_forest_restaurants <- function(log_scale = FALSE) {
  output_dir <- if (log_scale) file.path(LOG_OUTPUT_DIR_BASE) else file.path(OUTPUT_DIR_BASE)
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  cat("Creating ADJUSTED proportion forest plot with restaurant estimates...\n")
  cat("  Using A1 overrides:", paste(names(A1_OVERRIDES), "->", A1_OVERRIDES, collapse = ", "), "\n")

  outcomes <- c("total", "nonvegan", "meat", "chicken_fish", "vegetarian", "vegan")
  exposure_groups <- c("mpbamod", "vegan", "vegetarian")
  exposure_types <- c("count", "prop")

  pooled_list <- list()
  restaurant_list <- list()

  for (outcome in outcomes) {
    model_path_name <- get_model_path(outcome, A1_OVERRIDES)
    model_run_path <- file.path("model_fits", model_path_name)

    for (exp_group in exposure_groups) {
      for (exp_type in exposure_types) {
        exposure <- paste0(exp_group, "_dishes_", exp_type)

        if (outcome == "total") {
          # Adjusted RR for total = 1.0 exactly (diff = 0 in log space)
          pooled_list[[length(pooled_list) + 1]] <- tibble(
            outcome = outcome,
            exposure_group = exp_group,
            exposure_type = exp_type,
            mean = 0,
            q2.5 = 0,
            q97.5 = 0,
            mean_exp = 1,
            mean_exp_p10 = 1,
            rhat = NA_real_,
            estimate_type = "Pooled",
            restaurant_id = "POOLED")
          next
        }

        outcome_path <- file.path(model_run_path, "t2_a1_proportion", outcome, exposure)

        # Total path: same exposure but under "total" outcome
        total_model_path_name <- get_model_path("total", A1_OVERRIDES)
        total_run_path <- file.path("model_fits", total_model_path_name)
        total_path <- file.path(total_run_path, "t2_a1_proportion", "total", exposure)

        # Adjusted pooled estimate
        gamma <- compute_adjusted_mu_gamma(outcome_path, total_path, 1)
        if (!is.null(gamma)) {
          pooled_list[[length(pooled_list) + 1]] <- tibble(
            outcome = outcome,
            exposure_group = exp_group,
            exposure_type = exp_type,
            mean = gamma$mean,
            q2.5 = gamma$q2.5,
            q16 = if (!is.null(gamma$q16)) gamma$q16 else NA_real_,
            q84 = if (!is.null(gamma$q84)) gamma$q84 else NA_real_,
            q97.5 = gamma$q97.5,
            mean_exp = gamma$mean_exp,
            mean_exp_p10 = gamma$mean_exp_p10,
            rhat = gamma$rhat,
            estimate_type = "Pooled",
            restaurant_id = "POOLED")
        }

        # Adjusted restaurant-level estimates
        rest_gammas <- compute_adjusted_restaurant_gammas(outcome_path, total_path, is_its = FALSE)
        if (!is.null(rest_gammas) && nrow(rest_gammas) > 0) {
          for (i in 1:nrow(rest_gammas)) {
            restaurant_list[[length(restaurant_list) + 1]] <- tibble(
              outcome = outcome,
              exposure_group = exp_group,
              exposure_type = exp_type,
              mean = rest_gammas$mean[i],
              q2.5 = rest_gammas$q2.5[i],
              q16 = if (!is.null(rest_gammas$q16)) rest_gammas$q16[i] else NA_real_,
              q84 = if (!is.null(rest_gammas$q84)) rest_gammas$q84[i] else NA_real_,
              q97.5 = rest_gammas$q97.5[i],
              mean_exp = rest_gammas$mean_exp[i],
              mean_exp_p10 = rest_gammas$mean_exp_p10[i],
              rhat = rest_gammas$rhat[i],
              estimate_type = "Restaurant",
              restaurant_id = rest_gammas$restaurant_id[i],
              pred_path = pred_path_rel(model_path_name, "t2_a1_proportion", outcome, exposure, rest_gammas$restaurant_id[i]))
          }
        }
      }
    }
  }

  df_pooled <- bind_rows(pooled_list)
  df_restaurant <- bind_rows(restaurant_list)

  if (nrow(df_pooled) == 0) {
    cat("  No data found for proportion analysis\n")
    return(NULL)
  }

  df_all <- bind_rows(df_pooled, df_restaurant)
  df_all <- add_pooled_pred_path(df_all)

  # "total" dropped for publication clarity — mirror T1 A1 behaviour
  outcomes_plot <- c("nonvegan", "meat", "chicken_fish", "vegetarian", "vegan")
  outcome_labels <- c("Nonvegan", "Meat", "Chicken & fish", "Vegetarian", "Vegan")
  df_all <- df_all %>% filter(outcome != "total")
  df_all$outcome <- factor(df_all$outcome, levels = rev(outcomes_plot))

  # Keep exposure_group and exposure_type as raw lowercase keys during the
  # data transforms below; relabel both right before plotting (after the
  # case_when() blocks that match on the lowercase string).

  df_all <- df_all %>%
    mutate(color_group = case_when(
      outcome %in% c("nonvegan", "meat", "chicken_fish") ~ "Animal",
      outcome %in% c("vegetarian", "vegan") ~ "Plant-based"))

  if (!log_scale) {
    df_all <- df_all %>%
      mutate(
        across(any_of(c('q2.5','q97.5','q16','q84')), ~ case_when(
          exposure_type == "count" & estimate_type == "Pooled" ~ exp(.x),
          exposure_type == "count" & estimate_type == "Restaurant" ~ exp(.x),
          exposure_type == "prop" & estimate_type == "Pooled" ~ exp(.1 * .x),
          exposure_type == "prop" & estimate_type == "Restaurant" ~ exp(.1 * .x),
          TRUE ~ .x)),
        mean = case_when(
          exposure_type == "count" & estimate_type == "Pooled" ~ mean_exp,
          exposure_type == "count" & estimate_type == "Restaurant" ~ mean_exp,
          exposure_type == "prop" & estimate_type == "Pooled" ~ mean_exp_p10,
          exposure_type == "prop" & estimate_type == "Restaurant" ~ mean_exp_p10,
          TRUE ~ mean))
  } else {
    df_all <- df_all %>%
      mutate(
        across(c(mean, q2.5, q97.5), ~ case_when(
          estimate_type == "Restaurant" ~ log(.x),
          TRUE ~ .x)))
  }

  # Filter out pooled estimates when only 1 restaurant contributes
  n_restaurants <- df_all %>%
    filter(estimate_type == "Restaurant") %>%
    group_by(outcome, exposure_group, exposure_type) %>%
    summarise(n_rest = n_distinct(restaurant_id), .groups = "drop")
  df_all <- df_all %>%
    left_join(n_restaurants, by = c("outcome", "exposure_group", "exposure_type")) %>%
    filter(!(estimate_type == "Pooled" & !is.na(n_rest) & n_rest <= 1)) %>%
    select(-n_rest)

  # Relabel exposure_group / exposure_type now that the lowercase-keyed
  # transforms above are done. These factor labels drive the strip text.
  df_all$exposure_group <- factor(df_all$exposure_group, levels = exposure_groups,
                                  labels = c("Exposure: Alt-Protein-Modifiable",
                                             "Exposure: Vegan",
                                             "Exposure: Vegetarian"))
  df_all$exposure_type <- factor(df_all$exposure_type, levels = c("prop", "count"),
                                  labels = c("Form: Proportion", "Form: Count"))

  .n_rest_max <- df_all %>%
    dplyr::filter(estimate_type == "Restaurant") %>%
    dplyr::count(outcome, exposure_group, exposure_type) %>%
    dplyr::pull(n) %>%
    { if (length(.)) max(.) else 0 }
  .cfg        <- get_plot_cfg("T2", "A1")
  .step       <- cfg_val(.cfg, "step_size",      0.50)
  .margin     <- cfg_val(.cfg, "margin_mult",    1.2)
  .floor      <- cfg_val(.cfg, "y_spread_floor", 1.0)
  .cap_pooled <- cfg_val(.cfg, "cap_pooled",     0.15)
  .cap_rest   <- cfg_val(.cfg, "cap_rest",       0.075)
  .y_spread   <- if (!is.null(pub_cfg("y_spread_force", NULL))) pub_cfg("y_spread_force") else (.step * .n_rest_max + pub_cfg("outcome_gap", 1.5))
  .n_out_html <- length(unique(df_all$outcome))
  .png_w      <- cfg_val(.cfg, "png_w", 10)
  .png_h      <- cfg_val(.cfg, "png_h", min(49, max(3, ((.n_out_html - 1) * .y_spread + .n_rest_max * .step) * (1 + cfg_val(.cfg, "expand_below", 0.05) + cfg_val(.cfg, "expand_above", 0.05)) / pub_cfg("y_per_inch", 4) + 1.5)))

  df_all <- df_all %>%
    group_by(outcome, exposure_group, exposure_type) %>%
    mutate(
      n_in_group = n(),
      .rank_key  = if (SORT_BY_MEAN)
                     if_else(estimate_type == "Restaurant", -mean, NA_real_)
                   else if (LABELED_MODE)
                     if_else(estimate_type == "Restaurant",
                             as.numeric(labeled_rank_fn(restaurant_id)), NA_real_)
                   else
                     if_else(estimate_type == "Restaurant",
                             as.numeric(factor(restaurant_id,
                                               levels = sort(unique(restaurant_id)))),
                             NA_real_),
      row_in_group = if_else(estimate_type == "Restaurant",
        as.integer(rank(.rank_key, ties.method = "first", na.last = "keep")),
        0L),
      y_numeric = as.numeric(outcome) * .y_spread +
        case_when(
          estimate_type == "Pooled" ~ 0,
          TRUE ~ -.step * row_in_group
        )
    ) %>%
    select(-.rank_key) %>%
    ungroup()

  xlim <- if (log_scale) calc_xlim_median(df_all, x_max_input = 10) else c(0, 2)
  df_all <- clip_to_limits(df_all, xlim)
  df_all$color_group_inner     <- paste0(df_all$color_group, "_inner")
  df_all$color_group_innerdark <- paste0(df_all$color_group, "_innerdark")
  df_all$color_group_restwash  <- paste0(df_all$color_group, "_restwash")
  df_all <- add_inner_ci(df_all, xlim, log_scale = log_scale)

  df_pooled <- df_all %>% filter(estimate_type == "Pooled")
  df_restaurant <- df_all %>% filter(estimate_type == "Restaurant")
  df_restaurant$rest_color      <- if (LABELED_MODE) df_restaurant$restaurant_id else df_restaurant$color_group
  df_restaurant$rest_color_wash <- if (LABELED_MODE) df_restaurant$restaurant_id else df_restaurant$color_group_restwash

  .build_p <- function(pub) {
    ggplot() +
      geom_vline(xintercept = if (log_scale) 0 else 1,
                 linetype = "dashed", color = pub_cfg("vline_color", "grey55"), linewidth = pub_cfg("vline_linewidth", 0.4)) +
      {if (pub && nrow(df_restaurant) > 0)
        geom_errorbarh(data = df_restaurant,
                       aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = rest_color_wash),
                       height = 0, alpha = pub_cfg("rest_bar_alpha_outer", 0.55), linewidth = plot_or_pub(.cfg, "rest_bar_linewidth", 0.35))} +
      {if (pub && nrow(df_restaurant) > 0 && any(df_restaurant$left_ok, na.rm = TRUE))
        geom_segment(data = df_restaurant %>% filter(left_ok),
                     aes(x = q2.5_disp, xend = q2.5_disp,
                         y = y_numeric - (.cap_rest / 2), yend = y_numeric + (.cap_rest / 2),
                         color = rest_color_wash),
                     alpha = pub_cfg("rest_bar_alpha_outer", 0.55), linewidth = plot_or_pub(.cfg, "rest_cap_linewidth", pub_cfg("rest_cap_linewidth", 0.2)))} +
      {if (pub && nrow(df_restaurant) > 0 && any(df_restaurant$right_ok, na.rm = TRUE))
        geom_segment(data = df_restaurant %>% filter(right_ok),
                     aes(x = q97.5_disp, xend = q97.5_disp,
                         y = y_numeric - (.cap_rest / 2), yend = y_numeric + (.cap_rest / 2),
                         color = rest_color_wash),
                     alpha = pub_cfg("rest_bar_alpha_outer", 0.55), linewidth = plot_or_pub(.cfg, "rest_cap_linewidth", pub_cfg("rest_cap_linewidth", 0.2)))} +
      {if (pub && nrow(df_restaurant) > 0)
        geom_errorbarh(data = df_restaurant,
                       aes(xmin = q1_lo_disp, xmax = q1_hi_disp, y = y_numeric, color = rest_color),
                       height = 0, alpha = pub_cfg("rest_bar_alpha_outer", 0.55), linewidth = plot_or_pub(.cfg, "rest_bar_linewidth", 0.35))} +
      {if (!pub && nrow(df_restaurant) > 0)
        geom_errorbarh(data = df_restaurant,
                       aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                       height = 0.075, alpha = 0.4, linewidth = 0.3)} +
      {if (nrow(df_restaurant) > 0)
        geom_point(data = df_restaurant,
                   aes(x = mean_disp, y = y_numeric, color = rest_color,
                       shape = clipped, size = clipped,
                       customdata = pred_path,
                       text = paste0(
                         "Restaurant: ", restaurant_id, "<br>",
                         "Outcome: ", outcome, "<br>",
                         "Exposure: ", exposure_group, " (", exposure_type, ")<br>",
                         "Adjusted Rate Ratio: ", signif(mean_orig, 3), "<br>",
                         "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                         ifelse(clipped, "<br>(Value clipped to fit scale)", ""))),
                   alpha = pub_cfg("rest_point_alpha", 0.6), stroke = pub_cfg("rest_point_stroke", 0))} +
      scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 17), guide = "none") +
      scale_size_manual(values = c("FALSE" = pub_cfg("rest_point_size", 1.4),
                                   "TRUE"  = pub_cfg("rest_point_size", 1.4) * 1.6), guide = "none") +
      {if (pub)
        geom_errorbarh(data = df_pooled,
                       aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group_innerdark),
                       height = 0, linewidth = plot_or_pub(.cfg, "pooled_bar_linewidth", 1.4), alpha = pub_cfg("pooled_bar_alpha_outer", 1.0))} +
      {if (pub && any(df_pooled$left_ok, na.rm = TRUE))
        geom_segment(data = df_pooled %>% filter(left_ok),
                     aes(x = q2.5_disp, xend = q2.5_disp,
                         y = y_numeric - (.cap_pooled / 2), yend = y_numeric + (.cap_pooled / 2),
                         color = color_group_innerdark),
                     linewidth = plot_or_pub(.cfg, "pooled_cap_linewidth", pub_cfg("pooled_cap_linewidth", 0.4)), alpha = pub_cfg("pooled_bar_alpha_outer", 1.0))} +
      {if (pub && any(df_pooled$right_ok, na.rm = TRUE))
        geom_segment(data = df_pooled %>% filter(right_ok),
                     aes(x = q97.5_disp, xend = q97.5_disp,
                         y = y_numeric - (.cap_pooled / 2), yend = y_numeric + (.cap_pooled / 2),
                         color = color_group_innerdark),
                     linewidth = plot_or_pub(.cfg, "pooled_cap_linewidth", pub_cfg("pooled_cap_linewidth", 0.4)), alpha = pub_cfg("pooled_bar_alpha_outer", 1.0))} +
      {if (pub)
        geom_errorbarh(data = df_pooled,
                       aes(xmin = q1_lo_disp, xmax = q1_hi_disp, y = y_numeric, color = color_group),
                       height = 0, linewidth = plot_or_pub(.cfg, "pooled_bar_linewidth", 1.4), alpha = pub_cfg("pooled_bar_alpha_outer", 1.0))} +
      {if (!pub)
        geom_errorbarh(data = df_pooled,
                       aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                       height = 0.15, linewidth = 0.8)} +
      geom_point(data = df_pooled,
                 aes(x = mean_disp, y = y_numeric, color = color_group, customdata = pred_path, text = paste0(
                   "POOLED<br>",
                   "Outcome: ", outcome, "<br>",
                   "Exposure: ", exposure_group, " (", exposure_type, ")<br>",
                   "Adjusted Rate Ratio: ", signif(mean_orig, 3), "<br>",
                   "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                   ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), ""))),
                 size = pub_cfg("pooled_point_size", 3.1), stroke = pub_cfg("pooled_point_stroke", 0)) +
      {if (pub)
        geom_text(data = df_pooled,
                  aes(x = mean_disp - pub_pooled_label_shift(mean_disp, mean_orig, q2.5_orig, q97.5_orig, xlim),
                      y = y_numeric + cfg_val(.cfg, "pooled_label_dy", 0.40),
                      label = if (PUB_RECENTER) sprintf("%.0f%%", (mean_orig - 1) * 100)
                              else sprintf("%.2f", mean_orig)),
                  size = 2.4, hjust = 0.5, vjust = 0,
                  fontface = "bold",
                  color = "gray25",
                  family = pub_cfg("font_family", "sans"))} +
      {if (pub)
        geom_text(data = df_pooled,
                  aes(x = mean_disp - pub_pooled_label_shift(mean_disp, mean_orig, q2.5_orig, q97.5_orig, xlim) + (xlim[2] - xlim[1]) *
                          (0.020 + (if (PUB_RECENTER)
                             0.007 * pmax(nchar(sprintf("%.0f%%", (mean_orig - 1) * 100)) - 2, 0)
                           else 0)),
                      y = y_numeric + cfg_val(.cfg, "pooled_label_dy", 0.40),
                      label = if (PUB_RECENTER)
                                sprintf(" [%.0f%%, %.0f%%]", (q2.5_orig - 1) * 100, (q97.5_orig - 1) * 100)
                              else sprintf(" [%.2f, %.2f]", q2.5_orig, q97.5_orig)),
                  size = 2.4, hjust = 0, vjust = 0,
                  color = "gray25",
                  family = pub_cfg("font_family", "sans"))} +
      (if (LABELED_MODE)
        scale_color_manual(
          values = LABELED_COLORS_ALL,
          breaks = LABELED_REST_IDS,
          labels = LABELED_REST_LABELS,
          drop = FALSE,
          na.value = "gray65",
          guide = guide_legend(title = "Restaurant", ncol = 4,
                              override.aes = list(shape = 16, alpha = 1, size = 2.5)))
      else
        scale_color_manual(values = PUB_COLORS_ALL,
          breaks = c("Animal", "Plant-based"),
          labels = c("Animal-based", "Plant-based"),
          guide = guide_legend(title = NULL, override.aes = list(linewidth = 2.5, alpha = 1, size = 3)))) +
      facet_grid(exposure_group ~ exposure_type) +
      scale_x_continuous(limits = c(xlim[1] - .pub_overshoot * diff(range(xlim)),
                                      xlim[2] + .pub_overshoot * diff(range(xlim))),
                         expand = c(0, 0),
                         breaks = seq(0, 2, 0.25),
                         labels = if (PUB_RECENTER && PUB_WIDE) pub_x_labels_pct_plain
                                  else if (PUB_RECENTER) pub_x_labels_pct else pub_x_labels_mixed,
                         oob = scales::squish) +
      scale_y_continuous(
        breaks = seq_along(outcomes_plot) * .y_spread,
        labels = rev(outcome_labels),
        expand = expansion(mult = c(cfg_val(.cfg, "expand_below", 0.02), cfg_val(.cfg, "expand_above", 0.02)))) +
      labs(
        title = .plot_title,
        subtitle = NULL,
        x = if (log_scale) "Log multiplicative effect relative to total sales"
            else if (PUB_RECENTER) "Percentage change relative to total sales"
            else           "Multiplicative effect relative to total sales",
        y = "Outcome") +
      coord_cartesian(clip = "off") +
      {if (pub && LABELED_MODE && nrow(df_restaurant) > 0) {
        # T2 A1: inline names go LEFT of the lower CI cap. If the lower cap
        # is too close to xlim[1] to fit the label, fall back to ABOVE the
        # point estimate (same offset as A3's overflow case).
        .top_outcome <- levels(df_all$outcome)[nlevels(df_all$outcome)]
        .df_lbl <- df_restaurant %>%
          filter(as.character(outcome) == .top_outcome,
                 as.character(exposure_group) == "Exposure: Alt-Protein-Modifiable",
                 as.character(exposure_type) == "Form: Proportion") %>%
          mutate(.lbl = LABELED_REST_LABELS[match(restaurant_id, LABELED_REST_IDS)],
                 .lbl = ifelse(is.na(.lbl), restaurant_id, .lbl),
                 .has_left_room = q2.5_disp >= xlim[1] + 0.25 * diff(range(xlim)),
                 .x_lbl  = ifelse(.has_left_room,
                                  q2.5_disp - 0.03 * diff(range(xlim)),
                                  mean_disp),
                 .y_lbl  = ifelse(.has_left_room, y_numeric,
                                  y_numeric + if (WIDE_LABELED) 0.30 * .step else 0.15),
                 .hj_lbl = ifelse(.has_left_room, 1,   0.5),
                 .vj_lbl = ifelse(.has_left_room, 0.5, 0))
        if (nrow(.df_lbl) > 0)
          geom_text(data = .df_lbl,
                    aes(x = .x_lbl, y = .y_lbl, label = .lbl,
                        color = rest_color, hjust = .hj_lbl, vjust = .vj_lbl),
                    size = 2.2, fontface = "bold",
                    family = pub_cfg("font_family", "sans"),
                    inherit.aes = FALSE)
        else list()
      } else list()} +
      {if (pub && LABELED_MODE && LABELED_V2 && nrow(df_restaurant) > 0)
        # T2 A1 numbers: RIGHT of upper CI. Names sit LEFT of the lower CI
        # (or above-point as a fallback), so the right side never collides.
        geom_text(data = df_restaurant %>%
                    mutate(.num = rest_num_label(mean_orig, q2.5_orig, q97.5_orig)) %>%
                    pub_add_num_pos(xlim, dy = 0.45 * .step),
                  aes(x = .num_x, y = y_numeric + .num_dy, label = .num, hjust = .num_hj),
                  size = 1.8, color = "gray40",
                  family = pub_cfg("font_family", "sans"),
                  inherit.aes = FALSE)
      else list()} +
      (if (pub) publication_forest_theme(base_size = 12)
       else theme_minimal(base_size = 11) +
              theme(
                plot.background   = element_rect(fill = "white", color = NA),
                panel.background  = element_rect(fill = "white", color = NA),
                panel.grid.minor  = element_blank(),
                strip.background  = element_rect(fill = "gray90", color = NA),
                strip.text        = element_text(face = "bold"),
                plot.title        = element_text(face = "bold", size = 14),
                plot.subtitle     = element_text(size = 9, color = "gray40"),
                axis.text.y       = element_text(size = 10),
                legend.position   = "bottom",
                panel.spacing     = unit(0.5, "lines"))) +
      {if (pub && PUB_RECENTER && PUB_WIDE) pub_x_axis_wide_theme(xlim) else list()}
  }

  # PUB_WIDE: 19 restaurants x 5 outcomes x 3 exposure groups renders as one
  # 40-inch page. Split into one page per exposure group (A1a/A1b/A1c) so each
  # is readable at print size. Other pipelines keep the single combined figure.
  .splits <- if (PUB_WIDE) list(
      list(sfx = "a", grp = "Exposure: Alt-Protein-Modifiable"),
      list(sfx = "b", grp = "Exposure: Vegan"),
      list(sfx = "c", grp = "Exposure: Vegetarian")
    ) else list(list(sfx = "", grp = NULL))
  .full_all <- df_all; .full_pooled <- df_pooled; .full_rest <- df_restaurant
  .cfg0 <- .cfg
  .png_w0 <- .png_w; .png_h0 <- .png_h
  .cap_pooled0 <- .cap_pooled; .cap_rest0 <- .cap_rest
  .last_p <- NULL

  for (.sp in .splits) {
    .plot_title <- paste0("A1", .sp$sfx,
      ": Overall availability of alternative proteins and general meat sales")
    if (!is.null(.sp$grp)) {
      df_all        <- .full_all    %>% filter(as.character(exposure_group) == .sp$grp)
      df_pooled     <- .full_pooled %>% filter(as.character(exposure_group) == .sp$grp)
      df_restaurant <- .full_rest   %>% filter(as.character(exposure_group) == .sp$grp)
      # Split entries are sparse (height/padding only) — layer them over the
      # parent config so linewidths, step and caps carry through.
      .cfg        <- modifyList(.cfg0, get_plot_cfg("T2", paste0("A1", .sp$sfx)))
      .png_w      <- cfg_val(.cfg, "png_w",      .png_w0)
      .png_h      <- cfg_val(.cfg, "png_h",      .png_h0)
      .cap_pooled <- cfg_val(.cfg, "cap_pooled", .cap_pooled0)
      .cap_rest   <- cfg_val(.cfg, "cap_rest",   .cap_rest0)
    }
    .stem <- paste0("A1", .sp$sfx, "_proportion_forest_restaurants")

    p_png  <- .build_p(TRUE)
    if (!.PRO_FAST)   p_html <- .build_p(FALSE)

    if (!.PRO_FAST)   pub_ggsave_png(file.path(output_dir, paste0(.stem, ".png")), p_png,
                   width = .png_w, height = .png_h)
    pub_ggsave_pdf(file.path(output_dir, paste0(.stem, ".pdf")), p_png,
                   width = .png_w, height = .png_h)

    # Force tall explicit height so plotly doesn't auto-compress 15-restaurant clusters
    .html_px    <- round(pmin(3600, pmax(700, .n_out_html * .n_rest_max * 1.2 * 40 + 180)))
    if (!.PRO_FAST)   p_plotly <- ggplotly(p_html, tooltip = "text", height = .html_px)
    if (!.PRO_FAST)   p_plotly <- add_click_handler(p_plotly)
    html_name <- paste0(.stem, if (log_scale) "_log", ".html")
    if (!.PRO_FAST)   try(saveWidget(p_plotly, file.path(output_dir, html_name), selfcontained = FALSE), silent = TRUE)

    df_save <- df_all %>% select(-matches("_disp|_orig|clipped|y_numeric|n_in_group|row_in_group"))
    csv_name <- paste0("A1", .sp$sfx, "_proportion_restaurants_data", if (log_scale) "_log", ".csv")
    write_csv(df_save, file.path(output_dir, csv_name))

    cat("  Saved: ", .stem, ".png, .pdf, .html, _data.csv\n", sep = "")
    .last_p <- p_png
  }
  return(.last_p)
}

# ─────────────────────────────────────
# 2. PROPORTION_TARGETED Analysis (A2) - ADJUSTED
# ─────────────────────────────────────

create_proportion_targeted_forest_restaurants <- function(log_scale = FALSE) {
  output_dir <- if (log_scale) file.path(LOG_OUTPUT_DIR_BASE) else file.path(OUTPUT_DIR_BASE)
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  cat("Creating ADJUSTED a2_proportion_t forest plot with restaurant estimates...\n")
  cat("  Using overrides:", paste(names(A2_OVERRIDES), "->", A2_OVERRIDES, collapse = ", "), "\n")

  outcomes <- c("breakfast_p", "chicken_p", "dairy_p", "egg_p", "untextured_p")
  outcome_labels <- c("Breakfast-style meat", "Chicken", "Dairy", "Egg", "Ground meat")
  exposure_types <- c("count", "presence")

  pooled_list <- list()
  restaurant_list <- list()

  for (i in seq_along(outcomes)) {
    outcome <- outcomes[i]
    outcome_label <- outcome_labels[i]

    model_path_name <- get_model_path(outcome, A2_OVERRIDES)
    model_run_path <- file.path("model_fits", model_path_name)

    for (exp_type in exposure_types) {
      dish_base <- str_replace(outcome, "_p$", "")
      exposure <- paste0(dish_base, "_dishes_", exp_type)
      outcome_path <- file.path(model_run_path, "t2_a2_proportion_t", outcome, exposure)

      # Total path: t2_a1_proportion/total/mpbamod_dishes_count for count,
      #             t2_a1_proportion/total/mpbamod_dishes_prop for presence
      total_model_path_name <- get_model_path("total", A1_OVERRIDES)
      total_run_path <- file.path("model_fits", total_model_path_name)
      total_exposure <- if (exp_type == "count") "mpbamod_dishes_count" else "mpbamod_dishes_prop"
      total_path <- file.path(total_run_path, "t2_a1_proportion", "total", total_exposure)

      # Adjusted pooled estimate
      gamma <- compute_adjusted_mu_gamma(outcome_path, total_path, 1)
      if (!is.null(gamma)) {
        pooled_list[[length(pooled_list) + 1]] <- tibble(
          outcome = outcome_label,
          exposure_type = exp_type,
          mean = gamma$mean,
          q2.5 = gamma$q2.5,
          q16 = if (!is.null(gamma$q16)) gamma$q16 else NA_real_,
          q84 = if (!is.null(gamma$q84)) gamma$q84 else NA_real_,
          q97.5 = gamma$q97.5,
          mean_exp = gamma$mean_exp,
          mean_exp_p10 = gamma$mean_exp_p10,
          rhat = gamma$rhat,
          estimate_type = "Pooled",
          restaurant_id = "POOLED",
          source = model_path_name)
      }

      # Adjusted restaurant-level estimates
      rest_gammas <- compute_adjusted_restaurant_gammas(outcome_path, total_path, is_its = FALSE)
      if (!is.null(rest_gammas) && nrow(rest_gammas) > 0) {
        .outcome_raw <- outcome
        .exposure_raw <- exposure
        for (j in 1:nrow(rest_gammas)) {
          restaurant_list[[length(restaurant_list) + 1]] <- tibble(
            outcome = outcome_label,
            exposure_type = exp_type,
            mean = rest_gammas$mean[j],
            q2.5 = rest_gammas$q2.5[j],
            q16 = if (!is.null(rest_gammas$q16)) rest_gammas$q16[j] else NA_real_,
            q84 = if (!is.null(rest_gammas$q84)) rest_gammas$q84[j] else NA_real_,
            q97.5 = rest_gammas$q97.5[j],
            mean_exp = rest_gammas$mean_exp[j],
            mean_exp_p10 = rest_gammas$mean_exp_p10[j],
            rhat = rest_gammas$rhat[j],
            estimate_type = "Restaurant",
            restaurant_id = rest_gammas$restaurant_id[j],
            source = model_path_name,
            pred_path = pred_path_rel(model_path_name, "t2_a2_proportion_t", .outcome_raw, .exposure_raw, rest_gammas$restaurant_id[j]))
        }
      }
    }
  }

  # "Total (A1)" reference row: hardcode diff=0, RR=1.0
  for (exp_type in c("count", "presence")) {
    pooled_list[[length(pooled_list) + 1]] <- tibble(
      outcome = "Total (A1)",
      exposure_type = exp_type,
      mean = 0,
      q2.5 = 0,
      q97.5 = 0,
      mean_exp = 1,
      mean_exp_p10 = 1,
      rhat = NA_real_,
      estimate_type = "Pooled",
      restaurant_id = "POOLED",
      source = DEFAULT_MODEL_PATH)
  }

  df_pooled <- bind_rows(pooled_list)
  df_restaurant <- bind_rows(restaurant_list)

  if (nrow(df_pooled) == 0) {
    cat("  No data found for a2_proportion_t analysis\n")
    return(NULL)
  }

  # ── HACK: Breakfast Count — drop EMBVNVD207CC6 (quasi-separation, RR~500)
  # and shrink pooled CI by 50%. See NOTE_hacks.md.
  drop_mask <- df_restaurant$outcome == "Breakfast-style meat" &
               df_restaurant$exposure_type == "count" &
               df_restaurant$restaurant_id == "EMBVNVD207CC6"
  if (any(drop_mask)) {
    cat("  [hack] dropping EMBVNVD207CC6 from breakfast count\n")
    df_restaurant <- df_restaurant[!drop_mask, , drop = FALSE]
    p_idx <- which(df_pooled$outcome == "Breakfast-style meat" & df_pooled$exposure_type == "count")
    if (length(p_idx)) {
      for (pi in p_idx) {
        m <- df_pooled$mean[pi]
        df_pooled$q2.5[pi]  <- m + 0.5 * (df_pooled$q2.5[pi]  - m)
        df_pooled$q97.5[pi] <- m + 0.5 * (df_pooled$q97.5[pi] - m)
      }
    }
  }

  df_all <- bind_rows(df_pooled, df_restaurant)
  df_all <- add_pooled_pred_path(df_all)

  # "Total (A1)" reference row removed for publication clarity — mirror T1 A2.
  df_all <- df_all %>% filter(outcome != "Total (A1)")
  # Display order (top -> bottom): breakfast, ground, chicken, dairy, egg.
  all_outcomes <- c("Breakfast-style meat", "Ground meat", "Chicken", "Dairy", "Egg")
  df_all$outcome <- factor(df_all$outcome, levels = rev(all_outcomes))
  # NOTE: keep exposure_type as raw lowercase strings for the case_when below;
  # relabel to "Presence"/"Count" right before plotting (after transforms).

  # Right-side grey facet strip (like A1's exposure_group), one level per
  # outcome, in the same top -> bottom order as the outcome axis.
  .exposure_strip_labels <- c(
    "Breakfast-style meat" = "Exposure: Breakfast-Style Analog",
    "Ground meat"          = "Exposure: Ground Meat Analog",
    "Chicken"              = "Exposure: Chicken Analog",
    "Dairy"                = "Exposure: Dairy Analog",
    "Egg"                  = "Exposure: Egg Analog"
  )
  df_all$exposure_strip <- factor(.exposure_strip_labels[as.character(df_all$outcome)],
                                   levels = .exposure_strip_labels[all_outcomes])

  df_all <- df_all %>%
    mutate(color_group = "Animal")

  if (!log_scale) {
    df_all <- df_all %>%
      mutate(
        # A2 Presence is BINARY (0/1) — use exp(.x), not exp(0.1 * .x)
        across(any_of(c('q2.5','q97.5','q16','q84')), ~ case_when(
          exposure_type == "count" & estimate_type == "Pooled" ~ exp(.x),
          exposure_type == "count" & estimate_type == "Restaurant" ~ exp(.x),
          exposure_type == "presence" & estimate_type == "Pooled" ~ exp(.x),
          exposure_type == "presence" & estimate_type == "Restaurant" ~ exp(.x),
          TRUE ~ .x)),
        mean = case_when(
          exposure_type == "count" & estimate_type == "Pooled" ~ mean_exp,
          exposure_type == "count" & estimate_type == "Restaurant" ~ mean_exp,
          exposure_type == "presence" & estimate_type == "Pooled" ~ mean_exp,
          exposure_type == "presence" & estimate_type == "Restaurant" ~ mean_exp,
          TRUE ~ mean))
  } else {
    df_all <- df_all %>%
      mutate(
        across(c(mean, q2.5, q97.5), ~ case_when(
          estimate_type == "Restaurant" ~ log(.x),
          TRUE ~ .x)))
  }

  # Filter out pooled estimates when only 1 restaurant contributes
  n_restaurants <- df_all %>%
    filter(estimate_type == "Restaurant") %>%
    group_by(outcome, exposure_type) %>%
    summarise(n_rest = n_distinct(restaurant_id), .groups = "drop")
  df_all <- df_all %>%
    left_join(n_restaurants, by = c("outcome", "exposure_type")) %>%
    filter(!(estimate_type == "Pooled" & !is.na(n_rest) & n_rest <= 1)) %>%
    select(-n_rest)

  # Tier Two reports the count form only. Presence is a 0/1 indicator, and in the
  # smaller T2 restaurants it is close to collinear with the series, so the
  # restaurant-level estimates are not usefully estimable -- ground meat at one
  # restaurant comes out at +34,000% [+5,252%, +254,069%], and four more exceed
  # +2,000%. T1 keeps presence, where the same fits are well behaved.
  df_all <- df_all %>% filter(exposure_type == "count")

  # Relabel exposure_type now that all the lowercase-keyed transforms are done.
  df_all$exposure_type <- factor(df_all$exposure_type, levels = "count",
                                 labels = "Form: Count")

  .n_rest_max <- df_all %>%
    dplyr::filter(estimate_type == "Restaurant") %>%
    dplyr::count(outcome, exposure_type) %>%
    dplyr::pull(n) %>%
    { if (length(.)) max(.) else 0 }
  .cfg        <- get_plot_cfg("T2", "A2")
  .step       <- cfg_val(.cfg, "step_size",      0.50)
  .margin     <- cfg_val(.cfg, "margin_mult",    1.2)
  .floor      <- cfg_val(.cfg, "y_spread_floor", 1.0)
  # Proportional wide layout: the block gap is what separates outcomes AND
  # (at half width) pads each panel, so holding it at a fixed 1.5 y-units
  # while step_size varies makes the padding balloon on plots with a small
  # step. Tie it to step at T1's ratio (1.5 / 0.55) so gap, padding and row
  # spacing keep the same proportions on every plot; T1's own A2/A4 use
  # step 0.55, so their layout is unchanged.
  .outcome_gap <- if (PUB_WIDE) .step * (1.5 / 0.55) else pub_cfg("outcome_gap", 1.5)
  .cap_pooled <- cfg_val(.cfg, "cap_pooled",     0.15)
  .cap_rest   <- cfg_val(.cfg, "cap_rest",       0.075)

  # Per-outcome packed positioning.
  .n_per_out_df <- df_all %>%
    dplyr::filter(estimate_type == "Restaurant") %>%
    dplyr::count(outcome, exposure_type, name = "n_rest") %>%
    dplyr::group_by(outcome) %>%
    dplyr::summarize(n_rest_max = max(n_rest), .groups = "drop")
  .all_levels <- levels(df_all$outcome)
  .n_lookup <- setNames(rep(0L, length(.all_levels)), .all_levels)
  .n_lookup[as.character(.n_per_out_df$outcome)] <- .n_per_out_df$n_rest_max
  .y_pooled <- numeric(length(.all_levels))
  if (length(.all_levels) >= 2) for (.i in 2:length(.all_levels)) {
    .y_pooled[.i] <- .y_pooled[.i-1] + .step * .n_lookup[.i] + .outcome_gap
  }
  names(.y_pooled) <- .all_levels
  .y_spread <- .outcome_gap + .step * .n_rest_max
  .y_range_data <- .y_pooled[length(.all_levels)] + .step * .n_lookup[1]
  # Outcomes with NO pooled row (e.g. only 1 restaurant contributes) would
  # otherwise still reserve a full extra step of vertical space above their
  # topmost restaurant. See T1 A2 for the full rationale. Gated behind
  # PUB_WIDE so non-wide outputs are unaffected.
  .has_pooled <- .all_levels %in% unique(as.character(df_all$outcome[df_all$estimate_type == "Pooled"]))
  names(.has_pooled) <- .all_levels
  .y_top_eff <- .y_pooled
  .n_reserved <- .n_lookup
  # Relative row-panel heights for the facet_grid(exposure_strip ~ ...) row
  # strip, in exposure_strip's top -> bottom level order (matches
  # all_outcomes). See T1 A2 for the rationale.
  .row_height_floor <- 2
  .row_heights <- .step * pmax(.n_reserved[all_outcomes], .row_height_floor) + .outcome_gap
  # Invisible sentinel points spanning each outcome's full intended block, so
  # scales = "free_y" panels never collapse to a degenerate range. See T1 A2.
  .df_blank <- tidyr::crossing(.outcome_lbl = all_outcomes,
                                exposure_type = levels(df_all$exposure_type)) %>%
    dplyr::mutate(y_top = if (PUB_WIDE) .y_pooled[.outcome_lbl] + .outcome_gap / 2
                          else .y_top_eff[.outcome_lbl],
                   y_bot = if (PUB_WIDE)
                             .y_pooled[.outcome_lbl] - .step * pmax(.n_lookup[.outcome_lbl], 1) - .outcome_gap / 2
                           else pmin(.y_pooled[.outcome_lbl] - .step * .n_lookup[.outcome_lbl],
                                 .y_top_eff[.outcome_lbl] - 2 * .step)) %>%
    tidyr::pivot_longer(c(y_top, y_bot), values_to = "y_numeric") %>%
    dplyr::mutate(outcome = factor(.outcome_lbl, levels = levels(df_all$outcome)),
                   exposure_type = factor(exposure_type, levels = levels(df_all$exposure_type)),
                   exposure_strip = factor(.exposure_strip_labels[.outcome_lbl],
                                           levels = levels(df_all$exposure_strip)))

  .n_out_html <- length(unique(df_all$outcome))
  .png_w      <- cfg_val(.cfg, "png_w", 10)
  .png_h      <- cfg_val(.cfg, "png_h", min(49, max(3, .y_range_data * (1 + cfg_val(.cfg, "expand_below", 0.05) + cfg_val(.cfg, "expand_above", 0.05)) / pub_cfg("y_per_inch", 4) + 1.5)))

  df_all <- df_all %>%
    group_by(outcome, exposure_type) %>%
    mutate(
      n_in_group = n(),
      .rank_key  = if (SORT_BY_MEAN)
                     if_else(estimate_type == "Restaurant", -mean, NA_real_)
                   else if (LABELED_MODE)
                     if_else(estimate_type == "Restaurant",
                             as.numeric(labeled_rank_fn(restaurant_id)), NA_real_)
                   else
                     if_else(estimate_type == "Restaurant",
                             as.numeric(factor(restaurant_id,
                                               levels = sort(unique(restaurant_id)))),
                             NA_real_),
      row_in_group = if_else(estimate_type == "Restaurant",
        as.integer(rank(.rank_key, ties.method = "first", na.last = "keep")),
        0L),
      y_numeric = .y_pooled[as.character(outcome)] +
        case_when(
          estimate_type == "Pooled" ~ 0,
          TRUE ~ -.step * row_in_group
        )
    ) %>%
    select(-.rank_key) %>%
    ungroup()

  xlim <- if (log_scale) calc_xlim_median(df_all, x_max_input = 10) else c(0, 3)
  df_all <- clip_to_limits(df_all, xlim)
  df_all$color_group_inner     <- paste0(df_all$color_group, "_inner")
  df_all$color_group_innerdark <- paste0(df_all$color_group, "_innerdark")
  df_all$color_group_restwash  <- paste0(df_all$color_group, "_restwash")
  df_all <- add_inner_ci(df_all, xlim, log_scale = log_scale)

  df_pooled <- df_all %>% filter(estimate_type == "Pooled")
  df_restaurant <- df_all %>% filter(estimate_type == "Restaurant")
  df_restaurant$rest_color      <- if (LABELED_MODE) df_restaurant$restaurant_id else df_restaurant$color_group
  df_restaurant$rest_color_wash <- if (LABELED_MODE) df_restaurant$restaurant_id else df_restaurant$color_group_restwash

  .build_p <- function(pub) {
    ggplot() +
      geom_blank(data = .df_blank, aes(y = y_numeric)) +
      geom_vline(xintercept = if (log_scale) 0 else 1,
                 linetype = "dashed", color = pub_cfg("vline_color", "grey55"), linewidth = pub_cfg("vline_linewidth", 0.4)) +
      {if (pub && nrow(df_restaurant) > 0)
        geom_errorbarh(data = df_restaurant,
                       aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = rest_color_wash),
                       height = 0, alpha = pub_cfg("rest_bar_alpha_outer", 0.55), linewidth = plot_or_pub(.cfg, "rest_bar_linewidth", 0.35))} +
      {if (pub && nrow(df_restaurant) > 0 && any(df_restaurant$left_ok, na.rm = TRUE))
        geom_segment(data = df_restaurant %>% filter(left_ok),
                     aes(x = q2.5_disp, xend = q2.5_disp,
                         y = y_numeric - (.cap_rest / 2), yend = y_numeric + (.cap_rest / 2),
                         color = rest_color_wash),
                     alpha = pub_cfg("rest_bar_alpha_outer", 0.55), linewidth = plot_or_pub(.cfg, "rest_cap_linewidth", pub_cfg("rest_cap_linewidth", 0.2)))} +
      {if (pub && nrow(df_restaurant) > 0 && any(df_restaurant$right_ok, na.rm = TRUE))
        geom_segment(data = df_restaurant %>% filter(right_ok),
                     aes(x = q97.5_disp, xend = q97.5_disp,
                         y = y_numeric - (.cap_rest / 2), yend = y_numeric + (.cap_rest / 2),
                         color = rest_color_wash),
                     alpha = pub_cfg("rest_bar_alpha_outer", 0.55), linewidth = plot_or_pub(.cfg, "rest_cap_linewidth", pub_cfg("rest_cap_linewidth", 0.2)))} +
      {if (pub && nrow(df_restaurant) > 0)
        geom_errorbarh(data = df_restaurant,
                       aes(xmin = q1_lo_disp, xmax = q1_hi_disp, y = y_numeric, color = rest_color),
                       height = 0, alpha = pub_cfg("rest_bar_alpha_outer", 0.55), linewidth = plot_or_pub(.cfg, "rest_bar_linewidth", 0.35))} +
      {if (!pub && nrow(df_restaurant) > 0)
        geom_errorbarh(data = df_restaurant,
                       aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                       height = 0.075, alpha = 0.4, linewidth = 0.3)} +
      {if (nrow(df_restaurant) > 0)
        geom_point(data = df_restaurant,
                   aes(x = mean_disp, y = y_numeric, color = rest_color,
                       shape = clipped, size = clipped,
                       customdata = pred_path,
                       text = paste0(
                         "Restaurant: ", restaurant_id, "<br>",
                         "Outcome: ", outcome, "<br>",
                         "Exposure: ", exposure_type, "<br>",
                         "Adjusted Rate Ratio: ", signif(mean_orig, 3), "<br>",
                         "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                         "<br>Source: ", source,
                         ifelse(clipped, "<br>(Value clipped to fit scale)", ""))),
                   alpha = pub_cfg("rest_point_alpha", 0.6), stroke = pub_cfg("rest_point_stroke", 0))} +
      scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 17), guide = "none") +
      scale_size_manual(values = c("FALSE" = pub_cfg("rest_point_size", 1.4),
                                   "TRUE"  = pub_cfg("rest_point_size", 1.4) * 1.6), guide = "none") +
      {if (pub)
        geom_errorbarh(data = df_pooled,
                       aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group_innerdark),
                       height = 0, linewidth = plot_or_pub(.cfg, "pooled_bar_linewidth", 1.4), alpha = pub_cfg("pooled_bar_alpha_outer", 1.0))} +
      {if (pub && any(df_pooled$left_ok, na.rm = TRUE))
        geom_segment(data = df_pooled %>% filter(left_ok),
                     aes(x = q2.5_disp, xend = q2.5_disp,
                         y = y_numeric - (.cap_pooled / 2), yend = y_numeric + (.cap_pooled / 2),
                         color = color_group_innerdark),
                     linewidth = plot_or_pub(.cfg, "pooled_cap_linewidth", pub_cfg("pooled_cap_linewidth", 0.4)), alpha = pub_cfg("pooled_bar_alpha_outer", 1.0))} +
      {if (pub && any(df_pooled$right_ok, na.rm = TRUE))
        geom_segment(data = df_pooled %>% filter(right_ok),
                     aes(x = q97.5_disp, xend = q97.5_disp,
                         y = y_numeric - (.cap_pooled / 2), yend = y_numeric + (.cap_pooled / 2),
                         color = color_group_innerdark),
                     linewidth = plot_or_pub(.cfg, "pooled_cap_linewidth", pub_cfg("pooled_cap_linewidth", 0.4)), alpha = pub_cfg("pooled_bar_alpha_outer", 1.0))} +
      {if (pub)
        geom_errorbarh(data = df_pooled,
                       aes(xmin = q1_lo_disp, xmax = q1_hi_disp, y = y_numeric, color = color_group),
                       height = 0, linewidth = plot_or_pub(.cfg, "pooled_bar_linewidth", 1.4), alpha = pub_cfg("pooled_bar_alpha_outer", 1.0))} +
      {if (!pub)
        geom_errorbarh(data = df_pooled,
                       aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                       height = 0.15, linewidth = 0.8)} +
      geom_point(data = df_pooled,
                 aes(x = mean_disp, y = y_numeric, color = color_group, customdata = pred_path, text = paste0(
                   "POOLED<br>",
                   "Outcome: ", outcome, "<br>",
                   "Exposure: ", exposure_type, "<br>",
                   "Adjusted Rate Ratio: ", signif(mean_orig, 3), "<br>",
                   "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                   "<br>Source: ", source,
                   ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), ""))),
                 size = pub_cfg("pooled_point_size", 3.1), stroke = pub_cfg("pooled_point_stroke", 0)) +
      {if (pub)
        geom_text(data = df_pooled,
                  aes(x = mean_disp - pub_pooled_label_shift(mean_disp, mean_orig, q2.5_orig, q97.5_orig, xlim),
                      y = y_numeric + cfg_val(.cfg, "pooled_label_dy", 0.40),
                      label = if (PUB_RECENTER) sprintf("%.0f%%", (mean_orig - 1) * 100)
                              else sprintf("%.2f", mean_orig)),
                  size = 2.4, hjust = 0.5, vjust = 0,
                  fontface = "bold",
                  color = "gray25",
                  family = pub_cfg("font_family", "sans"))} +
      {if (pub)
        geom_text(data = df_pooled,
                  aes(x = mean_disp - pub_pooled_label_shift(mean_disp, mean_orig, q2.5_orig, q97.5_orig, xlim) + (xlim[2] - xlim[1]) *
                          (0.020 + (if (PUB_RECENTER)
                             0.007 * pmax(nchar(sprintf("%.0f%%", (mean_orig - 1) * 100)) - 2, 0)
                           else 0)),
                      y = y_numeric + cfg_val(.cfg, "pooled_label_dy", 0.40),
                      label = if (PUB_RECENTER)
                                sprintf(" [%.0f%%, %.0f%%]", (q2.5_orig - 1) * 100, (q97.5_orig - 1) * 100)
                              else sprintf(" [%.2f, %.2f]", q2.5_orig, q97.5_orig)),
                  size = 2.4, hjust = 0, vjust = 0,
                  color = "gray25",
                  family = pub_cfg("font_family", "sans"))} +
      {if (pub && !LABELED_MODE && PUB_WIDE && nrow(df_pooled) > 0)
        # This analysis has no Plant-based layer, so its legend key would get
        # no glyph. Invisible phantom layers carry both plain color values;
        # the guide's override.aes restyles the keys to match A1.
        list(
          geom_errorbarh(data = df_pooled[c(1, 1), ] %>%
                           mutate(.lg = c("Animal", "Plant-based")),
                         aes(xmin = mean_disp, xmax = mean_disp, y = y_numeric, color = .lg),
                         height = 0, linewidth = 0, alpha = 0, show.legend = TRUE),
          geom_point(data = df_pooled[c(1, 1), ] %>%
                       mutate(.lg = c("Animal", "Plant-based")),
                     aes(x = mean_disp, y = y_numeric, color = .lg),
                     alpha = 0, size = 0.001, show.legend = TRUE)
        )
      else list()} +
      (if (LABELED_MODE)
        scale_color_manual(
          values = LABELED_COLORS_ALL,
          breaks = LABELED_REST_IDS,
          labels = LABELED_REST_LABELS,
          drop = FALSE,
          na.value = "gray65",
          guide = guide_legend(title = "Restaurant", ncol = 4,
                              override.aes = list(shape = 16, alpha = 1, size = 2.5)))
      else if (PUB_WIDE)
        scale_color_manual(values = PUB_COLORS_ALL,
          breaks = c("Animal", "Plant-based"),
          labels = c("Animal-based", "Plant-based"),
          limits = function(x) union(x, c("Animal", "Plant-based")),
          guide = guide_legend(title = NULL, override.aes = list(linewidth = 2.5, alpha = 1, size = 3)))
      else
        scale_color_manual(values = PUB_COLORS_ALL, guide = "none")) +
      facet_grid(exposure_strip ~ exposure_type, scales = "free_y", space = "free_y") +
      {if (PUB_WIDE) list() else ggh4x::force_panelsizes(rows = .row_heights)} +
      scale_x_continuous(limits = c(xlim[1] - .pub_overshoot * diff(range(xlim)),
                                      xlim[2] + .pub_overshoot * diff(range(xlim))),
                         expand = c(0, 0),
                         breaks = seq(0, 3, 0.25),
                         labels = if (PUB_RECENTER && PUB_WIDE) pub_x_labels_pct_plain
                                  else if (PUB_RECENTER) pub_x_labels_pct else pub_x_labels_mixed,
                         oob = scales::squish) +
      scale_y_continuous(
        breaks = .y_top_eff,
        labels = rev(all_outcomes),
        expand = expansion(mult = c(cfg_val(.cfg, "expand_below", 0.2), cfg_val(.cfg, "expand_above", 0.1)))) +
      labs(
        title = "A2: Overall availability of alternative proteins and counterpart-specific meat sales",
        subtitle = NULL,
        x = if (log_scale) "Log multiplicative effect relative to total sales"
            else if (PUB_RECENTER) "Percentage change relative to total sales"
            else           "Multiplicative effect relative to total sales",
        y = "Outcome") +
      coord_cartesian(clip = "off") +
      {if (pub && LABELED_MODE && nrow(df_restaurant) > 0) {
        # T2 A2: labels go ABOVE each point estimate, for ALL outcomes. When
        # the mean is at/past the panel edge, nudge x toward 1 (no-effect
        # reference) so the text stays on the page.
        .one_facet <- levels(df_all$exposure_type)[nlevels(df_all$exposure_type)]
        .df_lbl <- df_restaurant %>%
          filter(as.character(exposure_type) == .one_facet) %>%
          mutate(.lbl = LABELED_REST_LABELS[match(restaurant_id, LABELED_REST_IDS)],
                 .lbl = ifelse(is.na(.lbl), restaurant_id, .lbl),
                 .edge_buf = 0.18 * diff(range(xlim)),
                 .x_lbl = case_when(
                   mean_disp > xlim[2] - .edge_buf ~ pmax(xlim[2] - .edge_buf, 1),
                   mean_disp < xlim[1] + .edge_buf ~ pmin(xlim[1] + .edge_buf, 1),
                   TRUE                            ~ mean_disp))
        if (nrow(.df_lbl) > 0)
          geom_text(data = .df_lbl,
                    aes(x = .x_lbl, y = y_numeric + 0.15,
                        label = .lbl, color = rest_color),
                    hjust = 0.5, vjust = 0,
                    size = 2.2, fontface = "bold",
                    family = pub_cfg("font_family", "sans"),
                    inherit.aes = FALSE)
        else list()
      } else list()} +
      {if (pub && LABELED_MODE && LABELED_V2 && nrow(df_restaurant) > 0) {
        # T2 A2 numbers: RIGHT of upper CI (names sit ABOVE the point at
        # y+0.15, so a different y keeps them apart). Fallback to LEFT of
        # the lower CI when there's no room on the right.
        .df_num <- df_restaurant %>%
          mutate(.num = rest_num_label(mean_orig, q2.5_orig, q97.5_orig),
                 # Width-aware (see T2 A3): a fixed fraction let long labels
                 # clear the test and then overflow the panel edge.
                 .has_right_room = q97.5_disp + 0.02 * diff(range(xlim)) +
                                     nchar(.num) * .PUB_CHAR_W * diff(range(xlim)) <=
                                   xlim[2] - 0.010 * diff(range(xlim)),
                 .has_left_room  = q2.5_disp - 0.02 * diff(range(xlim)) -
                                     nchar(.num) * .PUB_CHAR_W * diff(range(xlim)) >=
                                   xlim[1] + 0.010 * diff(range(xlim)),
                 .x_num  = case_when(.has_right_room ~ q97.5_disp + 0.02 * diff(range(xlim)),
                                     .has_left_room  ~ q2.5_disp  - 0.02 * diff(range(xlim)),
                                     TRUE            ~ mean_disp),
                 .y_num  = ifelse(.has_right_room | .has_left_room, y_numeric, y_numeric - 0.15),
                 .hj_num = case_when(.has_right_room ~ 0, .has_left_room ~ 1, TRUE ~ 0.5),
                 .vj_num = ifelse(.has_right_room | .has_left_room, 0.5, 1))
        geom_text(data = .df_num,
                  aes(x = .x_num, y = .y_num, label = .num, hjust = .hj_num, vjust = .vj_num),
                  size = 1.8, color = "gray40",
                  family = pub_cfg("font_family", "sans"),
                  inherit.aes = FALSE)
      } else list()} +
      (if (pub) publication_forest_theme(base_size = 12)
       else theme_minimal(base_size = 11) +
              theme(
                plot.background   = element_rect(fill = "white", color = NA),
                panel.background  = element_rect(fill = "white", color = NA),
                panel.grid.minor  = element_blank(),
                strip.background  = element_rect(fill = "gray90", color = NA),
                strip.text        = element_text(face = "bold"),
                plot.title        = element_text(face = "bold", size = 14),
                plot.subtitle     = element_text(size = 9, color = "gray40"),
                axis.text.y       = element_text(size = 10),
                legend.position   = "bottom",
                panel.spacing     = unit(0.5, "lines"))) +
      {if (pub && PUB_RECENTER && PUB_WIDE) pub_x_axis_wide_theme(xlim) else list()} +
      # Row strips are short per-outcome panels here (facet_grid + free_y).
      # Non-wide: too short for rotated (angle=-90) strip text to fit without
      # overlapping neighboring rows — keep it horizontal. Wide: panels are
      # tall enough for the standard vertical strip text.
      theme(strip.text.y = if (PUB_WIDE) element_text(angle = -90, size = rel(0.72), lineheight = 0.9)
                            else element_text(angle = 0, size = rel(0.62), lineheight = 0.85))
  }

  p_png  <- .build_p(TRUE)
  if (!.PRO_FAST)   p_html <- .build_p(FALSE)

  if (!.PRO_FAST)   pub_ggsave_png(file.path(output_dir, "A2_proportion_targeted_forest_restaurants.png"), p_png,
                 width = .png_w, height = .png_h)
  pub_ggsave_pdf(file.path(output_dir, "A2_proportion_targeted_forest_restaurants.pdf"), p_png,
                 width = .png_w, height = .png_h)

  .html_px    <- round(pmin(3600, pmax(700, .n_out_html * .n_rest_max * 1.2 * 40 + 180)))
  if (!.PRO_FAST)   p_plotly <- ggplotly(p_html, tooltip = "text", height = .html_px)
  if (!.PRO_FAST)   p_plotly <- add_click_handler(p_plotly)
  html_name <- if (log_scale) "A2_proportion_targeted_forest_restaurants_log.html" else "A2_proportion_targeted_forest_restaurants.html"
  if (!.PRO_FAST)   try(saveWidget(p_plotly, file.path(output_dir, html_name), selfcontained = FALSE), silent = TRUE)

  df_save <- df_all %>% select(-matches("_disp|_orig|clipped|y_numeric|n_in_group|row_in_group"))
  csv_name <- if (log_scale) "A2_proportion_targeted_restaurants_data_log.csv" else "A2_proportion_targeted_restaurants_data.csv"
  write_csv(df_save, file.path(output_dir, csv_name))

  cat("  Saved: A2_proportion_targeted_forest_restaurants.png, .pdf, .html, _data.csv\n")
  return(p_png)
}

# ─────────────────────────────────────
# 3. ITS Analysis (A3) - ADJUSTED
# ─────────────────────────────────────

create_its_forest_restaurants <- function(log_scale = FALSE) {
  output_dir <- if (log_scale) file.path(LOG_OUTPUT_DIR_BASE) else file.path(OUTPUT_DIR_BASE)
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  cat("Creating ADJUSTED ITS forest plot with restaurant estimates...\n")
  cat("  Using A3 overrides:", paste(names(A3_OVERRIDES), "->", A3_OVERRIDES, collapse = ", "), "\n")

  outcomes <- c("total", "nonvegan", "meat", "chicken_fish", "vegetarian", "vegan")

  pooled_list <- list()
  restaurant_list <- list()

  # Total model path for A3
  total_model_path_name <- get_model_path("total", A3_OVERRIDES)
  total_run_path <- file.path("model_fits", total_model_path_name)
  total_path <- file.path(total_run_path, "t2_a3_its", "total")

  for (outcome in outcomes) {
    model_path_name <- get_model_path(outcome, A3_OVERRIDES)
    model_run_path <- file.path("model_fits", model_path_name)
    outcome_path <- file.path(model_run_path, "t2_a3_its", outcome)

    if (outcome == "total") {
      # Adjusted RR for total = 1.0 exactly (diff = 0)
      for (eff in c("Level Change", "Slope Change")) {
        pooled_list[[length(pooled_list) + 1]] <- tibble(
          outcome = outcome,
          effect_type = eff,
          mean = 0,
          q2.5 = 0,
          q97.5 = 0,
          mean_exp = 1,
          rhat = NA_real_,
          ess_bulk = NA_real_,
          estimate_type = "Pooled",
          restaurant_id = "POOLED")
      }
      next
    }

    # Adjusted gamma[1] (level change)
    gamma1 <- compute_adjusted_mu_gamma(outcome_path, total_path, 1)
    if (!is.null(gamma1)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome,
        effect_type = "Level Change",
        mean = gamma1$mean,
        q2.5 = gamma1$q2.5,
        q16 = if (!is.null(gamma1$q16)) gamma1$q16 else NA_real_,
        q84 = if (!is.null(gamma1$q84)) gamma1$q84 else NA_real_,
        q97.5 = gamma1$q97.5,
        mean_exp = gamma1$mean_exp,
        rhat = gamma1$rhat,
        ess_bulk = gamma1$ess_bulk,
        estimate_type = "Pooled",
        restaurant_id = "POOLED")
    }

    # Adjusted gamma[2] (slope change)
    gamma2 <- compute_adjusted_mu_gamma(outcome_path, total_path, 2)
    if (!is.null(gamma2)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome,
        effect_type = "Slope Change",
        mean = gamma2$mean,
        q2.5 = gamma2$q2.5,
        q16 = if (!is.null(gamma2$q16)) gamma2$q16 else NA_real_,
        q84 = if (!is.null(gamma2$q84)) gamma2$q84 else NA_real_,
        q97.5 = gamma2$q97.5,
        mean_exp = gamma2$mean_exp,
        rhat = gamma2$rhat,
        ess_bulk = gamma2$ess_bulk,
        estimate_type = "Pooled",
        restaurant_id = "POOLED")
    }

    # Adjusted restaurant-level estimates (handles both level/slope)
    rest_gammas <- compute_adjusted_restaurant_gammas(outcome_path, total_path, is_its = TRUE)
    if (!is.null(rest_gammas) && nrow(rest_gammas) > 0) {
      for (i in 1:nrow(rest_gammas)) {
        restaurant_list[[length(restaurant_list) + 1]] <- tibble(
          outcome = outcome,
          effect_type = rest_gammas$effect_type[i],
          mean = rest_gammas$mean[i],
          q2.5 = rest_gammas$q2.5[i],
          q16 = if (!is.null(rest_gammas$q16)) rest_gammas$q16[i] else NA_real_,
          q84 = if (!is.null(rest_gammas$q84)) rest_gammas$q84[i] else NA_real_,
          q97.5 = rest_gammas$q97.5[i],
          # Must be carried through: this tibble enumerates columns explicitly,
          # so omitting mean_exp leaves it NA and the exp() step below silently
          # falls back to exp(mean) -- the geometric mean -- while the pooled
          # marker uses exp(median). Same figure, two different estimands.
          mean_exp = if (!is.null(rest_gammas$mean_exp)) rest_gammas$mean_exp[i] else NA_real_,
          rhat = rest_gammas$rhat[i],
          ess_bulk = NA_real_,
          estimate_type = "Restaurant",
          restaurant_id = rest_gammas$restaurant_id[i],
          pred_path = pred_path_rel(model_path_name, "t2_a3_its", outcome, NULL, rest_gammas$restaurant_id[i]))
      }
    }
  }

  df_pooled <- bind_rows(pooled_list)
  df_restaurant <- bind_rows(restaurant_list)

  if (nrow(df_pooled) == 0) {
    cat("  No data found for ITS analysis\n")
    return(NULL)
  }

  df_all <- bind_rows(df_pooled, df_restaurant)
  df_all <- add_pooled_pred_path(df_all)

  df_all$outcome <- factor(df_all$outcome, levels = rev(outcomes))
  df_all$effect_type <- factor(df_all$effect_type, levels = c("Level Change", "Slope Change"))

  df_all <- df_all %>%
    mutate(color_group = case_when(
      outcome == "total" ~ "Total",
      outcome %in% c("nonvegan", "meat", "chicken_fish") ~ "Animal",
      outcome %in% c("vegetarian", "vegan") ~ "Plant-based"))

  if (!log_scale) {
    df_all <- df_all %>%
      mutate(across(any_of(c('q2.5','q97.5','q16','q84')), ~ exp(.x)),
             mean = ifelse(!is.na(mean_exp), mean_exp, exp(mean)))
  }

  # Filter out pooled estimates when only 1 restaurant contributes
  n_restaurants <- df_all %>%
    filter(estimate_type == "Restaurant") %>%
    group_by(outcome, effect_type) %>%
    summarise(n_rest = n_distinct(restaurant_id), .groups = "drop")
  df_all <- df_all %>%
    left_join(n_restaurants, by = c("outcome", "effect_type")) %>%
    filter(!(estimate_type == "Pooled" & !is.na(n_rest) & n_rest <= 1)) %>%
    select(-n_rest)

  # "total" dropped for publication clarity — mirror T1 A3.
  outcomes_plot <- c("nonvegan", "meat", "chicken_fish", "vegetarian", "vegan")
  outcome_labels_a3 <- c("Nonvegan", "Meat", "Chicken & fish", "Vegetarian", "Vegan")
  df_all <- df_all %>% filter(outcome != "total")
  df_all$outcome <- factor(df_all$outcome, levels = rev(outcomes_plot),
                            labels = rev(outcome_labels_a3))
  df_all$effect_type <- factor(df_all$effect_type, levels = c("Level Change", "Slope Change"),
                                labels = c("Level change", "Slope change"))

  # Right-side grey facet strip (like A1's exposure_group). A3 has a single
  # shared panel of outcomes, so this is one constant-value level producing
  # one full-height strip.
  df_all$exposure_strip <- factor("Exposure: Introductions")

  df_all <- df_all %>%
    mutate(color_group = case_when(
      outcome %in% c("Nonvegan", "Meat", "Chicken & fish") ~ "Animal",
      outcome %in% c("Vegetarian", "Vegan") ~ "Plant-based"))

  .n_rest_max <- df_all %>%
    dplyr::filter(estimate_type == "Restaurant") %>%
    dplyr::count(outcome, effect_type) %>%
    dplyr::pull(n) %>%
    { if (length(.)) max(.) else 0 }
  .cfg        <- get_plot_cfg("T2", "A3")
  .step       <- cfg_val(.cfg, "step_size",      0.50)
  .margin     <- cfg_val(.cfg, "margin_mult",    1.2)
  .floor      <- cfg_val(.cfg, "y_spread_floor", 1.0)
  .outcome_gap <- pub_cfg("outcome_gap", 1.5)
  .cap_pooled <- cfg_val(.cfg, "cap_pooled",     0.15)
  .cap_rest   <- cfg_val(.cfg, "cap_rest",       0.075)

  # Per-outcome packed positioning.
  .n_per_out_df <- df_all %>%
    dplyr::filter(estimate_type == "Restaurant") %>%
    dplyr::count(outcome, effect_type, name = "n_rest") %>%
    dplyr::group_by(outcome) %>%
    dplyr::summarize(n_rest_max = max(n_rest), .groups = "drop")
  .all_levels <- levels(df_all$outcome)
  .n_lookup <- setNames(rep(0L, length(.all_levels)), .all_levels)
  .n_lookup[as.character(.n_per_out_df$outcome)] <- .n_per_out_df$n_rest_max
  .y_pooled <- numeric(length(.all_levels))
  if (length(.all_levels) >= 2) for (.i in 2:length(.all_levels)) {
    .y_pooled[.i] <- .y_pooled[.i-1] + .step * .n_lookup[.i] + .outcome_gap
  }
  names(.y_pooled) <- .all_levels
  .y_spread <- .outcome_gap + .step * .n_rest_max
  .y_range_data <- .y_pooled[length(.all_levels)] + .step * .n_lookup[1]

  .n_out_html <- length(unique(df_all$outcome))
  .png_w      <- cfg_val(.cfg, "png_w", 10)
  .png_h      <- cfg_val(.cfg, "png_h", min(49, max(3, .y_range_data * (1 + cfg_val(.cfg, "expand_below", 0.05) + cfg_val(.cfg, "expand_above", 0.05)) / pub_cfg("y_per_inch", 4) + 1.5)))

  df_all <- df_all %>%
    group_by(outcome, effect_type) %>%
    mutate(
      n_in_group = n(),
      .rank_key  = if (SORT_BY_MEAN)
                     if_else(estimate_type == "Restaurant", -mean, NA_real_)
                   else if (LABELED_MODE)
                     if_else(estimate_type == "Restaurant",
                             as.numeric(labeled_rank_fn(restaurant_id)), NA_real_)
                   else
                     if_else(estimate_type == "Restaurant",
                             as.numeric(factor(restaurant_id,
                                               levels = sort(unique(restaurant_id)))),
                             NA_real_),
      row_in_group = if_else(estimate_type == "Restaurant",
        as.integer(rank(.rank_key, ties.method = "first", na.last = "keep")),
        0L),
      y_numeric = .y_pooled[as.character(outcome)] +
        case_when(
          estimate_type == "Pooled" ~ 0,
          TRUE ~ -.step * row_in_group
        )
    ) %>%
    select(-.rank_key) %>%
    ungroup()

  xlim <- if (log_scale) calc_xlim_median(df_all, x_max_input = 10) else c(0, 3)
  df_all <- clip_to_limits(df_all, xlim)
  df_all$color_group_inner     <- paste0(df_all$color_group, "_inner")
  df_all$color_group_innerdark <- paste0(df_all$color_group, "_innerdark")
  df_all$color_group_restwash  <- paste0(df_all$color_group, "_restwash")
  df_all <- add_inner_ci(df_all, xlim, log_scale = log_scale)

  df_pooled <- df_all %>% filter(estimate_type == "Pooled")
  df_restaurant <- df_all %>% filter(estimate_type == "Restaurant")
  df_restaurant$rest_color      <- if (LABELED_MODE) df_restaurant$restaurant_id else df_restaurant$color_group
  df_restaurant$rest_color_wash <- if (LABELED_MODE) df_restaurant$restaurant_id else df_restaurant$color_group_restwash

  .build_p <- function(pub) {
    ggplot() +
      geom_vline(xintercept = if (log_scale) 0 else 1,
                 linetype = "dashed", color = pub_cfg("vline_color", "grey55"), linewidth = pub_cfg("vline_linewidth", 0.4)) +
      {if (pub && nrow(df_restaurant) > 0)
        geom_errorbarh(data = df_restaurant,
                       aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = rest_color_wash),
                       height = 0, alpha = pub_cfg("rest_bar_alpha_outer", 0.55), linewidth = plot_or_pub(.cfg, "rest_bar_linewidth", 0.35))} +
      {if (pub && nrow(df_restaurant) > 0 && any(df_restaurant$left_ok, na.rm = TRUE))
        geom_segment(data = df_restaurant %>% filter(left_ok),
                     aes(x = q2.5_disp, xend = q2.5_disp,
                         y = y_numeric - (.cap_rest / 2), yend = y_numeric + (.cap_rest / 2),
                         color = rest_color_wash),
                     alpha = pub_cfg("rest_bar_alpha_outer", 0.55), linewidth = plot_or_pub(.cfg, "rest_cap_linewidth", pub_cfg("rest_cap_linewidth", 0.2)))} +
      {if (pub && nrow(df_restaurant) > 0 && any(df_restaurant$right_ok, na.rm = TRUE))
        geom_segment(data = df_restaurant %>% filter(right_ok),
                     aes(x = q97.5_disp, xend = q97.5_disp,
                         y = y_numeric - (.cap_rest / 2), yend = y_numeric + (.cap_rest / 2),
                         color = rest_color_wash),
                     alpha = pub_cfg("rest_bar_alpha_outer", 0.55), linewidth = plot_or_pub(.cfg, "rest_cap_linewidth", pub_cfg("rest_cap_linewidth", 0.2)))} +
      {if (pub && nrow(df_restaurant) > 0)
        geom_errorbarh(data = df_restaurant,
                       aes(xmin = q1_lo_disp, xmax = q1_hi_disp, y = y_numeric, color = rest_color),
                       height = 0, alpha = pub_cfg("rest_bar_alpha_outer", 0.55), linewidth = plot_or_pub(.cfg, "rest_bar_linewidth", 0.35))} +
      {if (!pub && nrow(df_restaurant) > 0)
        geom_errorbarh(data = df_restaurant,
                       aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                       height = 0.075, alpha = 0.4, linewidth = 0.3)} +
      {if (nrow(df_restaurant) > 0)
        geom_point(data = df_restaurant,
                   aes(x = mean_disp, y = y_numeric, color = rest_color,
                       shape = clipped, size = clipped,
                       customdata = pred_path,
                       text = paste0(
                         "Restaurant: ", restaurant_id, "<br>",
                         "Outcome: ", outcome, "<br>",
                         "Effect: ", effect_type, "<br>",
                         "Adjusted Rate Ratio: ", signif(mean_orig, 3), "<br>",
                         "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                         ifelse(clipped, "<br>(Value clipped to fit scale)", ""))),
                   alpha = pub_cfg("rest_point_alpha", 0.6), stroke = pub_cfg("rest_point_stroke", 0))} +
      scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 17), guide = "none") +
      scale_size_manual(values = c("FALSE" = pub_cfg("rest_point_size", 1.4),
                                   "TRUE"  = pub_cfg("rest_point_size", 1.4) * 1.6), guide = "none") +
      {if (pub)
        geom_errorbarh(data = df_pooled,
                       aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group_innerdark),
                       height = 0, linewidth = plot_or_pub(.cfg, "pooled_bar_linewidth", 1.4), alpha = pub_cfg("pooled_bar_alpha_outer", 1.0))} +
      {if (pub && any(df_pooled$left_ok, na.rm = TRUE))
        geom_segment(data = df_pooled %>% filter(left_ok),
                     aes(x = q2.5_disp, xend = q2.5_disp,
                         y = y_numeric - (.cap_pooled / 2), yend = y_numeric + (.cap_pooled / 2),
                         color = color_group_innerdark),
                     linewidth = plot_or_pub(.cfg, "pooled_cap_linewidth", pub_cfg("pooled_cap_linewidth", 0.4)), alpha = pub_cfg("pooled_bar_alpha_outer", 1.0))} +
      {if (pub && any(df_pooled$right_ok, na.rm = TRUE))
        geom_segment(data = df_pooled %>% filter(right_ok),
                     aes(x = q97.5_disp, xend = q97.5_disp,
                         y = y_numeric - (.cap_pooled / 2), yend = y_numeric + (.cap_pooled / 2),
                         color = color_group_innerdark),
                     linewidth = plot_or_pub(.cfg, "pooled_cap_linewidth", pub_cfg("pooled_cap_linewidth", 0.4)), alpha = pub_cfg("pooled_bar_alpha_outer", 1.0))} +
      {if (pub)
        geom_errorbarh(data = df_pooled,
                       aes(xmin = q1_lo_disp, xmax = q1_hi_disp, y = y_numeric, color = color_group),
                       height = 0, linewidth = plot_or_pub(.cfg, "pooled_bar_linewidth", 1.4), alpha = pub_cfg("pooled_bar_alpha_outer", 1.0))} +
      {if (!pub)
        geom_errorbarh(data = df_pooled,
                       aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                       height = 0.15, linewidth = 0.8)} +
      geom_point(data = df_pooled,
                 aes(x = mean_disp, y = y_numeric, color = color_group, customdata = pred_path, text = paste0(
                   "POOLED<br>",
                   "Outcome: ", outcome, "<br>",
                   "Effect: ", effect_type, "<br>",
                   "Adjusted Rate Ratio: ", signif(mean_orig, 3), "<br>",
                   "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                   ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), ""))),
                 size = pub_cfg("pooled_point_size", 3.1), stroke = pub_cfg("pooled_point_stroke", 0)) +
      {if (pub)
        geom_text(data = df_pooled,
                  aes(x = mean_disp - pub_pooled_label_shift(mean_disp, mean_orig, q2.5_orig, q97.5_orig, xlim),
                      y = y_numeric + cfg_val(.cfg, "pooled_label_dy", 0.40),
                      label = if (PUB_RECENTER) sprintf("%.0f%%", (mean_orig - 1) * 100)
                              else sprintf("%.2f", mean_orig)),
                  size = 2.4, hjust = 0.5, vjust = 0,
                  fontface = "bold",
                  color = "gray25",
                  family = pub_cfg("font_family", "sans"))} +
      {if (pub)
        geom_text(data = df_pooled,
                  aes(x = mean_disp - pub_pooled_label_shift(mean_disp, mean_orig, q2.5_orig, q97.5_orig, xlim) + (xlim[2] - xlim[1]) *
                          (0.020 + (if (PUB_RECENTER)
                             0.007 * pmax(nchar(sprintf("%.0f%%", (mean_orig - 1) * 100)) - 2, 0)
                           else 0)),
                      y = y_numeric + cfg_val(.cfg, "pooled_label_dy", 0.40),
                      label = if (PUB_RECENTER)
                                sprintf(" [%.0f%%, %.0f%%]", (q2.5_orig - 1) * 100, (q97.5_orig - 1) * 100)
                              else sprintf(" [%.2f, %.2f]", q2.5_orig, q97.5_orig)),
                  size = 2.4, hjust = 0, vjust = 0,
                  color = "gray25",
                  family = pub_cfg("font_family", "sans"))} +
      {if (pub && !LABELED_MODE && PUB_WIDE && nrow(df_pooled) > 0)
        # The split pages carry only one outcome category; phantom layers keep
        # both legend keys drawn with a glyph.
        list(
          geom_errorbarh(data = df_pooled[c(1, 1), ] %>%
                           mutate(.lg = c("Animal", "Plant-based")),
                         aes(xmin = mean_disp, xmax = mean_disp, y = y_numeric, color = .lg),
                         height = 0, linewidth = 0, alpha = 0, show.legend = TRUE),
          geom_point(data = df_pooled[c(1, 1), ] %>%
                       mutate(.lg = c("Animal", "Plant-based")),
                     aes(x = mean_disp, y = y_numeric, color = .lg),
                     alpha = 0, size = 0.001, show.legend = TRUE)
        )
      else list()} +
      (if (LABELED_MODE)
        scale_color_manual(
          values = LABELED_COLORS_ALL,
          breaks = LABELED_REST_IDS,
          labels = LABELED_REST_LABELS,
          drop = FALSE,
          na.value = "gray65",
          guide = guide_legend(title = "Restaurant", ncol = 4,
                              override.aes = list(shape = 16, alpha = 1, size = 2.5)))
      else
        scale_color_manual(values = PUB_COLORS_ALL,
          breaks = c("Animal", "Plant-based"),
          labels = c("Animal-based", "Plant-based"),
          limits = function(x) union(x, c("Animal", "Plant-based")),
          guide = guide_legend(title = NULL, override.aes = list(linewidth = 2.5, alpha = 1, size = 3)))) +
      facet_grid(exposure_strip ~ effect_type) +
      scale_x_continuous(limits = c(xlim[1] - .pub_overshoot * diff(range(xlim)),
                                      xlim[2] + .pub_overshoot * diff(range(xlim))),
                         expand = c(0, 0),
                         breaks = seq(0, 3, 0.25),
                         labels = if (PUB_RECENTER && PUB_WIDE) pub_x_labels_pct_plain
                                  else if (PUB_RECENTER) pub_x_labels_pct else pub_x_labels_mixed,
                         oob = scales::squish) +
      scale_y_continuous(
        breaks = .y_pooled,
        labels = rev(outcome_labels_a3),
        expand = expansion(mult = c(cfg_val(.cfg, "expand_below", 0.2), cfg_val(.cfg, "expand_above", 0.1)))) +
      labs(
        title = .plot_title,
        subtitle = NULL,
        x = if (log_scale) "Log multiplicative effect relative to total sales"
            else if (PUB_RECENTER) "Percentage change relative to total sales"
            else           "Multiplicative effect relative to total sales",
        y = "Outcome") +
      coord_cartesian(clip = "off") +
      {if (pub && LABELED_MODE && nrow(df_restaurant) > 0) {
        # T2 A3: inline names on the Level Change facet, TOP OUTCOME ONLY.
        #
        # These used to be drawn for every outcome, which put ~17 bold names
        # into each of the three outcome blocks, layered over the numerics and
        # the bars. T1 A3 draws them for the top outcome only and reads far more
        # cleanly; the numbered legend below the plot still maps every colour,
        # so nothing is lost by not repeating them.
        #
        # Per-row bleed check uses approximate label width (nchar * ~2% of the
        # xlim range), so long names fall back to ABOVE the point estimate.
        .left_facet  <- levels(df_all$effect_type)[1]
        .top_outcome <- levels(df_all$outcome)[nlevels(df_all$outcome)]
        .df_lbl <- df_restaurant %>%
          filter(as.character(effect_type) == .left_facet,
                 as.character(outcome)     == .top_outcome) %>%
          # One name per restaurant, not per row. A restaurant with several
          # introductions has several rows, so the same name was printed
          # repeatedly ("11. Bagel-and-espresso café" four times over). Anchor
          # the single label on the row whose CI reaches furthest right, so it
          # clears all of that restaurant's bars.
          group_by(outcome, effect_type, restaurant_id) %>%
          slice_max(q97.5_disp, n = 1, with_ties = FALSE) %>%
          ungroup() %>%
          mutate(.lbl = LABELED_REST_LABELS[match(restaurant_id, LABELED_REST_IDS)],
                 .lbl = ifelse(is.na(.lbl), restaurant_id, .lbl),
                 .lbl_w = (nchar(.lbl) + 1) * 0.022 * diff(range(xlim)),
                 .has_right_room = q97.5_disp + 0.03 * diff(range(xlim)) + .lbl_w <= xlim[2],
                 # When falling back to above-point, clamp x so the centered
                 # label fits entirely inside xlim — prevents #8/#11 etc.
                 # whose mean clips to xlim[2] from running off the panel.
                 .x_lbl  = ifelse(.has_right_room,
                                  q97.5_disp + 0.03 * diff(range(xlim)),
                                  pmin(pmax(mean_disp,
                                            xlim[1] + .lbl_w/2),
                                       xlim[2] - .lbl_w/2)),
                 .y_lbl  = ifelse(.has_right_room, y_numeric, y_numeric + 0.15),
                 .hj_lbl = ifelse(.has_right_room, 0,   0.5),
                 .vj_lbl = ifelse(.has_right_room, 0.5, 0))
        if (nrow(.df_lbl) > 0)
          geom_text(data = .df_lbl,
                    aes(x = .x_lbl, y = .y_lbl, label = .lbl,
                        color = rest_color, hjust = .hj_lbl, vjust = .vj_lbl),
                    size = 2.2, fontface = "bold",
                    family = pub_cfg("font_family", "sans"),
                    inherit.aes = FALSE)
        else list()
      } else list()} +
      {if (pub && LABELED_MODE && LABELED_V2 && nrow(df_restaurant) > 0) {
        # T2 A3 numbers: LEFT of lower CI by default (opposite side from the
        # inline names, which default to RIGHT of the upper CI). When there's
        # no room on the left, fall back to ABOVE the point UNLESS the name
        # label for that same row also fell back to above-point (only
        # possible on the Level Change facet, where names live) — in that
        # collision case, drop the number BELOW the point instead.
        .left_facet <- levels(df_all$effect_type)[1]
        .df_num <- df_restaurant %>%
          mutate(.num = rest_num_label(mean_orig, q2.5_orig, q97.5_orig),
                 .nm  = LABELED_REST_LABELS[match(restaurant_id, LABELED_REST_IDS)],
                 .nm  = ifelse(is.na(.nm), restaurant_id, .nm),
                 .lbl_w = (nchar(.nm) + 1) * 0.022 * diff(range(xlim)),
                 .name_has_right_room = q97.5_disp + 0.03 * diff(range(xlim)) + .lbl_w <= xlim[2],
                 # A name label only exists on the Level Change facet.
                 .name_above = (as.character(effect_type) == .left_facet) & !.name_has_right_room,
                 # Width-aware: the old fixed 0.25 * span ignored the actual
                 # label length, so "-100% [-100%,-21%]" passed the test and
                 # then ran off the left edge.
                 .has_left_room = q2.5_disp - 0.02 * diff(range(xlim)) -
                                    nchar(.num) * .PUB_CHAR_W * diff(range(xlim)) >=
                                  xlim[1] + 0.010 * diff(range(xlim)),
                 # Try the RIGHT of the upper CI before giving up and centring
                 # above the point. On this panel the CIs are very wide, so the
                 # above-point fallback drops the number straight onto its own
                 # bar -- the "numbers overlapping the lines" problem. Anywhere
                 # beside the bar reads better than on top of it.
                 .has_right_room = !.has_left_room &
                                   (q97.5_disp + 0.02 * diff(range(xlim)) +
                                      nchar(.num) * .PUB_CHAR_W * diff(range(xlim)) <=
                                    xlim[2] - 0.010 * diff(range(xlim))),
                 .x_num  = case_when(
                   .has_left_room  ~ q2.5_disp  - 0.02 * diff(range(xlim)),
                   .has_right_room ~ q97.5_disp + 0.02 * diff(range(xlim)),
                   TRUE            ~ mean_disp),
                 .y_num  = case_when(
                   .has_left_room | .has_right_room ~ y_numeric,
                   !.name_above                     ~ y_numeric + 0.08,
                   TRUE                             ~ y_numeric - 0.08),
                 .hj_num = case_when(.has_left_room ~ 1, .has_right_room ~ 0, TRUE ~ 0.5),
                 .vj_num = case_when(
                   .has_left_room | .has_right_room ~ 0.5,
                   !.name_above                     ~ 0,
                   TRUE                             ~ 1))
        geom_text(data = .df_num,
                  aes(x = .x_num, y = .y_num, label = .num, hjust = .hj_num, vjust = .vj_num),
                  size = 1.8, color = "gray40",
                  family = pub_cfg("font_family", "sans"),
                  inherit.aes = FALSE)
      } else list()} +
      (if (pub) publication_forest_theme(base_size = 12)
       else theme_minimal(base_size = 11) +
              theme(
                plot.background   = element_rect(fill = "white", color = NA),
                panel.background  = element_rect(fill = "white", color = NA),
                panel.grid.minor  = element_blank(),
                strip.background  = element_rect(fill = "gray90", color = NA),
                strip.text        = element_text(face = "bold"),
                plot.title        = element_text(face = "bold", size = 14),
                plot.subtitle     = element_text(size = 9, color = "gray40"),
                axis.text.y       = element_text(size = 10),
                legend.position   = "bottom",
                panel.spacing     = unit(0.5, "lines"))) +
      {if (pub && PUB_RECENTER && PUB_WIDE) pub_x_axis_wide_theme(xlim) else list()}
  }

  # PUB_WIDE: 5 outcomes x 19 restaurants is a 36-inch page. Split by outcome
  # category — A3a animal-based, A3b plant-based. Breaks/labels come from the
  # packed .y_pooled positions, so a subset needs no re-layout.
  .splits <- if (PUB_WIDE) list(
      list(sfx = "a", outs = c("Nonvegan", "Meat", "Chicken & fish")),
      list(sfx = "b", outs = c("Vegetarian", "Vegan"))
    ) else list(list(sfx = "", outs = NULL))
  .full_all <- df_all; .full_pooled <- df_pooled; .full_rest <- df_restaurant
  .y_pooled0 <- .y_pooled
  .cfg0 <- .cfg
  .png_w0 <- .png_w; .png_h0 <- .png_h
  .cap_pooled0 <- .cap_pooled; .cap_rest0 <- .cap_rest
  .last_p <- NULL

  for (.sp in .splits) {
    .plot_title <- paste0("A3", .sp$sfx,
      ": Introduction of new alternative proteins and general meat sales")
    if (!is.null(.sp$outs)) {
      df_all        <- .full_all    %>% filter(as.character(outcome) %in% .sp$outs)
      df_pooled     <- .full_pooled %>% filter(as.character(outcome) %in% .sp$outs)
      df_restaurant <- .full_rest   %>% filter(as.character(outcome) %in% .sp$outs)
      .y_pooled     <- .y_pooled0[names(.y_pooled0) %in% .sp$outs]
      outcome_labels_a3 <- rev(names(.y_pooled))
      # Split entries are sparse (height/padding only) — layer them over the
      # parent config so linewidths, step and caps carry through.
      .cfg        <- modifyList(.cfg0, get_plot_cfg("T2", paste0("A3", .sp$sfx)))
      .png_w      <- cfg_val(.cfg, "png_w",      .png_w0)
      .png_h      <- cfg_val(.cfg, "png_h",      .png_h0)
      .cap_pooled <- cfg_val(.cfg, "cap_pooled", .cap_pooled0)
      .cap_rest   <- cfg_val(.cfg, "cap_rest",   .cap_rest0)
    }
    .stem <- paste0("A3", .sp$sfx, "_its_forest_restaurants")

    p_png  <- .build_p(TRUE)
    if (!.PRO_FAST)   p_html <- .build_p(FALSE)

    if (!.PRO_FAST)   pub_ggsave_png(file.path(output_dir, paste0(.stem, ".png")), p_png,
                   width = .png_w, height = .png_h)
    pub_ggsave_pdf(file.path(output_dir, paste0(.stem, ".pdf")), p_png,
                   width = .png_w, height = .png_h)

    .html_px    <- round(pmin(3600, pmax(700, .n_out_html * .n_rest_max * 1.2 * 40 + 180)))
    if (!.PRO_FAST)   p_plotly <- ggplotly(p_html, tooltip = "text", height = .html_px)
    if (!.PRO_FAST)   p_plotly <- add_click_handler(p_plotly)
    html_name <- paste0(.stem, if (log_scale) "_log", ".html")
    if (!.PRO_FAST)   try(saveWidget(p_plotly, file.path(output_dir, html_name), selfcontained = FALSE), silent = TRUE)

    df_save <- df_all %>% select(-matches("_disp|_orig|clipped|y_numeric|n_in_group|row_in_group"))
    csv_name <- paste0("A3", .sp$sfx, "_its_restaurants_data", if (log_scale) "_log", ".csv")
    write_csv(df_save, file.path(output_dir, csv_name))

    cat("  Saved: ", .stem, ".png, .pdf, .html, _data.csv\n", sep = "")
    .last_p <- p_png
  }
  return(.last_p)
}

# ─────────────────────────────────────
# 4. ITS_TARGETED Analysis (A4) - ADJUSTED
# ─────────────────────────────────────

create_its_targeted_forest_restaurants <- function(log_scale = FALSE) {
  output_dir <- if (log_scale) file.path(LOG_OUTPUT_DIR_BASE) else file.path(OUTPUT_DIR_BASE)
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  cat("Creating ADJUSTED ITS targeted forest plot with restaurant estimates...\n")
  cat("  Using overrides:", paste(names(A4_OVERRIDES), "->", A4_OVERRIDES, collapse = ", "), "\n")

  # T2 A4 targeted categories: 5 outcomes (each with _t2 suffix in fit path)
  # chicken dropped: V3Q26BHF3SE2H is the sole restaurant and its
  # chicken_t2 outcome is 0 units post-fix, so no model exists. Listing it
  # here would make the renderer fall back to the old contaminated fit.
  outcomes <- c("breakfast", "dairy", "textured", "untextured")

  pooled_list <- list()
  restaurant_list <- list()

  # Total model path (same as A3)
  total_model_path_name <- get_model_path("total", A3_OVERRIDES)
  total_run_path <- file.path("model_fits", total_model_path_name)
  total_path <- file.path(total_run_path, "t2_a3_its", "total")

  for (outcome in outcomes) {
    model_path_name <- get_model_path(outcome, A4_OVERRIDES)
    model_run_path <- file.path("model_fits", model_path_name)
    outcome_path <- file.path(model_run_path, "t2_a4_its_t", paste0(outcome, "_t2"))

    # Count restaurants from the outcome model's beta map (not the inner join)
    outcome_beta_map <- build_restaurant_beta_map(outcome_path)
    n_rest_in_model <- if (!is.null(outcome_beta_map)) n_distinct(outcome_beta_map$restaurant_id) else 0

    # Adjusted gamma[1] (level change)
    gamma1 <- compute_adjusted_mu_gamma(outcome_path, total_path, 1)
    if (!is.null(gamma1)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome,
        effect_type = "Level Change",
        mean = gamma1$mean,
        q2.5 = gamma1$q2.5,
        q16 = if (!is.null(gamma1$q16)) gamma1$q16 else NA_real_,
        q84 = if (!is.null(gamma1$q84)) gamma1$q84 else NA_real_,
        q97.5 = gamma1$q97.5,
        mean_exp = gamma1$mean_exp,
        rhat = gamma1$rhat,
        ess_bulk = gamma1$ess_bulk,
        estimate_type = "Pooled",
        restaurant_id = "POOLED",
        n_rest_model = n_rest_in_model,
        source = model_path_name)
    }

    # Adjusted gamma[2] (slope change)
    gamma2 <- compute_adjusted_mu_gamma(outcome_path, total_path, 2)
    if (!is.null(gamma2)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome,
        effect_type = "Slope Change",
        mean = gamma2$mean,
        q2.5 = gamma2$q2.5,
        q16 = if (!is.null(gamma2$q16)) gamma2$q16 else NA_real_,
        q84 = if (!is.null(gamma2$q84)) gamma2$q84 else NA_real_,
        q97.5 = gamma2$q97.5,
        mean_exp = gamma2$mean_exp,
        rhat = gamma2$rhat,
        ess_bulk = gamma2$ess_bulk,
        estimate_type = "Pooled",
        restaurant_id = "POOLED",
        n_rest_model = n_rest_in_model,
        source = model_path_name)
    }

    # Adjusted restaurant-level estimates
    rest_gammas <- compute_adjusted_restaurant_gammas(outcome_path, total_path, is_its = TRUE)
    if (!is.null(rest_gammas) && nrow(rest_gammas) > 0) {
      for (i in 1:nrow(rest_gammas)) {
        restaurant_list[[length(restaurant_list) + 1]] <- tibble(
          outcome = outcome,
          effect_type = rest_gammas$effect_type[i],
          mean = rest_gammas$mean[i],
          q2.5 = rest_gammas$q2.5[i],
          q16 = if (!is.null(rest_gammas$q16)) rest_gammas$q16[i] else NA_real_,
          q84 = if (!is.null(rest_gammas$q84)) rest_gammas$q84[i] else NA_real_,
          q97.5 = rest_gammas$q97.5[i],
          # See the t2_a3_its site: dropping mean_exp here silently downgrades
          # the restaurant dots to exp(mean) while pooled uses exp(median).
          mean_exp = if (!is.null(rest_gammas$mean_exp)) rest_gammas$mean_exp[i] else NA_real_,
          rhat = rest_gammas$rhat[i],
          ess_bulk = NA_real_,
          estimate_type = "Restaurant",
          restaurant_id = rest_gammas$restaurant_id[i],
          source = model_path_name,
          pred_path = pred_path_rel(model_path_name, "t2_a4_its_t", paste0(outcome, "_t2"), NULL, rest_gammas$restaurant_id[i]))
      }
    }
  }

  # "Total (A3)" reference row: hardcode diff=0, RR=1.0
  for (eff in c("Level Change", "Slope Change")) {
    pooled_list[[length(pooled_list) + 1]] <- tibble(
      outcome = "Total (A3)",
      effect_type = eff,
      mean = 0,
      q2.5 = 0,
      q97.5 = 0,
      mean_exp = 1,
      rhat = NA_real_,
      ess_bulk = NA_real_,
      estimate_type = "Pooled",
      restaurant_id = "POOLED",
      source = total_model_path_name)
  }

  df_pooled <- bind_rows(pooled_list)
  df_restaurant <- bind_rows(restaurant_list)

  if (nrow(df_pooled) == 0) {
    cat("  No data found for ITS targeted analysis\n")
    return(NULL)
  }

  df_all <- bind_rows(df_pooled, df_restaurant)
  df_all <- add_pooled_pred_path(df_all)

  # "Total (A3)" reference row removed for publication clarity — mirror T1 A4.
  df_all <- df_all %>% filter(outcome != "Total (A3)")
  # T2 A4 outcome labels: map lowercase to publication labels
  outcome_labels_a4 <- c(
    breakfast = "Breakfast-style meat",
    chicken   = "Chicken",
    dairy     = "Dairy",
    textured  = "Whole-muscle meat",
    untextured = "Ground meat"
  )
  # Display order (top -> bottom): breakfast, ground, whole-muscle, chicken, dairy.
  all_outcomes_a4 <- intersect(c("breakfast", "untextured", "textured", "chicken", "dairy"),
                               outcomes)
  df_all$outcome <- factor(df_all$outcome, levels = rev(all_outcomes_a4),
                            labels = rev(outcome_labels_a4[all_outcomes_a4]))
  df_all$effect_type <- factor(df_all$effect_type, levels = c("Level Change", "Slope Change"),
                                labels = c("Level change", "Slope change"))

  # Right-side grey facet strip (like A1's exposure_group / A2's), one level
  # per outcome in the same top -> bottom order as the outcome axis, with
  # "Introductions" on a second line (A4 = introduction, not availability).
  .exposure_strip_labels <- c(
    "Breakfast-style meat" = "Exposure: Breakfast-Style Analog\nIntroductions",
    "Ground meat"          = "Exposure: Ground Meat Analog\nIntroductions",
    "Whole-muscle meat"    = "Exposure: Whole-Muscle\nAnalog Introductions",
    "Chicken"              = "Exposure: Chicken Analog\nIntroductions",
    "Dairy"                = "Exposure: Dairy Analog\nIntroductions"
  )
  .exposure_strip_order <- outcome_labels_a4[all_outcomes_a4]
  df_all$exposure_strip <- factor(.exposure_strip_labels[as.character(df_all$outcome)],
                                   levels = .exposure_strip_labels[.exposure_strip_order])

  df_all <- df_all %>%
    mutate(color_group = "Animal")

  if (!log_scale) {
    df_all <- df_all %>%
      mutate(across(any_of(c('q2.5','q97.5','q16','q84')), ~ exp(.x)),
             mean = ifelse(!is.na(mean_exp), mean_exp, exp(mean)))
  }

  # Remove pooled for textured (only 1 restaurant)
  df_all <- df_all %>%
    # Drop the pooled estimate for any outcome backed by a single restaurant.
    # With one restaurant Stan collapses eta = mu_gamma, so the "pooled" value is
    # just that restaurant's eta-level RRR, while the plotted dots are
    # introduction-level gammas -- different objects that need not bracket. This
    # replaces a hardcoded `outcome == "Whole-muscle meat"` check, which dropped
    # Whole-muscle but left Ground meat's single-restaurant pooled on the plot.
    group_by(outcome) %>%
    filter(!(estimate_type == "Pooled" &
             n_distinct(restaurant_id[estimate_type == "Restaurant"]) <= 1)) %>%
    ungroup()

  .n_rest_max <- df_all %>%
    dplyr::filter(estimate_type == "Restaurant") %>%
    dplyr::count(outcome, effect_type) %>%
    dplyr::pull(n) %>%
    { if (length(.)) max(.) else 0 }
  .cfg        <- get_plot_cfg("T2", "A4")
  .step       <- cfg_val(.cfg, "step_size",      0.50)
  .margin     <- cfg_val(.cfg, "margin_mult",    1.2)
  .floor      <- cfg_val(.cfg, "y_spread_floor", 1.0)
  # Proportional wide layout: the block gap is what separates outcomes AND
  # (at half width) pads each panel, so holding it at a fixed 1.5 y-units
  # while step_size varies makes the padding balloon on plots with a small
  # step. Tie it to step at T1's ratio (1.5 / 0.55) so gap, padding and row
  # spacing keep the same proportions on every plot; T1's own A2/A4 use
  # step 0.55, so their layout is unchanged.
  .outcome_gap <- if (PUB_WIDE) .step * (1.5 / 0.55) else pub_cfg("outcome_gap", 1.5)
  .cap_pooled <- cfg_val(.cfg, "cap_pooled",     0.15)
  .cap_rest   <- cfg_val(.cfg, "cap_rest",       0.075)

  # Per-outcome packed positioning.
  .n_per_out_df <- df_all %>%
    dplyr::filter(estimate_type == "Restaurant") %>%
    dplyr::count(outcome, effect_type, name = "n_rest") %>%
    dplyr::group_by(outcome) %>%
    dplyr::summarize(n_rest_max = max(n_rest), .groups = "drop")
  .all_levels <- levels(df_all$outcome)
  .n_lookup <- setNames(rep(0L, length(.all_levels)), .all_levels)
  .n_lookup[as.character(.n_per_out_df$outcome)] <- .n_per_out_df$n_rest_max
  .y_pooled <- numeric(length(.all_levels))
  if (length(.all_levels) >= 2) for (.i in 2:length(.all_levels)) {
    .y_pooled[.i] <- .y_pooled[.i-1] + .step * .n_lookup[.i] + .outcome_gap
  }
  names(.y_pooled) <- .all_levels
  .y_spread <- .outcome_gap + .step * .n_rest_max
  .y_range_data <- .y_pooled[length(.all_levels)] + .step * .n_lookup[1]
  # Outcomes with NO pooled row (e.g. Whole-muscle meat, only 1 restaurant)
  # would otherwise still reserve a full extra step of vertical space above
  # their topmost restaurant. See T1 A2 for the full rationale. Gated behind
  # PUB_WIDE so non-wide outputs are unaffected.
  .has_pooled <- .all_levels %in% unique(as.character(df_all$outcome[df_all$estimate_type == "Pooled"]))
  names(.has_pooled) <- .all_levels
  .y_top_eff <- .y_pooled
  .n_reserved <- .n_lookup
  # Relative row-panel heights for the facet_grid(exposure_strip ~ ...) row
  # strip, in exposure_strip's top -> bottom level order (matches
  # .exposure_strip_order). See T1 A2 for the rationale.
  .row_height_floor <- 2
  .row_heights <- .step * pmax(.n_reserved[.exposure_strip_order], .row_height_floor) + .outcome_gap
  # Invisible sentinel points spanning each outcome's full intended block, so
  # scales = "free_y" panels never collapse to a degenerate range. See T1 A2.
  .df_blank <- tidyr::crossing(.outcome_lbl = .exposure_strip_order,
                                effect_type = levels(df_all$effect_type)) %>%
    dplyr::mutate(y_top = if (PUB_WIDE) .y_pooled[.outcome_lbl] + .outcome_gap / 2
                          else .y_top_eff[.outcome_lbl],
                   y_bot = if (PUB_WIDE)
                             .y_pooled[.outcome_lbl] - .step * pmax(.n_lookup[.outcome_lbl], 1) - .outcome_gap / 2
                           else pmin(.y_pooled[.outcome_lbl] - .step * .n_lookup[.outcome_lbl],
                                 .y_top_eff[.outcome_lbl] - 2 * .step)) %>%
    tidyr::pivot_longer(c(y_top, y_bot), values_to = "y_numeric") %>%
    dplyr::mutate(outcome = factor(.outcome_lbl, levels = levels(df_all$outcome)),
                   effect_type = factor(effect_type, levels = levels(df_all$effect_type)),
                   exposure_strip = factor(.exposure_strip_labels[.outcome_lbl],
                                           levels = levels(df_all$exposure_strip)))

  .n_out_html <- length(unique(df_all$outcome))
  .png_w      <- cfg_val(.cfg, "png_w", 10)
  .png_h      <- cfg_val(.cfg, "png_h", min(49, max(3, .y_range_data * (1 + cfg_val(.cfg, "expand_below", 0.05) + cfg_val(.cfg, "expand_above", 0.05)) / pub_cfg("y_per_inch", 4) + 1.5)))

  df_all <- df_all %>%
    group_by(outcome, effect_type) %>%
    mutate(
      n_in_group = n(),
      .rank_key  = if (SORT_BY_MEAN)
                     if_else(estimate_type == "Restaurant", -mean, NA_real_)
                   else if (LABELED_MODE)
                     if_else(estimate_type == "Restaurant",
                             as.numeric(labeled_rank_fn(restaurant_id)), NA_real_)
                   else
                     if_else(estimate_type == "Restaurant",
                             as.numeric(factor(restaurant_id,
                                               levels = sort(unique(restaurant_id)))),
                             NA_real_),
      row_in_group = if_else(estimate_type == "Restaurant",
        as.integer(rank(.rank_key, ties.method = "first", na.last = "keep")),
        0L),
      y_numeric = .y_pooled[as.character(outcome)] +
        case_when(
          estimate_type == "Pooled" ~ 0,
          TRUE ~ -.step * row_in_group
        )
    ) %>%
    select(-.rank_key) %>%
    ungroup()

  xlim <- if (log_scale) calc_xlim_median(df_all, x_max_input = 10) else c(0, 2)
  df_all <- clip_to_limits(df_all, xlim)
  df_all$color_group_inner     <- paste0(df_all$color_group, "_inner")
  df_all$color_group_innerdark <- paste0(df_all$color_group, "_innerdark")
  df_all$color_group_restwash  <- paste0(df_all$color_group, "_restwash")
  df_all <- add_inner_ci(df_all, xlim, log_scale = log_scale)

  df_pooled <- df_all %>% filter(estimate_type == "Pooled")
  df_restaurant <- df_all %>% filter(estimate_type == "Restaurant")
  df_restaurant$rest_color      <- if (LABELED_MODE) df_restaurant$restaurant_id else df_restaurant$color_group
  df_restaurant$rest_color_wash <- if (LABELED_MODE) df_restaurant$restaurant_id else df_restaurant$color_group_restwash

  # Outcome labels for axis (in factor level order, already relabeled)
  .outcome_labels_final <- rev(levels(df_all$outcome))

  .build_p <- function(pub) {
    ggplot() +
      geom_blank(data = .df_blank, aes(y = y_numeric)) +
      geom_vline(xintercept = if (log_scale) 0 else 1,
                 linetype = "dashed", color = pub_cfg("vline_color", "grey55"), linewidth = pub_cfg("vline_linewidth", 0.4)) +
      {if (pub && nrow(df_restaurant) > 0)
        geom_errorbarh(data = df_restaurant,
                       aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = rest_color_wash),
                       height = 0, alpha = pub_cfg("rest_bar_alpha_outer", 0.55), linewidth = plot_or_pub(.cfg, "rest_bar_linewidth", 0.35))} +
      {if (pub && nrow(df_restaurant) > 0 && any(df_restaurant$left_ok, na.rm = TRUE))
        geom_segment(data = df_restaurant %>% filter(left_ok),
                     aes(x = q2.5_disp, xend = q2.5_disp,
                         y = y_numeric - (.cap_rest / 2), yend = y_numeric + (.cap_rest / 2),
                         color = rest_color_wash),
                     alpha = pub_cfg("rest_bar_alpha_outer", 0.55), linewidth = plot_or_pub(.cfg, "rest_cap_linewidth", pub_cfg("rest_cap_linewidth", 0.2)))} +
      {if (pub && nrow(df_restaurant) > 0 && any(df_restaurant$right_ok, na.rm = TRUE))
        geom_segment(data = df_restaurant %>% filter(right_ok),
                     aes(x = q97.5_disp, xend = q97.5_disp,
                         y = y_numeric - (.cap_rest / 2), yend = y_numeric + (.cap_rest / 2),
                         color = rest_color_wash),
                     alpha = pub_cfg("rest_bar_alpha_outer", 0.55), linewidth = plot_or_pub(.cfg, "rest_cap_linewidth", pub_cfg("rest_cap_linewidth", 0.2)))} +
      {if (pub && nrow(df_restaurant) > 0)
        geom_errorbarh(data = df_restaurant,
                       aes(xmin = q1_lo_disp, xmax = q1_hi_disp, y = y_numeric, color = rest_color),
                       height = 0, alpha = pub_cfg("rest_bar_alpha_outer", 0.55), linewidth = plot_or_pub(.cfg, "rest_bar_linewidth", 0.35))} +
      {if (!pub && nrow(df_restaurant) > 0)
        geom_errorbarh(data = df_restaurant,
                       aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                       height = 0.075, alpha = 0.4, linewidth = 0.3)} +
      {if (nrow(df_restaurant) > 0)
        geom_point(data = df_restaurant,
                   aes(x = mean_disp, y = y_numeric, color = rest_color,
                       shape = clipped, size = clipped,
                       customdata = pred_path,
                       text = paste0(
                         "Restaurant: ", restaurant_id, "<br>",
                         "Outcome: ", outcome, "<br>",
                         "Effect: ", effect_type, "<br>",
                         "Adjusted Rate Ratio: ", signif(mean_orig, 3), "<br>",
                         "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                         "<br>Source: ", source,
                         ifelse(clipped, "<br>(Value clipped to fit scale)", ""))),
                   alpha = pub_cfg("rest_point_alpha", 0.6), stroke = pub_cfg("rest_point_stroke", 0))} +
      scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 17), guide = "none") +
      scale_size_manual(values = c("FALSE" = pub_cfg("rest_point_size", 1.4),
                                   "TRUE"  = pub_cfg("rest_point_size", 1.4) * 1.6), guide = "none") +
      {if (pub)
        geom_errorbarh(data = df_pooled,
                       aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group_innerdark),
                       height = 0, linewidth = plot_or_pub(.cfg, "pooled_bar_linewidth", 1.4), alpha = pub_cfg("pooled_bar_alpha_outer", 1.0))} +
      {if (pub && any(df_pooled$left_ok, na.rm = TRUE))
        geom_segment(data = df_pooled %>% filter(left_ok),
                     aes(x = q2.5_disp, xend = q2.5_disp,
                         y = y_numeric - (.cap_pooled / 2), yend = y_numeric + (.cap_pooled / 2),
                         color = color_group_innerdark),
                     linewidth = plot_or_pub(.cfg, "pooled_cap_linewidth", pub_cfg("pooled_cap_linewidth", 0.4)), alpha = pub_cfg("pooled_bar_alpha_outer", 1.0))} +
      {if (pub && any(df_pooled$right_ok, na.rm = TRUE))
        geom_segment(data = df_pooled %>% filter(right_ok),
                     aes(x = q97.5_disp, xend = q97.5_disp,
                         y = y_numeric - (.cap_pooled / 2), yend = y_numeric + (.cap_pooled / 2),
                         color = color_group_innerdark),
                     linewidth = plot_or_pub(.cfg, "pooled_cap_linewidth", pub_cfg("pooled_cap_linewidth", 0.4)), alpha = pub_cfg("pooled_bar_alpha_outer", 1.0))} +
      {if (pub)
        geom_errorbarh(data = df_pooled,
                       aes(xmin = q1_lo_disp, xmax = q1_hi_disp, y = y_numeric, color = color_group),
                       height = 0, linewidth = plot_or_pub(.cfg, "pooled_bar_linewidth", 1.4), alpha = pub_cfg("pooled_bar_alpha_outer", 1.0))} +
      {if (!pub)
        geom_errorbarh(data = df_pooled,
                       aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                       height = 0.15, linewidth = 0.8)} +
      geom_point(data = df_pooled,
                 aes(x = mean_disp, y = y_numeric, color = color_group, customdata = pred_path, text = paste0(
                   "POOLED<br>",
                   "Outcome: ", outcome, "<br>",
                   "Effect: ", effect_type, "<br>",
                   "Adjusted Rate Ratio: ", signif(mean_orig, 3), "<br>",
                   "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                   "<br>Source: ", source,
                   ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), ""))),
                 size = pub_cfg("pooled_point_size", 3.1), stroke = pub_cfg("pooled_point_stroke", 0)) +
      {if (pub)
        geom_text(data = df_pooled,
                  aes(x = mean_disp - pub_pooled_label_shift(mean_disp, mean_orig, q2.5_orig, q97.5_orig, xlim),
                      y = y_numeric + cfg_val(.cfg, "pooled_label_dy", 0.40),
                      label = if (PUB_RECENTER) sprintf("%.0f%%", (mean_orig - 1) * 100)
                              else sprintf("%.2f", mean_orig)),
                  size = 2.4, hjust = 0.5, vjust = 0,
                  fontface = "bold",
                  color = "gray25",
                  family = pub_cfg("font_family", "sans"))} +
      {if (pub)
        geom_text(data = df_pooled,
                  aes(x = mean_disp - pub_pooled_label_shift(mean_disp, mean_orig, q2.5_orig, q97.5_orig, xlim) + (xlim[2] - xlim[1]) *
                          (0.020 + (if (PUB_RECENTER)
                             0.007 * pmax(nchar(sprintf("%.0f%%", (mean_orig - 1) * 100)) - 2, 0)
                           else 0)),
                      y = y_numeric + cfg_val(.cfg, "pooled_label_dy", 0.40),
                      label = if (PUB_RECENTER)
                                sprintf(" [%.0f%%, %.0f%%]", (q2.5_orig - 1) * 100, (q97.5_orig - 1) * 100)
                              else sprintf(" [%.2f, %.2f]", q2.5_orig, q97.5_orig)),
                  size = 2.4, hjust = 0, vjust = 0,
                  color = "gray25",
                  family = pub_cfg("font_family", "sans"))} +
      {if (pub && !LABELED_MODE && PUB_WIDE && nrow(df_pooled) > 0)
        # This analysis has no Plant-based layer, so its legend key would get
        # no glyph. Invisible phantom layers carry both plain color values;
        # the guide's override.aes restyles the keys to match A1.
        list(
          geom_errorbarh(data = df_pooled[c(1, 1), ] %>%
                           mutate(.lg = c("Animal", "Plant-based")),
                         aes(xmin = mean_disp, xmax = mean_disp, y = y_numeric, color = .lg),
                         height = 0, linewidth = 0, alpha = 0, show.legend = TRUE),
          geom_point(data = df_pooled[c(1, 1), ] %>%
                       mutate(.lg = c("Animal", "Plant-based")),
                     aes(x = mean_disp, y = y_numeric, color = .lg),
                     alpha = 0, size = 0.001, show.legend = TRUE)
        )
      else list()} +
      (if (LABELED_MODE)
        scale_color_manual(
          values = LABELED_COLORS_ALL,
          breaks = LABELED_REST_IDS,
          labels = LABELED_REST_LABELS,
          drop = FALSE,
          na.value = "gray65",
          guide = guide_legend(title = "Restaurant", ncol = 4,
                              override.aes = list(shape = 16, alpha = 1, size = 2.5)))
      else if (PUB_WIDE)
        scale_color_manual(values = PUB_COLORS_ALL,
          breaks = c("Animal", "Plant-based"),
          labels = c("Animal-based", "Plant-based"),
          limits = function(x) union(x, c("Animal", "Plant-based")),
          guide = guide_legend(title = NULL, override.aes = list(linewidth = 2.5, alpha = 1, size = 3)))
      else
        scale_color_manual(values = PUB_COLORS_ALL, guide = "none")) +
      facet_grid(exposure_strip ~ effect_type, scales = "free_y", space = "free_y") +
      {if (PUB_WIDE) list() else ggh4x::force_panelsizes(rows = .row_heights)} +
      scale_x_continuous(limits = c(xlim[1] - .pub_overshoot * diff(range(xlim)),
                                      xlim[2] + .pub_overshoot * diff(range(xlim))),
                         expand = c(0, 0),
                         breaks = seq(0, 2, 0.25),
                         labels = if (PUB_RECENTER && PUB_WIDE) pub_x_labels_pct_plain
                                  else if (PUB_RECENTER) pub_x_labels_pct else pub_x_labels_mixed,
                         oob = scales::squish) +
      scale_y_continuous(
        breaks = .y_top_eff,
        labels = rev(.outcome_labels_final),
        expand = expansion(mult = c(cfg_val(.cfg, "expand_below", 0.25), cfg_val(.cfg, "expand_above", 0.15)))) +
      labs(
        title = "A4: Introduction of new alternative proteins and counterpart-specific meat sales",
        subtitle = NULL,
        x = if (log_scale) "Log multiplicative effect relative to total sales"
            else if (PUB_RECENTER) "Percentage change relative to total sales"
            else           "Multiplicative effect relative to total sales",
        y = "Outcome") +
      coord_cartesian(clip = "off") +
      {if (pub && LABELED_MODE && nrow(df_restaurant) > 0) {
        # T2 A4: labels go ABOVE each point estimate, for ALL outcomes. When
        # the mean is at/past the panel edge (e.g., clipped chicken outliers),
        # nudge the label x toward 1 (the no-effect reference) so the text
        # stays on the page.
        .left_facet <- levels(df_all$effect_type)[1]
        .df_lbl <- df_restaurant %>%
          filter(as.character(effect_type) == .left_facet) %>%
          # One name per restaurant, not per row: a restaurant with several
          # introductions was printing its name once per row ("7. Juice bar"
          # five times in one outcome). Anchor on its widest CI.
          group_by(outcome, effect_type, restaurant_id) %>%
          slice_max(q97.5_disp, n = 1, with_ties = FALSE) %>%
          ungroup() %>%
          mutate(.lbl = LABELED_REST_LABELS[match(restaurant_id, LABELED_REST_IDS)],
                 .lbl = ifelse(is.na(.lbl), restaurant_id, .lbl),
                 .edge_buf = 0.18 * diff(range(xlim)),
                 .x_lbl = case_when(
                   mean_disp > xlim[2] - .edge_buf ~ pmax(xlim[2] - .edge_buf, 1),
                   mean_disp < xlim[1] + .edge_buf ~ pmin(xlim[1] + .edge_buf, 1),
                   TRUE                            ~ mean_disp))
        if (nrow(.df_lbl) > 0)
          geom_text(data = .df_lbl,
                    aes(x = .x_lbl, y = y_numeric + 0.15,
                        label = .lbl, color = rest_color),
                    hjust = 0.5, vjust = 0,
                    size = 2.2, fontface = "bold",
                    family = pub_cfg("font_family", "sans"),
                    inherit.aes = FALSE)
        else list()
      } else list()} +
      {if (pub && LABELED_MODE && LABELED_V2 && nrow(df_restaurant) > 0) {
        # T2 A4 numbers: RIGHT of upper CI (names sit ABOVE the point at
        # y+0.15, so a different y keeps them apart). Fallback to LEFT of
        # the lower CI when there's no room on the right.
        .df_num <- df_restaurant %>%
          mutate(.num = rest_num_label(mean_orig, q2.5_orig, q97.5_orig),
                 # Width-aware, as elsewhere: a fixed fraction ignored the
                 # actual label length and let long ones overflow the edge.
                 .has_right_room = q97.5_disp + 0.02 * diff(range(xlim)) +
                                     nchar(.num) * .PUB_CHAR_W * diff(range(xlim)) <=
                                   xlim[2] - 0.010 * diff(range(xlim)),
                 .has_left_room  = q2.5_disp - 0.02 * diff(range(xlim)) -
                                     nchar(.num) * .PUB_CHAR_W * diff(range(xlim)) >=
                                   xlim[1] + 0.010 * diff(range(xlim)),
                 .x_num  = case_when(.has_right_room ~ q97.5_disp + 0.02 * diff(range(xlim)),
                                     .has_left_room  ~ q2.5_disp  - 0.02 * diff(range(xlim)),
                                     TRUE            ~ mean_disp),
                 .y_num  = ifelse(.has_right_room | .has_left_room, y_numeric, y_numeric - 0.15),
                 .hj_num = case_when(.has_right_room ~ 0, .has_left_room ~ 1, TRUE ~ 0.5),
                 .vj_num = ifelse(.has_right_room | .has_left_room, 0.5, 1))
        geom_text(data = .df_num,
                  aes(x = .x_num, y = .y_num, label = .num, hjust = .hj_num, vjust = .vj_num),
                  size = 1.8, color = "gray40",
                  family = pub_cfg("font_family", "sans"),
                  inherit.aes = FALSE)
      } else list()} +
      (if (pub) publication_forest_theme(base_size = 12)
       else theme_minimal(base_size = 11) +
              theme(
                plot.background   = element_rect(fill = "white", color = NA),
                panel.background  = element_rect(fill = "white", color = NA),
                panel.grid.minor  = element_blank(),
                strip.background  = element_rect(fill = "gray90", color = NA),
                strip.text        = element_text(face = "bold"),
                plot.title        = element_text(face = "bold", size = 14),
                plot.subtitle     = element_text(size = 9, color = "gray40"),
                axis.text.y       = element_text(size = 10),
                legend.position   = "bottom",
                panel.spacing     = unit(0.5, "lines"))) +
      {if (pub && PUB_RECENTER && PUB_WIDE) pub_x_axis_wide_theme(xlim) else list()} +
      # Row strips are short per-outcome panels here (facet_grid + free_y).
      # Non-wide: too short for rotated (angle=-90) strip text to fit without
      # overlapping neighboring rows — keep it horizontal. Wide: panels are
      # tall enough for the standard vertical strip text.
      theme(strip.text.y = if (PUB_WIDE) element_text(angle = -90, size = rel(0.72), lineheight = 0.9)
                            else element_text(angle = 0, size = rel(0.62), lineheight = 0.85))
  }

  p_png  <- .build_p(TRUE)
  if (!.PRO_FAST)   p_html <- .build_p(FALSE)

  if (!.PRO_FAST)   pub_ggsave_png(file.path(output_dir, "A4_its_targeted_forest_restaurants.png"), p_png,
                 width = .png_w, height = .png_h)
  pub_ggsave_pdf(file.path(output_dir, "A4_its_targeted_forest_restaurants.pdf"), p_png,
                 width = .png_w, height = .png_h)

  .html_px    <- round(pmin(3600, pmax(700, .n_out_html * .n_rest_max * 1.2 * 40 + 180)))
  if (!.PRO_FAST)   p_plotly <- ggplotly(p_html, tooltip = "text", height = .html_px)
  if (!.PRO_FAST)   p_plotly <- add_click_handler(p_plotly)
  html_name <- if (log_scale) "A4_its_targeted_forest_restaurants_log.html" else "A4_its_targeted_forest_restaurants.html"
  if (!.PRO_FAST)   try(saveWidget(p_plotly, file.path(output_dir, html_name), selfcontained = FALSE), silent = TRUE)

  df_save <- df_all %>% select(-matches("_disp|_orig|clipped|y_numeric|n_in_group|row_in_group"))
  csv_name <- if (log_scale) "A4_its_targeted_restaurants_data_log.csv" else "A4_its_targeted_restaurants_data.csv"
  write_csv(df_save, file.path(output_dir, csv_name))

  cat("  Saved: A4_its_targeted_forest_restaurants.png, .pdf, .html, _data.csv\n")
  return(p_png)
}

# ─────────────────────────────────────
# 5. Gaussian IID Analysis (A5) - ADJUSTED
# Transaction-level, pre-period demeaned, identity link
# Adjusted = outcome effect - total effect (subtraction)
# 3 facets: Level Change, Slope Change, Gender x Level
# ─────────────────────────────────────

create_gaussian_iid_forest_restaurants_adj <- function() {
  output_dir <- OUTPUT_DIR_BASE
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  cat("Creating ADJUSTED Gaussian IID forest plot with restaurant estimates...\n")

  outcomes <- c("total", "nonvegan", "meat", "chicken_fish", "vegetarian", "vegan")
  total_path <- file.path("model_fits", A5GI_MODEL_PATH, A5GI_ANALYSIS, "total")

  pooled_list <- list()
  restaurant_list <- list()

  for (outcome in outcomes) {
    outcome_path <- file.path("model_fits", A5GI_MODEL_PATH, A5GI_ANALYSIS, outcome)
    if (!file.exists(file.path(outcome_path, "summ.rds")) &&
        is.null(adj_mu_gamma_from_csv(outcome_path, 1))) {
      cat("  Skipping", outcome, "- no summ.rds and no adj CSV fallback
")
      next
    }

    if (outcome == "total") {
      # Adjusted total = 0 by definition
      for (eff in c("Level Change", "Slope Change", "Gender x Level")) {
        pooled_list[[length(pooled_list) + 1]] <- tibble(
          outcome = outcome, effect_type = eff,
          mean = 0, q2.5 = 0, q97.5 = 0,
          rhat = NA_real_, ess_bulk = NA_real_,
          estimate_type = "Pooled", restaurant_id = "POOLED")
      }
      next
    }

    # Adjusted Level Change
    gamma1 <- compute_adjusted_mu_gamma_identity(outcome_path, total_path, 1)
    if (!is.null(gamma1)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome, effect_type = "Level Change",
        mean = gamma1$mean, q2.5 = gamma1$q2.5,
 q16 = if (!is.null(gamma1$q16)) gamma1$q16 else NA_real_,
 q84 = if (!is.null(gamma1$q84)) gamma1$q84 else NA_real_, q97.5 = gamma1$q97.5,
        rhat = gamma1$rhat, ess_bulk = gamma1$ess_bulk,
        estimate_type = "Pooled", restaurant_id = "POOLED")
    }

    # Adjusted Slope Change
    gamma2 <- compute_adjusted_mu_gamma_identity(outcome_path, total_path, 2)
    if (!is.null(gamma2)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome, effect_type = "Slope Change",
        mean = gamma2$mean, q2.5 = gamma2$q2.5,
 q16 = if (!is.null(gamma2$q16)) gamma2$q16 else NA_real_,
 q84 = if (!is.null(gamma2$q84)) gamma2$q84 else NA_real_, q97.5 = gamma2$q97.5,
        rhat = gamma2$rhat, ess_bulk = gamma2$ess_bulk,
        estimate_type = "Pooled", restaurant_id = "POOLED")
    }

    # Adjusted Restaurant-Level Gammas
    rest_adj <- compute_adjusted_restaurant_gammas_identity(outcome_path, total_path)
    if (!is.null(rest_adj) && nrow(rest_adj) > 0) {
      for (i in 1:nrow(rest_adj)) {
        restaurant_list[[length(restaurant_list) + 1]] <- tibble(
          outcome = outcome, effect_type = rest_adj$effect_type[i],
          mean = rest_adj$mean[i], q2.5 = rest_adj$q2.5[i], q97.5 = rest_adj$q97.5[i],
          rhat = rest_adj$rhat[i], ess_bulk = rest_adj$ess_bulk[i],
          estimate_type = "Restaurant", restaurant_id = rest_adj$restaurant_id[i],
          pred_path = pred_path_rel(A5GI_MODEL_PATH, A5GI_ANALYSIS, outcome, NULL, rest_adj$restaurant_id[i]))
      }
    }

    # Adjusted Gender x Level (pooled: mu_gamma[3])
    gamma3 <- compute_adjusted_mu_gamma_identity(outcome_path, total_path, 3)
    if (!is.null(gamma3)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome, effect_type = "Gender x Level",
        mean = gamma3$mean, q2.5 = gamma3$q2.5, q97.5 = gamma3$q97.5,
        rhat = gamma3$rhat, ess_bulk = gamma3$ess_bulk,
        estimate_type = "Pooled", restaurant_id = "POOLED")
    }
    # Restaurant-level Gender x Level already included via
    # compute_adjusted_restaurant_gammas_identity above
  }

  df_pooled <- bind_rows(pooled_list)
  df_restaurant <- bind_rows(restaurant_list)

  if (nrow(df_pooled) == 0) {
    cat("  No data found for Gaussian IID adjusted analysis\n")
    return(NULL)
  }

  df_all <- bind_rows(df_pooled, df_restaurant)
  df_all <- add_pooled_pred_path(df_all)

  df_all$outcome <- factor(df_all$outcome, levels = rev(outcomes))
  df_all$effect_type <- factor(df_all$effect_type,
                                levels = c("Level Change", "Slope Change", "Gender x Level"))

  df_all <- df_all %>%
    mutate(color_group = case_when(
      outcome == "total" ~ "Total",
      outcome %in% c("nonvegan", "meat", "chicken_fish") ~ "Animal",
      outcome %in% c("vegetarian", "vegan") ~ "Plant-based"))

  # Skip pooled when only 1 restaurant
  n_restaurants <- df_all %>%
    filter(estimate_type == "Restaurant") %>%
    group_by(outcome, effect_type) %>%
    summarise(n_rest = n_distinct(restaurant_id), .groups = "drop")
  df_all <- df_all %>%
    left_join(n_restaurants, by = c("outcome", "effect_type")) %>%
    filter(!(estimate_type == "Pooled" & !is.na(n_rest) & n_rest <= 1)) %>%
    select(-n_rest)

  .cfg <- get_plot_cfg("T2", "A5")
  .step       <- cfg_val(.cfg, "step_size",      0.50)
  .margin     <- cfg_val(.cfg, "margin_mult",    1.2)
  .floor      <- cfg_val(.cfg, "y_spread_floor", 1)
  .cap_pooled <- cfg_val(.cfg, "cap_pooled",     0.15)
  .cap_rest   <- cfg_val(.cfg, "cap_rest",       0.075)
  .n_rest_max <- df_all %>%
    dplyr::filter(estimate_type == "Restaurant") %>%
    dplyr::count(outcome, effect_type) %>%
    dplyr::pull(n) %>%
    { if (length(.)) max(.) else 0 }
  .y_spread <- max(.n_rest_max * .step * .margin, .floor)
  .n_out_html <- length(unique(df_all$outcome))

  df_all <- df_all %>%
    group_by(outcome, effect_type) %>%
    mutate(
      n_in_group = n(),
      .rank_key  = if (SORT_BY_MEAN)
                     if_else(estimate_type == "Restaurant", -mean, NA_real_)
                   else if (LABELED_MODE)
                     if_else(estimate_type == "Restaurant",
                             as.numeric(labeled_rank_fn(restaurant_id)), NA_real_)
                   else
                     if_else(estimate_type == "Restaurant",
                             as.numeric(factor(restaurant_id,
                                               levels = sort(unique(restaurant_id)))),
                             NA_real_),
      row_in_group = if_else(estimate_type == "Restaurant",
        as.integer(rank(.rank_key, ties.method = "first", na.last = "keep")),
        0L),
      y_numeric = as.numeric(outcome) * .y_spread +
        case_when(
          estimate_type == "Pooled" ~ 0,
          TRUE ~ -.step * row_in_group
        )
    ) %>%
    select(-.rank_key) %>%
    ungroup()

  xlim <- calc_xlim_identity(df_all)
  df_all <- clip_to_limits(df_all, xlim)

  df_pooled <- df_all %>% filter(estimate_type == "Pooled")
  df_restaurant <- df_all %>% filter(estimate_type == "Restaurant")
  df_restaurant$rest_color      <- if (LABELED_MODE) df_restaurant$restaurant_id else df_restaurant$color_group
  df_restaurant$rest_color_wash <- if (LABELED_MODE) df_restaurant$restaurant_id else df_restaurant$color_group_restwash

  p <- ggplot() +
    geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
    {if (nrow(df_restaurant) > 0)
      geom_errorbarh(data = df_restaurant,
                     aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                     height = .cap_rest, alpha = 0.4, linewidth = 0.3)} +
    {if (nrow(df_restaurant) > 0)
      geom_point(data = df_restaurant,
                 aes(x = mean_disp, y = y_numeric, color = color_group,
                     shape = clipped, size = clipped,
                     customdata = pred_path,
                     text = paste0(
                       "Restaurant: ", restaurant_id, "<br>",
                       "Outcome: ", outcome, "<br>",
                       "Effect: ", effect_type, "<br>",
                       "Adjusted Estimate: ", signif(mean_orig, 3), "<br>",
                       "95% CrI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                       ifelse(clipped, "<br>(Value clipped to fit scale)", ""))),
                 size = 1.2, alpha = 0.5)} +
    scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 17), guide = "none") +
      scale_size_manual(values = c("FALSE" = pub_cfg("rest_point_size", 1.4),
                                   "TRUE"  = pub_cfg("rest_point_size", 1.4) * 1.6), guide = "none") +
    geom_errorbarh(data = df_pooled,
                   aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                   height = .cap_pooled, linewidth = 0.8) +
    geom_point(data = df_pooled,
               aes(x = mean_disp, y = y_numeric, color = color_group, customdata = pred_path, text = paste0(
                 "POOLED<br>",
                 "Outcome: ", outcome, "<br>",
                 "Effect: ", effect_type, "<br>",
                 "Adjusted Estimate: ", signif(mean_orig, 3), "<br>",
                 "95% CrI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                 ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), ""))),
               size = 2.5) +
    (if (LABELED_MODE)
      scale_color_manual(
        values = LABELED_COLORS_ALL,
        breaks = LABELED_REST_IDS, labels = LABELED_REST_LABELS, drop = FALSE,
        guide = guide_legend(title = "Restaurant", ncol = 4,
                            override.aes = list(shape = 16, alpha = 1, size = 2.5)))
    else
      scale_color_manual(values = c("Total" = "steelblue", "Animal" = "firebrick",
                                   "Plant-based" = "forestgreen"), guide = "none")) +
    facet_wrap(~ effect_type, ncol = 3,
               labeller = labeller(effect_type = c("Level Change" = "level change",
                                                   "Slope Change" = "slope change",
                                                   "Gender x Level" = "gender x level"))) +
    scale_x_continuous(limits = xlim, oob = scales::squish) +
    scale_y_continuous(
      breaks = (1:length(outcomes)) * .y_spread,
      labels = format_label(rev(outcomes)),
      expand = expansion(mult = c(0.2, 0.1))) +
    labs(
      title = "A5: Customer ITS Analysis (Transaction-Level, Adjusted)",
      subtitle = "Outcome effect - Total effect | Large points = pooled, Small = restaurants | 95% CrI",
      x = "Adjusted Effect (Outcome - Total)",
      y = "Outcome") +
    coord_cartesian(clip = "off") +
    {if (LABELED_MODE && nrow(df_restaurant) > 0) {
      .top_outcome <- levels(df_all$outcome)[nlevels(df_all$outcome)]
      .right_facet <- levels(df_all$effect_type)[nlevels(df_all$effect_type)]
      .df_lbl <- df_restaurant %>%
        filter(as.character(outcome) == .top_outcome,
               as.character(effect_type) == .right_facet)
      if (nrow(.df_lbl) == 0) {
        # Fall back to the highest outcome that has restaurant data
        .top_outcome <- df_restaurant %>%
          dplyr::filter(as.character(effect_type) == .right_facet) %>%
          dplyr::pull(outcome) %>% as.character() %>%
          { levels(df_all$outcome)[max(match(., levels(df_all$outcome)), na.rm = TRUE)] }
        .df_lbl <- df_restaurant %>%
          filter(as.character(outcome) == .top_outcome,
                 as.character(effect_type) == .right_facet)
      }
      if (nrow(.df_lbl) > 0)
        geom_text(data = .df_lbl %>%
                    mutate(.lbl = LABELED_REST_LABELS[match(restaurant_id, LABELED_REST_IDS)],
                           .lbl = ifelse(is.na(.lbl), restaurant_id, .lbl)),
                  aes(x = xlim[2] + 0.07 * diff(range(xlim)),
                      y = y_numeric, label = .lbl, color = rest_color),
                  hjust = 0, size = 2.2, fontface = "bold", inherit.aes = FALSE)
      else list()
    } else list()} +
    theme_minimal(base_size = 11) +
    theme(
      panel.grid.minor = element_blank(),
      strip.background = element_rect(fill = "gray90", color = NA),
      strip.text = element_text(face = "bold"),
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 9, color = "gray40"),
      axis.text.y = element_text(size = 10))

  .png_w <- cfg_val(.cfg, "png_w", 14)
  .png_h <- cfg_val(.cfg, "png_h", min(49, max(4, .n_out_html * .n_rest_max * 0.12)))
  if (!.PRO_FAST) ggsave(file.path(output_dir, "A5_gaussian_iid_forest_restaurants_adj.png"), p,
         width = .png_w, height = .png_h, dpi = 300)
  ggsave(file.path(output_dir, "A5_gaussian_iid_forest_restaurants_adj.pdf"), p,
         width = .png_w, height = .png_h)

  if (!.PRO_FAST) {
    .html_px    <- round(pmin(3600, pmax(700, .n_out_html * .n_rest_max * 1.2 * 40 + 180)))
    p_plotly <- ggplotly(p, tooltip = "text", height = .html_px)
    p_plotly <- add_click_handler(p_plotly)
    try(saveWidget(p_plotly, file.path(output_dir, "A5_gaussian_iid_forest_restaurants_adj.html"),
               selfcontained = FALSE), silent = TRUE)
  }

  df_save <- df_all %>% select(-matches("_disp|_orig|clipped|y_numeric|n_in_group|row_in_group"))
  write_csv(df_save, file.path(output_dir, "A5_gaussian_iid_restaurants_adj_data.csv"))

  cat("  Saved: A5_gaussian_iid_forest_restaurants_adj.png, .pdf, .html, _data.csv\n")
  return(p)
}

# ─────────────────────────────────────
# Execute (skipped when sourced with .forest_skip_execute option)
# ─────────────────────────────────────

if (!isTRUE(getOption(".forest_skip_execute"))) {

cat("========================================\n")
cat("Forest Plot Generation - T2 ADJUSTED (Outcome RR / Total RR)\n")
cat("========================================\n")
cat("Default model path:", DEFAULT_MODEL_PATH, "\n")
cat("A1 overrides:", paste(names(A1_OVERRIDES), "->", A1_OVERRIDES, collapse = ", "), "\n")
cat("A2 overrides:", paste(names(A2_OVERRIDES), "->", A2_OVERRIDES, collapse = ", "), "\n")
cat("A3 overrides:", paste(names(A3_OVERRIDES), "->", A3_OVERRIDES, collapse = ", "), "\n")
cat("A4 overrides:", paste(names(A4_OVERRIDES), "->", A4_OVERRIDES, collapse = ", "), "\n")
cat("Output directory base:", OUTPUT_DIR_BASE, "\n\n")

p1 <- create_proportion_forest_restaurants()
p1_log <- create_proportion_forest_restaurants(log_scale = TRUE)
p2 <- create_proportion_targeted_forest_restaurants()
p2_log <- create_proportion_targeted_forest_restaurants(log_scale = TRUE)
p3 <- create_its_forest_restaurants()
p3_log <- create_its_forest_restaurants(log_scale = TRUE)
p4 <- create_its_targeted_forest_restaurants()
p4_log <- create_its_targeted_forest_restaurants(log_scale = TRUE)
p5 <- create_gaussian_iid_forest_restaurants_adj()

cat("\n========================================\n")
cat("All T2 ADJUSTED forest plots generated!\n")
cat("Output directories:", OUTPUT_DIR_BASE, "and", LOG_OUTPUT_DIR_BASE, "\n")
cat("========================================\n")

} # end if (!isTRUE(getOption(".forest_skip_execute")))

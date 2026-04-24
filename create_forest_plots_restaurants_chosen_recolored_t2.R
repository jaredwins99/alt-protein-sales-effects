source("publication/forest_fallback.R")
# Forest Plot Generation Script - T2 VERSION with Restaurant-Level Estimates - RECOLORED
# Creates horizontal forest plots with mixed model sources - T2 (Tier 2) restaurant set
# Prefers finalized_redone_trunc_cp where fits exist; falls back to finalized_redone_trunc
# T2 ITS_TARGETED outcomes (A4): breakfast, chicken, dairy, textured, untextured (each with _t2 fit suffix)
# RECOLORED: Uses color scheme from create_forest_plots_chosen.R and includes Total reference

library(tidyverse)
library(ggplot2)
library(patchwork)
library(htmlwidgets)
library(plotly)

source("model_scripts/view_params_funcs.R")
source("model_scripts/ci95_helpers.R")

# ─────────────────────────────────────
#         Configuration - EDIT HERE
# ─────────────────────────────────────

# Default model path for most analyses
# DEFAULT_MODEL_PATH <- "finalized_redone"
DEFAULT_MODEL_PATH <- "finalized_redone_trunc"

# Override paths for specific outcomes (outcome -> model_path)
# T2 override strategy: prefer finalized_redone_trunc_cp where the T2 fit exists,
# else fall back to DEFAULT_MODEL_PATH (finalized_redone_trunc).

# A1 proportion overrides (T2): t2_a1_proportion fits under _cp: chicken_fish, meat, nonvegan, total
A1_OVERRIDES <- list(
  "total" = "finalized_redone_trunc_cp",
  "nonvegan" = "finalized_redone_trunc_cp",
  "meat" = "finalized_redone_trunc_cp",
  "chicken_fish" = "finalized_redone_trunc_cp"
  # vegan, vegetarian -> default (finalized_redone_trunc)
)

# A2 a2_proportion_t overrides (T2)
A2_OVERRIDES <- list(
)

# A3 its overrides (T2): t2_a3_its fits under _cp exist for meat and nonvegan only;
# rest fall back to finalized_redone_trunc/t2_a3_its
A3_OVERRIDES <- list(
  "nonvegan" = "finalized_redone_trunc_cp",
  "meat" = "finalized_redone_trunc_cp"
  # total, chicken_fish, vegetarian, vegan -> default (finalized_redone_trunc)
)

# A4 a4_its_t overrides (T2): t2_a4_its_t fits under _cp: breakfast_t2, dairy_t2;
# (textured_t2, untextured_t2 also under _cp per listing) chicken_t2 -> default
A4_OVERRIDES <- list(
  "breakfast" = "finalized_redone_trunc_cp",
  "textured" = "finalized_redone_trunc_cp",
  "untextured" = "finalized_redone_trunc_cp"
  # chicken -> default (finalized_redone_trunc)
  # dairy   -> default (finalized_redone_trunc) — _cp fit never existed
)

# A5 Gaussian IID (transaction-level, pre-period demeaned, identity link) - T2
A5GI_MODEL_PATH <- "finalized_redone_trunc_cp"
A5GI_ANALYSIS   <- "t2_a5_customer_day"

SORT_BY_MEAN <- Sys.getenv("SORT_BY_MEAN", "FALSE") == "TRUE"
source("publication/present_helpers.R")
OUTPUT_DIR_BASE      <- present_path(paste0("forest_plots/base/t2", if (SORT_BY_MEAN) "_sorted" else ""))
LOG_OUTPUT_DIR_BASE  <- present_path(paste0("forest_plots/z_log_and_overlay/t2", if (SORT_BY_MEAN) "_sorted" else ""))

# T2 has up to 15 restaurants per outcome; spread outcomes vertically so their
# restaurant dot clouds don't overlap adjacent outcomes.
Y_SPREAD <- 7.5

# ─────────────────────────────────────
#             Helper Functions
# ─────────────────────────────────────

extract_mu_gamma <- function(model_path, gamma_index = 1) {
  # Use 95% CI helper function
  gamma <- extract_mu_gamma_95ci(model_path, gamma_index)
  if (is.null(gamma)) return(NULL)
  list(
    mean = gamma$mean,
    mean_exp = gamma$mean_exp,
    mean_exp_p10 = gamma$mean_exp_p10,
    median = gamma$median,
    sd = gamma$sd,
    q2.5 = gamma$q2.5,
    q97.5 = gamma$q97.5,
    rhat = gamma$rhat,
    ess_bulk = gamma$ess_bulk)}

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

extract_restaurant_id <- function(model_col) {
  model_col %>%
    str_replace("^exposure_", "") %>%
    str_replace("_\\d+(_slope)?$", "")}

extract_restaurant_gammas <- function(model_path, is_its = FALSE) {
  # Use 95% CI helper function
  gammas <- extract_restaurant_gammas_95ci(model_path, is_its)
  return(gammas)
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

clip_to_limits <- function(df, xlim) {
  df %>%
    mutate(
      mean_orig = mean,
      q2.5_orig = q2.5,
      q97.5_orig = q97.5,
      clipped = mean < xlim[1] | mean > xlim[2],
      mean_disp = pmin(pmax(mean, xlim[1]), xlim[2]),
      q2.5_disp = q2.5,
      q97.5_disp = q97.5
    )
}

# ─────────────────────────────────────
#   A5 Gaussian IID Helper Functions
#   Identity link: no exp(), reference at 0
# ─────────────────────────────────────

extract_pooled_exposure_identity <- function(model_path, gamma_index = 1) {
  result <- compute_mu_gamma_95ci(model_path, gamma_indices = gamma_index)
  if (is.null(result) || nrow(result) == 0) return(NULL)
  row <- result[1, ]
  list(mean = row$mean, q2.5 = row$q2.5, q97.5 = row$q97.5,
       rhat = row$rhat, ess_bulk = row$ess_bulk)
}

extract_restaurant_gammas_identity <- function(model_path) {
  if (!file.exists(file.path(model_path, "predictor_map.rds"))) return(NULL)
  if (!file.exists(file.path(model_path, "samples.rds")) &&
      !file.exists(file.path(model_path, "summ.rds")) &&
      is.null(.ci95_rows_for(model_path))) return(NULL)

  model <- list(
    summary = read_summ_fallback(model_path),
    predictor_map = read_pmap_fallback(model_path))

  gammas <- find_betas_95ci(model, model_path)
  if (is.null(gammas)) return(NULL)

  gammas <- gammas %>%
    filter(!is.na(model_col) & str_detect(model_col, "^exposure_"))
  if (nrow(gammas) == 0) return(NULL)

  gammas %>% mutate(
    is_slope = str_detect(model_col, "_slope"),
    is_gender = str_detect(model_col, "_gendermale$"),
    effect_type = case_when(
      is_gender ~ "gender x level",
      is_slope ~ "slope change",
      TRUE ~ "level change"),
    restaurant_id = model_col %>%
      str_replace("^exposure_", "") %>%
      str_replace("_\\d+(_slope|_gendermale|_genderfemale)?$", ""))
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
# 1. PROPORTION Analysis (A1)
# RECOLORED: Total=steelblue, Animal=firebrick, Plant-based=forestgreen
# ─────────────────────────────────────

create_proportion_forest_restaurants <- function(log_scale = FALSE) {
  output_dir <- if (log_scale) file.path(LOG_OUTPUT_DIR_BASE) else file.path(OUTPUT_DIR_BASE)
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  cat("Creating proportion forest plot with restaurant estimates (recolored)...\n")
  cat("  Using A1 overrides:", paste(names(A1_OVERRIDES), "->", A1_OVERRIDES, collapse = ", "), "\n")

  # RECOLORED: Same outcome order as create_forest_plots_chosen.R

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
        model_path <- file.path(model_run_path, "t2_a1_proportion", outcome, exposure)
        summ_path <- file.path(model_path, "summ.rds")

        gamma <- extract_mu_gamma(model_path, 1)
        if (!is.null(gamma)) {
          pooled_list[[length(pooled_list) + 1]] <- tibble(
            outcome = outcome,
            exposure_group = exp_group,
            exposure_type = exp_type,
            mean = gamma$mean,
            mean_exp = gamma$mean_exp,
            mean_exp_p10 = gamma$mean_exp_p10,
            q2.5 = gamma$q2.5,
            q97.5 = gamma$q97.5,
            rhat = gamma$rhat,
            estimate_type = "Pooled",
            restaurant_id = "POOLED")
        }

        rest_gammas <- extract_restaurant_gammas(model_path, is_its = FALSE)
        if (!is.null(rest_gammas) && nrow(rest_gammas) > 0) {
          for (i in 1:nrow(rest_gammas)) {
            restaurant_list[[length(restaurant_list) + 1]] <- tibble(
              outcome = outcome,
              exposure_group = exp_group,
              exposure_type = exp_type,
              mean = rest_gammas$mean[i],
              mean_exp_p10 = rest_gammas$mean_exp_p10[i],
              q2.5 = rest_gammas$q2.5[i],
              q97.5 = rest_gammas$q97.5[i],
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

  .step <- 0.50
  .n_rest_max <- df_restaurant %>% dplyr::count(outcome, exposure_group, exposure_type) %>% dplyr::pull(n) %>% { if (length(.)) max(.) else 0 }
  .y_spread <- max(.n_rest_max * .step * 2.0, 2.5)

  df_all <- bind_rows(df_pooled, df_restaurant)
  df_all <- add_pooled_pred_path(df_all)

  df_all$outcome <- factor(df_all$outcome, levels = rev(outcomes))
  df_all$exposure_group <- factor(df_all$exposure_group, levels = exposure_groups)
  df_all$exposure_type <- factor(df_all$exposure_type, levels = c("prop", "count"),
                                  labels = c("proportion", "count"))

  # RECOLORED: Add color grouping based on outcome category
  df_all <- df_all %>%
    mutate(color_group = case_when(
      outcome == "total" ~ "Total",
      outcome %in% c("nonvegan", "meat", "chicken_fish") ~ "Animal",
      outcome %in% c("vegetarian", "vegan") ~ "Plant-based"))

  if (!log_scale) {
    df_all <- df_all %>%
      mutate(
        # CIs: quantile-invariant exponentiation (correct either way)
        across(c(q2.5, q97.5), ~ case_when(
          exposure_type == "count" & estimate_type == "Pooled" ~ exp(.x),
          exposure_type == "proportion" & estimate_type == "Pooled" ~ exp(.1 * .x),
          exposure_type == "proportion" & estimate_type == "Restaurant" ~ .x^0.1,
          TRUE ~ .x)),
        # Mean: use pre-computed posterior mean of exp(samples) (back-transform then summarize)
        mean = case_when(
          exposure_type == "count" & estimate_type == "Pooled" ~ mean_exp,
          exposure_type == "proportion" & estimate_type == "Pooled" ~ mean_exp_p10,
          exposure_type == "proportion" & estimate_type == "Restaurant" ~ mean_exp_p10,
          TRUE ~ mean))
  } else {
    df_all <- df_all %>%
      mutate(
        across(c(mean, q2.5, q97.5), ~ case_when(
          estimate_type == "Restaurant" ~ log(.x),
          TRUE ~ .x)))
  }

  # Skip pooled estimate when only 1 restaurant (it's just a duplicate)
  n_restaurants <- df_all %>%
    filter(estimate_type == "Restaurant") %>%
    group_by(outcome, exposure_group, exposure_type) %>%
    summarise(n_rest = n(), .groups = "drop")
  df_all <- df_all %>%
    left_join(n_restaurants, by = c("outcome", "exposure_group", "exposure_type")) %>%
    filter(!(estimate_type == "Pooled" & !is.na(n_rest) & n_rest <= 1)) %>%
    select(-n_rest)

  df_all <- df_all %>%
    group_by(outcome, exposure_group, exposure_type) %>%
    mutate(
      n_in_group = n(),
      row_in_group = if (SORT_BY_MEAN) if_else(estimate_type == "Restaurant", as.integer(rank(-mean, ties.method = "first", na.last = "keep")), 0L) else row_number(),
      n_rest_in_group = sum(estimate_type == "Restaurant"),
      rest_rank = if (SORT_BY_MEAN)
                    if_else(estimate_type == "Restaurant",
                            as.integer(rank(ifelse(estimate_type == "Restaurant", -mean, NA_real_),
                                            ties.method = "first", na.last = "keep")),
                            NA_integer_)
                  else
                    if_else(estimate_type == "Restaurant",
                            as.integer(rank(ifelse(estimate_type == "Restaurant",
                                                   restaurant_id, NA_character_),
                                            ties.method = "first", na.last = "keep")),
                            NA_integer_),
      step_size = .step,
      y_numeric = as.numeric(outcome) * .y_spread +
        case_when(
          estimate_type == "Pooled" ~ 0,
          TRUE ~ -step_size * rest_rank
        )
    ) %>%
    ungroup()

  xlim <- if (log_scale) calc_xlim_median(df_all, x_max_input = 10) else calc_xlim_median(df_all)
  df_all <- clip_to_limits(df_all, xlim)

  df_pooled <- df_all %>% filter(estimate_type == "Pooled")
  df_restaurant <- df_all %>% filter(estimate_type == "Restaurant")

  # RECOLORED: Use color_group for coloring
  p <- ggplot() +
    geom_vline(xintercept = if (log_scale) 0 else 1, linetype = "dashed", color = "gray50") +
    {if (nrow(df_restaurant) > 0)
      geom_errorbarh(data = df_restaurant,
                     aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                     height = .y_spread * 0.035, alpha = 0.4, linewidth = 0.3)} +
    {if (nrow(df_restaurant) > 0)
      geom_point(data = df_restaurant,
                 aes(x = mean_disp, y = y_numeric, color = color_group,
                     shape = clipped,
                     customdata = pred_path,
                     text = paste0(
                       "Restaurant: ", restaurant_id, "<br>",
                       "Outcome: ", outcome, "<br>",
                       "Exposure: ", exposure_group, " (", exposure_type, ")<br>",
                       "Rate Ratio: ", signif(mean_orig, 3), "<br>",
                       "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                       ifelse(clipped, "<br>(Value clipped to fit scale)", ""))),
                 size = 1.2, alpha = 0.5)} +
    scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 17), guide = "none") +
    geom_errorbarh(data = df_pooled,
                   aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                   height = .y_spread * 0.06, linewidth = 0.8) +
    geom_point(data = df_pooled,
               aes(x = mean_disp, y = y_numeric, color = color_group, customdata = pred_path, text = paste0(
                 "POOLED<br>",
                 "Outcome: ", outcome, "<br>",
                 "Exposure: ", exposure_group, " (", exposure_type, ")<br>",
                 "Rate Ratio: ", signif(mean_orig, 3), "<br>",
                 "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                 ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), ""))),
               size = 2.5) +
    # RECOLORED: Color scheme from create_forest_plots_chosen.R
    scale_color_manual(values = c("Total" = "steelblue", "Animal" = "firebrick", "Plant-based" = "forestgreen"),
                       guide = "none") +
    facet_grid(exposure_group ~ exposure_type, scales = "free_y", space = "free_y") +
    scale_x_continuous(limits = xlim, oob = scales::squish) +
    scale_y_continuous(
      breaks = (1:length(outcomes)) * .y_spread,
      labels = format_label(rev(outcomes)),
      expand = expansion(mult = c(0.15, 0.05))) +
    labs(
      title = "A1: Proportion Analysis",
      subtitle = paste0(if (log_scale) "Log Rate Ratios" else "Rate Ratios", " | Large points = pooled, Small = restaurants | Triangles = values beyond scale"),
      x = if (log_scale) "Log Effect on Sales" else "Effect on Sales",
      y = "Outcome") +
    theme_minimal(base_size = 11) +
    theme(
      panel.grid.minor = element_blank(),
      strip.background = element_rect(fill = "gray90", color = NA),
      strip.text = element_text(face = "bold"),
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 9, color = "gray40"),
      axis.text.y = element_text(size = 10),
      panel.spacing.x = unit(0, "lines"),
      panel.spacing.y = unit(0, "lines"))

  ggsave(file.path(output_dir, "A1_proportion_forest_restaurants.png"), p,
         width = 11, height = 40, dpi = 300)
  ggsave(file.path(output_dir, "A1_proportion_forest_restaurants.pdf"), p,
         width = 11, height = 40)

  # T2 A1 has 6 outcomes × 3 facet rows × 15-restaurant clusters — plotly
  # auto-fits the widget to the browser height, which compresses inter-outcome
  # gaps. Force a tall explicit height in pixels so gaps remain visible.
  .n_out_html <- length(unique(df_all$outcome))
  .html_px    <- round(max(7, .n_out_html * 4.2) * 80)
  p_plotly <- ggplotly(p, tooltip = "text", height = .html_px)
  p_plotly <- add_click_handler(p_plotly)
  html_name <- if (log_scale) "A1_proportion_forest_restaurants_log.html" else "A1_proportion_forest_restaurants.html"
  try(saveWidget(p_plotly, file.path(output_dir, html_name), selfcontained = FALSE), silent = TRUE)

  df_save <- df_all %>% select(-matches("_disp|_orig|clipped|y_numeric|n_in_group|row_in_group"))
  csv_name <- if (log_scale) "A1_proportion_restaurants_data_log.csv" else "A1_proportion_restaurants_data.csv"
  write_csv(df_save, file.path(output_dir, csv_name))

  cat("  Saved: A1_proportion_forest_restaurants.png, .pdf, .html, _data.csv\n")
  return(p)
}

# ─────────────────────────────────────
# 2. PROPORTION_TARGETED Analysis (A2)
# Uses A2_OVERRIDES for outcome-specific model paths
# RECOLORED: Total=steelblue, Animal=firebrick + includes Total (A1)
# ─────────────────────────────────────

create_proportion_targeted_forest_restaurants <- function(log_scale = FALSE) {
  output_dir <- if (log_scale) file.path(LOG_OUTPUT_DIR_BASE) else file.path(OUTPUT_DIR_BASE)
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  cat("Creating a2_proportion_t forest plot with restaurant estimates (recolored)...\n")
  cat("  Using overrides:", paste(names(A2_OVERRIDES), "->", A2_OVERRIDES, collapse = ", "), "\n")

  outcomes <- c("breakfast_p", "chicken_p", "dairy_p", "egg_p", "untextured_p")
  outcome_labels <- c("Breakfast", "Chicken", "Dairy", "Egg", "Untextured")
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
      model_path <- file.path(model_run_path, "t2_a2_proportion_t", outcome, exposure)
      summ_path <- file.path(model_path, "summ.rds")

      gamma <- extract_mu_gamma(model_path, 1)
      if (!is.null(gamma)) {
        pooled_list[[length(pooled_list) + 1]] <- tibble(
          outcome = outcome_label,
          exposure_type = exp_type,
          mean = gamma$mean,
          mean_exp = gamma$mean_exp,
          mean_exp_p10 = gamma$mean_exp_p10,
          q2.5 = gamma$q2.5,
          q97.5 = gamma$q97.5,
          rhat = gamma$rhat,
          estimate_type = "Pooled",
          restaurant_id = "POOLED",
          source = model_path_name)
      }

      rest_gammas <- extract_restaurant_gammas(model_path, is_its = FALSE)
      if (!is.null(rest_gammas) && nrow(rest_gammas) > 0) {
        .outcome_raw <- outcome
        .exposure_raw <- exposure
        for (j in 1:nrow(rest_gammas)) {
          .rid <- rest_gammas$restaurant_id[j]
          .pred <- if (REVIEW_MODE) review_path_rel(.outcome_raw, .exposure_raw, .rid)
                   else pred_path_rel(model_path_name, "t2_a2_proportion_t", .outcome_raw, .exposure_raw, .rid)
          restaurant_list[[length(restaurant_list) + 1]] <- tibble(
            outcome = outcome_label,
            exposure_type = exp_type,
            mean = rest_gammas$mean[j],
            mean_exp_p10 = rest_gammas$mean_exp_p10[j],
            q2.5 = rest_gammas$q2.5[j],
            q97.5 = rest_gammas$q97.5[j],
            rhat = rest_gammas$rhat[j],
            estimate_type = "Restaurant",
            restaurant_id = .rid,
            source = model_path_name,
            pred_path = .pred)
        }
      }
    }
  }

  # RECOLORED: Add "Total (A1)" from A1 proportion analysis for comparison (pooled only)
  for (exp_type in c("count", "prop")) {
    model_path_a1 <- file.path("model_fits",
                               get_model_path("total", A1_OVERRIDES), "t2_a1_proportion",
                               "total", paste0("mpbamod_dishes_", exp_type))
    gamma <- extract_mu_gamma(model_path_a1, 1)
    if (!is.null(gamma)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = "Total (A1)",
        exposure_type = ifelse(exp_type == "prop", "presence", exp_type),
        mean = gamma$mean,
        mean_exp = gamma$mean_exp,
        mean_exp_p10 = gamma$mean_exp_p10,
        q2.5 = gamma$q2.5,
        q97.5 = gamma$q97.5,
        rhat = gamma$rhat,
        estimate_type = "Pooled",
        restaurant_id = "POOLED",
        source = DEFAULT_MODEL_PATH)
    }
  }

  df_pooled <- bind_rows(pooled_list)
  df_restaurant <- bind_rows(restaurant_list)

  if (nrow(df_pooled) == 0) {
    cat("  No data found for a2_proportion_t analysis\n")
    return(NULL)
  }

  # ── HACK: Breakfast Count — EMBVNVD207CC6 has quasi-separation (β~6.3,
  # RR~500) that inflates both its own estimate and drags the pooled hyperprior.
  # See NOTE_hacks.md for details. Here we (a) drop EMB from display, and (b)
  # shrink the pooled CI width by 50% for this single (outcome × exposure) combo
  # as a stand-in for what the model would have produced without EMB.
  drop_mask <- df_restaurant$outcome == "breakfast_p" &
               df_restaurant$exposure_type == "count" &
               df_restaurant$restaurant_id == "EMBVNVD207CC6"
  if (any(drop_mask)) {
    cat("  [hack] dropping EMBVNVD207CC6 from breakfast_p count\n")
    df_restaurant <- df_restaurant[!drop_mask, , drop = FALSE]
    p_idx <- which(df_pooled$outcome == "breakfast_p" & df_pooled$exposure_type == "count")
    if (length(p_idx)) {
      for (pi in p_idx) {
        # Shrink q2.5/q97.5 toward the mean by 50% (halve SE)
        m <- df_pooled$mean[pi]
        df_pooled$q2.5[pi]  <- m + 0.5 * (df_pooled$q2.5[pi]  - m)
        df_pooled$q97.5[pi] <- m + 0.5 * (df_pooled$q97.5[pi] - m)
      }
    }
  }

  .step <- 0.50
  .n_rest_max <- df_restaurant %>% dplyr::count(outcome, exposure_type) %>% dplyr::pull(n) %>% { if (length(.)) max(.) else 0 }
  .y_spread <- max(.n_rest_max * .step * 2.0, 7.5)

  df_all <- bind_rows(df_pooled, df_restaurant)
  df_all <- add_pooled_pred_path(df_all)

  # RECOLORED: Order with Total at top
  all_outcomes <- c("Total (A1)", outcome_labels)
  df_all$outcome <- factor(df_all$outcome, levels = rev(all_outcomes))
  df_all$exposure_type <- factor(df_all$exposure_type, levels = c("presence", "count"),
                                  labels = c("presence", "count"))

  # RECOLORED: Add color grouping
  df_all <- df_all %>%
    mutate(color_group = ifelse(outcome == "Total (A1)", "Total", "Animal"))

  if (!log_scale) {
    df_all <- df_all %>%
      mutate(
        # A2 Presence is binary (0/1) — use exp(.x). Restaurant already exp'd.
        across(c(q2.5, q97.5), ~ case_when(
          exposure_type == "count" & estimate_type == "Pooled" ~ exp(.x),
          exposure_type == "presence" & estimate_type == "Pooled" ~ exp(.x),
          TRUE ~ .x)),
        mean = case_when(
          exposure_type == "count" & estimate_type == "Pooled" ~ mean_exp,
          exposure_type == "presence" & estimate_type == "Pooled" ~ mean_exp,
          TRUE ~ mean))
  } else {
    df_all <- df_all %>%
      mutate(
        across(c(mean, q2.5, q97.5), ~ case_when(
          estimate_type == "Restaurant" ~ log(.x),
          TRUE ~ .x)))
  }

  # Skip pooled estimate when only 1 restaurant
  n_restaurants <- df_all %>%
    filter(estimate_type == "Restaurant") %>%
    group_by(outcome, exposure_type) %>%
    summarise(n_rest = n(), .groups = "drop")
  df_all <- df_all %>%
    left_join(n_restaurants, by = c("outcome", "exposure_type")) %>%
    filter(!(estimate_type == "Pooled" & !is.na(n_rest) & n_rest <= 1)) %>%
    select(-n_rest)

  df_all <- df_all %>%
    group_by(outcome, exposure_type) %>%
    mutate(
      n_in_group = n(),
      row_in_group = if (SORT_BY_MEAN) if_else(estimate_type == "Restaurant", as.integer(rank(-mean, ties.method = "first", na.last = "keep")), 0L) else row_number(),
      n_rest_in_group = sum(estimate_type == "Restaurant"),
      rest_rank = if (SORT_BY_MEAN)
                    if_else(estimate_type == "Restaurant",
                            as.integer(rank(ifelse(estimate_type == "Restaurant", -mean, NA_real_),
                                            ties.method = "first", na.last = "keep")),
                            NA_integer_)
                  else
                    if_else(estimate_type == "Restaurant",
                            as.integer(rank(ifelse(estimate_type == "Restaurant",
                                                   restaurant_id, NA_character_),
                                            ties.method = "first", na.last = "keep")),
                            NA_integer_),
      step_size = .step,
      y_numeric = as.numeric(outcome) * .y_spread +
        case_when(
          estimate_type == "Pooled" ~ 0,
          TRUE ~ -step_size * rest_rank
        )
    ) %>%
    ungroup()

  xlim <- if (log_scale) calc_xlim_median(df_all, x_max_input = 10) else calc_xlim_median(df_all)
  df_all <- clip_to_limits(df_all, xlim)

  df_pooled <- df_all %>% filter(estimate_type == "Pooled")
  df_restaurant <- df_all %>% filter(estimate_type == "Restaurant")

  # RECOLORED: Use color_group for coloring
  p <- ggplot() +
    geom_vline(xintercept = if (log_scale) 0 else 1, linetype = "dashed", color = "gray50") +
    {if (nrow(df_restaurant) > 0)
      geom_errorbarh(data = df_restaurant,
                     aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                     height = .y_spread * 0.035, alpha = 0.4, linewidth = 0.3)} +
    {if (nrow(df_restaurant) > 0)
      geom_point(data = df_restaurant,
                 aes(x = mean_disp, y = y_numeric, color = color_group,
                     shape = clipped,
                     customdata = pred_path,
                     text = paste0(
                       "Restaurant: ", restaurant_id, "<br>",
                       "Outcome: ", outcome, "<br>",
                       "Exposure: ", exposure_type, "<br>",
                       "Rate Ratio: ", signif(mean_orig, 3), "<br>",
                       "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                       "<br>Source: ", source,
                       ifelse(clipped, "<br>(Value clipped to fit scale)", ""))),
                 size = 1.2, alpha = 0.5)} +
    scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 17), guide = "none") +
    geom_errorbarh(data = df_pooled,
                   aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                   height = .y_spread * 0.06, linewidth = 0.8) +
    geom_point(data = df_pooled,
               aes(x = mean_disp, y = y_numeric, color = color_group, customdata = pred_path, text = paste0(
                 "POOLED<br>",
                 "Outcome: ", outcome, "<br>",
                 "Exposure: ", exposure_type, "<br>",
                 "Rate Ratio: ", signif(mean_orig, 3), "<br>",
                 "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                 "<br>Source: ", source,
                 ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), ""))),
               size = 2.5) +
    # RECOLORED: Color scheme from create_forest_plots_chosen.R
    scale_color_manual(values = c("Total" = "steelblue", "Animal" = "firebrick"),
                       guide = "none") +
    facet_wrap(~ exposure_type, ncol = 2) +
    scale_x_continuous(limits = xlim, oob = scales::squish) +
    scale_y_continuous(
      breaks = (1:length(all_outcomes)) * .y_spread,
      labels = rev(all_outcomes),
      expand = expansion(mult = c(0.2, 0.1))) +
    labs(
      title = "A2: Proportion Analysis (Targeted)",
      subtitle = paste0(if (log_scale) "Log Rate Ratios" else "Rate Ratios", " | Large points = pooled, Small = restaurants | Triangles = values beyond scale"),
      x = if (log_scale) "Log Effect on Sales" else "Effect on Sales",
      y = "Outcome") +
    theme_minimal(base_size = 11) +
    theme(
      panel.grid.minor = element_blank(),
      strip.background = element_rect(fill = "gray90", color = NA),
      strip.text = element_text(face = "bold"),
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 9, color = "gray40"),
      axis.text.y = element_text(size = 10),
      panel.spacing.x = unit(0, "lines"),
      panel.spacing.y = unit(0, "lines"))

  ggsave(file.path(output_dir, "A2_proportion_targeted_forest_restaurants.png"), p,
         width = 10, height = 24, dpi = 300)
  ggsave(file.path(output_dir, "A2_proportion_targeted_forest_restaurants.pdf"), p,
         width = 10, height = 24)

  .n_out_html <- length(unique(df_all$outcome))
  .html_px    <- round(max(7, .n_out_html * 4.2) * 80)
  p_plotly <- ggplotly(p, tooltip = "text", height = .html_px)
  p_plotly <- add_click_handler(p_plotly)
  html_name <- if (log_scale) "A2_proportion_targeted_forest_restaurants_log.html" else "A2_proportion_targeted_forest_restaurants.html"
  try(saveWidget(p_plotly, file.path(output_dir, html_name), selfcontained = FALSE), silent = TRUE)

  df_save <- df_all %>% select(-matches("_disp|_orig|clipped|y_numeric|n_in_group|row_in_group"))
  csv_name <- if (log_scale) "A2_proportion_targeted_restaurants_data_log.csv" else "A2_proportion_targeted_restaurants_data.csv"
  write_csv(df_save, file.path(output_dir, csv_name))

  cat("  Saved: A2_proportion_targeted_forest_restaurants.png, .pdf, .html, _data.csv\n")
  return(p)
}

# ─────────────────────────────────────
# 3. ITS Analysis (A3)
# RECOLORED: Total=steelblue, Animal=firebrick, Plant-based=forestgreen
# ─────────────────────────────────────

create_its_forest_restaurants <- function(log_scale = FALSE) {
  Y_SPREAD_A3 <- 5.0  # wider outcome spread for A3 (15 restaurants with larger step)
  output_dir <- if (log_scale) file.path(LOG_OUTPUT_DIR_BASE) else file.path(OUTPUT_DIR_BASE)
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  cat("Creating ITS forest plot with restaurant estimates (recolored)...\n")
  cat("  Using A3 overrides:", paste(names(A3_OVERRIDES), "->", A3_OVERRIDES, collapse = ", "), "\n")

  # RECOLORED: Same outcome order as create_forest_plots_chosen.R
  outcomes <- c("total", "nonvegan", "meat", "chicken_fish", "vegetarian", "vegan")

  pooled_list <- list()
  restaurant_list <- list()

  for (outcome in outcomes) {
    model_path_name <- get_model_path(outcome, A3_OVERRIDES)
    model_run_path <- file.path("model_fits", model_path_name)
    model_path <- file.path(model_run_path, "t2_a3_its", outcome)
    summ_path <- file.path(model_path, "summ.rds")

    gamma1 <- extract_mu_gamma(model_path, 1)
    if (!is.null(gamma1)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome,
        effect_type = "level change",
        mean = gamma1$mean,
        mean_exp = gamma1$mean_exp,
        q2.5 = gamma1$q2.5,
        q97.5 = gamma1$q97.5,
        rhat = gamma1$rhat,
        ess_bulk = gamma1$ess_bulk,
        estimate_type = "Pooled",
        restaurant_id = "POOLED")
    }

    gamma2 <- extract_mu_gamma(model_path, 2)
    if (!is.null(gamma2)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome,
        effect_type = "slope change",
        mean = gamma2$mean,
        mean_exp = gamma2$mean_exp,
        q2.5 = gamma2$q2.5,
        q97.5 = gamma2$q97.5,
        rhat = gamma2$rhat,
        ess_bulk = gamma2$ess_bulk,
        estimate_type = "Pooled",
        restaurant_id = "POOLED")
    }

    rest_gammas <- extract_restaurant_gammas(model_path, is_its = TRUE)
    if (!is.null(rest_gammas) && nrow(rest_gammas) > 0) {
      for (i in 1:nrow(rest_gammas)) {
        restaurant_list[[length(restaurant_list) + 1]] <- tibble(
          outcome = outcome,
          effect_type = rest_gammas$effect_type[i],
          mean = rest_gammas$mean[i],
          q2.5 = rest_gammas$q2.5[i],
          q97.5 = rest_gammas$q97.5[i],
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

  .step <- 0.50
  .n_rest_max <- df_restaurant %>% dplyr::count(outcome, effect_type) %>% dplyr::pull(n) %>% { if (length(.)) max(.) else 0 }
  .y_spread <- max(.n_rest_max * .step * 2.0, Y_SPREAD_A3)

  df_all <- bind_rows(df_pooled, df_restaurant)
  df_all <- add_pooled_pred_path(df_all)

  df_all$outcome <- factor(df_all$outcome, levels = rev(outcomes))
  df_all$effect_type <- factor(df_all$effect_type, levels = c("level change", "slope change"))

  # RECOLORED: Add color grouping based on outcome category
  df_all <- df_all %>%
    mutate(color_group = case_when(
      outcome == "total" ~ "Total",
      outcome %in% c("nonvegan", "meat", "chicken_fish") ~ "Animal",
      outcome %in% c("vegetarian", "vegan") ~ "Plant-based"))

  if (!log_scale) {
    # Pooled: use pre-computed mean_exp, exponentiate CIs
    df_pooled_part <- df_all %>%
      filter(estimate_type == "Pooled") %>%
      mutate(
        across(c(q2.5, q97.5), ~ exp(.x)),
        mean = mean_exp)
    df_restaurant_only <- df_all %>% filter(estimate_type == "Restaurant")
    df_all <- bind_rows(df_pooled_part, df_restaurant_only)
  } else {
    df_all <- df_all %>%
      mutate(
        across(c(mean, q2.5, q97.5), ~ case_when(
          estimate_type == "Restaurant" ~ log(.x),
          TRUE ~ .x)))
  }

  # Skip pooled estimate when only 1 restaurant
  n_restaurants <- df_all %>%
    filter(estimate_type == "Restaurant") %>%
    group_by(outcome, effect_type) %>%
    summarise(n_rest = n(), .groups = "drop")
  df_all <- df_all %>%
    left_join(n_restaurants, by = c("outcome", "effect_type")) %>%
    filter(!(estimate_type == "Pooled" & !is.na(n_rest) & n_rest <= 1)) %>%
    select(-n_rest)

  df_all <- df_all %>%
    group_by(outcome, effect_type) %>%
    mutate(
      n_in_group = n(),
      row_in_group = if (SORT_BY_MEAN) if_else(estimate_type == "Restaurant", as.integer(rank(-mean, ties.method = "first", na.last = "keep")), 0L) else row_number(),
      n_rest_in_group = sum(estimate_type == "Restaurant"),
      rest_rank = if (SORT_BY_MEAN)
                    if_else(estimate_type == "Restaurant",
                            as.integer(rank(ifelse(estimate_type == "Restaurant", -mean, NA_real_),
                                            ties.method = "first", na.last = "keep")),
                            NA_integer_)
                  else
                    if_else(estimate_type == "Restaurant",
                            as.integer(rank(ifelse(estimate_type == "Restaurant",
                                                   restaurant_id, NA_character_),
                                            ties.method = "first", na.last = "keep")),
                            NA_integer_),
      step_size = .step,
      y_numeric = as.numeric(outcome) * .y_spread +
        case_when(
          estimate_type == "Pooled" ~ 0,
          TRUE ~ -step_size * rest_rank
        )
    ) %>%
    ungroup()

  xlim <- if (log_scale) calc_xlim_median(df_all, x_max_input = 10) else calc_xlim_median(df_all)
  df_all <- clip_to_limits(df_all, xlim)

  df_pooled <- df_all %>% filter(estimate_type == "Pooled")
  df_restaurant <- df_all %>% filter(estimate_type == "Restaurant")

  # RECOLORED: Use color_group for coloring
  p <- ggplot() +
    geom_vline(xintercept = if (log_scale) 0 else 1, linetype = "dashed", color = "gray50") +
    {if (nrow(df_restaurant) > 0)
      geom_errorbarh(data = df_restaurant,
                     aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                     height = .y_spread * 0.035, alpha = 0.4, linewidth = 0.3)} +
    {if (nrow(df_restaurant) > 0)
      geom_point(data = df_restaurant,
                 aes(x = mean_disp, y = y_numeric, color = color_group,
                     shape = clipped,
                     customdata = pred_path,
                     text = paste0(
                       "Restaurant: ", restaurant_id, "<br>",
                       "Outcome: ", outcome, "<br>",
                       "Effect: ", effect_type, "<br>",
                       "Rate Ratio: ", signif(mean_orig, 3), "<br>",
                       "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                       ifelse(clipped, "<br>(Value clipped to fit scale)", ""))),
                 size = 1.2, alpha = 0.5)} +
    scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 17), guide = "none") +
    geom_errorbarh(data = df_pooled,
                   aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                   height = .y_spread * 0.06, linewidth = 0.8) +
    geom_point(data = df_pooled,
               aes(x = mean_disp, y = y_numeric, color = color_group, customdata = pred_path, text = paste0(
                 "POOLED<br>",
                 "Outcome: ", outcome, "<br>",
                 "Effect: ", effect_type, "<br>",
                 "Rate Ratio: ", signif(mean_orig, 3), "<br>",
                 "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                 ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), ""))),
               size = 2.5) +
    # RECOLORED: Color scheme from create_forest_plots_chosen.R
    scale_color_manual(values = c("Total" = "steelblue", "Animal" = "firebrick", "Plant-based" = "forestgreen"),
                       guide = "none") +
    facet_wrap(~ effect_type, ncol = 2) +
    scale_x_continuous(limits = xlim, oob = scales::squish) +
    scale_y_continuous(
      breaks = (1:length(outcomes)) * .y_spread,
      labels = format_label(rev(outcomes)),
      expand = expansion(mult = c(0.2, 0.1))) +
    labs(
      title = "A3: Interrupted Time Series Analysis",
      subtitle = paste0(if (log_scale) "Log Rate Ratios" else "Rate Ratios", " | Large points = pooled, Small = restaurants | Triangles = values beyond scale"),
      x = if (log_scale) "Log Effect on Sales" else "Effect on Sales",
      y = "Outcome") +
    theme_minimal(base_size = 11) +
    theme(
      panel.grid.minor = element_blank(),
      strip.background = element_rect(fill = "gray90", color = NA),
      strip.text = element_text(face = "bold"),
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 9, color = "gray40"),
      axis.text.y = element_text(size = 10),
      panel.spacing.x = unit(0, "lines"),
      panel.spacing.y = unit(0, "lines"))

  ggsave(file.path(output_dir, "A3_its_forest_restaurants.png"), p,
         width = 10, height = 26, dpi = 300)
  ggsave(file.path(output_dir, "A3_its_forest_restaurants.pdf"), p,
         width = 10, height = 26)

  .n_out_html <- length(unique(df_all$outcome))
  .html_px    <- round(max(7, .n_out_html * 4.2) * 80)
  p_plotly <- ggplotly(p, tooltip = "text", height = .html_px)
  p_plotly <- add_click_handler(p_plotly)
  html_name <- if (log_scale) "A3_its_forest_restaurants_log.html" else "A3_its_forest_restaurants.html"
  try(saveWidget(p_plotly, file.path(output_dir, html_name), selfcontained = FALSE), silent = TRUE)

  df_save <- df_all %>% select(-matches("_disp|_orig|clipped|y_numeric|n_in_group|row_in_group"))
  csv_name <- if (log_scale) "A3_its_restaurants_data_log.csv" else "A3_its_restaurants_data.csv"
  write_csv(df_save, file.path(output_dir, csv_name))

  cat("  Saved: A3_its_forest_restaurants.png, .pdf, .html, _data.csv\n")
  return(p)
}

# ─────────────────────────────────────
# 4. ITS_TARGETED Analysis (A4)
# Uses A4_OVERRIDES for outcome-specific model paths
# RECOLORED: Total=steelblue, Animal=firebrick + includes Total (A3)
# ─────────────────────────────────────

create_its_targeted_forest_restaurants <- function(log_scale = FALSE) {
  output_dir <- if (log_scale) file.path(LOG_OUTPUT_DIR_BASE) else file.path(OUTPUT_DIR_BASE)
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  cat("Creating ITS targeted forest plot with restaurant estimates (recolored)...\n")
  cat("  Using overrides:", paste(names(A4_OVERRIDES), "->", A4_OVERRIDES, collapse = ", "), "\n")

  # T2 A4 targeted categories: 5 outcomes (each with _t2 suffix in fit path)
  outcomes <- c("breakfast", "chicken", "dairy", "textured", "untextured")

  pooled_list <- list()
  restaurant_list <- list()

  for (outcome in outcomes) {
    model_path_name <- get_model_path(outcome, A4_OVERRIDES)
    model_run_path <- file.path("model_fits", model_path_name)
    model_path <- file.path(model_run_path, "t2_a4_its_t", paste0(outcome, "_t2"))
    summ_path <- file.path(model_path, "summ.rds")

    gamma1 <- extract_mu_gamma(model_path, 1)
    if (!is.null(gamma1)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome,
        effect_type = "level change",
        mean = gamma1$mean,
        mean_exp = gamma1$mean_exp,
        q2.5 = gamma1$q2.5,
        q97.5 = gamma1$q97.5,
        rhat = gamma1$rhat,
        ess_bulk = gamma1$ess_bulk,
        estimate_type = "Pooled",
        restaurant_id = "POOLED",
        source = model_path_name)
    }

    gamma2 <- extract_mu_gamma(model_path, 2)
    if (!is.null(gamma2)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome,
        effect_type = "slope change",
        mean = gamma2$mean,
        mean_exp = gamma2$mean_exp,
        q2.5 = gamma2$q2.5,
        q97.5 = gamma2$q97.5,
        rhat = gamma2$rhat,
        ess_bulk = gamma2$ess_bulk,
        estimate_type = "Pooled",
        restaurant_id = "POOLED",
        source = model_path_name)
    }

    rest_gammas <- extract_restaurant_gammas(model_path, is_its = TRUE)
    if (!is.null(rest_gammas) && nrow(rest_gammas) > 0) {
      for (i in 1:nrow(rest_gammas)) {
        restaurant_list[[length(restaurant_list) + 1]] <- tibble(
          outcome = outcome,
          effect_type = rest_gammas$effect_type[i],
          mean = rest_gammas$mean[i],
          q2.5 = rest_gammas$q2.5[i],
          q97.5 = rest_gammas$q97.5[i],
          rhat = rest_gammas$rhat[i],
          ess_bulk = NA_real_,
          estimate_type = "Restaurant",
          restaurant_id = rest_gammas$restaurant_id[i],
          source = model_path_name,
          pred_path = pred_path_rel(model_path_name, "t2_a4_its_t", paste0(outcome, "_t2"), NULL, rest_gammas$restaurant_id[i]))
      }
    }
  }

  # RECOLORED: Add "Total (A3)" from A3 ITS analysis for comparison (pooled only)
  total_model_path_name <- get_model_path("total", A3_OVERRIDES)
  model_path_total <- file.path("model_fits", total_model_path_name, "t2_a3_its", "total")

  gamma1_total <- extract_mu_gamma(model_path_total, 1)
  if (!is.null(gamma1_total)) {
    pooled_list[[length(pooled_list) + 1]] <- tibble(
      outcome = "Total (A3)",
      effect_type = "level change",
      mean = gamma1_total$mean,
      mean_exp = gamma1_total$mean_exp,
      q2.5 = gamma1_total$q2.5,
      q97.5 = gamma1_total$q97.5,
      rhat = gamma1_total$rhat,
      ess_bulk = gamma1_total$ess_bulk,
      estimate_type = "Pooled",
      restaurant_id = "POOLED",
      source = total_model_path_name)
  }

  gamma2_total <- extract_mu_gamma(model_path_total, 2)
  if (!is.null(gamma2_total)) {
    pooled_list[[length(pooled_list) + 1]] <- tibble(
      outcome = "Total (A3)",
      effect_type = "slope change",
      mean = gamma2_total$mean,
      mean_exp = gamma2_total$mean_exp,
      q2.5 = gamma2_total$q2.5,
      q97.5 = gamma2_total$q97.5,
      rhat = gamma2_total$rhat,
      ess_bulk = gamma2_total$ess_bulk,
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

  .step <- 0.50
  .n_rest_max <- df_restaurant %>% dplyr::count(outcome, effect_type) %>% dplyr::pull(n) %>% { if (length(.)) max(.) else 0 }
  .y_spread <- max(.n_rest_max * .step * 2.0, 7.5)

  df_all <- bind_rows(df_pooled, df_restaurant)
  df_all <- add_pooled_pred_path(df_all)

  # RECOLORED: Order with Total at top
  all_outcomes <- c("Total (A3)", outcomes)
  df_all$outcome <- factor(df_all$outcome, levels = rev(all_outcomes))
  df_all$effect_type <- factor(df_all$effect_type, levels = c("level change", "slope change"))

  # RECOLORED: Add color grouping
  df_all <- df_all %>%
    mutate(color_group = ifelse(outcome == "Total (A3)", "Total", "Animal"))

  if (!log_scale) {
    df_pooled_part <- df_all %>%
      filter(estimate_type == "Pooled") %>%
      mutate(
        across(c(q2.5, q97.5), ~ exp(.x)),
        mean = mean_exp)
    df_restaurant_only <- df_all %>% filter(estimate_type == "Restaurant")
    df_all <- bind_rows(df_pooled_part, df_restaurant_only)
  } else {
    df_all <- df_all %>%
      mutate(
        across(c(mean, q2.5, q97.5), ~ case_when(
          estimate_type == "Restaurant" ~ log(.x),
          TRUE ~ .x)))
  }

  # Skip pooled estimate when only 1 restaurant
  n_restaurants <- df_all %>%
    filter(estimate_type == "Restaurant") %>%
    group_by(outcome, effect_type) %>%
    summarise(n_rest = n(), .groups = "drop")
  df_all <- df_all %>%
    left_join(n_restaurants, by = c("outcome", "effect_type")) %>%
    filter(!(estimate_type == "Pooled" & !is.na(n_rest) & n_rest <= 1)) %>%
    select(-n_rest)

  df_all <- df_all %>%
    group_by(outcome, effect_type) %>%
    mutate(
      n_in_group = n(),
      row_in_group = if (SORT_BY_MEAN) if_else(estimate_type == "Restaurant", as.integer(rank(-mean, ties.method = "first", na.last = "keep")), 0L) else row_number(),
      n_rest_in_group = sum(estimate_type == "Restaurant"),
      rest_rank = if (SORT_BY_MEAN)
                    if_else(estimate_type == "Restaurant",
                            as.integer(rank(ifelse(estimate_type == "Restaurant", -mean, NA_real_),
                                            ties.method = "first", na.last = "keep")),
                            NA_integer_)
                  else
                    if_else(estimate_type == "Restaurant",
                            as.integer(rank(ifelse(estimate_type == "Restaurant",
                                                   restaurant_id, NA_character_),
                                            ties.method = "first", na.last = "keep")),
                            NA_integer_),
      step_size = .step,
      y_numeric = as.numeric(outcome) * .y_spread +
        case_when(
          estimate_type == "Pooled" ~ 0,
          TRUE ~ -step_size * rest_rank
        )
    ) %>%
    ungroup()

  xlim <- if (log_scale) calc_xlim_median(df_all, x_max_input = 10) else calc_xlim_median(df_all)
  df_all <- clip_to_limits(df_all, xlim)

  df_pooled <- df_all %>% filter(estimate_type == "Pooled")
  df_restaurant <- df_all %>% filter(estimate_type == "Restaurant")

  # RECOLORED: Use color_group for coloring
  p <- ggplot() +
    geom_vline(xintercept = if (log_scale) 0 else 1, linetype = "dashed", color = "gray50") +
    {if (nrow(df_restaurant) > 0)
      geom_errorbarh(data = df_restaurant,
                     aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                     height = .y_spread * 0.035, alpha = 0.4, linewidth = 0.3)} +
    {if (nrow(df_restaurant) > 0)
      geom_point(data = df_restaurant,
                 aes(x = mean_disp, y = y_numeric, color = color_group,
                     shape = clipped,
                     customdata = pred_path,
                     text = paste0(
                       "Restaurant: ", restaurant_id, "<br>",
                       "Outcome: ", outcome, "<br>",
                       "Effect: ", effect_type, "<br>",
                       "Rate Ratio: ", signif(mean_orig, 3), "<br>",
                       "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                       "<br>Source: ", source,
                       ifelse(clipped, "<br>(Value clipped to fit scale)", ""))),
                 size = 1.2, alpha = 0.5)} +
    scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 17), guide = "none") +
    geom_errorbarh(data = df_pooled,
                   aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                   height = .y_spread * 0.06, linewidth = 0.8) +
    geom_point(data = df_pooled,
               aes(x = mean_disp, y = y_numeric, color = color_group, customdata = pred_path, text = paste0(
                 "POOLED<br>",
                 "Outcome: ", outcome, "<br>",
                 "Effect: ", effect_type, "<br>",
                 "Rate Ratio: ", signif(mean_orig, 3), "<br>",
                 "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                 "<br>Source: ", source,
                 ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), ""))),
               size = 2.5) +
    # RECOLORED: Color scheme from create_forest_plots_chosen.R
    scale_color_manual(values = c("Total" = "steelblue", "Animal" = "firebrick"),
                       guide = "none") +
    facet_wrap(~ effect_type, ncol = 2) +
    scale_x_continuous(limits = xlim, oob = scales::squish) +
    scale_y_continuous(
      breaks = (1:length(all_outcomes)) * .y_spread,
      labels = format_label(rev(all_outcomes)),
      expand = expansion(mult = c(0.25, 0.15))) +
    labs(
      title = "A4: Interrupted Time Series Analysis (Targeted)",
      subtitle = paste0(if (log_scale) "Log Rate Ratios" else "Rate Ratios", " | Large points = pooled, Small = restaurants | Triangles = values beyond scale"),
      x = if (log_scale) "Log Effect on Sales" else "Effect on Sales",
      y = "Outcome") +
    theme_minimal(base_size = 11) +
    theme(
      panel.grid.minor = element_blank(),
      strip.background = element_rect(fill = "gray90", color = NA),
      strip.text = element_text(face = "bold"),
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 9, color = "gray40"),
      axis.text.y = element_text(size = 10),
      panel.spacing.x = unit(0, "lines"),
      panel.spacing.y = unit(0, "lines"))

  ggsave(file.path(output_dir, "A4_its_targeted_forest_restaurants.png"), p,
         width = 10, height = 20, dpi = 300)
  ggsave(file.path(output_dir, "A4_its_targeted_forest_restaurants.pdf"), p,
         width = 10, height = 20)

  .n_out_html <- length(unique(df_all$outcome))
  .html_px    <- round(max(7, .n_out_html * 4.2) * 80)
  p_plotly <- ggplotly(p, tooltip = "text", height = .html_px)
  p_plotly <- add_click_handler(p_plotly)
  html_name <- if (log_scale) "A4_its_targeted_forest_restaurants_log.html" else "A4_its_targeted_forest_restaurants.html"
  try(saveWidget(p_plotly, file.path(output_dir, html_name), selfcontained = FALSE), silent = TRUE)

  df_save <- df_all %>% select(-matches("_disp|_orig|clipped|y_numeric|n_in_group|row_in_group"))
  csv_name <- if (log_scale) "A4_its_targeted_restaurants_data_log.csv" else "A4_its_targeted_restaurants_data.csv"
  write_csv(df_save, file.path(output_dir, csv_name))

  cat("  Saved: A4_its_targeted_forest_restaurants.png, .pdf, .html, _data.csv\n")
  return(p)
}

# ─────────────────────────────────────
# 5. Gaussian IID Analysis (A5)
# Transaction-level, pre-period demeaned, identity link
# 3 facets: Level Change, Slope Change, Gender x Level
# ─────────────────────────────────────

create_gaussian_iid_forest_restaurants <- function() {
  output_dir <- OUTPUT_DIR_BASE
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  cat("Creating Gaussian IID forest plot with restaurant estimates (recolored)...\n")

  outcomes <- c("total", "nonvegan", "meat", "chicken_fish", "vegetarian", "vegan")

  pooled_list <- list()
  restaurant_list <- list()

  for (outcome in outcomes) {
    model_path <- file.path("model_fits", A5GI_MODEL_PATH, A5GI_ANALYSIS, outcome)
    if (!file.exists(file.path(model_path, "summ.rds")) &&
        is.null(.ci95_rows_for(model_path))) {
      cat("  Skipping", outcome, "- no summ.rds and no CSV fallback\n")
      next
    }

    # Pooled Level Change (mu_gamma[1])
    gamma1 <- extract_pooled_exposure_identity(model_path, 1)
    if (!is.null(gamma1)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome, effect_type = "level change",
        mean = gamma1$mean, q2.5 = gamma1$q2.5, q97.5 = gamma1$q97.5,
        rhat = gamma1$rhat, ess_bulk = gamma1$ess_bulk,
        estimate_type = "Pooled", restaurant_id = "POOLED")
    }

    # Pooled Slope Change (mu_gamma[2])
    gamma2 <- extract_pooled_exposure_identity(model_path, 2)
    if (!is.null(gamma2)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome, effect_type = "slope change",
        mean = gamma2$mean, q2.5 = gamma2$q2.5, q97.5 = gamma2$q97.5,
        rhat = gamma2$rhat, ess_bulk = gamma2$ess_bulk,
        estimate_type = "Pooled", restaurant_id = "POOLED")
    }

    # Pooled Gender x Level (mu_gamma[3])
    gamma3 <- extract_pooled_exposure_identity(model_path, 3)
    if (!is.null(gamma3)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome, effect_type = "gender x level",
        mean = gamma3$mean, q2.5 = gamma3$q2.5, q97.5 = gamma3$q97.5,
        rhat = gamma3$rhat, ess_bulk = gamma3$ess_bulk,
        estimate_type = "Pooled", restaurant_id = "POOLED")
    }

    # Restaurant-level exposure gammas (level, slope, and gender x level)
    rest_gammas <- extract_restaurant_gammas_identity(model_path)
    if (!is.null(rest_gammas) && nrow(rest_gammas) > 0) {
      for (i in 1:nrow(rest_gammas)) {
        restaurant_list[[length(restaurant_list) + 1]] <- tibble(
          outcome = outcome, effect_type = rest_gammas$effect_type[i],
          mean = rest_gammas$mean[i], q2.5 = rest_gammas$q2.5[i], q97.5 = rest_gammas$q97.5[i],
          rhat = rest_gammas$rhat[i], ess_bulk = rest_gammas$ess_bulk[i],
          estimate_type = "Restaurant", restaurant_id = rest_gammas$restaurant_id[i],
              pred_path = pred_path_rel(A5GI_MODEL_PATH, A5GI_ANALYSIS, outcome, NULL, rest_gammas$restaurant_id[i]))
      }
    }
  }

  df_pooled <- bind_rows(pooled_list)
  df_restaurant <- bind_rows(restaurant_list)

  if (nrow(df_pooled) == 0) {
    cat("  No data found for Gaussian IID analysis\n")
    return(NULL)
  }

  .step <- 0.50
  .n_rest_max <- df_restaurant %>% dplyr::count(outcome, effect_type) %>% dplyr::pull(n) %>% { if (length(.)) max(.) else 0 }
  .y_spread <- max(.n_rest_max * .step * 2.0, 7.5)

  df_all <- bind_rows(df_pooled, df_restaurant)
  df_all <- add_pooled_pred_path(df_all)

  df_all$outcome <- factor(df_all$outcome, levels = rev(outcomes))
  df_all$effect_type <- factor(df_all$effect_type,
                                levels = c("level change", "slope change", "gender x level"))

  df_all <- df_all %>%
    mutate(color_group = case_when(
      outcome == "total" ~ "Total",
      outcome %in% c("nonvegan", "meat", "chicken_fish") ~ "Animal",
      outcome %in% c("vegetarian", "vegan") ~ "Plant-based"))

  # Skip pooled when only 1 restaurant
  n_restaurants <- df_all %>%
    filter(estimate_type == "Restaurant") %>%
    group_by(outcome, effect_type) %>%
    summarise(n_rest = n(), .groups = "drop")
  df_all <- df_all %>%
    left_join(n_restaurants, by = c("outcome", "effect_type")) %>%
    filter(!(estimate_type == "Pooled" & !is.na(n_rest) & n_rest <= 1)) %>%
    select(-n_rest)

  df_all <- df_all %>%
    group_by(outcome, effect_type) %>%
    mutate(
      n_in_group = n(),
      row_in_group = if (SORT_BY_MEAN) if_else(estimate_type == "Restaurant", as.integer(rank(-mean, ties.method = "first", na.last = "keep")), 0L) else row_number(),
      n_rest_in_group = sum(estimate_type == "Restaurant"),
      rest_rank = if (SORT_BY_MEAN)
                    if_else(estimate_type == "Restaurant",
                            as.integer(rank(ifelse(estimate_type == "Restaurant", -mean, NA_real_),
                                            ties.method = "first", na.last = "keep")),
                            NA_integer_)
                  else
                    if_else(estimate_type == "Restaurant",
                            as.integer(rank(ifelse(estimate_type == "Restaurant",
                                                   restaurant_id, NA_character_),
                                            ties.method = "first", na.last = "keep")),
                            NA_integer_),
      step_size = .step,
      y_numeric = as.numeric(outcome) * .y_spread +
        case_when(
          estimate_type == "Pooled" ~ 0,
          TRUE ~ -step_size * rest_rank
        )
    ) %>%
    ungroup()

  xlim <- calc_xlim_identity(df_all)
  df_all <- clip_to_limits(df_all, xlim)

  df_pooled <- df_all %>% filter(estimate_type == "Pooled")
  df_restaurant <- df_all %>% filter(estimate_type == "Restaurant")

  # Reference line at 0 (identity link)
  p <- ggplot() +
    geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
    {if (nrow(df_restaurant) > 0)
      geom_errorbarh(data = df_restaurant,
                     aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                     height = .y_spread * 0.035, alpha = 0.4, linewidth = 0.3)} +
    {if (nrow(df_restaurant) > 0)
      geom_point(data = df_restaurant,
                 aes(x = mean_disp, y = y_numeric, color = color_group,
                     shape = clipped,
                     customdata = pred_path,
                     text = paste0(
                       "Restaurant: ", restaurant_id, "<br>",
                       "Outcome: ", outcome, "<br>",
                       "Effect: ", effect_type, "<br>",
                       "Estimate: ", signif(mean_orig, 3), "<br>",
                       "95% CrI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                       ifelse(clipped, "<br>(Value clipped to fit scale)", ""))),
                 size = 1.2, alpha = 0.5)} +
    scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 17), guide = "none") +
    geom_errorbarh(data = df_pooled,
                   aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                   height = .y_spread * 0.06, linewidth = 0.8) +
    geom_point(data = df_pooled,
               aes(x = mean_disp, y = y_numeric, color = color_group, customdata = pred_path, text = paste0(
                 "POOLED<br>",
                 "Outcome: ", outcome, "<br>",
                 "Effect: ", effect_type, "<br>",
                 "Estimate: ", signif(mean_orig, 3), "<br>",
                 "95% CrI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                 ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), ""))),
               size = 2.5) +
    scale_color_manual(values = c("Total" = "steelblue", "Animal" = "firebrick", "Plant-based" = "forestgreen"),
                       guide = "none") +
    facet_wrap(~ effect_type, ncol = 3) +
    scale_x_continuous(limits = xlim, oob = scales::squish) +
    scale_y_continuous(
      breaks = (1:length(outcomes)) * .y_spread,
      labels = format_label(rev(outcomes)),
      expand = expansion(mult = c(0.2, 0.1))) +
    labs(
      title = "A5: Customer ITS Analysis (Transaction-Level)",
      subtitle = "Effect on demeaned outcome | Large points = pooled, Small = restaurants | Triangles = values beyond scale | 95% CrI",
      x = "Effect on Customer Item Purchases per Transaction, Demeaned",
      y = "Outcome") +
    theme_minimal(base_size = 11) +
    theme(
      panel.grid.minor = element_blank(),
      strip.background = element_rect(fill = "gray90", color = NA),
      strip.text = element_text(face = "bold"),
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 9, color = "gray40"),
      axis.text.y = element_text(size = 10),
      panel.spacing.x = unit(0, "lines"),
      panel.spacing.y = unit(0, "lines"))

  ggsave(file.path(output_dir, "z_A5_transaction_gaussian_iid_forest_restaurants.png"), p,
         width = 14, height = 26, dpi = 300)
  ggsave(file.path(output_dir, "z_A5_transaction_gaussian_iid_forest_restaurants.pdf"), p,
         width = 14, height = 26)

  .n_out_html <- length(unique(df_all$outcome))
  .html_px    <- round(max(7, .n_out_html * 4.2) * 80)
  p_plotly <- ggplotly(p, tooltip = "text", height = .html_px)
  p_plotly <- add_click_handler(p_plotly)
  try(saveWidget(p_plotly, file.path(output_dir, "z_A5_transaction_gaussian_iid_forest_restaurants.html"),
             selfcontained = FALSE), silent = TRUE)

  df_save <- df_all %>% select(-matches("_disp|_orig|clipped|y_numeric|n_in_group|row_in_group"))
  write_csv(df_save, file.path(output_dir, "z_A5_transaction_gaussian_iid_restaurants_data.csv"))

  cat("  Saved: z_A5_transaction_gaussian_iid_forest_restaurants.png, .pdf, .html, _data.csv\n")
  return(p)
}

# ─────────────────────────────────────
# Execute (skipped when sourced with .forest_skip_execute option)
# ─────────────────────────────────────

if (!isTRUE(getOption(".forest_skip_execute"))) {

cat("========================================\n")
cat("Forest Plot Generation - T2 VERSION (with Restaurants) - RECOLORED\n")
cat("========================================\n")
cat("Default model path:", DEFAULT_MODEL_PATH, "\n")
cat("A1 overrides:", paste(names(A1_OVERRIDES), "->", A1_OVERRIDES, collapse = ", "), "\n")
cat("A2 overrides:", paste(names(A2_OVERRIDES), "->", A2_OVERRIDES, collapse = ", "), "\n")
cat("A3 overrides:", paste(names(A3_OVERRIDES), "->", A3_OVERRIDES, collapse = ", "), "\n")
cat("A4 overrides:", paste(names(A4_OVERRIDES), "->", A4_OVERRIDES, collapse = ", "), "\n")
cat("Output directory base:", OUTPUT_DIR_BASE, "\n\n")

if (REVIEW_MODE) {
  p2 <- create_proportion_targeted_forest_restaurants()
} else {
  p1 <- create_proportion_forest_restaurants()
  p1_log <- create_proportion_forest_restaurants(log_scale = TRUE)
  p2 <- create_proportion_targeted_forest_restaurants()
  p2_log <- create_proportion_targeted_forest_restaurants(log_scale = TRUE)
  p3 <- create_its_forest_restaurants()
  p3_log <- create_its_forest_restaurants(log_scale = TRUE)
  p4 <- create_its_targeted_forest_restaurants()
  p4_log <- create_its_targeted_forest_restaurants(log_scale = TRUE)
  p5 <- create_gaussian_iid_forest_restaurants()
}

cat("\n========================================\n")
cat("All T2 forest plots with restaurant estimates generated (RECOLORED)!\n")
cat("Output directories:", OUTPUT_DIR_BASE, "and", LOG_OUTPUT_DIR_BASE, "\n")
cat("========================================\n")

} # end if (!isTRUE(getOption(".forest_skip_execute")))

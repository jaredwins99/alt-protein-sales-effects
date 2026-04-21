source("publication/forest_fallback.R")
# Forest Plot Generation Script - T2 ADJUSTED with IMPLIED COMPOSITIONAL OVERLAY
# Overlays "implied" adjusted RRs derived from the compositional constraint:
#   share_meat * adj_RR_meat + share_veg * adj_RR_veg = 1
# to visualize shrinkage inconsistency from independent hierarchical models.
# Scope: A1 (t2_proportion) and A3 (t2_its) only. T2 (Tier 2) restaurant set.

# Source the T2 adjusted script (reuse all helpers, config, cache)
options(.forest_skip_execute = TRUE)
source("create_forest_plots_restaurants_chosen_recolored_adj_t2.R")
options(.forest_skip_execute = NULL)

# Override output directory
OUTPUT_DIR_BASE <- "forest_plots/forest_plots_restaurants_trunc_recolored_adj_overlay_t2"

# ─────────────────────────────────────
#   Compositional Shares (hardcoded)
# ─────────────────────────────────────
# From data/4_data_parquet_modeling/its/finalized.parquet
SHARES <- list(
  meat = 0.600,
  vegetarian = 0.400,
  nonvegan = 0.900,
  vegan = 0.100
)

# ─────────────────────────────────────
#   Implied Adjusted RR Helper
# ─────────────────────────────────────

#' Compute Implied Adjusted RR from Compositional Constraint
#'
#' Given: share_source * adj_RR_source + share_target * adj_RR_target = 1
#' => implied_target = (1 - share_source * adj_RR_source) / share_target
#'
#' The `scale` parameter controls which RR space the constraint is applied in:
#'   scale=1 (count): exact compositional constraint on count-scale RRs
#'   scale=0.1 (proportion): first-order approximation using per-10pp RRs,
#'     keeping implied values on the same display scale as model estimates.
#'
#' @param source_outcome_path Path to source outcome model (e.g., meat)
#' @param total_path Path to total model
#' @param gamma_index Which mu_gamma index (1 or 2)
#' @param share_source Share of source component (e.g., 0.6 for meat)
#' @param share_target Share of target component (e.g., 0.4 for vegetarian)
#' @param scale Multiplier for log-space diff before exp (1 = count, 0.1 = proportion)
#' @return List with mean, q2.5, q97.5, log variants, and diagnostics
compute_implied_adj_rr <- function(source_outcome_path, total_path, gamma_index,
                                   share_source, share_target, scale = 1) {
  samples_source <- read_samples_cached(source_outcome_path)
  samples_total <- read_samples_cached(total_path)

  if (is.null(samples_source) || is.null(samples_total)) return(NULL)

  param_name <- paste0("mu_gamma[", gamma_index, "]")
  if (!(param_name %in% names(samples_source)) ||
      !(param_name %in% names(samples_total))) return(NULL)

  source_draws <- samples_source[[param_name]]
  total_draws <- samples_total[[param_name]]

  n <- min(length(source_draws), length(total_draws))
  diff_draws <- source_draws[1:n] - total_draws[1:n]

  # Adjusted RR for source at the given scale
  adj_rr_source <- exp(scale * diff_draws)

  # Implied target RR per draw (on same scale as adj_rr_source)
  implied <- (1 - share_source * adj_rr_source) / share_target

  # Clamp for log safety
  implied_pos <- pmax(implied, 1e-10)

  list(
    mean = mean(implied),
    q2.5 = unname(quantile(implied, 0.025)),
    q97.5 = unname(quantile(implied, 0.975)),
    mean_log = mean(log(implied_pos)),
    q2.5_log = unname(quantile(log(implied_pos), 0.025)),
    q97.5_log = unname(quantile(log(implied_pos), 0.975)),
    n_negative = sum(implied <= 0),
    n_total = length(implied)
  )
}

# ─────────────────────────────────────
# 1. PROPORTION Analysis (A1) - OVERLAY
# ─────────────────────────────────────

create_proportion_forest_overlay <- function(log_scale = FALSE) {
  output_dir <- if (log_scale) file.path(paste0(OUTPUT_DIR_BASE, "_log")) else file.path(OUTPUT_DIR_BASE)
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  cat("Creating ADJUSTED proportion forest plot with IMPLIED OVERLAY...\n")

  outcomes <- c("total", "nonvegan", "meat", "chicken_fish", "vegetarian", "vegan")
  exposure_groups <- c("mpbamod", "vegan", "vegetarian")
  exposure_types <- c("count", "prop")

  # ── Build model data (same as adjusted A1) ──
  pooled_list <- list()
  restaurant_list <- list()

  for (outcome in outcomes) {
    model_path_name <- get_model_path(outcome, A1_OVERRIDES)
    model_run_path <- file.path("model_fits", model_path_name)

    for (exp_group in exposure_groups) {
      for (exp_type in exposure_types) {
        exposure <- paste0(exp_group, "_dishes_", exp_type)

        if (outcome == "total") {
          pooled_list[[length(pooled_list) + 1]] <- tibble(
            outcome = outcome,
            exposure_group = exp_group,
            exposure_type = exp_type,
            mean = 0, q2.5 = 0, q97.5 = 0,
            mean_exp = 1, mean_exp_p10 = 1,
            rhat = NA_real_,
            estimate_type = "Pooled",
            restaurant_id = "POOLED")
          next
        }

        outcome_path <- file.path(model_run_path, "t2_proportion", outcome, exposure)
        total_model_path_name <- get_model_path("total", A1_OVERRIDES)
        total_run_path <- file.path("model_fits", total_model_path_name)
        total_path <- file.path(total_run_path, "t2_proportion", "total", exposure)

        gamma <- compute_adjusted_mu_gamma(outcome_path, total_path, 1)
        if (!is.null(gamma)) {
          pooled_list[[length(pooled_list) + 1]] <- tibble(
            outcome = outcome,
            exposure_group = exp_group,
            exposure_type = exp_type,
            mean = gamma$mean, q2.5 = gamma$q2.5, q97.5 = gamma$q97.5,
            mean_exp = gamma$mean_exp, mean_exp_p10 = gamma$mean_exp_p10,
            rhat = gamma$rhat,
            estimate_type = "Pooled",
            restaurant_id = "POOLED")
        }

        rest_gammas <- compute_adjusted_restaurant_gammas(outcome_path, total_path, is_its = FALSE)
        if (!is.null(rest_gammas) && nrow(rest_gammas) > 0) {
          for (i in 1:nrow(rest_gammas)) {
            restaurant_list[[length(restaurant_list) + 1]] <- tibble(
              outcome = outcome,
              exposure_group = exp_group,
              exposure_type = exp_type,
              mean = rest_gammas$mean[i], q2.5 = rest_gammas$q2.5[i], q97.5 = rest_gammas$q97.5[i],
              mean_exp_p10 = rest_gammas$mean_exp_p10[i],
              rhat = rest_gammas$rhat[i],
              estimate_type = "Restaurant",
              restaurant_id = rest_gammas$restaurant_id[i])
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

  df_all$outcome <- factor(df_all$outcome, levels = rev(outcomes))
  df_all$exposure_group <- factor(df_all$exposure_group, levels = exposure_groups)
  df_all$exposure_type <- factor(df_all$exposure_type, levels = c("prop", "count"),
                                  labels = c("Proportion", "Count"))

  df_all <- df_all %>%
    mutate(color_group = case_when(
      outcome == "total" ~ "Total",
      outcome %in% c("nonvegan", "meat", "chicken_fish") ~ "Animal",
      outcome %in% c("vegetarian", "vegan") ~ "Plant-based"))

  if (!log_scale) {
    df_all <- df_all %>%
      mutate(
        across(c(q2.5, q97.5), ~ case_when(
          exposure_type == "Count" & estimate_type == "Pooled" ~ exp(.x),
          exposure_type == "Proportion" & estimate_type == "Pooled" ~ exp(.1 * .x),
          exposure_type == "Proportion" & estimate_type == "Restaurant" ~ .x^0.1,
          TRUE ~ .x)),
        mean = case_when(
          exposure_type == "Count" & estimate_type == "Pooled" ~ mean_exp,
          exposure_type == "Proportion" & estimate_type == "Pooled" ~ mean_exp_p10,
          exposure_type == "Proportion" & estimate_type == "Restaurant" ~ mean_exp_p10,
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

  # Compute y_numeric for model rows
  df_all <- df_all %>%
    group_by(outcome, exposure_group, exposure_type) %>%
    mutate(
      n_in_group = n(),
      row_in_group = row_number(),
      y_numeric = as.numeric(outcome) +
        case_when(
          estimate_type == "Pooled" ~ 0,
          TRUE ~ -0.12 * row_in_group
        )
    ) %>%
    ungroup()

  # ── Compute implied estimates ──
  # For count exposure: scale=1 (exact compositional constraint on count-scale RRs)
  # For proportion exposure: scale=0.1 (first-order approx using per-10pp RRs,
  #   so implied values are on the same display scale as model estimates)
  outcome_levels <- rev(outcomes)  # factor level order
  implied_list <- list()

  for (exp_group in exposure_groups) {
    for (exp_type in exposure_types) {
      exposure <- paste0(exp_group, "_dishes_", exp_type)
      exp_type_label <- if (exp_type == "prop") "Proportion" else "Count"
      scale <- if (exp_type == "prop") 0.1 else 1

      total_model_path_name <- get_model_path("total", A1_OVERRIDES)
      total_run_path <- file.path("model_fits", total_model_path_name)
      total_path <- file.path(total_run_path, "t2_proportion", "total", exposure)

      # Meat -> implied vegetarian
      meat_path <- file.path("model_fits", get_model_path("meat", A1_OVERRIDES),
                             "t2_proportion", "meat", exposure)
      implied_veg <- compute_implied_adj_rr(meat_path, total_path, 1,
                                            SHARES$meat, SHARES$vegetarian, scale = scale)

      if (!is.null(implied_veg)) {
        vals <- if (!log_scale) {
          c(implied_veg$mean, implied_veg$q2.5, implied_veg$q97.5)
        } else {
          c(implied_veg$mean_log, implied_veg$q2.5_log, implied_veg$q97.5_log)
        }

        veg_y <- which(outcome_levels == "vegetarian")
        implied_list[[length(implied_list) + 1]] <- tibble(
          outcome = factor("vegetarian", levels = outcome_levels),
          exposure_group = factor(exp_group, levels = exposure_groups),
          exposure_type = factor(exp_type_label, levels = c("Proportion", "Count")),
          mean = vals[1], q2.5 = vals[2], q97.5 = vals[3],
          estimate_type = "Implied",
          restaurant_id = "IMPLIED",
          color_group = "Implied Veg",
          rhat = NA_real_,
          y_numeric = veg_y + 0.15,
          implied_from = "meat",
          n_negative = implied_veg$n_negative,
          n_total_draws = implied_veg$n_total)
      }

      # Nonvegan -> implied vegan
      nonvegan_path <- file.path("model_fits", get_model_path("nonvegan", A1_OVERRIDES),
                                 "t2_proportion", "nonvegan", exposure)
      implied_vgn <- compute_implied_adj_rr(nonvegan_path, total_path, 1,
                                            SHARES$nonvegan, SHARES$vegan, scale = scale)

      if (!is.null(implied_vgn)) {
        vals <- if (!log_scale) {
          c(implied_vgn$mean, implied_vgn$q2.5, implied_vgn$q97.5)
        } else {
          c(implied_vgn$mean_log, implied_vgn$q2.5_log, implied_vgn$q97.5_log)
        }

        vgn_y <- which(outcome_levels == "vegan")
        implied_list[[length(implied_list) + 1]] <- tibble(
          outcome = factor("vegan", levels = outcome_levels),
          exposure_group = factor(exp_group, levels = exposure_groups),
          exposure_type = factor(exp_type_label, levels = c("Proportion", "Count")),
          mean = vals[1], q2.5 = vals[2], q97.5 = vals[3],
          estimate_type = "Implied",
          restaurant_id = "IMPLIED",
          color_group = "Implied Vegan",
          rhat = NA_real_,
          y_numeric = vgn_y + 0.15,
          implied_from = "nonvegan",
          n_negative = implied_vgn$n_negative,
          n_total_draws = implied_vgn$n_total)
      }
    }
  }

  df_implied <- bind_rows(implied_list)

  if (nrow(df_implied) > 0) {
    cat("  Computed", nrow(df_implied), "implied estimates\n")
    for (i in 1:nrow(df_implied)) {
      row <- df_implied[i, ]
      cat(sprintf("    %s from %s | %s %s | mean=%.3f [%.3f, %.3f] | neg draws: %d/%d\n",
                  as.character(row$outcome), row$implied_from,
                  as.character(row$exposure_group), as.character(row$exposure_type),
                  row$mean, row$q2.5, row$q97.5,
                  row$n_negative, row$n_total_draws))
    }
  }

  # Combine model + implied
  df_all <- bind_rows(df_all, df_implied)

  # Compute xlim and clip
  xlim <- if (log_scale) calc_xlim_median(df_all, x_max_input = 10) else calc_xlim_median(df_all)
  df_all <- clip_to_limits(df_all, xlim)

  # Split for plotting
  df_model_pooled <- df_all %>% filter(estimate_type == "Pooled")
  df_model_restaurant <- df_all %>% filter(estimate_type == "Restaurant")
  df_implied_plot <- df_all %>% filter(estimate_type == "Implied")

  # ── Build plot ──
  p <- ggplot() +
    geom_vline(xintercept = if (log_scale) 0 else 1, linetype = "dashed", color = "gray50") +
    # Restaurant estimates
    {if (nrow(df_model_restaurant) > 0)
      geom_errorbarh(data = df_model_restaurant,
                     aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                     height = 0.06, alpha = 0.4, linewidth = 0.3)} +
    {if (nrow(df_model_restaurant) > 0)
      geom_point(data = df_model_restaurant,
                 aes(x = mean_disp, y = y_numeric, color = color_group,
                     shape = clipped,
                     text = paste0(
                       "Restaurant: ", restaurant_id, "<br>",
                       "Outcome: ", outcome, "<br>",
                       "Exposure: ", exposure_group, " (", exposure_type, ")<br>",
                       "Adjusted Rate Ratio: ", signif(mean_orig, 3), "<br>",
                       "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                       ifelse(clipped, "<br>(Value clipped to fit scale)", ""))),
                 size = 1.2, alpha = 0.5)} +
    scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 17), guide = "none") +
    # Model pooled estimates
    geom_errorbarh(data = df_model_pooled,
                   aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                   height = 0.15, linewidth = 0.8) +
    geom_point(data = df_model_pooled,
               aes(x = mean_disp, y = y_numeric, color = color_group, text = paste0(
                 "POOLED (Model)<br>",
                 "Outcome: ", outcome, "<br>",
                 "Exposure: ", exposure_group, " (", exposure_type, ")<br>",
                 "Adjusted Rate Ratio: ", signif(mean_orig, 3), "<br>",
                 "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                 ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), ""))),
               size = 2.5) +
    # Implied estimates (overlay)
    {if (nrow(df_implied_plot) > 0)
      geom_errorbarh(data = df_implied_plot,
                     aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                     height = 0.1, linewidth = 0.6, linetype = "dashed")} +
    {if (nrow(df_implied_plot) > 0)
      geom_point(data = df_implied_plot,
                 aes(x = mean_disp, y = y_numeric, color = color_group,
                     text = paste0(
                       "IMPLIED (from ", implied_from, ")<br>",
                       "Outcome: ", outcome, "<br>",
                       "Exposure: ", exposure_group, " (", exposure_type, ")<br>",
                       "Implied Rate Ratio: ", signif(mean_orig, 3), "<br>",
                       "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                       "<br>Negative draws: ", n_negative, "/", n_total_draws)),
                 shape = 5, size = 3, stroke = 1.2)} +
    scale_color_manual(
      values = c("Total" = "steelblue", "Animal" = "firebrick", "Plant-based" = "forestgreen",
                 "Implied Veg" = "purple", "Implied Vegan" = "darkorange"),
      breaks = c("Implied Veg", "Implied Vegan"),
      labels = c("Veg (implied)", "Vegan (implied)"),
      name = NULL,
      guide = guide_legend(override.aes = list(shape = 5, size = 3))) +
    facet_grid(exposure_group ~ exposure_type, scales = "free_y", space = "free_y") +
    scale_x_continuous(limits = xlim, oob = scales::squish) +
    scale_y_continuous(
      breaks = 1:length(outcomes),
      labels = format_label(rev(outcomes)),
      expand = expansion(mult = c(0.15, 0.05))) +
    labs(
      title = "A1: Proportion Analysis (Adjusted + Implied Overlay)",
      subtitle = paste0("Outcome RR / Total RR | ",
                        if (log_scale) "Log Adjusted Rate Ratios" else "Adjusted Rate Ratios",
                        " | Circles = model | Diamonds = implied from compositional constraint",
                        "\nCount: exact | Proportion: 1st-order approx (per-10pp)",
                        " | share_meat=0.6, share_veg=0.4, share_nonvegan=0.9, share_vegan=0.1"),
      x = if (log_scale) "Log Adjusted Rate Ratio" else "Adjusted Rate Ratio",
      y = "Outcome") +
    theme_minimal(base_size = 11) +
    theme(
      panel.grid.minor = element_blank(),
      strip.background = element_rect(fill = "gray90", color = NA),
      strip.text = element_text(face = "bold"),
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 8, color = "gray40"),
      axis.text.y = element_text(size = 10),
      legend.position = "bottom")

  prefix <- if (log_scale) "A1_proportion_forest_restaurants_log" else "A1_proportion_forest_restaurants"

  ggsave(file.path(output_dir, paste0(prefix, ".png")), p,
         width = 12, height = 12, dpi = 300)
  ggsave(file.path(output_dir, paste0(prefix, ".pdf")), p,
         width = 12, height = 12)

  p_plotly <- ggplotly(p, tooltip = "text")
  try(saveWidget(p_plotly, file.path(output_dir, paste0(prefix, ".html")), selfcontained = TRUE), silent = TRUE)

  df_save <- df_all %>% select(-matches("_disp|_orig|clipped|y_numeric|n_in_group|row_in_group"))
  write_csv(df_save, file.path(output_dir, paste0(prefix, "_data.csv")))

  cat("  Saved:", prefix, ".png, .pdf, .html, _data.csv\n")
  return(p)
}

# ─────────────────────────────────────
# 3. ITS Analysis (A3) - OVERLAY
# ─────────────────────────────────────

create_its_forest_overlay <- function(log_scale = FALSE) {
  output_dir <- if (log_scale) file.path(paste0(OUTPUT_DIR_BASE, "_log")) else file.path(OUTPUT_DIR_BASE)
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  cat("Creating ADJUSTED ITS forest plot with IMPLIED OVERLAY...\n")

  outcomes <- c("total", "nonvegan", "meat", "chicken_fish", "vegetarian", "vegan")

  # ── Build model data (same as adjusted A3) ──
  pooled_list <- list()
  restaurant_list <- list()

  total_model_path_name <- get_model_path("total", A3_OVERRIDES)
  total_run_path <- file.path("model_fits", total_model_path_name)
  total_path <- file.path(total_run_path, "t2_its", "total")

  for (outcome in outcomes) {
    model_path_name <- get_model_path(outcome, A3_OVERRIDES)
    model_run_path <- file.path("model_fits", model_path_name)
    outcome_path <- file.path(model_run_path, "t2_its", outcome)

    if (outcome == "total") {
      for (eff in c("Level Change", "Slope Change")) {
        pooled_list[[length(pooled_list) + 1]] <- tibble(
          outcome = outcome,
          effect_type = eff,
          mean = 0, q2.5 = 0, q97.5 = 0,
          mean_exp = 1,
          rhat = NA_real_, ess_bulk = NA_real_,
          estimate_type = "Pooled",
          restaurant_id = "POOLED")
      }
      next
    }

    gamma1 <- compute_adjusted_mu_gamma(outcome_path, total_path, 1)
    if (!is.null(gamma1)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome,
        effect_type = "Level Change",
        mean = gamma1$mean, q2.5 = gamma1$q2.5, q97.5 = gamma1$q97.5,
        mean_exp = gamma1$mean_exp,
        rhat = gamma1$rhat, ess_bulk = gamma1$ess_bulk,
        estimate_type = "Pooled",
        restaurant_id = "POOLED")
    }

    gamma2 <- compute_adjusted_mu_gamma(outcome_path, total_path, 2)
    if (!is.null(gamma2)) {
      pooled_list[[length(pooled_list) + 1]] <- tibble(
        outcome = outcome,
        effect_type = "Slope Change",
        mean = gamma2$mean, q2.5 = gamma2$q2.5, q97.5 = gamma2$q97.5,
        mean_exp = gamma2$mean_exp,
        rhat = gamma2$rhat, ess_bulk = gamma2$ess_bulk,
        estimate_type = "Pooled",
        restaurant_id = "POOLED")
    }

    rest_gammas <- compute_adjusted_restaurant_gammas(outcome_path, total_path, is_its = TRUE)
    if (!is.null(rest_gammas) && nrow(rest_gammas) > 0) {
      for (i in 1:nrow(rest_gammas)) {
        restaurant_list[[length(restaurant_list) + 1]] <- tibble(
          outcome = outcome,
          effect_type = rest_gammas$effect_type[i],
          mean = rest_gammas$mean[i], q2.5 = rest_gammas$q2.5[i], q97.5 = rest_gammas$q97.5[i],
          rhat = rest_gammas$rhat[i], ess_bulk = NA_real_,
          estimate_type = "Restaurant",
          restaurant_id = rest_gammas$restaurant_id[i])
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

  df_all$outcome <- factor(df_all$outcome, levels = rev(outcomes))
  df_all$effect_type <- factor(df_all$effect_type, levels = c("Level Change", "Slope Change"))

  df_all <- df_all %>%
    mutate(color_group = case_when(
      outcome == "total" ~ "Total",
      outcome %in% c("nonvegan", "meat", "chicken_fish") ~ "Animal",
      outcome %in% c("vegetarian", "vegan") ~ "Plant-based"))

  if (!log_scale) {
    df_pooled_part <- df_all %>%
      filter(estimate_type == "Pooled") %>%
      mutate(across(c(q2.5, q97.5), ~ exp(.x)), mean = mean_exp)
    df_restaurant_only <- df_all %>% filter(estimate_type == "Restaurant")
    df_all <- bind_rows(df_pooled_part, df_restaurant_only)
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
    group_by(outcome, effect_type) %>%
    summarise(n_rest = n_distinct(restaurant_id), .groups = "drop")
  df_all <- df_all %>%
    left_join(n_restaurants, by = c("outcome", "effect_type")) %>%
    filter(!(estimate_type == "Pooled" & !is.na(n_rest) & n_rest <= 1)) %>%
    select(-n_rest)

  # Compute y_numeric for model rows
  df_all <- df_all %>%
    group_by(outcome, effect_type) %>%
    mutate(
      n_in_group = n(),
      row_in_group = row_number(),
      y_numeric = as.numeric(outcome) +
        case_when(
          estimate_type == "Pooled" ~ 0,
          TRUE ~ -0.08 * row_in_group
        )
    ) %>%
    ungroup()

  # ── Compute implied estimates ──
  outcome_levels <- rev(outcomes)
  implied_list <- list()

  for (gamma_idx in 1:2) {
    eff_label <- if (gamma_idx == 1) "Level Change" else "Slope Change"

    # Meat -> implied vegetarian
    meat_path <- file.path("model_fits", get_model_path("meat", A3_OVERRIDES), "t2_its", "meat")
    implied_veg <- compute_implied_adj_rr(meat_path, total_path, gamma_idx,
                                          SHARES$meat, SHARES$vegetarian)

    if (!is.null(implied_veg)) {
      if (!log_scale) {
        vals <- c(implied_veg$mean, implied_veg$q2.5, implied_veg$q97.5)
      } else {
        vals <- c(implied_veg$mean_log, implied_veg$q2.5_log, implied_veg$q97.5_log)
      }

      veg_y <- which(outcome_levels == "vegetarian")
      implied_list[[length(implied_list) + 1]] <- tibble(
        outcome = factor("vegetarian", levels = outcome_levels),
        effect_type = factor(eff_label, levels = c("Level Change", "Slope Change")),
        mean = vals[1], q2.5 = vals[2], q97.5 = vals[3],
        estimate_type = "Implied",
        restaurant_id = "IMPLIED",
        color_group = "Implied Veg",
        rhat = NA_real_,
        y_numeric = veg_y + 0.15,
        implied_from = "meat",
        n_negative = implied_veg$n_negative,
        n_total_draws = implied_veg$n_total)
    }

    # Nonvegan -> implied vegan
    nonvegan_path <- file.path("model_fits", get_model_path("nonvegan", A3_OVERRIDES), "t2_its", "nonvegan")
    implied_vgn <- compute_implied_adj_rr(nonvegan_path, total_path, gamma_idx,
                                          SHARES$nonvegan, SHARES$vegan)

    if (!is.null(implied_vgn)) {
      if (!log_scale) {
        vals <- c(implied_vgn$mean, implied_vgn$q2.5, implied_vgn$q97.5)
      } else {
        vals <- c(implied_vgn$mean_log, implied_vgn$q2.5_log, implied_vgn$q97.5_log)
      }

      vgn_y <- which(outcome_levels == "vegan")
      implied_list[[length(implied_list) + 1]] <- tibble(
        outcome = factor("vegan", levels = outcome_levels),
        effect_type = factor(eff_label, levels = c("Level Change", "Slope Change")),
        mean = vals[1], q2.5 = vals[2], q97.5 = vals[3],
        estimate_type = "Implied",
        restaurant_id = "IMPLIED",
        color_group = "Implied Vegan",
        rhat = NA_real_,
        y_numeric = vgn_y + 0.15,
        implied_from = "nonvegan",
        n_negative = implied_vgn$n_negative,
        n_total_draws = implied_vgn$n_total)
    }
  }

  df_implied <- bind_rows(implied_list)

  if (nrow(df_implied) > 0) {
    cat("  Computed", nrow(df_implied), "implied estimates\n")
    for (i in 1:nrow(df_implied)) {
      row <- df_implied[i, ]
      cat(sprintf("    %s from %s | %s | mean=%.3f [%.3f, %.3f] | neg draws: %d/%d\n",
                  as.character(row$outcome), row$implied_from,
                  as.character(row$effect_type),
                  row$mean, row$q2.5, row$q97.5,
                  row$n_negative, row$n_total_draws))
    }
  }

  # Combine model + implied
  df_all <- bind_rows(df_all, df_implied)

  # Compute xlim and clip
  xlim <- if (log_scale) calc_xlim_median(df_all, x_max_input = 10) else calc_xlim_median(df_all)
  df_all <- clip_to_limits(df_all, xlim)

  # Split for plotting
  df_model_pooled <- df_all %>% filter(estimate_type == "Pooled")
  df_model_restaurant <- df_all %>% filter(estimate_type == "Restaurant")
  df_implied_plot <- df_all %>% filter(estimate_type == "Implied")

  # ── Build plot ──
  p <- ggplot() +
    geom_vline(xintercept = if (log_scale) 0 else 1, linetype = "dashed", color = "gray50") +
    # Restaurant estimates
    {if (nrow(df_model_restaurant) > 0)
      geom_errorbarh(data = df_model_restaurant,
                     aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                     height = 0.05, alpha = 0.4, linewidth = 0.3)} +
    {if (nrow(df_model_restaurant) > 0)
      geom_point(data = df_model_restaurant,
                 aes(x = mean_disp, y = y_numeric, color = color_group,
                     shape = clipped,
                     text = paste0(
                       "Restaurant: ", restaurant_id, "<br>",
                       "Outcome: ", outcome, "<br>",
                       "Effect: ", effect_type, "<br>",
                       "Adjusted Rate Ratio: ", signif(mean_orig, 3), "<br>",
                       "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                       ifelse(clipped, "<br>(Value clipped to fit scale)", ""))),
                 size = 1.2, alpha = 0.5)} +
    scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 17), guide = "none") +
    # Model pooled estimates
    geom_errorbarh(data = df_model_pooled,
                   aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                   height = 0.15, linewidth = 0.8) +
    geom_point(data = df_model_pooled,
               aes(x = mean_disp, y = y_numeric, color = color_group, text = paste0(
                 "POOLED (Model)<br>",
                 "Outcome: ", outcome, "<br>",
                 "Effect: ", effect_type, "<br>",
                 "Adjusted Rate Ratio: ", signif(mean_orig, 3), "<br>",
                 "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                 ifelse(!is.na(rhat), paste0("<br>Rhat: ", signif(rhat, 3)), ""))),
               size = 2.5) +
    # Implied estimates (overlay)
    {if (nrow(df_implied_plot) > 0)
      geom_errorbarh(data = df_implied_plot,
                     aes(xmin = q2.5_disp, xmax = q97.5_disp, y = y_numeric, color = color_group),
                     height = 0.1, linewidth = 0.6, linetype = "dashed")} +
    {if (nrow(df_implied_plot) > 0)
      geom_point(data = df_implied_plot,
                 aes(x = mean_disp, y = y_numeric, color = color_group,
                     text = paste0(
                       "IMPLIED (from ", implied_from, ")<br>",
                       "Outcome: ", outcome, "<br>",
                       "Effect: ", effect_type, "<br>",
                       "Implied Rate Ratio: ", signif(mean_orig, 3), "<br>",
                       "95% CI: [", signif(q2.5_orig, 3), ", ", signif(q97.5_orig, 3), "]",
                       "<br>Negative draws: ", n_negative, "/", n_total_draws)),
                 shape = 5, size = 3, stroke = 1.2)} +
    scale_color_manual(
      values = c("Total" = "steelblue", "Animal" = "firebrick", "Plant-based" = "forestgreen",
                 "Implied Veg" = "purple", "Implied Vegan" = "darkorange"),
      breaks = c("Implied Veg", "Implied Vegan"),
      labels = c("Veg (implied)", "Vegan (implied)"),
      name = NULL,
      guide = guide_legend(override.aes = list(shape = 5, size = 3))) +
    facet_wrap(~ effect_type, ncol = 2) +
    scale_x_continuous(limits = xlim, oob = scales::squish) +
    scale_y_continuous(
      breaks = 1:length(outcomes),
      labels = format_label(rev(outcomes)),
      expand = expansion(mult = c(0.2, 0.1))) +
    labs(
      title = "A3: Interrupted Time Series Analysis (Adjusted + Implied Overlay)",
      subtitle = paste0("Outcome RR / Total RR | ",
                        if (log_scale) "Log Adjusted Rate Ratios" else "Adjusted Rate Ratios",
                        " | Circles = model | Diamonds = implied from compositional constraint",
                        " | Level: exact at t=0 | Slope: approximate (shares drift post-intervention)"),
      x = if (log_scale) "Log Adjusted Rate Ratio" else "Adjusted Rate Ratio",
      y = "Outcome") +
    theme_minimal(base_size = 11) +
    theme(
      panel.grid.minor = element_blank(),
      strip.background = element_rect(fill = "gray90", color = NA),
      strip.text = element_text(face = "bold"),
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 8, color = "gray40"),
      axis.text.y = element_text(size = 10),
      legend.position = "bottom")

  prefix <- if (log_scale) "A3_its_forest_restaurants_log" else "A3_its_forest_restaurants"

  ggsave(file.path(output_dir, paste0(prefix, ".png")), p,
         width = 11, height = 8, dpi = 300)
  ggsave(file.path(output_dir, paste0(prefix, ".pdf")), p,
         width = 11, height = 8)

  p_plotly <- ggplotly(p, tooltip = "text")
  try(saveWidget(p_plotly, file.path(output_dir, paste0(prefix, ".html")), selfcontained = TRUE), silent = TRUE)

  df_save <- df_all %>% select(-matches("_disp|_orig|clipped|y_numeric|n_in_group|row_in_group"))
  write_csv(df_save, file.path(output_dir, paste0(prefix, "_data.csv")))

  cat("  Saved:", prefix, ".png, .pdf, .html, _data.csv\n")
  return(p)
}

# ─────────────────────────────────────
# Execute
# ─────────────────────────────────────

cat("========================================\n")
cat("Forest Plot Generation - T2 ADJUSTED + IMPLIED COMPOSITIONAL OVERLAY\n")
cat("========================================\n")
cat("Compositional shares:\n")
cat("  meat/vegetarian:", SHARES$meat, "/", SHARES$vegetarian, "\n")
cat("  nonvegan/vegan:", SHARES$nonvegan, "/", SHARES$vegan, "\n")
cat("Output directory base:", OUTPUT_DIR_BASE, "\n\n")

p1 <- create_proportion_forest_overlay()
p1_log <- create_proportion_forest_overlay(log_scale = TRUE)
p3 <- create_its_forest_overlay()
p3_log <- create_its_forest_overlay(log_scale = TRUE)

cat("\n========================================\n")
cat("All T2 ADJUSTED + OVERLAY forest plots generated!\n")
cat("Output directories:", OUTPUT_DIR_BASE, "and", paste0(OUTPUT_DIR_BASE, "_log"), "\n")
cat("========================================\n")

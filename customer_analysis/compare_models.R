# compare_models.R
# Compare fixest conditional Poisson vs Stan conditional Poisson (multilevel)
#
# Source from project root:
#   source("customer_analysis/compare_models.R")
#
# Reads results from:
#   - customer_analysis/transaction_level/fixest/results_exposures/
#   - customer_analysis/transaction_level/stan_poisson/results/
#
# Produces:
#   - Console output: side-by-side specification table + overlap analysis
#   - customer_analysis/compare_models_summary.md

library(tidyverse)

# ==============================================================================
#                          1. SPECIFICATION TABLE
# ==============================================================================

spec_table <- tribble(
  ~Feature,                  ~`Fixest (fepois)`,                                 ~`Stan (multilevel)`,
  "Likelihood",              "Conditional Poisson",                              "Conditional Poisson",
  "Software",                "fixest::fepois()",                                 "CmdStan (custom .stan)",
  "Formula",                 "outcome ~ X | customer_id",                        "target += sum_y_nu - n_i * log_sum_exp(nu)",
  "Customer FE",             "Conditioned out (sufficient stat)",                "Conditioned out (sufficient stat)",
  "Estimation",              "ML via IRLS (frequentist)",                        "Full Bayesian (NUTS HMC)",
  "Restaurant structure",    "Independent per-restaurant models",                "Joint model, all restaurants simultaneously",
  "Multilevel exposure",     "None",                                             "3-level: mu_gamma -> eta[k,r] -> gamma[k,r,e]",
  "Partial pooling",         "No -- each restaurant estimated in isolation",     "Yes -- shrinks extreme estimates toward global mean",
  "Covariate effects",       "Per-restaurant (independent)",                     "Per-restaurant (random effects w/ shared mean)",
  "Exposure level effect",   "beta (MLE per restaurant)",                        "gamma = mu_gamma + eta + epsilon (posterior)",
  "Exposure slope effect",   "beta:date_code (MLE per restaurant)",              "Same 3-level hierarchy for slopes",
  "Standard errors",         "Clustered sandwich (vcov = ~customer_id)",         "Not applicable (Bayesian)",
  "Confidence/credible int", "estimate +/- 1.96*SE (95% Wald CI)",              "Posterior quantiles (q5, q95 = 90% CI)",
  "Priors",                  "None (pure likelihood)",                           "Normal(0, scale) on mu_gamma; t(3,0,scale) on sigmas",
  "Overdispersion",          "Handled via clustered SEs",                        "Handled by conditional likelihood + posterior",
  "Train/test split",        "90/10 by date",                                   "90/10 by date",
  "Gender interactions",     "exposure:gender (if available)",                   "Not included (absorbed by conditional likelihood)"
)

cat("\n")
cat("================================================================\n")
cat("  MODEL SPECIFICATION COMPARISON\n")
cat("  Fixest Conditional Poisson vs Stan Multilevel Conditional Poisson\n")
cat("================================================================\n\n")

for (i in seq_len(nrow(spec_table))) {
  cat(sprintf("%-28s\n", spec_table$Feature[i]))
  cat(sprintf("  Fixest: %s\n", spec_table$`Fixest (fepois)`[i]))
  cat(sprintf("  Stan:   %s\n\n", spec_table$`Stan (multilevel)`[i]))
}

# ==============================================================================
#                    2. DISCOVER AVAILABLE RESULTS
# ==============================================================================

fixest_dir <- "customer_analysis/transaction_level/fixest/results_exposures"
stan_dir   <- "customer_analysis/transaction_level/stan_poisson/results"

# Fixest outcomes: filenames like A5_nonvegan.csv -> extract outcome name
fixest_files <- list.files(fixest_dir, pattern = "^A5_.*\\.csv$", full.names = TRUE)
fixest_outcomes <- gsub("^A5_|\\.csv$", "", basename(fixest_files))
names(fixest_files) <- fixest_outcomes

# Stan outcomes: subdirectory names
stan_outcomes <- list.dirs(stan_dir, recursive = FALSE, full.names = FALSE)

cat("================================================================\n")
cat("  AVAILABLE RESULTS\n")
cat("================================================================\n\n")
cat("Fixest A5 outcomes:", paste(fixest_outcomes, collapse = ", "), "\n")
cat("Stan outcomes:     ", paste(stan_outcomes, collapse = ", "), "\n\n")

# Find overlapping outcomes
overlap <- intersect(fixest_outcomes, stan_outcomes)

if (length(overlap) == 0) {
  cat("*** NO OVERLAPPING OUTCOMES ***\n\n")
  cat("Currently:\n")
  cat("  - Fixest has: ", paste(fixest_outcomes, collapse = ", "), "\n")
  cat("  - Stan has:   ", paste(stan_outcomes, collapse = ", "), "\n\n")
  cat("To enable direct comparison, either:\n")
  cat("  1. Run fixest for 'total' outcome (add to run_all_analyses.R), OR\n")
  cat("  2. Run Stan for one of:", paste(fixest_outcomes, collapse = ", "), "\n\n")
} else {
  cat("Overlapping outcomes:", paste(overlap, collapse = ", "), "\n\n")
}

# ==============================================================================
#          3. LOAD AND COMPARE (if overlapping outcomes exist)
# ==============================================================================

comparison_results <- NULL

if (length(overlap) > 0) {

  for (outcome in overlap) {
    cat(sprintf("\n--- Comparing outcome: %s ---\n\n", outcome))

    # ------------------------------------------------------------------
    # 3a. Load fixest results
    # ------------------------------------------------------------------
    fixest_df <- read_csv(fixest_files[[outcome]], show_col_types = FALSE)

    # Extract exposure level and slope terms per restaurant
    fixest_exposure <- fixest_df %>%
      filter(grepl("^exposure_", term)) %>%
      filter(!grepl(":gender", term)) %>%
      mutate(
        # Parse: exposure_RESTID_LEVEL or exposure_RESTID_LEVEL:date_code
        has_slope = grepl(":date_code", term),
        effect_type = ifelse(has_slope, "slope", "level"),
        # Extract restaurant ID from the term name
        rest_id = str_extract(term, "(?<=exposure_)[A-Z0-9]+"),
        # Extract exposure level number
        expo_level = str_extract(term, "(?<=_)\\d+(?=($|:))") %>% as.integer()
      ) %>%
      select(rest_id, expo_level, effect_type,
             fixest_est = estimate, fixest_se = std_error,
             fixest_ci_lo = ci_lower, fixest_ci_hi = ci_upper,
             fixest_pval = p_value,
             n_obs, n_customers)

    # ------------------------------------------------------------------
    # 3b. Load Stan results
    # ------------------------------------------------------------------
    stan_summ <- readRDS(file.path(stan_dir, outcome, "summ.rds"))
    stan_pmap <- readRDS(file.path(stan_dir, outcome, "predictor_map.rds"))
    stan_rests <- readRDS(file.path(stan_dir, outcome, "restaurants_order.rds"))

    # Build mapping from (rest_id, expo_level, effect_type) to beta[col, rest_idx]
    expo_rows <- stan_pmap %>%
      filter(type %in% c("exposure", "slope")) %>%
      mutate(
        effect_type = ifelse(type == "exposure", "level", "slope"),
        rest_id = str_extract(model_col, "(?<=exposure_)[A-Z0-9]+"),
        expo_level = str_extract(model_col, "(?<=_)\\d+(?=($|_slope))") %>% as.integer()
      )

    # For each exposure row, figure out which restaurant index it maps to
    # Each exposure column only has a non-zero beta for its own restaurant
    stan_exposure <- expo_rows %>%
      rowwise() %>%
      mutate(
        rest_idx = which(stan_rests == rest_id),
        beta_var = paste0("beta[", col_index, ",", rest_idx, "]")
      ) %>%
      ungroup()

    # Join with summary
    stan_exposure <- stan_exposure %>%
      left_join(
        stan_summ %>% select(variable, stan_mean = mean, stan_median = median,
                             stan_sd = sd, stan_q5 = q5, stan_q95 = q95,
                             stan_rhat = rhat),
        by = c("beta_var" = "variable")
      ) %>%
      select(rest_id, expo_level, effect_type,
             stan_mean, stan_median, stan_sd, stan_q5, stan_q95, stan_rhat)

    # ------------------------------------------------------------------
    # 3c. Merge
    # ------------------------------------------------------------------
    merged <- fixest_exposure %>%
      inner_join(stan_exposure, by = c("rest_id", "expo_level", "effect_type"))

    if (nrow(merged) == 0) {
      cat("  No matching exposure terms found between models.\n")
      next
    }

    merged$outcome <- outcome

    # Print comparison table
    cat("\n  Exposure Effect Comparison (level and slope):\n")
    cat("  ", strrep("-", 100), "\n")
    cat(sprintf("  %-16s %-6s %-6s %10s %10s %10s %10s %10s\n",
                "Restaurant", "Level", "Type", "Fixest_Est", "Stan_Mean", "Diff",
                "Fixest_SE", "Stan_SD"))
    cat("  ", strrep("-", 100), "\n")

    for (j in seq_len(nrow(merged))) {
      r <- merged[j, ]
      cat(sprintf("  %-16s %-6d %-6s %10.6f %10.6f %10.6f %10.6f %10.6f\n",
                  r$rest_id, r$expo_level, r$effect_type,
                  r$fixest_est, r$stan_mean, r$fixest_est - r$stan_mean,
                  r$fixest_se, r$stan_sd))
    }
    cat("\n")

    # Accumulate
    comparison_results <- bind_rows(comparison_results, merged)
  }

  # ------------------------------------------------------------------
  # 4. SCATTER PLOTS (if we have comparison data)
  # ------------------------------------------------------------------
  if (!is.null(comparison_results) && nrow(comparison_results) > 0) {

    plot_dir <- "customer_analysis/transaction_level/comparison_plots"
    dir.create(plot_dir, showWarnings = FALSE, recursive = TRUE)

    # --- 4a. Scatter: fixest estimate vs stan posterior mean ---
    p_scatter <- ggplot(comparison_results, aes(x = fixest_est, y = stan_mean)) +
      geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "grey50") +
      geom_errorbar(aes(ymin = stan_q5, ymax = stan_q95), width = 0, alpha = 0.3, color = "steelblue") +
      geom_errorbarh(aes(xmin = fixest_ci_lo, xmax = fixest_ci_hi), height = 0, alpha = 0.3, color = "firebrick") +
      geom_point(aes(color = effect_type, shape = rest_id), size = 3) +
      labs(
        title = "Fixest MLE vs Stan Posterior Mean (Exposure Effects)",
        subtitle = paste("Outcomes:", paste(unique(comparison_results$outcome), collapse = ", ")),
        x = "Fixest Conditional Poisson MLE",
        y = "Stan Multilevel Posterior Mean",
        color = "Effect Type",
        shape = "Restaurant"
      ) +
      theme_minimal() +
      theme(legend.position = "bottom")

    ggsave(file.path(plot_dir, "fixest_vs_stan_scatter.png"), p_scatter,
           width = 8, height = 7, dpi = 300)
    cat("Saved scatter plot:", file.path(plot_dir, "fixest_vs_stan_scatter.png"), "\n")

    # --- 4b. Shrinkage plot: how much does Stan shrink toward mu_gamma? ---
    # For each outcome, load mu_gamma
    for (outcome in overlap) {
      stan_summ <- readRDS(file.path(stan_dir, outcome, "summ.rds"))

      mu_gamma_rows <- stan_summ %>% filter(grepl("^mu_gamma\\[", variable))
      if (nrow(mu_gamma_rows) > 0) {
        cat(sprintf("\n  Stan global means (mu_gamma) for '%s':\n", outcome))
        for (k in seq_len(nrow(mu_gamma_rows))) {
          label <- ifelse(k == 1, "level", "slope")
          cat(sprintf("    mu_gamma[%d] (%s): mean = %.6f, 90%% CI = [%.6f, %.6f]\n",
                      k, label, mu_gamma_rows$mean[k], mu_gamma_rows$q5[k], mu_gamma_rows$q95[k]))
        }
      }
    }

    # Shrinkage visualization
    shrinkage_data <- comparison_results %>%
      group_by(outcome, effect_type) %>%
      mutate(
        fixest_grand_mean = mean(fixest_est, na.rm = TRUE)
      ) %>%
      ungroup()

    p_shrinkage <- ggplot(shrinkage_data, aes(y = paste(rest_id, expo_level, sep = "_"))) +
      geom_point(aes(x = fixest_est, color = "Fixest MLE"), size = 3) +
      geom_point(aes(x = stan_mean, color = "Stan Posterior Mean"), size = 3, shape = 17) +
      geom_segment(
        aes(x = fixest_est, xend = stan_mean,
            yend = paste(rest_id, expo_level, sep = "_")),
        arrow = arrow(length = unit(0.15, "cm")),
        color = "grey40", alpha = 0.5
      ) +
      facet_grid(effect_type ~ outcome, scales = "free") +
      scale_color_manual(values = c("Fixest MLE" = "firebrick", "Stan Posterior Mean" = "steelblue")) +
      labs(
        title = "Shrinkage: Fixest MLE -> Stan Posterior Mean",
        subtitle = "Arrows show direction of partial pooling",
        x = "Estimate",
        y = "Restaurant_ExposureLevel",
        color = ""
      ) +
      theme_minimal() +
      theme(legend.position = "bottom")

    ggsave(file.path(plot_dir, "shrinkage_plot.png"), p_shrinkage,
           width = 10, height = 6, dpi = 300)
    cat("Saved shrinkage plot:", file.path(plot_dir, "shrinkage_plot.png"), "\n")
  }
}

# ==============================================================================
#          5. WRITE MARKDOWN SUMMARY
# ==============================================================================

md_lines <- c(
  "# Model Comparison: Fixest vs Stan Conditional Poisson",
  "",
  "## Overview",
  "",
  "Both models estimate the effect of plant-based menu item exposure on customer",
  "purchasing behavior using a **conditional Poisson** likelihood that conditions",
  "on each customer's total purchase count (the sufficient statistic). This",
  "eliminates customer fixed effects without estimating them.",
  "",
  "The key difference is **structure**: fixest estimates each restaurant independently,",
  "while Stan estimates all restaurants jointly with a multilevel hierarchy that shares",
  "information across restaurants.",
  "",
  "## Specification Comparison",
  "",
  "| Feature | Fixest (`fepois`) | Stan (multilevel) |",
  "|---------|-------------------|-------------------|"
)

for (i in seq_len(nrow(spec_table))) {
  # Escape pipe characters in cell values so they don't break the markdown table
  feat   <- gsub("\\|", "\\\\|", spec_table$Feature[i])
  fixest <- gsub("\\|", "\\\\|", spec_table$`Fixest (fepois)`[i])
  stan   <- gsub("\\|", "\\\\|", spec_table$`Stan (multilevel)`[i])
  md_lines <- c(md_lines, sprintf("| %s | %s | %s |", feat, fixest, stan))
}

md_lines <- c(md_lines, "",
  "## Likelihood",
  "",
  "Both models use an **identical** conditional Poisson likelihood:",
  "",
  "```",
  "log p(y_i | beta) = sum_t y_it * nu_it - n_i * log(sum_t exp(nu_it))",
  "```",
  "",
  "where `nu_it = X_it * beta` is the linear predictor and `n_i = sum_t y_it`",
  "is the customer's total count. This form cancels out any customer-level",
  "constant (the customer fixed effect), so it does not need to be estimated.",
  "",
  "- **Fixest**: `fixest::fepois(outcome ~ predictors | customer_id, vcov = ~customer_id)`",
  "- **Stan**: Implemented directly in the `model` block via `target += sum_y_nu - n_i[c] * log_sum_exp(nu[c_start:c_end])`",
  "",
  "## Inference Framework",
  "",
  "| Aspect | Fixest | Stan |",
  "|--------|--------|------|",
  "| Point estimate | Maximum Likelihood Estimate (MLE) | Posterior mean (or median) |",
  "| Uncertainty | Sandwich/clustered SE at customer level | Full posterior distribution |",
  "| Intervals | 95% Wald CI: estimate +/- 1.96 * SE | 90% credible interval: [q5, q95] |",
  "| p-values | Wald test | Not directly; check if CI excludes zero |",
  "| Priors | None (pure likelihood) | Normal(0, scale) on mu_gamma; Student-t(3,0,scale) on sigmas |",
  "",
  "## Structural Differences",
  "",
  "### Fixest: Independent Per-Restaurant Models",
  "",
  "Each restaurant is estimated in complete isolation. The exposure effect for",
  "restaurant r is simply the MLE from that restaurant's data alone. If a restaurant",
  "has very few customers or extreme data, its estimate can be noisy or extreme.",
  "",
  "### Stan: 3-Level Multilevel Hierarchy",
  "",
  "All restaurants are estimated jointly. The exposure effect for a specific exposure",
  "column at restaurant r is decomposed as:",
  "",
  "```",
  "gamma[k,r,e] = mu_gamma[k] + eta[k,r] + epsilon[k,r,e]",
  "```",
  "",
  "where:",
  "- `mu_gamma[k]` = global mean effect for parameter k (k=1: level, k=2: slope)",
  "- `eta[k,r] ~ N(0, sigma_gamma_between[k])` = between-restaurant deviation",
  "- `epsilon[k,r,e] ~ N(0, sigma_gamma_within[k])` = within-restaurant deviation (multiple exposures)",
  "- `sigma_gamma_between` controls how much restaurants can differ from the global mean",
  "- `sigma_gamma_within` controls how much exposures within a restaurant can differ",
  "",
  "This is a **partial pooling** model. It shares information across restaurants,",
  "which has two key implications:",
  "",
  "1. **Shrinkage**: Extreme restaurant-specific estimates are pulled toward the global mean",
  "2. **Borrowing strength**: Restaurants with less data borrow information from data-rich restaurants",
  "",
  "## When the Models Should Agree",
  "",
  "With sufficient data per restaurant and weak/diffuse priors, the Stan posterior",
  "means should approximately equal the fixest MLEs. Specifically:",
  "",
  "- Large N per restaurant -> likelihood dominates prior -> posterior ~ MLE",
  "- Weak priors (large scale parameters) -> minimal shrinkage",
  "- Similar effect sizes across restaurants -> little tension between pooled and unpooled",
  "",
  "In the limit, with flat priors and a single restaurant, the Stan model reduces",
  "to the fixest model (the conditional Poisson MLE).",
  "",
  "## When the Models Should Diverge",
  "",
  "1. **Small samples**: Restaurants with few customers will see their Stan estimates",
  "   shrunk substantially toward the global mean, while fixest gives the raw MLE",
  "   (which may be noisy or extreme).",
  "",
  "2. **Strong priors**: If the prior scales are tight (small mu_gamma_scale,",
  "   sigma_gamma_between_scale), the Stan model applies more regularization.",
  "",
  "3. **Heterogeneous effects**: If true effects vary widely across restaurants,",
  "   the Stan model will partially pool, producing estimates between the restaurant-",
  "   specific MLE and the grand mean. The degree of shrinkage is estimated from data",
  "   (via sigma_gamma_between).",
  "",
  "4. **Extreme estimates**: A restaurant with an unusually large or small fixest",
  "   estimate will be pulled toward the center by the multilevel model. This is",
  "   desirable if the extreme estimate is due to noise, but conservative if the",
  "   restaurant truly has an unusual effect.",
  ""
)

# Add overlap/availability section
md_lines <- c(md_lines,
  "## Current Data Availability",
  "",
  sprintf("- **Fixest outcomes available**: %s", paste(fixest_outcomes, collapse = ", ")),
  sprintf("- **Stan outcomes available**: %s", paste(stan_outcomes, collapse = ", ")),
  ""
)

if (length(overlap) == 0) {
  md_lines <- c(md_lines,
    "**No overlapping outcomes exist for direct comparison.**",
    "",
    "The fixest models have been run for category-specific outcomes (nonvegan, meat,",
    "chicken_fish, vegan, vegetarian), while the Stan model has only been run for the",
    "`total` outcome. To enable a head-to-head comparison of estimates:",
    "",
    "1. Run fixest for the `total` outcome (already listed in `A5_OUTCOMES` in",
    "   `run_all_analyses.R`), or",
    "2. Run the Stan multilevel model for one of the existing fixest outcomes.",
    "",
    "Once overlapping outcomes exist, re-run this script to generate scatter plots",
    "of fixest MLE vs Stan posterior mean and shrinkage visualizations.",
    ""
  )
} else {
  md_lines <- c(md_lines,
    sprintf("**Overlapping outcomes**: %s", paste(overlap, collapse = ", ")),
    "",
    "### Comparison Results",
    ""
  )

  if (!is.null(comparison_results) && nrow(comparison_results) > 0) {
    md_lines <- c(md_lines,
      "| Restaurant | Expo Level | Type | Fixest Est | Stan Mean | Difference | Fixest SE | Stan SD |",
      "|-----------|-----------|------|-----------|----------|-----------|----------|---------|"
    )
    for (j in seq_len(nrow(comparison_results))) {
      r <- comparison_results[j, ]
      md_lines <- c(md_lines, sprintf("| %s | %d | %s | %.6f | %.6f | %.6f | %.6f | %.6f |",
                                      r$rest_id, r$expo_level, r$effect_type,
                                      r$fixest_est, r$stan_mean, r$fixest_est - r$stan_mean,
                                      r$fixest_se, r$stan_sd))
    }
    md_lines <- c(md_lines, "",
      "### Plots",
      "",
      "- `comparison_plots/fixest_vs_stan_scatter.png`: Scatter of fixest MLE vs Stan posterior mean with uncertainty bands",
      "- `comparison_plots/shrinkage_plot.png`: Arrows showing direction and magnitude of shrinkage from partial pooling",
      ""
    )
  }
}

md_lines <- c(md_lines,
  "## Summary",
  "",
  "| Question | Answer |",
  "|----------|--------|",
  "| Same likelihood? | Yes -- both use conditional Poisson |",
  "| Same point estimates? | Only asymptotically (large N, weak priors) |",
  "| Same intervals? | No -- Wald CI vs posterior credible interval |",
  "| Key advantage of fixest? | Fast, simple, no priors needed |",
  "| Key advantage of Stan? | Partial pooling, full posterior, better in small samples |",
  "| When to prefer fixest? | Quick exploratory analysis, large samples, no pooling desired |",
  "| When to prefer Stan? | Publication results, small samples, want shrinkage/regularization |",
  "",
  paste0("*Generated by `compare_models.R` on ", Sys.Date(), "*"),
  ""
)

# Write markdown
md_path <- "customer_analysis/compare_models_summary.md"
writeLines(md_lines, md_path)
cat("\nMarkdown summary written to:", md_path, "\n")

cat("\n================================================================\n")
cat("  COMPARISON COMPLETE\n")
cat("================================================================\n")

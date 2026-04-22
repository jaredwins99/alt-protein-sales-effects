################################################################################
# STRUCTURAL ZEROS ANALYSIS
# Identify and visualize structural zeros (closures / anomalous low days)
#
# Definition: A structural zero is an observation where a restaurant's count
# is so far below its OWN typical level that it likely represents a closure
# or anomalous event — not normal demand variation.
#
# Criterion: observation is 3+ SDs below the RESTAURANT-SPECIFIC mean
#
# Scope: Tier 1 restaurants only, matching model_starters definitions
################################################################################

library(tidyverse)
library(arrow)
library(patchwork)

OUT_DIR <- file.path("review", "zero_prop", "plots")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# ==============================================================================
# 1. LOAD DATA
# ==============================================================================

its_data <- read_parquet(file.path("data", "4_data_parquet_modeling", "a3_its", "finalized.parquet"))
customer_data <- read_parquet(file.path("data", "4_data_parquet_modeling", "customer", "finalized_customers.parquet"))
prop_data <- read_parquet(file.path("data", "4_data_parquet_modeling", "a1_proportion", "finalized_vegan_dishes_count.parquet"))
prop_targeted_data <- read_parquet(file.path("data", "4_data_parquet_modeling", "a2_proportion_t", "finalized_textured_dishes_count.parquet"))

if ("breakfast_outcome_p" %in% colnames(prop_targeted_data)) {
    prop_targeted_data <- prop_targeted_data %>%
        rename(breakfast_p_outcome = breakfast_outcome_p,
               chicken_p_outcome = chicken_outcome_p,
               dairy_p_outcome = dairy_outcome_p,
               egg_p_outcome = egg_outcome_p,
               textured_p_outcome = textured_outcome_p,
               untextured_p_outcome = untextured_outcome_p)
}

# ==============================================================================
# 2. T1 RESTAURANT-OUTCOME MAPPING (from model_starters)
# ==============================================================================

# Each entry: list of restaurants modeled for that outcome
# ITS outcomes
its_map <- list(
    total        = c('VLZX7K2M9QD4T', 'SRQS8F7JWA9MZ', '2HRX9P6HKXA8V', 'JHDN7CF1C03X5', 'L69HYJ4Y3TR91', 'ED5J990H5VAZT'),
    vegan        = c('VLZX7K2M9QD4T', 'SRQS8F7JWA9MZ', '2HRX9P6HKXA8V', 'JHDN7CF1C03X5', 'L69HYJ4Y3TR91', 'ED5J990H5VAZT'),
    vegetarian   = c('VLZX7K2M9QD4T', 'SRQS8F7JWA9MZ', '2HRX9P6HKXA8V', 'JHDN7CF1C03X5', 'L69HYJ4Y3TR91', 'ED5J990H5VAZT'),
    meat         = c('VLZX7K2M9QD4T', 'SRQS8F7JWA9MZ', '2HRX9P6HKXA8V', 'JHDN7CF1C03X5', 'L69HYJ4Y3TR91', 'ED5J990H5VAZT'),
    nonvegan     = c('VLZX7K2M9QD4T', 'SRQS8F7JWA9MZ', '2HRX9P6HKXA8V', 'JHDN7CF1C03X5', 'L69HYJ4Y3TR91', 'ED5J990H5VAZT'),
    chicken_fish = c('VLZX7K2M9QD4T', '2HRX9P6HKXA8V', 'JHDN7CF1C03X5', 'L69HYJ4Y3TR91', 'ED5J990H5VAZT')
)

# ITS targeted outcomes
its_targeted_map <- list(
    textured   = c('VLZX7K2M9QD4T'),
    untextured = c('SRQS8F7JWA9MZ'),
    breakfast  = c('2HRX9P6HKXA8V', 'L69HYJ4Y3TR91', 'ED5J990H5VAZT')
)

# Proportion (default T1 restaurants, no VLZX7K2M9QD4T)
prop_default <- c('SRQS8F7JWA9MZ', '2HRX9P6HKXA8V', 'JHDN7CF1C03X5', 'L69HYJ4Y3TR91', 'ED5J990H5VAZT', 'W8T41JZK0ZMEP')

# Proportion targeted
prop_targeted_map <- list(
    breakfast_p  = c('2HRX9P6HKXA8V', 'ED5J990H5VAZT', 'L69HYJ4Y3TR91'),
    chicken_p    = c('JHDN7CF1C03X5', 'W8T41JZK0ZMEP'),
    dairy_p      = c('ED5J990H5VAZT', 'JHDN7CF1C03X5', 'W8T41JZK0ZMEP'),
    egg_p        = c('ED5J990H5VAZT', 'W8T41JZK0ZMEP'),
    untextured_p = c('SRQS8F7JWA9MZ')
)

# Customer targeted
cust_targeted_map <- list(
    breakfast  = c('2HRX9P6HKXA8V', 'L69HYJ4Y3TR91', 'ED5J990H5VAZT'),
    untextured = c('SRQS8F7JWA9MZ')
)

# ==============================================================================
# 3. DETECT STRUCTURAL ZEROS — PER RESTAURANT
# ==============================================================================

detect_structural <- function(data, outcome_col, restaurants, analysis_label) {
    if (!outcome_col %in% colnames(data)) {
        message("Column ", outcome_col, " not found, skipping")
        return(tibble())
    }

    outcome_name <- str_remove(outcome_col, "_outcome$")

    data %>%
        filter(location_id %in% restaurants) %>%
        select(location_id, date, value = all_of(outcome_col)) %>%
        group_by(location_id) %>%
        mutate(
            rest_mean = mean(value, na.rm = TRUE),
            rest_sd = sd(value, na.rm = TRUE),
            threshold = rest_mean - 3 * rest_sd,
            is_structural = (value <= pmax(threshold, 0)) & (rest_mean > 0) & (rest_sd > 0)
        ) %>%
        ungroup() %>%
        mutate(outcome = outcome_name, analysis = analysis_label)
}

cat("Detecting structural zeros for T1 analyses...\n")

# ITS
its_obs_list <- imap(its_map, function(rests, outcome) {
    detect_structural(its_data, paste0(outcome, "_outcome"), rests, "a3_its")
})

# ITS targeted
its_t_obs_list <- imap(its_targeted_map, function(rests, outcome) {
    detect_structural(its_data, paste0(outcome, "_outcome"), rests, "a4_its_t")
})

# Proportion (same outcomes as ITS, different restaurants)
prop_outcomes <- c("total", "vegan", "vegetarian", "meat", "nonvegan", "chicken_fish")
prop_obs_list <- map(prop_outcomes, function(outcome) {
    detect_structural(prop_data, paste0(outcome, "_outcome"), prop_default, "a1_proportion")
})

# Proportion targeted
prop_t_obs_list <- imap(prop_targeted_map, function(rests, outcome) {
    detect_structural(prop_targeted_data, paste0(outcome, "_outcome"), rests, "a2_proportion_t")
})

# Customer (same restaurants as ITS for main outcomes)
cust_outcomes <- intersect(paste0(names(its_map), "_outcome"), colnames(customer_data))
cust_obs_list <- map(cust_outcomes, function(col) {
    outcome_name <- str_remove(col, "_outcome$")
    rests <- its_map[[outcome_name]]
    if (is.null(rests)) rests <- prop_default
    detect_structural(customer_data, col, rests, "customer")
})

# Customer targeted
cust_t_obs_list <- imap(cust_targeted_map, function(rests, outcome) {
    detect_structural(customer_data, paste0(outcome, "_outcome"), rests, "customer_targeted")
})

all_obs <- bind_rows(
    its_obs_list, its_t_obs_list,
    prop_obs_list, prop_t_obs_list,
    cust_obs_list, cust_t_obs_list
)

cat("Total observations:", nrow(all_obs), "\n")

# ==============================================================================
# 4. SUMMARIZE PER RESTAURANT-OUTCOME
# ==============================================================================

all_stats <- all_obs %>%
    group_by(location_id, outcome, analysis) %>%
    summarize(
        n_obs = n(),
        rest_mean = first(rest_mean),
        rest_sd = first(rest_sd),
        threshold_3sd = first(threshold),
        n_zeros = sum(value == 0, na.rm = TRUE),
        zero_rate = n_zeros / n_obs,
        n_structural = sum(is_structural, na.rm = TRUE),
        structural_rate = n_structural / n_obs,
        .groups = "drop"
    ) %>%
    mutate(
        outcome_type = case_when(
            outcome %in% c("total") ~ "Total",
            outcome %in% c("vegan", "vegetarian", "meat", "nonvegan", "chicken_fish") ~ "Main Category",
            outcome %in% c("breakfast", "textured", "untextured") ~ "Targeted",
            outcome %in% c("breakfast_p", "chicken_p", "dairy_p", "egg_p", "textured_p", "untextured_p") ~ "Targeted (Prop)",
            TRUE ~ "Other"
        )
    )

# ==============================================================================
# 5. PLOTS — SPLIT BY RESTAURANT
# ==============================================================================

# --- PLOT 1: Heatmap per restaurant x outcome (ITS analyses) ---
its_stats <- all_stats %>% filter(analysis %in% c("a3_its", "a4_its_t"))

p1 <- its_stats %>%
    ggplot(aes(x = outcome, y = location_id, fill = structural_rate)) +
    geom_tile(color = "white") +
    geom_text(aes(label = sprintf("%.1f%%", structural_rate * 100)), size = 2.8) +
    scale_fill_gradient2(low = "white", mid = "orange", high = "darkred",
                         midpoint = 0.05, limits = c(0, NA),
                         name = "Structural\nZero Rate") +
    labs(title = "Structural Zero Rate — ITS T1 (per-restaurant 3-SD)",
         subtitle = "Only restaurant-outcome pairs actually modeled in T1",
         x = "Outcome", y = "Restaurant") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(file.path(OUT_DIR, "heatmap_structural_its_t1.png"), p1, width = 12, height = 6, dpi = 150)

# --- PLOT 1b: Proportion targeted ---
prop_t_stats <- all_stats %>% filter(analysis == "a2_proportion_t")
if (nrow(prop_t_stats) > 0) {
    p1b <- prop_t_stats %>%
        ggplot(aes(x = outcome, y = location_id, fill = structural_rate)) +
        geom_tile(color = "white") +
        geom_text(aes(label = sprintf("%.1f%%", structural_rate * 100)), size = 2.8) +
        scale_fill_gradient2(low = "white", mid = "orange", high = "darkred",
                             midpoint = 0.05, limits = c(0, NA),
                             name = "Structural\nZero Rate") +
        labs(title = "Structural Zero Rate — Proportion Targeted T1",
             x = "Outcome", y = "Restaurant") +
        theme_minimal() +
        theme(axis.text.x = element_text(angle = 45, hjust = 1))

    ggsave(file.path(OUT_DIR, "heatmap_structural_prop_targeted_t1.png"), p1b, width = 10, height = 5, dpi = 150)
}

# --- PLOT 2: Per-restaurant faceted bar chart ---
p2 <- its_stats %>%
    ggplot(aes(x = outcome, y = structural_rate, fill = outcome_type)) +
    geom_col() +
    facet_wrap(~location_id, scales = "free_x") +
    scale_y_continuous(labels = scales::percent) +
    labs(title = "Structural Zero Rate by Restaurant (ITS T1)",
         x = "Outcome", y = "Structural Zero Rate", fill = "Type") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 60, hjust = 1, size = 7))

ggsave(file.path(OUT_DIR, "barplot_per_restaurant_its_t1.png"), p2, width = 14, height = 8, dpi = 150)

# --- PLOT 3: Time series per restaurant, all outcomes ---
plot_restaurant_ts <- function(obs_data, rest_id) {
    d <- obs_data %>%
        filter(location_id == rest_id, analysis %in% c("a3_its", "a4_its_t"))

    if (nrow(d) == 0) return(NULL)

    outcomes_available <- unique(d$outcome)

    ggplot(d, aes(x = date, y = value)) +
        geom_line(alpha = 0.4) +
        geom_point(data = filter(d, is_structural),
                   color = "red", size = 1.5, alpha = 0.8) +
        geom_hline(aes(yintercept = threshold), linetype = "dashed",
                   color = "red", alpha = 0.4) +
        geom_hline(aes(yintercept = rest_mean), linetype = "solid",
                   color = "blue", alpha = 0.3) +
        facet_wrap(~outcome, scales = "free_y") +
        labs(title = paste("Structural Zeros —", rest_id),
             subtitle = "Red = flagged (3 SD below mean). Blue = mean. Dashed = threshold.",
             x = "Date", y = "Count") +
        theme_minimal() +
        theme(strip.text = element_text(size = 9))
}

t1_restaurants <- unique(its_stats$location_id)
for (rid in t1_restaurants) {
    p <- plot_restaurant_ts(all_obs, rid)
    if (!is.null(p)) {
        n_outcomes <- length(unique(filter(all_obs, location_id == rid,
                                           analysis %in% c("a3_its", "a4_its_t"))$outcome))
        h <- max(6, ceiling(n_outcomes / 3) * 3)
        ggsave(file.path(OUT_DIR, paste0("timeseries_", rid, ".png")), p,
               width = 14, height = h, dpi = 150)
    }
}

# --- PLOT 4: Scatter — restaurant mean vs structural rate, by restaurant ---
p4 <- its_stats %>%
    filter(rest_mean > 0) %>%
    ggplot(aes(x = rest_mean, y = structural_rate, color = location_id, shape = outcome_type)) +
    geom_point(size = 3, alpha = 0.8) +
    geom_text(aes(label = outcome), hjust = -0.1, vjust = -0.1, size = 2.5, check_overlap = TRUE) +
    scale_y_continuous(labels = scales::percent) +
    scale_x_log10() +
    labs(title = "Restaurant Mean vs Structural Zero Rate (ITS T1)",
         x = "Restaurant Mean (log scale)", y = "Structural Zero Rate",
         color = "Restaurant", shape = "Outcome Type") +
    theme_minimal()

ggsave(file.path(OUT_DIR, "scatter_mean_vs_structural_t1.png"), p4, width = 13, height = 8, dpi = 150)

# --- PLOT 5: Co-occurrence — closures hit multiple outcomes ---
cooccurrence <- all_obs %>%
    filter(analysis %in% c("a3_its", "a4_its_t")) %>%
    group_by(location_id, date) %>%
    summarize(
        n_outcomes = n(),
        n_flagged = sum(is_structural),
        flagged_outcomes = paste(outcome[is_structural], collapse = ", "),
        .groups = "drop"
    ) %>%
    filter(n_flagged > 0)

p5 <- cooccurrence %>%
    ggplot(aes(x = n_flagged)) +
    geom_histogram(binwidth = 1, fill = "steelblue") +
    facet_wrap(~location_id, scales = "free_y") +
    labs(title = "Co-occurrence: How Many Outcomes Flagged on Same Day (per restaurant)",
         subtitle = "If closures, expect multiple outcomes flagged together",
         x = "# Outcomes Flagged", y = "# Days") +
    theme_minimal()

ggsave(file.path(OUT_DIR, "cooccurrence_per_restaurant.png"), p5, width = 12, height = 8, dpi = 150)

# ==============================================================================
# 6. SUMMARY TABLES
# ==============================================================================

cat("\n===== PER-RESTAURANT STRUCTURAL ZERO SUMMARY (ITS T1) =====\n")
its_stats %>%
    select(location_id, outcome, n_obs, zero_rate, structural_rate, rest_mean, threshold_3sd) %>%
    arrange(location_id, desc(structural_rate)) %>%
    print(n = 50)

cat("\n===== AGGREGATED BY OUTCOME =====\n")
its_stats %>%
    group_by(outcome_type, outcome) %>%
    summarize(
        n_restaurants = n(),
        restaurants = paste(location_id, collapse = ", "),
        mean_structural_rate = mean(structural_rate),
        mean_zero_rate = mean(zero_rate),
        .groups = "drop"
    ) %>%
    arrange(desc(mean_structural_rate)) %>%
    print(n = 20, width = 120)

# Save
write_csv(all_stats, file.path("review", "zero_prop", "zero_stats_all.csv"))
write_csv(its_stats, file.path("review", "zero_prop", "its_t1_stats.csv"))

cat("\nPlots saved to:", OUT_DIR, "\n")

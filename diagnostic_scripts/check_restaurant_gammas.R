library(tidyverse)
source("model_scripts/view_params_funcs.R")

cat("=== CASE 1: W8 in A2 Breakfast ===\n\n")

# Breakfast count
model_path <- "model_fits/finalized/proportion_targeted/breakfast_p/breakfast_dishes_count"
if (file.exists(file.path(model_path, "summ.rds"))) {
  model <- list(
    summary = readRDS(file.path(model_path, "summ.rds")),
    predictor_map = readRDS(file.path(model_path, "predictor_map.rds"))
  )
  
  gammas <- model %>%
    find_betas() %>%
    filter(!is.na(model_col) & str_detect(model_col, "exposure"))
  
  # Find W8
  w8_gamma <- gammas %>%
    filter(str_detect(model_col, "W8T41JZK0ZMEP"))
  
  if (nrow(w8_gamma) > 0) {
    cat("Breakfast Count - W8 Restaurant:\n")
    cat("  Raw gamma mean:", w8_gamma$mean, "\n")
    cat("  Rate Ratio = exp(gamma) =", exp(w8_gamma$mean), "\n")
    cat("  90% CI: [", exp(w8_gamma$q5), ",", exp(w8_gamma$q95), "]\n\n")
  }
}

# Breakfast presence
model_path <- "model_fits/finalized/proportion_targeted/breakfast_p/breakfast_dishes_presence"
if (file.exists(file.path(model_path, "summ.rds"))) {
  model <- list(
    summary = readRDS(file.path(model_path, "summ.rds")),
    predictor_map = readRDS(file.path(model_path, "predictor_map.rds"))
  )
  
  gammas <- model %>%
    find_betas() %>%
    filter(!is.na(model_col) & str_detect(model_col, "exposure"))
  
  # Find W8
  w8_gamma <- gammas %>%
    filter(str_detect(model_col, "W8T41JZK0ZMEP"))
  
  if (nrow(w8_gamma) > 0) {
    cat("Breakfast Presence - W8 Restaurant:\n")
    cat("  Raw gamma mean:", w8_gamma$mean, "\n")
    # For presence/proportion, use exp(0.1 * gamma)
    cat("  Rate Ratio = exp(0.1 * gamma) =", exp(0.1 * w8_gamma$mean), "\n")
    cat("  90% CI: [", exp(0.1 * w8_gamma$q5), ",", exp(0.1 * w8_gamma$q95), "]\n\n")
  }
}

cat("\n=== CASE 2: SRQ (SRQS8F7JWA9MZ) in A1 Vegan ===\n\n")

# Vegan dishes count
model_path <- "model_fits/finalized/proportion/vegan/vegan_dishes_count"
if (file.exists(file.path(model_path, "summ.rds"))) {
  model <- list(
    summary = readRDS(file.path(model_path, "summ.rds")),
    predictor_map = readRDS(file.path(model_path, "predictor_map.rds"))
  )
  
  gammas <- model %>%
    find_betas() %>%
    filter(!is.na(model_col) & str_detect(model_col, "exposure"))
  
  # Find SRQ
  srq_gamma <- gammas %>%
    filter(str_detect(model_col, "SRQS8F7JWA9MZ"))
  
  if (nrow(srq_gamma) > 0) {
    cat("Vegan Dishes Count - SRQ Restaurant:\n")
    cat("  Raw gamma mean:", srq_gamma$mean, "\n")
    cat("  Rate Ratio = exp(gamma) =", exp(srq_gamma$mean), "\n")
    cat("  90% CI: [", exp(srq_gamma$q5), ",", exp(srq_gamma$q95), "]\n\n")
  }
}

# Vegan dishes prop
model_path <- "model_fits/finalized/proportion/vegan/vegan_dishes_prop"
if (file.exists(file.path(model_path, "summ.rds"))) {
  model <- list(
    summary = readRDS(file.path(model_path, "summ.rds")),
    predictor_map = readRDS(file.path(model_path, "predictor_map.rds"))
  )
  
  gammas <- model %>%
    find_betas() %>%
    filter(!is.na(model_col) & str_detect(model_col, "exposure"))
  
  # Find SRQ
  srq_gamma <- gammas %>%
    filter(str_detect(model_col, "SRQS8F7JWA9MZ"))
  
  if (nrow(srq_gamma) > 0) {
    cat("Vegan Dishes Proportion - SRQ Restaurant:\n")
    cat("  Raw gamma mean:", srq_gamma$mean, "\n")
    cat("  Rate Ratio = exp(0.1 * gamma) =", exp(0.1 * srq_gamma$mean), "\n")
    cat("  90% CI: [", exp(0.1 * srq_gamma$q5), ",", exp(0.1 * srq_gamma$q95), "]\n\n")
  }
}

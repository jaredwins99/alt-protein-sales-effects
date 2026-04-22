library(tidyverse)

cat("=== CASE 1: W8 in A2 Breakfast (both count and presence) ===\n\n")

# Breakfast count
summ_path <- "model_fits/finalized/a2_proportion_t/breakfast_p/breakfast_dishes_count/summ.rds"
if (file.exists(summ_path)) {
  summ <- readRDS(summ_path)
  mu_gamma <- summ[summ$variable == "mu_gamma[1]", ]
  if (nrow(mu_gamma) > 0) {
    cat("Breakfast Count:\n")
    cat("  mu_gamma[1] =", mu_gamma$mean, "\n")
    cat("  Rate Ratio = exp(mu_gamma[1]) =", exp(mu_gamma$mean), "\n")
    cat("  90% CI: [", exp(mu_gamma$q5), ",", exp(mu_gamma$q95), "]\n\n")
  }
}

# Breakfast presence
summ_path <- "model_fits/finalized/a2_proportion_t/breakfast_p/breakfast_dishes_presence/summ.rds"
if (file.exists(summ_path)) {
  summ <- readRDS(summ_path)
  mu_gamma <- summ[summ$variable == "mu_gamma[1]", ]
  if (nrow(mu_gamma) > 0) {
    cat("Breakfast Presence:\n")
    cat("  mu_gamma[1] =", mu_gamma$mean, "\n")
    cat("  Rate Ratio = exp(0.1 * mu_gamma[1]) =", exp(0.1 * mu_gamma$mean), "\n")
    cat("  90% CI: [", exp(0.1 * mu_gamma$q5), ",", exp(0.1 * mu_gamma$q95), "]\n\n")
  }
}

cat("\n=== CASE 2: SRQ in A1 Proportion, vegan outcome, vegan_dishes exposure ===\n\n")

# Vegan dishes count
summ_path <- "model_fits/finalized/a1_proportion/vegan/vegan_dishes_count/summ.rds"
if (file.exists(summ_path)) {
  summ <- readRDS(summ_path)
  mu_gamma <- summ[summ$variable == "mu_gamma[1]", ]
  if (nrow(mu_gamma) > 0) {
    cat("Vegan Dishes Count:\n")
    cat("  mu_gamma[1] =", mu_gamma$mean, "\n")
    cat("  Rate Ratio = exp(mu_gamma[1]) =", exp(mu_gamma$mean), "\n")
    cat("  90% CI: [", exp(mu_gamma$q5), ",", exp(mu_gamma$q95), "]\n\n")
  }
}

# Vegan dishes prop
summ_path <- "model_fits/finalized/a1_proportion/vegan/vegan_dishes_prop/summ.rds"
if (file.exists(summ_path)) {
  summ <- readRDS(summ_path)
  mu_gamma <- summ[summ$variable == "mu_gamma[1]", ]
  if (nrow(mu_gamma) > 0) {
    cat("Vegan Dishes Proportion:\n")
    cat("  mu_gamma[1] =", mu_gamma$mean, "\n")
    cat("  Rate Ratio = exp(0.1 * mu_gamma[1]) =", exp(0.1 * mu_gamma$mean), "\n")
    cat("  90% CI: [", exp(0.1 * mu_gamma$q5), ",", exp(0.1 * mu_gamma$q95), "]\n\n")
  }
}

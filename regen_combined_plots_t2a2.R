source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# Regen combined weekly plots for 6 T2 A2 fit dirs under finalized_redone_trunc/
# whose per-restaurant PNGs exist but combined ones don't. Restaurants derived
# from the saved restaurants_order.rds for each fit.

regen <- function(outcome, exposure, price_pred) {
  ro <- readRDS(file.path("model_fits", "finalized_redone_trunc",
                          "t2_a2_proportion_t", outcome, exposure,
                          "restaurants_order.rds"))
  cat("\n==", outcome, exposure, "—", length(ro), "restaurants ==\n")
  run_prop_targeted_t2(
    outcome = outcome, exposure = exposure,
    restaurants_to_model = ro,
    extra_price_predictor = price_pred,
    directory = "finalized_redone_trunc",
    replot_only = TRUE)
}

regen("breakfast_p",  "breakfast_dishes_count",   "breakfast_p_price_real")
regen("breakfast_p",  "breakfast_dishes_presence","breakfast_p_price_real")
regen("dairy_p",      "dairy_dishes_count",       "dairy_p_price_real")
regen("dairy_p",      "dairy_dishes_presence",    "dairy_p_price_real")
regen("untextured_p", "untextured_dishes_count",  "untextured_p_price_real")
regen("untextured_p", "untextured_dishes_presence","untextured_p_price_real")

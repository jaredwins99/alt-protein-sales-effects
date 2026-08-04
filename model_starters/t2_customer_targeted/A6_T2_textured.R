source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_customer_t2_restaurants$textured = c('SAFK7ND1HR6XS')  # VLZX7K2M9QD4T removed: not in customer data
run_customer_targeted_t2_day(
    outcome = "textured_t2",
    restaurants_to_model = c('SAFK7ND1HR6XS'),
    extra_price_predictor = "textured_t2_price_real",
    directory = "finalized_uncontaminated2",
    thin = 2
)

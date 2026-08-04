source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_customer_restaurants$untextured = c('SRQS8F7JWA9MZ')
run_customer_targeted(
    outcome = "untextured",
    restaurants_to_model = c('SRQS8F7JWA9MZ'),
    extra_price_predictor = "untextured_price_real",
    directory = "finalized_uncontaminated2"
)

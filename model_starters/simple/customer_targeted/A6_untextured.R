source(file.path("model_scripts", "analysis_scripts", "run_analysis_nopred.R"))

# targeted_customer_restaurants$untextured = c('SRQS8F7JWA9MZ')
run_simple_customer_targeted(
    outcome = "untextured",
    restaurants_to_model = c('SRQS8F7JWA9MZ'),
    extra_price_predictor = "untextured_price_real"
)

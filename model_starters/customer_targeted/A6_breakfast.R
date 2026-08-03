source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_customer_restaurants$breakfast = c('2HRX9P6HKXA8V','L69HYJ4Y3TR91','ED5J990H5VAZT')
run_customer_targeted_day(
    outcome = "breakfast",
    restaurants_to_model = c('2HRX9P6HKXA8V', 'L69HYJ4Y3TR91', 'ED5J990H5VAZT'),
    extra_price_predictor = "breakfast_price_real",
    directory = "finalized_uncontaminated"
)

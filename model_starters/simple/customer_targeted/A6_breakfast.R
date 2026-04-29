source(file.path("model_scripts", "analysis_scripts", "run_analysis_nopred.R"))

# targeted_customer_restaurants$breakfast = c('2HRX9P6HKXA8V','L69HYJ4Y3TR91','ED5J990H5VAZT')
run_simple_customer_targeted(
    outcome = "breakfast",
    restaurants_to_model = c('2HRX9P6HKXA8V', 'L69HYJ4Y3TR91', 'ED5J990H5VAZT'),
    extra_price_predictor = "breakfast_price_real"
)

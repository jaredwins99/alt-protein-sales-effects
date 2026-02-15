source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_customer_t2_restaurants$breakfast = c('2HRX9P6HKXA8V','L69HYJ4Y3TR91','ED5J990H5VAZT','78AY09MVJVTYE','W8T41JZK0ZMEP','V3Q26BHF3SE2H')
run_customer_targeted_t2(
    outcome = "breakfast_t2",
    restaurants_to_model = c('2HRX9P6HKXA8V', 'L69HYJ4Y3TR91', 'ED5J990H5VAZT', '78AY09MVJVTYE', 'W8T41JZK0ZMEP', 'V3Q26BHF3SE2H'),
    extra_price_predictor = "breakfast_t2_price_real",
    directory = "finalized_redone_zi2"
)

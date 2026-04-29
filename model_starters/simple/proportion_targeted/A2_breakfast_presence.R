source(file.path("model_scripts", "analysis_scripts", "run_analysis_nopred.R"))

# targeted_proportion_restaurants$breakfast = c('2HRX9P6HKXA8V', 'ED5J990H5VAZT', 'JHDN7CF1C03X5', 'L69HYJ4Y3TR91', 'SRQS8F7JWA9MZ', 'W8T41JZK0ZMEP')
run_simple_prop_targeted(
    outcome = "breakfast_p",
    exposure = "breakfast_dishes_presence",
    restaurants_to_model = c('2HRX9P6HKXA8V', 'ED5J990H5VAZT', #'JHDN7CF1C03X5',
                             'L69HYJ4Y3TR91' #, 'SRQS8F7JWA9MZ', 'W8T41JZK0ZMEP'
                             ),
    extra_price_predictor = "breakfast_p_price_real"
)

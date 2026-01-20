source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_its_restaurants$breakfast = c('2HRX9P6HKXA8V','JHDN7CF1C03X5','L69HYJ4Y3TR91','ED5J990H5VAZT')
run_its_targeted(
    outcome = "breakfast",
    restaurants_to_model = c('2HRX9P6HKXA8V', #'JHDN7CF1C03X5',
                             'L69HYJ4Y3TR91', 'ED5J990H5VAZT' #, 'SRQS8F7JWA9MZ', 'W8T41JZK0ZMEP'
                             ),
    extra_price_predictor = "breakfast_price_real",
    directory = "redone_opt"
)

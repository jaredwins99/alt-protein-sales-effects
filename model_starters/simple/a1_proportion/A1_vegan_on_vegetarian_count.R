source(file.path("model_scripts", "analysis_scripts", "run_analysis_nopred.R"))

run_simple_prop(
    outcome = "vegan",
    exposure = "vegetarian_dishes_count",
    restaurants_to_model = c('SRQS8F7JWA9MZ', '2HRX9P6HKXA8V', 'JHDN7CF1C03X5', 'L69HYJ4Y3TR91', 'ED5J990H5VAZT', 'W8T41JZK0ZMEP')
)


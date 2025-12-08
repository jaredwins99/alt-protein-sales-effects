source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_proportion_restaurants$dairy = c('ED5J990H5VAZT', 'JHDN7CF1C03X5', 'W8T41JZK0ZMEP')
run_prop_targeted(
    outcome = "dairy_p",
    exposure = "dairy_dishes_count",
    restaurants_to_model = c('ED5J990H5VAZT', 'JHDN7CF1C03X5', 'W8T41JZK0ZMEP'),
    extra_price_predictor = "dairy_p_price_real",
    directory = "finalized"
)

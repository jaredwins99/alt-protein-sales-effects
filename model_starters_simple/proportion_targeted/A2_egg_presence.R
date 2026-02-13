source(file.path("model_scripts", "analysis_scripts", "run_analysis_nopred.R"))

# targeted_proportion_restaurants$egg = c('ED5J990H5VAZT', 'W8T41JZK0ZMEP')
run_simple_prop_targeted(
    outcome = "egg_p",
    exposure = "egg_dishes_presence",
    restaurants_to_model = c('ED5J990H5VAZT', 'W8T41JZK0ZMEP'),
    extra_price_predictor = "egg_p_price_real"
)

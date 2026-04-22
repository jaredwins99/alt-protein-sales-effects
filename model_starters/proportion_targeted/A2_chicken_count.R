source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_proportion_restaurants$chicken = c('JHDN7CF1C03X5', 'W8T41JZK0ZMEP')
run_prop_targeted(
    outcome = "chicken_p",
    exposure = "chicken_dishes_count",
    restaurants_to_model = c('JHDN7CF1C03X5', 'W8T41JZK0ZMEP'),
    extra_price_predictor = "chicken_p_price_real",
    directory = "finalized_redone_trunc_cp"
)

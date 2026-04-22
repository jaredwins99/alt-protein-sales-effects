source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_proportion_restaurants$egg = c('ED5J990H5VAZT', 'W8T41JZK0ZMEP')
run_prop_targeted(
    outcome = "egg_p",
    exposure = "egg_dishes_count",
    restaurants_to_model = c('ED5J990H5VAZT', 'W8T41JZK0ZMEP'),
    extra_price_predictor = "egg_p_price_real",
    directory = "finalized_redone_trunc_cp2"
)

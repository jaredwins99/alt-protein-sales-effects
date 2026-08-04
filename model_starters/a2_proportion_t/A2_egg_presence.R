source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_proportion_restaurants$egg = c('ED5J990H5VAZT', 'W8T41JZK0ZMEP')
run_prop_targeted(
    outcome = "egg_p",
    exposure = "egg_dishes_presence",
    # excluded - exposure constant across the train window under the
    #   2026-08-04 reviewed A2 clips (identifies nothing, draws from prior):
    #   W8T41JZK0ZMEP
    restaurants_to_model = c('ED5J990H5VAZT'),
    extra_price_predictor = "egg_p_price_real",
    directory = "finalized_uncontaminated"
)

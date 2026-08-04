source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_proportion_restaurants$dairy = c('ED5J990H5VAZT', 'JHDN7CF1C03X5', 'W8T41JZK0ZMEP')
run_prop_targeted(
    outcome = "dairy_p",
    exposure = "dairy_dishes_presence",
    # excluded - exposure constant across the train window under the
    #   2026-08-04 reviewed A2 clips (identifies nothing, draws from prior):
    #   JHDN7CF1C03X5  W8T41JZK0ZMEP
    restaurants_to_model = c('ED5J990H5VAZT'),
    extra_price_predictor = "dairy_p_price_real",
    directory = "finalized_uncontaminated"
)

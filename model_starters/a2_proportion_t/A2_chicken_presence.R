source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_proportion_restaurants$chicken = c('JHDN7CF1C03X5', 'W8T41JZK0ZMEP')
run_prop_targeted(
    outcome = "chicken_p",
    exposure = "chicken_dishes_presence",
    # excluded - exposure constant across the train window under the
    #   2026-08-04 reviewed A2 clips (identifies nothing, draws from prior):
    #   JHDN7CF1C03X5
    restaurants_to_model = c('W8T41JZK0ZMEP'),
    extra_price_predictor = "chicken_p_price_real",
    directory = "finalized_uncontaminated"
)

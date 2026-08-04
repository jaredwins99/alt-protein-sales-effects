source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_proportion_t2_restaurants$chicken = c('JHDN7CF1C03X5', 'W8T41JZK0ZMEP', '9XKJD8DQTH559', 'LBZEEFSBJNB3Z', 'SAFK7ND1HR6XS', 'V3Q26BHF3SE2H')
run_prop_targeted_t2(
    outcome = "chicken_p",
    exposure = "chicken_dishes_presence",
    # excluded - exposure constant across the train window under the
    #   2026-08-04 reviewed A2 clips (identifies nothing, draws from prior):
    #   9XKJD8DQTH559  JHDN7CF1C03X5  V3Q26BHF3SE2H
    # excluded previously:
    #   LBZEEFSBJNB3Z  SAFK7ND1HR6XS
    restaurants_to_model = c('W8T41JZK0ZMEP'),
    extra_price_predictor = "chicken_p_price_real",
    directory = "finalized_redone_trunc_cp"
)

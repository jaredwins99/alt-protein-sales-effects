source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_proportion_t2_restaurants$textured = c('W8T41JZK0ZMEP', '9XKJD8DQTH559', 'SAFK7ND1HR6XS')
run_prop_targeted_t2(
    outcome = "textured_p",
    exposure = "textured_dishes_count",
    # excluded - exposure constant across the train window under the
    #   2026-08-04 reviewed A2 clips (identifies nothing, draws from prior):
    #   SAFK7ND1HR6XS
    # excluded previously:
    #   W8T41JZK0ZMEP
    restaurants_to_model = c('9XKJD8DQTH559'),
    extra_price_predictor = "textured_p_price_real",
    directory = "finalized_uncontaminated"
)

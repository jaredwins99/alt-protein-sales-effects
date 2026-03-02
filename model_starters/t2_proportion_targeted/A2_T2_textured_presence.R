source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_proportion_t2_restaurants$textured = c('W8T41JZK0ZMEP', '9XKJD8DQTH559', 'SAFK7ND1HR6XS')
run_prop_targeted_t2(
    outcome = "textured_p",
    exposure = "textured_dishes_presence",
    restaurants_to_model = c('W8T41JZK0ZMEP', '9XKJD8DQTH559', 'SAFK7ND1HR6XS'),
    extra_price_predictor = "textured_p_price_real",
    directory = "finalized_redone_trunc"
)

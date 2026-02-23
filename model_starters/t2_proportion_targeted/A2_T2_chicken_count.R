source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_proportion_t2_restaurants$chicken = c('JHDN7CF1C03X5', 'W8T41JZK0ZMEP', '9XKJD8DQTH559', 'LBZEEFSBJNB3Z', 'SAFK7ND1HR6XS', 'V3Q26BHF3SE2H')
run_prop_targeted_t2(
    outcome = "chicken_p",
    exposure = "chicken_dishes_count",
    restaurants_to_model = c('JHDN7CF1C03X5', 'W8T41JZK0ZMEP', '9XKJD8DQTH559', 'LBZEEFSBJNB3Z', 'SAFK7ND1HR6XS', 'V3Q26BHF3SE2H'),
    extra_price_predictor = "chicken_p_price_real",
    directory = "finalized_redone_zi3",
    known_zi_dir = file.path("model_fits", "finalized_redone_zi", "t2_proportion", "total", "vegan_dishes_count")
)

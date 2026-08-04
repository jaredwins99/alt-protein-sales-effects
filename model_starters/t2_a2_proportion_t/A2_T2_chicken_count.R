source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_proportion_t2_restaurants$chicken = c('JHDN7CF1C03X5', 'W8T41JZK0ZMEP', '9XKJD8DQTH559', 'LBZEEFSBJNB3Z', 'SAFK7ND1HR6XS', 'V3Q26BHF3SE2H')
run_prop_targeted_t2(
    outcome = "chicken_p",
    exposure = "chicken_dishes_count",
        # LBZEEF and SAFK7ND removed: exposure is 100% constant within their
    # analysis windows, so they identify nothing and draw from the prior
restaurants_to_model = c('JHDN7CF1C03X5', 'W8T41JZK0ZMEP', '9XKJD8DQTH559',
                             #'LBZEEFSBJNB3Z', #'SAFK7ND1HR6XS',
                             'V3Q26BHF3SE2H'),
    extra_price_predictor = "chicken_p_price_real",
    directory = "finalized_uncontaminated"
)

source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_proportion_t2_restaurants$breakfast = c('2HRX9P6HKXA8V', 'ED5J990H5VAZT', 'JHDN7CF1C03X5', 'L69HYJ4Y3TR91', 'SRQS8F7JWA9MZ', 'W8T41JZK0ZMEP', '1SQPTEGYPH0GA', '78AY09MVJVTYE', '9XKJD8DQTH559', 'CB2KHY1C2G9PT', 'EMBVNVD207CC6', 'LBZEEFSBJNB3Z', 'LQ5EH4BKGV61T', 'SAFK7ND1HR6XS', 'V3Q26BHF3SE2H')
run_prop_targeted_t2(
    outcome = "breakfast_p",
    exposure = "breakfast_dishes_presence",
    restaurants_to_model = c('2HRX9P6HKXA8V', 'ED5J990H5VAZT', #'JHDN7CF1C03X5',
                             'L69HYJ4Y3TR91', #'SRQS8F7JWA9MZ', 'W8T41JZK0ZMEP',
                             '78AY09MVJVTYE', '9XKJD8DQTH559', 'CB2KHY1C2G9PT', 'EMBVNVD207CC6', 'LBZEEFSBJNB3Z', 'LQ5EH4BKGV61T', 'SAFK7ND1HR6XS', 'V3Q26BHF3SE2H'),
    extra_price_predictor = "breakfast_p_price_real",
    directory = "finalized_redone3"
)

source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_proportion_restaurants$untextured = c('JHDN7CF1C03X5', 'SRQS8F7JWA9MZ', 'W8T41JZK0ZMEP')
run_prop_targeted(
    outcome = "untextured_p",
    exposure = "untextured_dishes_count",
    restaurants_to_model = c(#'JHDN7CF1C03X5', 
    'SRQS8F7JWA9MZ'#, 
    #'W8T41JZK0ZMEP'
    ),
    extra_price_predictor = "untextured_p_price_real",
    directory = "finalized_redone_zi2"
)

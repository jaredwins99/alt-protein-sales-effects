source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_its_restaurants$untextured = c('SRQS8F7JWA9MZ','JHDN7CF1C03X5')
run_its_targeted(
    outcome = "untextured",
    restaurants_to_model = c('SRQS8F7JWA9MZ'#, 
    #'JHDN7CF1C03X5'
    ),
    extra_price_predictor = "untextured_price_real",
    directory = "finalized_redone3"
)

source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_its_restaurants$textured = c('VLZX7K2M9QD4T')
run_its_targeted(
    outcome = "textured",
    restaurants_to_model = c('VLZX7K2M9QD4T'),
    extra_price_predictor = "textured_price_real",
    directory = "finalized_redone_zi2"
)

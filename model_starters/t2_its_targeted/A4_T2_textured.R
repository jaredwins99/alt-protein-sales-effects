source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_its_t2_restaurants$textured = c('VLZX7K2M9QD4T','SAFK7ND1HR6XS')
run_its_targeted_t2(
    outcome = "textured_t2",
    restaurants_to_model = c('VLZX7K2M9QD4T', 'SAFK7ND1HR6XS'),
    extra_price_predictor = "textured_t2_price_real",
    directory = "finalized_redone"
)

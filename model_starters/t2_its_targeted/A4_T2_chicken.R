source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_its_t2_restaurants$chicken = c('V3Q26BHF3SE2H')
run_its_targeted_t2(
    outcome = "chicken_t2",
    restaurants_to_model = c('V3Q26BHF3SE2H'),
    extra_price_predictor = "chicken_t2_price_real",
    directory = "finalized_redone_zi3",
    known_zi_dir = file.path("model_fits", "finalized_redone_zi", "t2_its", "total")
)

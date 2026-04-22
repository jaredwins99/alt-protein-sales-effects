source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_customer_t2_restaurants$chicken = c('V3Q26BHF3SE2H')
run_customer_targeted_t2_day(
    outcome = "chicken_t2",
    restaurants_to_model = c('V3Q26BHF3SE2H'),
    extra_price_predictor = "chicken_t2_price_real",
    directory = "finalized_redone_trunc_cp2",
    thin = 2
)

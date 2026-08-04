source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

run_customer_t2(
    outcome = "chicken_fish",
    directory = "finalized_uncontaminated2",
    thin = 2
)

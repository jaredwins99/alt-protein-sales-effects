source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

run_customer_day(
    outcome = "vegan",
    directory = "finalized_redone_trunc_cp2",
    thin = 2
)

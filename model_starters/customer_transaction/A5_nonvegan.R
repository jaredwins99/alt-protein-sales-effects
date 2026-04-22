source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

run_customer(
    outcome = "nonvegan",
    directory = "finalized_redone_trunc_cp",
    thin = 2
)

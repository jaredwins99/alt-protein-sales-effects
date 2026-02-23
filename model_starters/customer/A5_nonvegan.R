source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

run_customer(
    outcome = "nonvegan",
    directory = "finalized_redone_zi3",
    known_zi_dir = file.path("model_fits", "finalized_redone_zi", "customer", "total")
)

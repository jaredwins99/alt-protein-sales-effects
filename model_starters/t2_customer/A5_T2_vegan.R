source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

run_customer_t2(
    outcome = "vegan",
    directory = "finalized_redone_zi2",
    known_zi_dir = file.path("model_fits", "finalized_redone_zi", "t2_customer", "total")
)

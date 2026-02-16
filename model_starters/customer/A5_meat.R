source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

run_customer(
    outcome = "meat",
    directory = "finalized_redone_zi2",
    known_zi_dir = file.path("model_fits", "finalized_redone_zi", "customer", "total")
)

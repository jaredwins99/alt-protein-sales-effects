source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

run_customer_gaussian_iid_a5(
    outcome = "nonvegan",
    directory = "finalized_redone_trunc"
)

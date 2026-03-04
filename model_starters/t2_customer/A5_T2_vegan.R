source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

run_customer_t2(
    outcome = "vegan",
    directory = "finalized_redone_trunc_cp"
)

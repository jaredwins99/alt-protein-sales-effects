source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

run_customer_t2(
    outcome = "total",
    directory = "finalized_redone_zi3",
    apply_truncation = TRUE
)

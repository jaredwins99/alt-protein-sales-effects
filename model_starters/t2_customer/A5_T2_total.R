source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

run_customer_t2(
    outcome = "total",
    directory = "finalized_redone_trunc_cp",
    apply_truncation = TRUE
)

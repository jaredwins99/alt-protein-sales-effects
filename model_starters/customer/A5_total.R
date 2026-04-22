source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

run_customer_day(
    outcome = "total",
    directory = "finalized_redone_trunc_cp",
    apply_truncation = TRUE,
    thin = 2
)

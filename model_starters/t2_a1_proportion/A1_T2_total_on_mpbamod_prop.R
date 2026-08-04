source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

run_prop_t2(
    outcome = "total",
    exposure = "mpbamod_dishes_prop",
    directory = "finalized_uncontaminated2",
    apply_truncation = TRUE,
    thin = 2
)

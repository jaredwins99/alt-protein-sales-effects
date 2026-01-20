source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

run_prop_t2(
    outcome = "nonvegan",
    exposure = "mpbamod_dishes_count",
    directory = "redone_opt"
)

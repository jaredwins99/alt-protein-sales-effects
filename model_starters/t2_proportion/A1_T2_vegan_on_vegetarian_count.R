source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

run_prop_t2(
    outcome = "vegan",
    exposure = "vegetarian_dishes_count",
    directory = "finalized_redone_trunc_cp"
)

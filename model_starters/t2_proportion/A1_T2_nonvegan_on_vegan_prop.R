source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

run_prop_t2(
    outcome = "nonvegan",
    exposure = "vegan_dishes_prop",
    directory = "finalized_redone"
)

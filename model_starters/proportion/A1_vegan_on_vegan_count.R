source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

run_prop(
    outcome = "vegan",
    exposure = "vegan_dishes_count",
    directory = "finalized"
)

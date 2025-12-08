source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

run_prop(
    outcome = "vegan",
    exposure = "mpbamod_dishes_prop",
    directory = "finalized"
)

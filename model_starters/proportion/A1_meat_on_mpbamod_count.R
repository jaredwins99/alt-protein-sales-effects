source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

run_prop(
    outcome = "meat",
    exposure = "mpbamod_dishes_count",
    directory = "finalized"
)

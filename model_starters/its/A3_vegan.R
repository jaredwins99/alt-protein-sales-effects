source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

run_its(
    outcome = "vegan",
    directory = "finalized"
)

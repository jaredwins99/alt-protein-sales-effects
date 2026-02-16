source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

run_prop_t2(
    outcome = "meat",
    exposure = "vegan_dishes_count",
    directory = "finalized_redone_zi2",
    known_zi_dir = file.path("model_fits", "finalized_redone_zi", "t2_proportion", "total", "vegan_dishes_count")
)

source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

run_prop_t2(
    outcome = "vegetarian",
    exposure = "vegetarian_dishes_prop",
    directory = "finalized_redone_zi2",
    known_zi_dir = file.path("model_fits", "finalized_redone_zi", "t2_proportion", "total", "vegetarian_dishes_prop")
)

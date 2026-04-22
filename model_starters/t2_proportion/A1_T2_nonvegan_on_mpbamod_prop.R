source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

run_prop_t2(
    outcome = "nonvegan",
    exposure = "mpbamod_dishes_prop",
    directory = "finalized_redone_trunc_cp2",
    thin = 2
)

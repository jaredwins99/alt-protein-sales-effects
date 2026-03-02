source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

run_customer_transaction(
    outcome = "chicken_fish",
    directory = "finalized_redone_trunc"
)

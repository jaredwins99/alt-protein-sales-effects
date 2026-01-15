source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_its_t2_restaurants$dairy = c('W8T41JZK0ZMEP','EMBVNVD207CC6','9XKJD8DQTH559')
run_its_targeted_t2(
    outcome = "dairy_t2",
    restaurants_to_model = c('W8T41JZK0ZMEP', 'EMBVNVD207CC6', '9XKJD8DQTH559'),
    extra_price_predictor = "dairy_t2_price_real",
    directory = "finalized_redone3"
)

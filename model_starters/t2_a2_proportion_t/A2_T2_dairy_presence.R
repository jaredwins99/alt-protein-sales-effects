source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_proportion_t2_restaurants$dairy = c('ED5J990H5VAZT', 'JHDN7CF1C03X5', 'W8T41JZK0ZMEP', '9XKJD8DQTH559', 'C0BE4NDSW26QN', 'EMBVNVD207CC6', 'LBZEEFSBJNB3Z', 'LFZFT3VASXPED', 'SAFK7ND1HR6XS', 'V3Q26BHF3SE2H')
run_prop_targeted_t2(
    outcome = "dairy_p",
    exposure = "dairy_dishes_presence",
    restaurants_to_model = c('ED5J990H5VAZT', 'JHDN7CF1C03X5', 'W8T41JZK0ZMEP', '9XKJD8DQTH559', 'C0BE4NDSW26QN', 'EMBVNVD207CC6', 'LBZEEFSBJNB3Z', 'LFZFT3VASXPED', 'SAFK7ND1HR6XS', 'V3Q26BHF3SE2H'),
    extra_price_predictor = "dairy_p_price_real",
    directory = "finalized_redone_trunc_cp"
)

source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_proportion_t2_restaurants$untextured = c('JHDN7CF1C03X5', 'SRQS8F7JWA9MZ', 'W8T41JZK0ZMEP', '1SQPTEGYPH0GA', '9XKJD8DQTH559', 'C0BE4NDSW26QN', 'CB2KHY1C2G9PT', 'EMBVNVD207CC6', 'LFZFT3VASXPED', 'LQ5EH4BKGV61T', 'S8MT0YGD2KTN9', 'SAFK7ND1HR6XS')
run_prop_targeted_t2(
    outcome = "untextured_p",
    exposure = "untextured_dishes_presence",
    restaurants_to_model = c('JHDN7CF1C03X5', 'SRQS8F7JWA9MZ', 'W8T41JZK0ZMEP', '1SQPTEGYPH0GA', '9XKJD8DQTH559', 'C0BE4NDSW26QN', 'CB2KHY1C2G9PT', 'EMBVNVD207CC6', 'LFZFT3VASXPED', 'LQ5EH4BKGV61T', 'S8MT0YGD2KTN9', 'SAFK7ND1HR6XS'),
    extra_price_predictor = "untextured_p_price_real",
    directory = "finalized"
)

source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_proportion_t2_restaurants$untextured = c('JHDN7CF1C03X5', 'SRQS8F7JWA9MZ', 'W8T41JZK0ZMEP', '1SQPTEGYPH0GA', '9XKJD8DQTH559', 'C0BE4NDSW26QN', 'CB2KHY1C2G9PT', 'EMBVNVD207CC6', 'LFZFT3VASXPED', 'LQ5EH4BKGV61T', 'S8MT0YGD2KTN9', 'SAFK7ND1HR6XS')
run_prop_targeted_t2(
    outcome = "untextured_p",
    exposure = "untextured_dishes_presence",
    # excluded - exposure constant across the train window under the
    #   2026-08-04 reviewed A2 clips (identifies nothing, draws from prior):
    #   9XKJD8DQTH559  C0BE4NDSW26QN  CB2KHY1C2G9PT  S8MT0YGD2KTN9
    # excluded previously:
    #   EMBVNVD207CC6  JHDN7CF1C03X5  LFZFT3VASXPED  SAFK7ND1HR6XS  W8T41JZK0ZMEP
    restaurants_to_model = c('SRQS8F7JWA9MZ', '1SQPTEGYPH0GA', 'LQ5EH4BKGV61T'),
    extra_price_predictor = "untextured_p_price_real",
    directory = "finalized_redone_trunc_cp"
)

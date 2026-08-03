source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_its_t2_restaurants$untextured = c('SRQS8F7JWA9MZ','JHDN7CF1C03X5','C0BE4NDSW26QN','S8MT0YGD2KTN9','9XKJD8DQTH559','LQ5EH4BKGV61T','1SQPTEGYPH0GA')
run_its_targeted_t2(
    outcome = "untextured_t2",
    # T1 A4 untextured excludes JHDN7CF1C03X5; mirrored here
    restaurants_to_model = c('SRQS8F7JWA9MZ', #'JHDN7CF1C03X5',
                             'C0BE4NDSW26QN', 'S8MT0YGD2KTN9', #'9XKJD8DQTH559',  # no burger sold; outcome is 2 isolated pulses
                             'LQ5EH4BKGV61T', '1SQPTEGYPH0GA'),
    extra_price_predictor = "untextured_t2_price_real",
    directory = "finalized_redone_trunc_cp",
    thin = 2
)

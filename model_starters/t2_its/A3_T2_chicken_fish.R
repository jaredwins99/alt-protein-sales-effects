source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

run_its_t2(
    outcome = "chicken_fish",
    restaurants_to_model = c('VLZX7K2M9QD4T', #'SRQS8F7JWA9MZ',
                             '2HRX9P6HKXA8V', 'JHDN7CF1C03X5', 'L69HYJ4Y3TR91', 'ED5J990H5VAZT', 'W8T41JZK0ZMEP',
                             'EMBVNVD207CC6', 'C0BE4NDSW26QN', 'V3Q26BHF3SE2H', 'LBZEEFSBJNB3Z',
                             'SAFK7ND1HR6XS', 'S8MT0YGD2KTN9', '1SQPTEGYPH0GA', '9XKJD8DQTH559',
                             'LQ5EH4BKGV61T', '78AY09MVJVTYE'),
    directory = "finalized_redone4"
)

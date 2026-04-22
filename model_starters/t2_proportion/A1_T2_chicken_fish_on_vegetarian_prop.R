source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

run_prop_t2(
    outcome = "chicken_fish",
    exposure = "vegetarian_dishes_prop",
    restaurants_to_model = c(#'SRQS8F7JWA9MZ',
                             '2HRX9P6HKXA8V', 'JHDN7CF1C03X5', 'L69HYJ4Y3TR91', 'ED5J990H5VAZT', 'W8T41JZK0ZMEP',
                             'EMBVNVD207CC6', 'C0BE4NDSW26QN', 'V3Q26BHF3SE2H', 'LBZEEFSBJNB3Z',
                             'SAFK7ND1HR6XS', 'CB2KHY1C2G9PT', 'S8MT0YGD2KTN9', 'LFZFT3VASXPED',
                             '1SQPTEGYPH0GA', '9XKJD8DQTH559', 'LQ5EH4BKGV61T', '78AY09MVJVTYE'),
    directory = "finalized_redone_trunc_cp2",
    thin = 2
)

source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

run_prop_t2(
    outcome = "vegan",
    exposure = "vegan_dishes_count",
    restaurants_to_model = c(#'SRQS8F7JWA9MZ',
                             '2HRX9P6HKXA8V', 'JHDN7CF1C03X5', 'L69HYJ4Y3TR91', 'ED5J990H5VAZT', 'W8T41JZK0ZMEP',
                             'EMBVNVD207CC6', 'C0BE4NDSW26QN', 'V3Q26BHF3SE2H', 'LBZEEFSBJNB3Z',
                             'SAFK7ND1HR6XS', 'CB2KHY1C2G9PT', 'S8MT0YGD2KTN9', 'LFZFT3VASXPED',
                             '1SQPTEGYPH0GA', '9XKJD8DQTH559', 'LQ5EH4BKGV61T', '78AY09MVJVTYE'),
    directory = "finalized_redone_zi2",
    known_zi_dir = file.path("model_fits", "finalized_redone_zi", "t2_proportion", "total", "vegan_dishes_count")
)

source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

run_prop(
    outcome = "total",
    exposure = "vegan_dishes_count",
    restaurants_to_model = c('SRQS8F7JWA9MZ', '2HRX9P6HKXA8V', 'JHDN7CF1C03X5', 'L69HYJ4Y3TR91', 'ED5J990H5VAZT', 'W8T41JZK0ZMEP'),
    directory = "finalized_redone_trunc_cp2",
    apply_truncation = TRUE
)


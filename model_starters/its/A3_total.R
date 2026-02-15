source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

run_its(
    outcome = "total",
    restaurants_to_model = c('VLZX7K2M9QD4T', 'SRQS8F7JWA9MZ', '2HRX9P6HKXA8V', 'JHDN7CF1C03X5', 'L69HYJ4Y3TR91', 'ED5J990H5VAZT'),
    directory = "finalized_redone_zi2"
)


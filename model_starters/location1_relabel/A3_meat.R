source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# A3 Tier 1 refit on location 1's relabelled outcomes. Settings are those of the
# published fit, finalized_redone_trunc_cp/a3_its/meat: same 6 restaurants,
# 3 chains, 1500 warmup + 2000 sampling, thin 1, adapt_delta 0.85,
# max_treedepth 12, seed 123, no truncation.
run_its(
    outcome = "meat",
    restaurants_to_model = c('VLZX7K2M9QD4T', 'SRQS8F7JWA9MZ', '2HRX9P6HKXA8V', 'JHDN7CF1C03X5', 'L69HYJ4Y3TR91', 'ED5J990H5VAZT'),
    directory = "finalized_location1_relabel",
    data_file = file.path("its_location1_relabel", "finalized.parquet"),
    adapt_delta = .85,
    max_treedepth = 12,
    thin = 1
)

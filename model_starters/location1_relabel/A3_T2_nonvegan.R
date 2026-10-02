source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# A3 Tier 2 refit on location 1's relabelled outcomes. Settings are those of
# the published fit, finalized_redone_trunc_cp/t2_a3_its/nonvegan, except its
# restaurant list: that fit inherited run_its_t2()'s default while the four
# Tier-1 restaurants were commented out of it, so it holds 13 restaurants
# (review/t2_a3_total_restaurant_gap.md).
# All 17 Tier-2 restaurants are passed explicitly: the 7 Tier-1 restaurants and
# the 10 Tier-2 ones, as in run_its_t2()'s default and the 17-restaurant fits of
# finalized_redone_trunc/t2_a3_its. 3 chains, 1500 warmup + 2000 sampling,
# thin 2, adapt_delta 0.85, max_treedepth 12, seed 123.
run_its_t2(
    outcome = "nonvegan",
    restaurants_to_model = c(
        'VLZX7K2M9QD4T', 'SRQS8F7JWA9MZ', '2HRX9P6HKXA8V', 'JHDN7CF1C03X5',
        'L69HYJ4Y3TR91', 'ED5J990H5VAZT', 'W8T41JZK0ZMEP',
        'EMBVNVD207CC6', 'C0BE4NDSW26QN', 'V3Q26BHF3SE2H', 'LBZEEFSBJNB3Z',
        'SAFK7ND1HR6XS', 'S8MT0YGD2KTN9', '1SQPTEGYPH0GA', '9XKJD8DQTH559',
        'LQ5EH4BKGV61T', '78AY09MVJVTYE'),
    directory = "finalized_location1_relabel",
    data_file = file.path("its_location1_relabel", "finalized.parquet"),
    adapt_delta = .85,
    max_treedepth = 12,
    iter_warmup = 1500,
    iter_sampling = 2000,
    thin = 2
)

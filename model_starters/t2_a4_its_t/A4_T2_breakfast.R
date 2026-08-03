source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_its_t2_restaurants$breakfast = c('2HRX9P6HKXA8V','JHDN7CF1C03X5','L69HYJ4Y3TR91','ED5J990H5VAZT','W8T41JZK0ZMEP','78AY09MVJVTYE','V3Q26BHF3SE2H')
run_its_targeted_t2(
    outcome = "breakfast_t2",
        # V3Q26BHF3SE2H removed: Turkey Sausage counterpart first sells mid-2022,
    # ~15 months AFTER the 2021 introductions, so no contemporaneous contrast
restaurants_to_model = c('2HRX9P6HKXA8V', 'L69HYJ4Y3TR91', 'ED5J990H5VAZT', '78AY09MVJVTYE'#, 'V3Q26BHF3SE2H'
    ),
    extra_price_predictor = "breakfast_t2_price_real",
    directory = "finalized_redone_trunc_cp",
    thin = 2
)

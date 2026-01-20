source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_proportion_t2_restaurants$egg = c('ED5J990H5VAZT', 'W8T41JZK0ZMEP', 'LBZEEFSBJNB3Z', '78AY09MVJVTYE', 'V3Q26BHF3SE2H')
run_prop_targeted_t2(
    outcome = "egg_p",
    exposure = "egg_dishes_presence",
    restaurants_to_model = c('ED5J990H5VAZT', 'W8T41JZK0ZMEP', 'LBZEEFSBJNB3Z', '78AY09MVJVTYE', 'V3Q26BHF3SE2H'),
    extra_price_predictor = "egg_p_price_real",
    directory = "redone_opt"
)

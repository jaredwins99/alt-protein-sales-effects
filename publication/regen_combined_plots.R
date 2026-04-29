source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

a3_rests_full <- c('VLZX7K2M9QD4T', 'SRQS8F7JWA9MZ', '2HRX9P6HKXA8V', 'JHDN7CF1C03X5', 'L69HYJ4Y3TR91', 'ED5J990H5VAZT')
a3_rests_no_srqs <- c('VLZX7K2M9QD4T', '2HRX9P6HKXA8V', 'JHDN7CF1C03X5', 'L69HYJ4Y3TR91', 'ED5J990H5VAZT')

run_its(outcome = "total",        restaurants_to_model = a3_rests_full,    directory = "finalized_redone_trunc_cp", apply_truncation = TRUE, replot_only = TRUE)
run_its(outcome = "meat",         restaurants_to_model = a3_rests_full,    directory = "finalized_redone_trunc_cp",                         replot_only = TRUE)
run_its(outcome = "chicken_fish", restaurants_to_model = a3_rests_no_srqs, directory = "finalized_redone_trunc_cp",                         replot_only = TRUE)
run_its(outcome = "nonvegan",     restaurants_to_model = a3_rests_full,    directory = "finalized_redone_trunc_cp",                         replot_only = TRUE)
run_its(outcome = "vegan",        restaurants_to_model = a3_rests_full,    directory = "finalized_redone_trunc_cp",                         replot_only = TRUE)
run_its(outcome = "vegetarian",   restaurants_to_model = a3_rests_full,    directory = "finalized_redone_trunc_cp",                         replot_only = TRUE)

run_its_targeted(outcome = "breakfast",
                 restaurants_to_model = c('2HRX9P6HKXA8V', 'L69HYJ4Y3TR91', 'ED5J990H5VAZT'),
                 extra_price_predictor = "breakfast_price_real",
                 directory = "finalized_redone_trunc_cp", replot_only = TRUE)
run_its_targeted(outcome = "textured",
                 restaurants_to_model = c('VLZX7K2M9QD4T'),
                 extra_price_predictor = "textured_price_real",
                 directory = "finalized_redone_trunc_cp", replot_only = TRUE)
run_its_targeted(outcome = "untextured",
                 restaurants_to_model = c('SRQS8F7JWA9MZ'),
                 extra_price_predictor = "untextured_price_real",
                 directory = "finalized_redone_trunc_cp", replot_only = TRUE)

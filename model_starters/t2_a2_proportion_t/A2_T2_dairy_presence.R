source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))

# targeted_proportion_t2_restaurants$dairy = c('ED5J990H5VAZT', 'JHDN7CF1C03X5', 'W8T41JZK0ZMEP', '9XKJD8DQTH559', 'C0BE4NDSW26QN', 'EMBVNVD207CC6', 'LBZEEFSBJNB3Z', 'LFZFT3VASXPED', 'SAFK7ND1HR6XS', 'V3Q26BHF3SE2H')
run_prop_targeted_t2(
    outcome = "dairy_p",
    exposure = "dairy_dishes_presence",
    # excluded - exposure constant across the train window under the
    #   2026-08-04 reviewed A2 clips (identifies nothing, draws from prior):
    #   C0BE4NDSW26QN  JHDN7CF1C03X5  LBZEEFSBJNB3Z  SAFK7ND1HR6XS  W8T41JZK0ZMEP
    # excluded previously:
    #   LFZFT3VASXPED
    restaurants_to_model = c('ED5J990H5VAZT', '9XKJD8DQTH559', 'EMBVNVD207CC6', 'V3Q26BHF3SE2H'),
    extra_price_predictor = "dairy_p_price_real",
    directory = "finalized_uncontaminated2"
)

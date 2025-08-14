source("run_ingarch.R")

# run_ingarch(
#     analysis = "its_t2",
#     outcome = "nonvegan",
#     data_file = "all_locations_daily_weather_inflation.parquet",
#     chains = 3,
#     parallel_chains = 3,
#     restaurants_to_model = c(
#     # Tier 1
#     'VLZX7K2M9QD4T', 
#     'SRQS8F7JWA9MZ', 
#     '2HRX9P6HKXA8V', 
#     'JHDN7CF1C03X5', 
#     'L69HYJ4Y3TR91',
#     'ED5J990H5VAZT',
#     'W8T41JZK0ZMEP',
    
#     # Tier 2
#     # 'EMBVNVD207CC6',
#     'C0BE4NDSW26QN',
#     #'75WYSXR9QBK5M',
#     'V3Q26BHF3SE2H',
#     'LBZEEFSBJNB3Z',
#     'SAFK7ND1HR6XS',
#     'CB2KHY1C2G9PT',
#     'S8MT0YGD2KTN9',
#     'LFZFT3VASXPED',
#     '1SQPTEGYPH0GA',
#     '9XKJD8DQTH559',
#     'LQ5EH4BKGV61T',
#     '78AY09MVJVTYE'
#     ))


# run_ingarch(
#     analysis = "targeted_its",
#     outcome = "textured",
#     data_file = "targeted/all_locations_daily_targeted_weather_inflation.parquet",
#     chains = 3,
#     parallel_chains = 3,
#     restaurants_to_model = c(
#         "VLZX7K2M9QD4T"
#     ))

# run_ingarch(
#     analysis = "targeted_its",
#     outcome = "untextured",
#     data_file = "targeted/all_locations_daily_targeted_weather_inflation.parquet",
#     chains = 3,
#     parallel_chains = 3,
#     restaurants_to_model = c(
#         'SRQS8F7JWA9MZ', 
#         'JHDN7CF1C03X5'
#     ))

run_ingarch(
    analysis = "targeted_its",
    outcome = "breakfast",
    data_file = "targeted/all_locations_daily_targeted_weather_inflation.parquet",
    chains = 3,
    parallel_chains = 3,
    restaurants_to_model = c(
        '2HRX9P6HKXA8V', 
        'JHDN7CF1C03X5', 
        'L69HYJ4Y3TR91',
        'ED5J990H5VAZT'
    ))




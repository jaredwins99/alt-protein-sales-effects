source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))


for (analysis_type in c('presence','count')) {
    for (outcome in c('breakfast','textured','untextured','chicken','dairy','egg')) {
        df <- read_parquet(paste0('data/4_data_parquet_modeling/proportion_targeted/finalized_', outcome, '_dishes_', analysis_type, '.parquet'))
        outcome_col <- paste0(outcome, '_outcome_p')
        df %>% select(contains('_p')) %>% glimpse()
        df <- df %>% rename(!!paste0(outcome, '_p_outcome') := !!sym(outcome_col))
        write_parquet(df, paste0('data/4_data_parquet_modeling/proportion_targeted/finalized_', outcome, '_dishes_', analysis_type, '.parquet'))
        
        df %>% select(contains('p_outcome') | contains('outcome_p')) %>% glimpse()
}}

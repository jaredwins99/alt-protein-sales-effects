library(purrr)

analyses <- list.dirs(file.path("model_fits","official"), recursive = FALSE, full.names = TRUE)

summaries <- map(analyses, function(analysis_path) {
  outcomes <- list.dirs(analysis_path, recursive = FALSE, full.names = TRUE)
  map(outcomes, function(outcome_path) {
    summ_file <- file.path(outcome_path, "summ_multi.rds")
    if (file.exists(summ_file)) {
      readRDS(summ_file)
    } else {
      NULL
    }}) %>% 
    set_names(basename(outcomes))}) %>% 
  set_names(basename(analyses))

transform_param <- function(df, rest_num = 1, rows = 40:59, cols = c("mean", "sd","q5", "q95"), pct = TRUE) {
  
  pattern <- paste0("beta\\[(", paste(rows, collapse = "|"), "),", rest_num, "\\]")
  
  df %>%
    filter(str_detect(variable, pattern)) %>%
    mutate(across(all_of(cols), ~ {
      val <- exp(.x)
      if (pct) val * 100 else val
    })) %>%
    select(variable, all_of(cols), ess_bulk)
}

# outcome1 <- 'chicken_fish'
# outcome1 <- 'meat'
outcome1 <- 'nonvegan'
# outcome1 <- 'total'
#outcome1 <- 'vegan'
#outcome1 <- 'vegetarian'

summ1 <- summaries[['its']][[outcome1]]
cols <- c("mean", "sd","q5", "q95")
summ1 %>% filter(variable %>% str_detect("gamma")) %>% 
  mutate(across(all_of(cols), ~ {val <- exp(.x)})) %>%
  print(n=40)
# summ1 %>% filter(variable %>% str_starts("beta"))  %>% print(n=100)
summ1 %>% transform_param(rest_num=1) %>% print() # loc0 VLZX7K2M9QD4T
summ1 %>% transform_param(rest_num=2) %>% print() # loc1 burger
summ1 %>% transform_param(rest_num=3) %>% print() # loc2 sausage
summ1 %>% transform_param(rest_num=4) %>% print() # loc3 cafe
summ1 %>% transform_param(rest_num=5) %>% print() # loc4 breakfast
summ1 %>% transform_param(rest_num=6) %>% print() # loc5 sandwich and bacon

outcome2 <- 'breakfast'
#outcome2 <- 'untextured'
#outcome2 <- 'textured'

summ2 <- summaries[['targeted_its']][[outcome2]]

summ2 %>% filter(variable %>% str_detect("gamma")) %>% 
  mutate(across(all_of(cols), ~ {val <- exp(.x)})) %>%
  print(n=40)
# summ2 %>% filter(variable %>% str_starts("beta"))  %>% print(n=100)
summ2 %>% transform_param(1) %>% print()
summ2 %>% transform_param(2) %>% print()
summ2 %>% transform_param(3) %>% print()
summ2 %>% transform_param(4) %>% print()
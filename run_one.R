library(tidyverse)
library(crayon)

set <- "nopred_redux"

read_summs <- function(outcome_path) {
    summ_file <- file.path(outcome_path, "summ.rds")
    exposure_file <- file.path(outcome_path, "exposure_map.rds")
    list(summ = if (file.exists(summ_file)) readRDS(summ_file) else NULL,
         exposure_map = if (file.exists(exposure_file)) readRDS(exposure_file) else NULL)}

read_analyses <- function(analysis_path) {
  outcomes <- list.dirs(analysis_path, recursive = FALSE, full.names = TRUE)
  map(outcomes, read_summs) %>% 
  set_names(basename(outcomes))}

analyses <- list.dirs(file.path("model_fits", set), recursive = FALSE, full.names = TRUE)
summaries <- map(analyses, read_analyses) %>% 
  set_names(basename(analyses))

find_summary <- function(summaries, analysis, outcome) {
  analysis <- as.character(analysis)
  outcome <- as.character(outcome)
  summ_and_map <- summaries[[analysis]][[outcome]]
  summ_and_map}

find_betas <- function(summ_and_map, 
                       cols = c('variable','mean',
                                #'sd',
                                'q5','q95')) {
  summ <- summ_and_map[['summ']]
  map <- summ_and_map[['exposure_map']]
  beta <- summ %>% 
    filter(variable %>% str_starts('beta')) %>% 
    mutate(index = variable %>% str_extract("(?<=\\[)\\d+") %>% as.integer()) %>% 
    select(index, all_of(cols), rhat)
  names <- map %>% 
    mutate(model_col = model_col %>% str_replace('exposure_', ''))
  named_summ <- beta %>% 
    left_join(names, by = c('index' = 'col_index')) %>% 
    filter(mean != 0) %>%
    select(model_col, all_of(cols), rhat)
  return(named_summ)}

find_gammas <- function(summ_and_map) {
  summ_and_map %>% 
    pluck('summ') %>%
    filter(variable %>% str_detect('mu_gamma'))}

exp_params <- function(df, col, slope_id, unit='year') {
  units <- list(day=365.25, year=1, month=365.25/12)
  scale <- units[[unit]]
  df %>%
    mutate(across(
      .cols = where(is.numeric) & !matches("rhat"), 
      .fns = ~ if_else(.data[[col]] %>% str_detect(slope_id), exp(.x / scale), exp(.x))))}

exp_betas <- function(df, unit='year') {
  df %>% exp_params('model_col', 'slope', unit)}

exp_gamma <- function(df, unit='year') {
  df %>% exp_params('variable', '2', unit)}

round_params <- function(df) {
  df %>% mutate(across(where(is.numeric) & !matches("rhat"), ~ round(.x, 2)))}

view_params <- function(summaries, analysis, outcome) {
  summ_and_map <- summaries %>% 
    find_summary(analysis, outcome)

  betas <- summ_and_map %>%
    find_betas() %>% 
    filter(!is.na(model_col)) %>%
    exp_betas(unit='year') %>%
    round_params()

  gammas <- summ_and_map %>% 
    find_gammas() %>%
    exp_gamma(unit='year') %>%
    round_params()

  sigmas <- summ_and_map %>% 
    pluck('summ') %>%
    filter(variable %>% str_detect('sigma_gamma'))

  list(betas = betas, gammas = gammas, sigmas = sigmas)
}
library(gt)

pretty_html <- function(df, name) {
  gt_tbl <- df %>%
    gt() %>%
    tab_style(
      style = list(cell_fill(color = "red")),
      locations = cells_body(rows = mean > 1 & q5 > 1)
    ) %>%
    tab_style(
      style = list(cell_fill(color = "pink")),
      locations = cells_body(rows = mean > 1 & q5 <= 1)
    ) %>%
    tab_style(
      style = list(cell_fill(color = "lime")),
      locations = cells_body(rows = mean < 1 & q95 < 1)
    ) %>%
    tab_style(
      style = list(cell_fill(color = "lightgreen")),
      locations = cells_body(rows = mean < 1 & q95 >= 1)
    )
  
  # save with provided name
  gtsave(gt_tbl, paste0(name, ".html"))
}

analysis1 <- 'its'
# outcome1 <- 'chicken_fish'
outcome1 <- 'meat'
# outcome1 <- 'nonvegan'
# outcome1 <- 'total'
# outcome1 <- 'vegan'
# outcome1 <- 'vegetarian'

summaries %>% view_params(analysis1, outcome1) %>% imap(~ pretty_html(.x, .y))

outcome2 <- 'breakfast'
#outcome2 <- 'untextured'
#outcome2 <- 'textured'

summ_and_map2 <- summaries %>% 
  find_summary('targeted_its', outcome2)

summ_and_map2 %>%
  find_betas() %>% 
  filter(!is.na(model_col)) %>%
  exp_betas(unit='year') %>%
  round_params() %>%
  print(n=25)

summ_and_map2 %>% 
  find_gammas() %>%
  exp_gamma(unit='year') %>%
  round_params() %>%
  print(n=25)

summ_and_map2 %>% 
  pluck('summ') %>%
  filter(variable %>% str_detect('sigma_gamma')) %>% 
  print(n=25)
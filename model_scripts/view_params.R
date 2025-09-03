library(tidyverse)
library(crayon)
library(gt)

read_summs <- function(outcome_path) {
    summ_file <- file.path(outcome_path, "summ.rds")
    predictor_file <- file.path(outcome_path, "predictor_map.rds")
    list(summ = if (file.exists(summ_file)) readRDS(summ_file) else NULL,
         predictor_map = if (file.exists(predictor_file)) readRDS(predictor_file) else NULL)}

read_analyses <- function(analysis_path) {
  outcomes <- list.dirs(analysis_path, recursive = FALSE, full.names = TRUE)
  map(outcomes, read_summs) %>% 
  set_names(basename(outcomes))}

find_model <- function(summaries, analysis, outcome) {
  analysis <- as.character(analysis)
  outcome <- as.character(outcome)
  model <- summaries[[analysis]][[outcome]]
  return(model)}

restaurant_map <- function(model) {
  map <- model[['predictor_map']]
  map %>% 
    filter(!str_detect(model_col,'slope') & 
           str_detect(model_col,'exposure') & 
           str_detect(model_col,'_1')) %>%
    mutate(rest_id = model_col %>% 
                        str_replace('exposure_','') %>% 
                        str_replace('_1',''),
          rest_index = row_number()) %>%
    select(rest_id, rest_index)}

find_betas <- function(model, 
                       cols = c('variable','mean',
                                #'sd',
                                'q5','q95')) {
  summ <- model[['summ']]
  map <- model[['predictor_map']]
  beta <- summ %>% 
    filter(variable %>% str_starts('beta')) %>% 
    mutate(index = variable %>% str_extract("(?<=\\[)\\d+") %>% as.integer()) %>% 
    select(index, all_of(cols), rhat)
  named_summ <- beta %>% 
    left_join(map, by = c('index' = 'col_index')) %>% 
    filter(mean != 0) %>%
    select(model_col, all_of(cols), rhat)
  return(named_summ)}

find_gammas <- function(model) {
  model %>% 
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

view_params <- function(model) {
  betas <- model %>%
    find_betas() %>% 
    filter(!is.na(model_col) & !str_detect(model_col, "exposure")) %>%
    #exp_betas(unit='year') %>%
    round_params() %>%
    mutate(
      rest_index = str_match(variable, "beta\\[\\d+,(\\d+)\\]")[, 2] %>% as.integer()) %>%
    left_join(rest_map, by = "rest_index") %>%
    group_by(rest_id) %>%
    group_nest(.key = "data") %>%          # one tibble per rest_id
    mutate(data = map(data, ~ select(.x, -rest_index))) %>%
    deframe() 
  betas <- betas[rest_map$rest_id]

  gammas <- model %>%
    find_betas() %>% 
    filter(!is.na(model_col) & str_detect(model_col, "exposure")) %>%
    exp_betas(unit='year') %>%
    round_params()

  mu_gammas <- model %>% 
    find_gammas() %>%
    exp_gamma(unit='year') %>%
    round_params()

  sigmas <- model %>% 
    pluck('summ') %>%
    filter(variable %>% str_detect('sigma_gamma'))

  list(betas=betas, gammas=gammas, mu_gammas=mu_gammas, sigmas=sigmas)}

pretty_html <- function(df, name, dir) {
  gt_tbl <- df %>%
    gt() %>%
    tab_style(
      style = list(cell_fill(color = "red")),
      locations = cells_body(rows = mean > 1 & q5 > 1)) %>%
    tab_style(
      style = list(cell_fill(color = "pink")),
      locations = cells_body(rows = mean > 1 & q5 <= 1)) %>%
    tab_style(
      style = list(cell_fill(color = "lime")),
      locations = cells_body(rows = mean < 1 & q95 < 1)) %>%
    tab_style(
      style = list(cell_fill(color = "lightgreen")),
      locations = cells_body(rows = mean < 1 & q95 >= 1))
  
  gt_tbl %>% gtsave(filename = paste0(name, ".html"), path = dir)}

# ──────────────────────────────────
#              Set
# ──────────────────────────────────

set <- 'testing_regularized2'

# ──────────────────────────────────
#            1. ITS
# ──────────────────────────────────

analysis1 <- 'its'

# outcome1 <- 'chicken_fish'
# outcome1 <- 'meat'
outcome1 <- 'nonvegan'
# outcome1 <- 'total'
# outcome1 <- 'vegan'
# outcome1 <- 'vegetarian'

model_path <- file.path("model_fits", set)
specific_path <- file.path(model_path, analysis1, outcome1)
html_path <- file.path(specific_path, "params")
if (!dir.exists(html_path)) dir.create(html_path, recursive = TRUE)

analyses <- list.dirs(model_path, recursive = FALSE, full.names = TRUE)
models <- map(analyses, read_analyses) %>% 
  set_names(basename(analyses))
model <- models %>% 
  find_model(analysis1, outcome1)
summ <- model %>% pluck("summ")
map <- model %>% pluck("predictor_map")
rest_map <- restaurant_map(model)

model %>%
  view_params() %>%
  pluck("betas") %>%
  pluck("JHDN7CF1C03X5")

model %>%
  view_params() %>% 
  imap(~ pretty_html(.x, .y, dir = html_path)) %>% 
  identity()

# summ %>% 
#   filter(variable %>% str_starts("mu_beta")) %>% print(n=100)


# all_vars <- unique(c(random_predictors, fixed_predictors, exposure_predictors))
# extract_var_level <- function(colname, vars_chr) {
#   if (colname %in% vars_chr) return(c(colname, NA))
#   matches <- vars_chr[startsWith(colname, vars_chr)]
#   if (length(matches) == 0) return(c(NA, NA))
#   v <- matches[which.max(nchar(matches))]
#   lvl <- sub(paste0("^", v), "", colname)
#   c(v, ifelse(nchar(lvl) == 0, NA, lvl))
# }
#   rowwise() %>%
#   mutate(
#     tmp = list(extract_var_level(model_col, all_vars)),
#     variable = tmp[1], level = tmp[2]) %>%
#   ungroup() %>%



# ──────────────────────────────────
#          2. Targeted
# ──────────────────────────────────

# analysis2 <- 'targeted_its'

# outcome2 <- 'breakfast'
# #outcome2 <- 'untextured'
# #outcome2 <- 'textured'

# model2 <- summaries %>% 
#   find_model(analysis2, outcome2)

# model2 %>%
#   find_betas() %>% 
#   filter(!is.na(model_col)) %>%
#   exp_betas(unit='year') %>%
#   round_params() %>%
#   print(n=25)

# model2 %>% 
#   find_gammas() %>%
#   exp_gamma(unit='year') %>%
#   round_params() %>%
#   print(n=25)

# model2 %>% 
#   pluck('summ') %>%
#   filter(variable %>% str_detect('sigma_gamma')) %>% 
#   print(n=25)
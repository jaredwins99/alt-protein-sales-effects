library(tidyverse)
library(crayon)
library(gt)

read_summs <- function(outcome_path) {
    summary_file <- file.path(outcome_path, "summ.rds")
    predictor_file <- file.path(outcome_path, "predictor_map.rds")
    list(summary = if (file.exists(summary_file)) readRDS(summary_file) else NULL,
         predictor_map = if (file.exists(predictor_file)) readRDS(predictor_file) else NULL)}

read_analyses <- function(analysis_path) {
  outcomes <- list.dirs(analysis_path, recursive = FALSE, full.names = TRUE)
  unnamed_models <- map(outcomes, read_summs) %>% 
    set_names(basename(outcomes))
  return(unnamed_models)}

find_model <- function(summaries, analysis, outcome) {
  analysis <- as.character(analysis)
  outcome <- as.character(outcome)
  model <- summaries[[analysis]][[outcome]]
  return(model)}

restaurant_map <- function(model) {
  map <- model[['predictor_map']]
  rest_map <- map %>% 
    filter(!str_detect(model_col,'slope') & 
           str_detect(model_col,'exposure') & 
           str_detect(model_col,'_1')) %>%
    mutate(rest_id = model_col %>% 
                        str_replace('exposure_','') %>% 
                        str_replace('_1',''),
          rest_index = row_number()) %>%
    select(rest_id, rest_index)
    return(rest_map)}

find_betas <- function(model, 
                       cols = c('variable','mean',
                                #'sd',
                                'q5','q95')) {
  summ <- model[['summary']]
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

model %>% find_mu_betas()

find_mu_betas <- function(model,
                           cols = c('variable','mean',
                                     'q5','q95')) {
  summ <- model[['summary']]
  map <- model[['predictor_map']]

  mu_beta <- summ %>%
    filter(str_starts(variable, "mu_beta")) %>%
    mutate(
      type  = str_extract(variable, "(?<=mu_beta_)[A-Za-z]+"),
      index = as.integer(str_extract(variable, "(?<=\\[)\\d+"))) %>%
    filter(type %in% c("random", "fixed")) %>%
    select(type, index, all_of(cols), rhat)

  mu_beta_map <- map %>%
    #mutate(type = if_else(str_detect(model_col, "\\d") & !str_detect(model_col, "season"), "fixed", type)) %>%
    filter(type %in% c("random", "fixed")) %>%
    group_by(type) %>%
    mutate(index_within_type = row_number()) %>%
    ungroup() %>%
    select(type, model_col, term, index_within_type)

  named_summ <- mu_beta %>% 
    left_join(mu_beta_map, by = c("type" = "type", "index" = "index_within_type")) %>% 
    filter(mean != 0) %>%
    select(model_col, all_of(cols), rhat)
  return(named_summ)}

find_gammas <- function(model) {
  model %>% 
    pluck('summary') %>%
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
    exp_betas(unit='year') %>%
    round_params() %>%
    mutate(
      rest_index = str_match(variable, "beta\\[\\d+,(\\d+)\\]")[, 2] %>% as.integer()) %>%
    left_join(rest_map, by = "rest_index") %>%
    group_by(rest_id) %>%
    group_nest(.key = "data") %>%          # one tibble per rest_id
    mutate(data = map(data, ~ select(.x, -rest_index))) %>%
    deframe() 
  betas <- betas[rest_map$rest_id]

  mu_betas <- model %>%
    find_mu_betas()  %>%
    exp_betas(unit='year') %>%
    round_params()

  gammas <- model %>%
    find_betas() %>% 
    filter(!is.na(model_col) & str_detect(model_col, "exposure")) %>%
    exp_betas(unit='year') %>%
    round_params()

  mu_gammas <- model %>% 
    find_gammas() %>%
    exp_gamma(unit='year') %>%
    round_params()

  sigma_gammas <- model %>% 
    pluck('summary') %>%
    filter(variable %>% str_detect('sigma_gamma'))

  return(list(betas=betas, mu_betas=mu_betas, gammas=gammas, mu_gammas=mu_gammas, sigma_gammas=sigma_gammas))}

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

set <- 'testing_reglessheavyonlyevil_group2_largesigma'

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
summ <- model %>% pluck("summary")
map <- model %>% pluck("predictor_map")
rest_map <- restaurant_map(model)
rest_map

model %>% pluck("summary") %>% select(variable) %>% print(n=100) 

model %>% pluck("summary") %>% filter(variable %>% str_detect("delta")) %>%select(variable, mean) %>% print(n=120)

mu_betas <- model %>%
  view_params() %>%
  pluck("mu_betas")
mu_betas %>% 
  print(n=100)

betas <- model %>%
  view_params() %>%
  pluck("betas")

walk2(names(betas), betas, ~{
  cat("\n---", .x, "---\n")
  print(.y, n = 100)
})

betas4 <- model %>%
  view_params() %>%
  pluck("betas") %>%
  pluck("JHDN7CF1C03X5")
betas4 %>%
  print(n=100)

mu_betas %>%
  select(model_col, mean) %>%
  left_join(
    betas4 %>% select(model_col, mean), 
    by = "model_col", 
    suffix = c("_mu", "_JHDN")) %>%
  print(n=100)

model %>%
  view_params() %>% 
  {.[c("mu_betas","mu_gammas","gammas","sigma_gammas")]} %>%
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
#   pluck('summary') %>%
#   filter(variable %>% str_detect('sigma_gamma')) %>% 
#   print(n=25)
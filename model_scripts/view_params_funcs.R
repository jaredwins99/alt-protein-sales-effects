library(tidyverse)
library(crayon)
library(gt)
#library(magick)
library(conflicted)

conflict_prefer("filter","dplyr")
conflict_prefer("lag", "dplyr")


# ───────────────────────────────────────
#              Read Models
# ───────────────────────────────────────

#' Read Model Summary and Predictor Map
#' @param outcome_path Path to a specific model outcome directory.
#' @return A list containing the model summary and predictor map tibbles.
read_summs <- function(outcome_path) {
    summary_file <- file.path(outcome_path, "summ.rds")
    predictor_file <- file.path(outcome_path, "predictor_map.rds")
    list(summary = if (file.exists(summary_file)) readRDS(summary_file) else NULL,
         predictor_map = if (file.exists(predictor_file)) readRDS(predictor_file) else NULL)}

#' Read All Analyses for a Given Model Path
#' @param analysis_path Path to a directory containing different analysis types (e.g., 'its').
#' @return A nested list of model summaries, named by analysis and outcome.
read_analyses <- function(analysis_path) {
  outcomes <- list.dirs(analysis_path, recursive = FALSE, full.names = TRUE)
  unnamed_models <- map(outcomes, read_summs) %>% 
    set_names(basename(outcomes))
  return(unnamed_models)}

#' Find a Specific Model from a Nested List
#' @param summaries The nested list structure from `read_analyses`.
#' @param analysis The name of the analysis (e.g., 'its').
#' @param outcome The name of the outcome (e.g., 'nonvegan').
#' @return The specific model object (list with summary and map).
find_model <- function(summaries, analysis, outcome) {
  analysis <- as.character(analysis)
  outcome <- as.character(outcome)
  model <- summaries[[analysis]][[outcome]]
  return(model)}

#' High-level Wrapper to Get a Specific Model Object
#' @param model_path Top-level path for a model set (e.g., 'model_fits/set1').
#' @param analysis The name of the analysis.
#' @param outcome The name of the outcome.
#' @return The specific model object.
model_items <- function(model_path, analysis, outcome) {
  analyses <- list.dirs(model_path, recursive = FALSE, full.names = TRUE)
  models <- map(analyses, read_analyses) %>% 
    set_names(basename(analyses))
  model <- models %>% 
    find_model(analysis, outcome)
  return(model)}

#' Create a Mapping of Restaurant IDs to an Index
#' @param map The predictor_map tibble from a model object.
#' @return A tibble with `rest_id` and `rest_index`.
restaurant_map <- function(map) {
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


# ───────────────────────────────────────
#          Proportion Models
# ───────────────────────────────────────


# Read all exposures inside one outcome directory
read_outcomes_prop <- function(outcome_path) {
  exposures <- list.dirs(outcome_path, recursive = FALSE, full.names = TRUE)
  exposure_models <- map(exposures, read_summs) |>
    set_names(basename(exposures))
  return(exposure_models)
}

# Read all outcomes inside one analysis directory
read_analyses_prop <- function(analysis_path) {
  outcomes <- list.dirs(analysis_path, recursive = FALSE, full.names = TRUE)
  outcome_models <- map(outcomes, read_outcomes_prop) |>
    set_names(basename(outcomes))
  return(outcome_models)
}

# Find specific model via analysis / outcome / exposure
find_model_prop <- function(summaries, analysis, outcome, exposure) {
  analysis <- as.character(analysis)
  outcome  <- as.character(outcome)
  exposure <- as.character(exposure)

  return(summaries[[analysis]][[outcome]][[exposure]])
}

# High-level wrapper
model_items_prop <- function(model_path, analysis, outcome, exposure) {
  analyses <- list.dirs(model_path, recursive = FALSE, full.names = TRUE)

  models <- map(analyses, read_analyses_prop) |>
    set_names(basename(analyses))

  model <- find_model_prop(models, analysis, outcome, exposure)
  return(model)
}

# ───────────────────────────────────────
#              Extract Params
# ───────────────────────────────────────

#' Find Beta Parameters (e.g., for exposures) from a Model
#' @param model A model object.
#' @param cols Columns to select from the summary.
#' @return A tibble of named beta parameters.
find_betas <- function(model, 
                       cols = c('variable','mean',
                                #'sd',
                                'q5','q95')) {
  summ <- model[['summary']]
  map <- model[['predictor_map']]

  beta <- summ %>% 
    filter(variable %>% str_starts('beta')) %>% 
    mutate(index = variable %>% str_extract("(?<=\\[)\\d+") %>% as.integer()) %>% 
    select(index, all_of(cols), rhat, ess_bulk)

  named_summ <- beta %>% 
    left_join(map, by = c('index' = 'col_index')) %>% 
    filter(mean != 0) %>%
    select(model_col, all_of(cols), rhat, ess_bulk)
  return(named_summ)}

#' Find Mu_Beta (Global Fixed/Random Effects) from a Model
#' @param model A model object.
#' @param cols Columns to select.
#' @return A tibble of named mu_beta parameters.
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
    select(type, index, all_of(cols), rhat, ess_bulk)

  mu_beta_map <- map %>%
    filter(type %in% c("random", "fixed")) %>%
    group_by(type) %>%
    mutate(index_within_type = row_number()) %>%
    ungroup() %>%
    select(type, model_col, term, index_within_type)

  named_summ <- mu_beta %>% 
    left_join(mu_beta_map, by = c("type" = "type", "index" = "index_within_type")) %>% 
    filter(mean != 0) %>%
    select(model_col, all_of(cols), rhat, ess_bulk)
  return(named_summ)}

#' Find Mu_Gamma (Global Exposure Effects) from a Model
#' @param model A model object.
#' @return A tibble with mu_gamma_1 (level) and mu_gamma_2 (slope).
find_gammas <- function(model) {
  model %>% 
    pluck('summary') %>%
    filter(variable %>% str_detect('mu_gamma'))}


# ───────────────────────────────────────
#              Transform Params
# ───────────────────────────────────────

#' Exponentiate Parameters (e.g., from log to normal scale)
#' @param df A tibble of parameters.
#' @param col The column containing the parameter name.
#' @param slope_id A string identifying slope parameters.
#' @param unit The time unit for scaling slopes.
#' @return A tibble with exponentiated numeric columns.
exp_params <- function(df, col, slope_id, unit='year') {
  units <- list(day=365.25, year=1, month=365.25/12)
  scale <- units[[unit]]
  df %>%
    mutate(
      is_slope =
        str_detect(.data[[col]], slope_id) &
        !is.infinite(ess_bulk)) %>%
    mutate(across(
      where(is.numeric) & !matches("rhat|ess"),
      ~ if_else(is_slope, exp(.x / scale), exp(.x)))) %>%
    select(-c(is_slope,ess_bulk))}

#' Wrapper to Exponentiate Beta Parameters
exp_betas <- function(df, unit='year') {
  df %>% exp_params('model_col', 'slope', unit)}

#' Wrapper to Exponentiate Gamma Parameters
exp_gamma <- function(df, unit='year') {
  df %>% exp_params('variable', '2', unit)}

#' Round Numeric Parameter Columns
round_params <- function(df) {
  df %>% mutate(across(where(is.numeric) & !matches("rhat"), ~ round(.x, 2)))}


# ───────────────────────────────────────
#              View Params
# ───────────────────────────────────────

view_params <- function(model) {
  # A temporary restaurant map is needed if not passed in
  temp_rest_map <- restaurant_map(model$predictor_map)
    
  betas <- model %>%
    find_betas() %>% 
    filter(!is.na(model_col) & !str_detect(model_col, "exposure")) %>%
    exp_betas(unit='year') %>%
    round_params() %>%
    mutate(
      rest_index = str_match(variable, "beta\\[\\d+,(\\d+)\\]")[, 2] %>% as.integer()) %>%
    # left_join(temp_rest_map, by = "rest_index") %>%
    # group_by(rest_id) %>%
    # group_nest(.key = "data") %>%
    # mutate(data = map(data, ~ select(.x, -rest_index))) %>%
    # deframe() %>%
    identity()
  #betas <- betas[temp_rest_map$rest_id]

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
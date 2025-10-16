library(tidyverse)
library(crayon)
library(gt)
library(magick)
library(conflicted)

conflict_prefer("filter","dplyr")

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

summarize_exposure <- function(g, id) {
  num <- unique(g$num)
  intercept <- g %>% filter(!str_detect(model_col, "slope"))
  slope <- g %>% filter(str_detect(model_col, "slope"))
  sprintf(
    "Exposure %s: Level %.2f (%.2f, %.2f); Slope %.2f (%.2f, %.2f)",
    num,
    intercept$mean[1], intercept$q5[1], intercept$q95[1],
    slope$mean[1], slope$q5[1], slope$q95[1])}

make_exposure_text <- function(g_all) {
  id <- unique(g_all$id)
  g_all %>%
    group_split(num) %>%
    map_chr(~ summarize_exposure(.x, id)) %>%
    paste(collapse = "\n")}

annotate_exposure_plot <- function(g_all, plot_path, plots_annotated_path) {
  id <- unique(g_all$id)
  text_block <- make_exposure_text(g_all)
  file_in  <- file.path(plot_path, paste0(id, ".png"))
  file_out <- file.path(plots_annotated_path, paste0(id, ".png"))
  if (file.exists(file_in)) {
    image_read(file_in) %>%
      image_annotate(
        text = text_block,
        gravity = "southwest",
        size = 50,
        color = "black"
      ) %>%
      image_write(file_out)
    message("Annotated ", file_out)
  } else {
    warning("File not found: ", file_in)}}

# ──────────────────────────────────
#              Set
# ──────────────────────────────────

set <- 'testing_reg5preds_onlyevil_group2_largesigma'


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
plot_path <- file.path(specific_path, "plots")
plots_annotated_path <- file.path(specific_path, "plots_annotated")
html_path <- file.path(specific_path, "params")
if (!dir.exists(plots_annotated_path)) dir.create(plots_annotated_path)
if (!dir.exists(html_path)) dir.create(html_path)

model_items <- function(model_path, analysis, outcome) {
  analyses <- list.dirs(model_path, recursive = FALSE, full.names = TRUE)
  models <- map(analyses, read_analyses) %>% 
    set_names(basename(analyses))
  model <- models %>% 
    find_model(analysis, outcome)
  return(model)}

model <- model_items(model_path, analysis1, outcome1)
summ <- model %>% pluck("summary")
map <- model %>% pluck("predictor_map")
rest_map <- restaurant_map(map)

summ %>% select(variable) %>% print(n=100)
summ %>% filter(variable %>% str_detect("delta")) %>% select(variable, mean) %>% print(n=120)
model %>% pluck("summary") %>% filter(variable %>% str_detect("phi")) %>% select(variable, mean) %>% print(n=120)

mu_betas <- model %>%
  view_params() %>%
  pluck("mu_betas")

betas <- model %>%
  view_params() %>%
  pluck("betas")

walk2(names(betas), betas, ~{
  cat("\n---", .x, "---\n")
  print(.y, n = 100)})

betas4 <- model %>%
  view_params() %>%
  pluck("betas") %>%
  pluck("JHDN7CF1C03X5")

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





set1 <- 'nopred_redux'
set2 <- 'testing_lessclipped'
set3 <- 'testing_reg5preds_onlyevil_group2_largesigma'
sets <- c(#set1, 
set2, set3)

model_paths <- map(sets, ~ file.path("model_fits", .x))
analysis_paths <- map(model_paths, ~ list.dirs(.x, recursive = FALSE, full.names = TRUE))
outcome_paths <- map(analysis_paths, ~ list.dirs(.x, recursive = FALSE, full.names = TRUE))
plot_paths <- map(outcome_paths, ~ file.path(.x, "plots"))
plots_annotated_paths <- map(outcome_paths, ~ file.path(.x, "plots_annotated"))
html_paths <- map(outcome_paths, ~ file.path(.x, "params"))
plots_annotated_paths %>% unlist() %>% walk(~ {if (!dir.exists(.x)) dir.create(.x)})
html_paths %>% unlist() %>% walk(~ {if (!dir.exists(.x)) dir.create(.x)})

output_dir <- "plots_stacked"

#model1 <- model_items(model_paths[[1]], analysis1, outcome1)
model2 <- model_items(model_paths[[1]], analysis1, outcome1)
model3 <- model_items(model_paths[[2]], analysis1, outcome1)
models <- list(#model1, 
model2, model3)

annotate_all_exposures <- function(model, plot_path, plots_annotated_path) {
  model %>%
    view_params() %>%
    pluck("gammas") %>%
    select(-c(variable, rhat)) %>%
    mutate(
      id  = str_extract(model_col, "(?<=exposure_)[A-Za-z0-9]+"),
      num = str_extract(model_col, "(?<=_)\\d+(?=($|_slope))")
    ) %>%
    group_split(id) %>%
    walk(
      annotate_exposure_plot,
      plot_path = plot_path,
      plots_annotated_path = plots_annotated_path
    )
}

stack_exposure_across_sets <- function(id, plots_annotated_paths, output_dir) {
  files <- map_chr(plots_annotated_paths, ~ file.path(.x, paste0(id, ".png")))
  existing_files <- files[file.exists(files)]

  if (length(existing_files) == 0) {
    warning("No files found for ", id)
    return(NULL)
  }

  imgs <- map(existing_files, ~ tryCatch(image_read(.x), error = function(e) NULL))
  imgs <- compact(imgs)

  if (length(imgs) == 0) {
    warning("No readable magick images for ", id)
    return(NULL)
  }

  widths <- map_dbl(imgs, ~ image_info(.x)[[1, "width"]])
  target_width <- min(widths)
  imgs_resized <- map(
    imgs,
    ~ image_resize(.x, geometry = geometry_size_pixels(width = target_width))
  )

  # Add white separator bars between images
  separator <- image_blank(width = target_width, height = 50, color = "white")
  imgs_with_gaps <- unlist(
    lapply(seq_along(imgs_resized), function(i) {
      if (i < length(imgs_resized))
        list(imgs_resized[[i]], separator)
      else
        list(imgs_resized[[i]])
    }),
    recursive = FALSE)

  stacked <- image_append(image_join(imgs_with_gaps), stack = TRUE)

  file_out <- file.path(output_dir, paste0(id, "_stacked.png"))
  image_write(stacked, file_out)
  message("Stacked ", file_out)
}



#annotate_all_exposures(model1, plot_paths[[1]], plots_annotated_paths[[1]])
annotate_all_exposures(model2, plot_paths[[1]], plots_annotated_paths[[1]])
annotate_all_exposures(model3, plot_paths[[2]], plots_annotated_paths[[2]])

walk(
  rest_map$rest_id,
  stack_exposure_across_sets,
  plots_annotated_paths = unlist(plots_annotated_paths),
  output_dir = output_dir)



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




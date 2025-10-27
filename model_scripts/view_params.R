library(tidyverse)
library(crayon)
library(gt)
library(magick)
library(conflicted)

conflict_prefer("filter","dplyr")

source("model_scripts/view_params_funcs.R")

# ───────────────────────────────────────
#              One Version
# ───────────────────────────────────────

# ────────────────────
#         Set
set <- 'testing_reg5preds_onlyevil_group2_largesigma'

# ─────────────────────────────
#           A3: ITS

# ────────────────────
#      Analysis
analysis1 <- 'its'

# ────────────────────
#      Outcome
# outcome1 <- 'chicken_fish'
# outcome1 <- 'meat'
outcome1 <- 'nonvegan'
# outcome1 <- 'total'
# outcome1 <- 'vegan'
# outcome1 <- 'vegetarian'

# ────────────────────
#        Paths
model_path <- file.path("model_fits", set)
specific_path <- file.path(model_path, analysis1, outcome1)
plot_path <- file.path(specific_path, "plots")
plots_annotated_path <- file.path(specific_path, "plots_annotated")
html_path <- file.path(specific_path, "params")
if (!dir.exists(plots_annotated_path)) dir.create(plots_annotated_path)
if (!dir.exists(html_path)) dir.create(html_path)

# ────────────────────
#      Objects
model <- model_items(model_path, analysis1, outcome1)
summ <- model %>% pluck("summary")
map <- model %>% pluck("predictor_map")
rest_map <- restaurant_map(map)

# ────────────────────
#      Estimates
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

# ─────────────────────────────
#          A4: Targeted

# ────────────────────
#      Analysis
# analysis2 <- 'targeted_its'

# ────────────────────
#      Outcome
# outcome2 <- 'breakfast'
# outcome2 <- 'untextured'
# outcome2 <- 'textured'

# ────────────────────
#      Objects
# model2 <- summaries %>% 
#   find_model(analysis2, outcome2)

# ────────────────────
#      Estimates
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


# ───────────────────────────────────────
#           Comparing Versions
# ───────────────────────────────────────

set1 <- 'nopred_redux'
set2 <- 'testing_lessclipped'
set3 <- 'testing_reg5preds_onlyevil_group2_largesigma'
sets <- c(set1, set2, set3)

model_paths <- map(sets, ~ file.path("model_fits", .x))
analysis_paths <- map(model_paths, ~ list.dirs(.x, recursive = FALSE, full.names = TRUE))
outcome_paths <- map(analysis_paths, ~ list.dirs(.x, recursive = FALSE, full.names = TRUE))
plot_paths <- map(outcome_paths, ~ file.path(.x, "plots"))
plots_annotated_paths <- map(outcome_paths, ~ file.path(.x, "plots_annotated"))
html_paths <- map(outcome_paths, ~ file.path(.x, "params"))
plots_annotated_paths %>% unlist() %>% walk(~ {if (!dir.exists(.x)) dir.create(.x)})
html_paths %>% unlist() %>% walk(~ {if (!dir.exists(.x)) dir.create(.x)})

output_dir <- "plots_stacked"

model1 <- model_items(model_paths[[1]], analysis1, outcome1)
model2 <- model_items(model_paths[[2]], analysis1, outcome1)
model3 <- model_items(model_paths[[3]], analysis1, outcome1)
models <- list(model1, model2, model3)

annotate_all_exposures(model1, plot_paths[[1]], plots_annotated_paths[[1]])
annotate_all_exposures(model2, plot_paths[[2]], plots_annotated_paths[[2]])
annotate_all_exposures(model3, plot_paths[[3]], plots_annotated_paths[[3]])

walk(
  rest_map$rest_id,
  stack_exposure_across_sets_by_outcome,
  plots_annotated_paths = unlist(plots_annotated_paths),
  output_dir = output_dir
)

# nonvegan
outcome_dir <- "plots_stacked/nonvegan"
output_file <- file.path(outcome_dir, "nonvegan_restaurants_combined.png")
stack_restaurants_horizontal(outcome_dir, rest_map, output_file)
annotate_stacked_with_mugamma_rows(list(model1, model2, model3), output_file)

# meat
outcome_dir <- "plots_stacked/meat"
output_file <- file.path(outcome_dir, "meat_restaurants_combined.png")
stack_restaurants_horizontal(outcome_dir, rest_map, output_file)
annotate_stacked_with_mugamma_rows(list(model1, model2, model3), output_file)

# chicken_fish
outcome_dir <- "plots_stacked/chicken_fish"
output_file <- file.path(outcome_dir, "chicken_fish_restaurants_combined.png")
stack_restaurants_horizontal(outcome_dir, rest_map, output_file)
annotate_stacked_with_mugamma_rows(list(model1, model2, model3), output_file)

# vegan
outcome_dir <- "plots_stacked/vegan"
output_file <- file.path(outcome_dir, "vegan_restaurants_combined.png")
stack_restaurants_horizontal(outcome_dir, rest_map, output_file)
annotate_stacked_with_mugamma_rows(list(model1, model2, model3), output_file)

# vegetarian
outcome_dir <- "plots_stacked/vegetarian"
output_file <- file.path(outcome_dir, "vegetarian_restaurants_combined.png")
stack_restaurants_horizontal(outcome_dir, rest_map, output_file)
annotate_stacked_with_mugamma_rows(list(model1, model2, model3), output_file)

# total
outcome_dir <- "plots_stacked/total"
output_file <- file.path(outcome_dir, "total_restaurants_combined.png")
stack_restaurants_horizontal(outcome_dir, rest_map, output_file)
annotate_stacked_with_mugamma_rows(list(model1, model2, model3), output_file)

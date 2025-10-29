library(tidyverse)
library(crayon)
library(gt)
library(magick)
library(conflicted)

conflict_prefer("filter","dplyr")

source("model_scripts/view_params_funcs.R")
source("model_scripts/plot_params_funcs.R")


# ───────────────────────────────────────
#               One Version
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
  #print(.y, n = 100)
  })

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
  #print(n=100) %>%
  identity()

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
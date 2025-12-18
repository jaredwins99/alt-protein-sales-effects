library(tidyverse)
source("model_scripts/view_params_funcs.R")

cat("=== All Restaurant Gammas for Breakfast Count ===\n")
model_path <- "model_fits/finalized/proportion_targeted/breakfast_p/breakfast_dishes_count"
model <- list(
  summary = readRDS(file.path(model_path, "summ.rds")),
  predictor_map = readRDS(file.path(model_path, "predictor_map.rds"))
)

gammas <- model %>%
  find_betas() %>%
  filter(!is.na(model_col) & str_detect(model_col, "exposure")) %>%
  mutate(restaurant = str_extract(model_col, "[^_]+(?=_\\d+$)"),
         rr = exp(mean)) %>%
  select(restaurant, mean, rr, q5, q95) %>%
  arrange(desc(rr))

print(gammas, n = Inf)

cat("\n\n=== All Restaurant Gammas for Vegan Count ===\n")
model_path <- "model_fits/finalized/proportion/vegan/vegan_dishes_count"
model <- list(
  summary = readRDS(file.path(model_path, "summ.rds")),
  predictor_map = readRDS(file.path(model_path, "predictor_map.rds"))
)

gammas <- model %>%
  find_betas() %>%
  filter(!is.na(model_col) & str_detect(model_col, "exposure")) %>%
  mutate(restaurant = str_extract(model_col, "[^_]+(?=_\\d+$)"),
         rr = exp(mean)) %>%
  select(restaurant, mean, rr, q5, q95) %>%
  arrange(desc(rr))

print(gammas, n = Inf)

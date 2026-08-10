## build_final_models.R -- write the manifest of models that back the reported results.
##
## This is the single source of truth for WHICH estimates are reported and in WHAT
## order. Both the Supplement tables (final_tables.R) and, eventually, the forest
## plot renderers should read it, so a table can never show a different set of
## estimates than the figure beside it.
##
## The selection rules below are lifted from
## create_forest_plots_restaurants_chosen_recolored_adj{,_t2}.R -- this script is
## where they are now written down rather than duplicated per consumer.
##
## Output: publication/config/final_models.csv, one row per reported cell:
##   table_id, tier, analysis, outcome_key, outcome_label, outcome_order,
##   column, column_order, fit_dir, total_dir, gamma_index, n_rest,
##   reported, suppress_reason, transform
##
## Usage: Rscript publication/scripts/build_final_models.R

suppressPackageStartupMessages({library(dplyr); library(stringr)})

ADJ <- "publication/forest_data_adj_95ci_fixed.csv"
OUT <- "publication/config/final_models.csv"
dir.create(dirname(OUT), showWarnings = FALSE, recursive = TRUE)

d <- read.csv(ADJ, stringsAsFactors = FALSE) %>%
  mutate(
    slug = sub("^.*/", "", fit_dir),
    column = case_when(
      str_detect(slug, "_prop$")     ~ "Proportion",
      str_detect(slug, "_count$")    ~ "Count",
      str_detect(slug, "_presence$") ~ "Presence",
      type_fine == "level"           ~ "Level change",
      type_fine == "slope"           ~ "Slope change",
      TRUE                           ~ NA_character_
    ),
    expo = case_when(
      str_detect(slug, "^mpbamod")    ~ "Alt-Protein-Modifiable",
      str_detect(slug, "^vegan")      ~ "Vegan",
      str_detect(slug, "^vegetarian") ~ "Vegetarian",
      TRUE                            ~ NA_character_
    )
  ) %>%
  filter(!is.na(column), type_fine %in% c("level", "slope")) %>%
  # the menu-availability designs are fitted without slopes; any slope row here is
  # an artefact of the shared extraction, not a reported estimate
  filter(!(analysis %in% c("a1_proportion", "t2_a1_proportion",
                           "a2_proportion_t", "t2_a2_proportion_t") &
           type_fine == "slope"))

## ---- how many restaurants back each pooled estimate --------------------------
n_rest <- d %>%
  filter(level == "restaurant") %>%
  group_by(analysis, outcome, column, expo) %>%
  summarise(n_rest = n_distinct(restaurant), .groups = "drop")

## ---- outcome order and labels, copied from the renderers ---------------------
## renderer L623/L1594 (T1), L660/L1666 (T2)
GEN  <- c(nonvegan = "Nonvegan", meat = "Meat", chicken_fish = "Chicken & fish",
          vegetarian = "Vegetarian", vegan = "Vegan")
## renderer L1132/L1239: whole-muscle is deliberately absent from A2 in both tiers
A2   <- c(breakfast_p = "Breakfast-style meat", untextured_p = "Ground meat",
          chicken_p = "Chicken", dairy_p = "Dairy", egg_p = "Egg")
## renderer L2038
A4T1 <- c(breakfast = "Breakfast-style meat", untextured = "Ground meat",
          textured = "Whole-muscle meat")
## renderer L2222
A4T2 <- c(breakfast_t2 = "Breakfast-style meat", dairy_t2 = "Dairy",
          textured_t2 = "Whole-muscle meat", untextured_t2 = "Ground meat")

SPEC <- list(
  list(id="t1_a1", tier="T1", an="a1_proportion",        lab=GEN,  cols=c("Count","Proportion")),
  list(id="t1_a2", tier="T1", an="a2_proportion_t",      lab=A2,   cols=c("Count","Presence")),
  list(id="t1_a3", tier="T1", an="a3_its",               lab=GEN,  cols=c("Level change","Slope change")),
  list(id="t1_a4", tier="T1", an="a4_its_t",             lab=A4T1, cols=c("Level change","Slope change")),
  list(id="t2_a1", tier="T2", an="t2_a1_proportion",     lab=GEN,  cols=c("Count","Proportion")),
  list(id="t2_a2", tier="T2", an="t2_a2_proportion_t",   lab=A2,   cols=c("Count","Presence")),
  list(id="t2_a3", tier="T2", an="t2_a3_its",            lab=GEN,  cols=c("Level change","Slope change")),
  list(id="t2_a4", tier="T2", an="t2_a4_its_t",          lab=A4T2, cols=c("Level change","Slope change")),
  list(id="t1_a5", tier="T1", an="a5_customer_day",      lab=GEN,  cols=c("Level change","Slope change")),
  list(id="t1_a6", tier="T1", an="a6_customer_t_day",    lab=A4T1, cols=c("Level change","Slope change")),
  list(id="t2_a5", tier="T2", an="t2_a5_customer_day",   lab=GEN,  cols=c("Level change","Slope change")),
  list(id="t2_a6", tier="T2", an="t2_a6_customer_t_day", lab=A4T2, cols=c("Level change","Slope change"))
)

rows <- lapply(SPEC, function(s) {
  x <- d %>%
    filter(level == "pooled", analysis == s$an,
           outcome %in% names(s$lab), column %in% s$cols)
  if (!nrow(x)) return(NULL)
  x %>%
    left_join(n_rest, by = c("analysis", "outcome", "column", "expo")) %>%
    mutate(
      table_id      = s$id,
      tier          = s$tier,
      outcome_key   = outcome,
      outcome_label = unname(s$lab[outcome]),
      outcome_order = match(outcome, names(s$lab)),
      column_order  = match(column, s$cols),
      # renderer L759/L1184/L1727
      suppress_reason = case_when(
        is.na(n_rest)                    ~ "no restaurant-level rows",
        n_rest <= 1                      ~ "fewer than two contributing restaurants",
        # renderer L1187: both contributing restaurants are atypical on the control
        # series, so the pooled falls outside both restaurant estimates
        analysis == "a2_proportion_t" &
          outcome == "breakfast_p" &
          column  == "Presence"          ~ "pooled outside both restaurant estimates",
        TRUE                             ~ NA_character_
      ),
      reported  = is.na(suppress_reason),
      transform = case_when(
        str_detect(analysis, "customer") ~ "identity",
        column == "Proportion"           ~ "exp_p10",
        TRUE                             ~ "exp"
      )
    ) %>%
    select(table_id, tier, analysis, outcome_key, outcome_label, outcome_order,
           column, column_order, exposure = expo, fit_dir, total_dir,
           gamma_index, n_rest, reported, suppress_reason, transform)
})

cfg <- bind_rows(rows) %>%
  arrange(match(table_id, sapply(SPEC, `[[`, "id")),
          outcome_order, column_order, exposure)

write.csv(cfg, OUT, row.names = FALSE, na = "")

message(sprintf("wrote %s: %d rows, %d reported, %d suppressed",
                OUT, nrow(cfg), sum(cfg$reported), sum(!cfg$reported)))
cfg %>% filter(reported) %>% count(table_id, name = "reported") %>%
  mutate(line = sprintf("  %-6s %d", table_id, reported)) %>% pull(line) %>%
  cat(sep = "\n")
cat("\n")
cfg %>% filter(!reported) %>% count(suppress_reason, name = "n") %>%
  mutate(line = sprintf("  suppressed: %-45s %d", suppress_reason, n)) %>%
  pull(line) %>% cat(sep = "\n")
cat("\n")

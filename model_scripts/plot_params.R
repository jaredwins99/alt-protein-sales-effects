library(tidyverse)
library(crayon)
library(gt)
library(magick)
library(conflicted)
orange <- make_style("orange")

conflict_prefer("filter","dplyr")

source("model_scripts/view_params_funcs.R")
source("model_scripts/plot_params_funcs.R")


# ───────────────────────────────────────
#           Comparing Versions
# ───────────────────────────────────────

# --- 1. Define Inputs ---

# Models
sets <- c(
  'nopred_redux' = "Model 1 (No Predictors)",
  'testing_lessclipped' = "Model 2 (Full Model)",
  'testing_reg5preds_onlyevil_group2_largesigma' = "Model 3 (Regularized Predictors)"
)

# Define the analysis and outcomes to process
analysis_name <- 'its'
outcomes_to_process <- c('nonvegan', 'meat', 'chicken_fish', 'vegan', 'vegetarian', 'total')

# Define paths
base_model_paths <- file.path("model_fits", names(sets))
output_dir <- "archive/plots_final_grids"


# --- 2. Load Models and Restaurant Map ---

# Load all necessary models into a nested list structure
cat(orange$bold("Loading models...\n"))

all_models <- map(outcomes_to_process, function(outcome) {
  map(base_model_paths, ~ model_items(.x, analysis_name, outcome)) %>%
    set_names(sets)
}) %>% set_names(outcomes_to_process)

cat(orange$bold("Models loaded.\n"))

# Generate the restaurant map (assuming it's the same for all models)
# We just need one representative model to get the map
first_model <- all_models[[1]][[1]]
if (is.null(first_model)) {
  stop("Could not load the first model to generate restaurant map. Check paths and file existence.")
}
rest_map <- restaurant_map(first_model$predictor_map)


# --- 3. Loop and Generate Grids ---

# Use walk to iterate through each outcome and generate its grid
walk(outcomes_to_process, function(current_outcome) {
  
  cat(cyan$bold$underline(paste("\n\n===== STARTING OUTCOME:", current_outcome, "=====\n")))
  
  output_file <- file.path(output_dir, paste0(current_outcome, "_comparison_grid.png"))
  
  generate_model_comparison_grid(
    models = all_models[[current_outcome]],
    rest_map = rest_map,
    outcome_name = current_outcome,
    base_model_paths = base_model_paths,
    analysis_name = analysis_name,
    output_file = output_file,
    save_annotated_cells = TRUE)})

cat(cyan$bold("\n\n===== All tasks complete. Check the '", output_dir, "' folder. =====\n"))
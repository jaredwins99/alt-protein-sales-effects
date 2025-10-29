library(tidyverse)
library(crayon)
library(gt)
library(magick)
library(conflicted)

conflict_prefer("filter","dplyr")
conflict_prefer("lag", "dplyr")

source("model_scripts/view_params_funcs.R")


# ───────────────────────────────────────
#      Visualize Individual Restaurants
# ───────────────────────────────────────

#' Create formatted text for a single restaurant's exposures.
#'
#' @param g A tibble of gamma parameters for a single restaurant, filtered from
#'   the main `gammas` tibble.
#' @return A single string with newlines, e.g., "Exposure 1: ...\nExposure 2: ..."
make_exposure_text <- function(g) {

  # Helper to summarize one exposure
  summarize_exposure <- function(exposure_df) {
    num <- unique(exposure_df$num)
    intercept <- exposure_df %>% filter(!str_detect(model_col, "slope"))
    slope <- exposure_df %>% filter(str_detect(model_col, "slope"))
    
    # Check if both intercept and slope were found
    if (nrow(intercept) == 0 || nrow(slope) == 0) return(sprintf("Exposure %s: Data incomplete", num))
    
    sprintf(
      "Exposure %s: Level %.2f (%.2f, %.2f); Slope %.2f (%.2f, %.2f)",
      num,
      intercept$mean[1], intercept$q5[1], intercept$q95[1],
      slope$mean[1], slope$q5[1], slope$q95[1])}

  g %>%
    group_split(num) %>%
    map_chr(summarize_exposure) %>%
    paste(collapse = "\n")}

#' Annotate a single restaurant plot with its exposure text.
#'
#' This function reads an image, adds padding to the bottom, and writes the
#' formatted text into the padding.
#'
#' @param plot_path The file path to the original, unannotated plot.
#' @param text_block The multi-line string of text to add.
#' @param output_path A file path (e.g., "path/to/image.png"), defaults to not saving.
#' @param bottom_padding Height in pixels to add for the text area.
#' @param font_size The size of the annotation font.
#' @param print_msg Logical, if TRUE prints a message when saving the annotated image.
#' @return A `magick` image object, or NULL if the file doesn't exist.
annotate_single_plot <- function(
  plot_path, 
  text_block, 
  output_path = NULL, 
  bottom_padding = 100, 
  font_size = 30,
  print_msg = FALSE) {

  if (!file.exists(plot_path)) {
    warning("Input plot not found: ", plot_path)
    # Return a blank placeholder image so the grid doesn't break
    return(image_blank(width = 800, height = 600, color = "white") %>%
           image_annotate("Plot Not Found", gravity = "center", size = 40, color = "red"))}
  
  img <- image_read(plot_path)
  info <- image_info(img)
  
  # Create a blank canvas for the text padding
  padding_canvas <- image_blank(
    width = info$width, 
    height = bottom_padding, 
    color = "white")
  
  # Stack original image on top of the padding
  img_with_padding <- image_append(
    c(img, padding_canvas), 
    stack = TRUE)
  
  # Annotate the new, taller image
  annotated_img <- image_annotate(
    img_with_padding,
    text = text_block,
    gravity = "SouthWest",
    location = "+20+10", # x+20, y+10 from bottom-left
    size = font_size,
    color = "black",
    font = "sans")

  if (!is.null(output_path)) {
    dir.create(dirname(output_path), showWarnings = FALSE, recursive = TRUE)
  
    image_write(annotated_img, path = output_path)
    if (print_msg) {
    cat(paste("    - Saved annotated cell to:", output_path, "\n"))}}
  
  return(annotated_img)}


# ───────────────────────────────────────
#          Global Parameters
# ───────────────────────────────────────

#' Create a `magick` image object for the mu_gamma (global average) text.
#'
#' @param model The model object to extract mu_gamma from.
#' @param model_name A character string to label the model (e.g., "Model 1: No Predictors").
#' @param target_width The desired width of the final text image, to match the plot row.
#' @param font_size The size of the annotation font.
#' @return A `magick` image object containing the formatted text on a white background.
create_mu_gamma_image <- function(model, model_name, target_width, font_size = 70) {
  
  mu_gammas_raw <- find_gammas(model)
  
  if (is.null(mu_gammas_raw) || nrow(mu_gammas_raw) < 2) {
    text_line <- sprintf("%s: Global parameters (mu_gamma) not found", model_name)
  } else {
    g <- mu_gammas_raw %>%
      exp_gamma(unit = 'year') %>%
      round_params()
      
    text_line <- sprintf(
      "%s Average: Level %.2f (%.2f, %.2f); Slope %.2f (%.2f, %.2f)",
      model_name,
      g$mean[1], g$q5[1], g$q95[1],
      g$mean[2], g$q5[2], g$q95[2])}
  
  # Create a canvas, annotate it, and trim it to find the text's natural size
  # This is a robust way to create a perfectly sized text image
  text_img <- image_blank(width = 2000, height = 500, color = "transparent") %>%
    image_annotate(text_line, gravity = "West", size = font_size, color = "black") %>%
    image_trim()
  
  # Create the final white canvas with padding
  text_info <- image_info(text_img)
  v_padding <- 20 # pixels top and bottom
  
  final_canvas <- image_blank(
    width = target_width,
    height = text_info$height + (2 * v_padding),
    color = "white")
  
  # Composite the text onto the final canvas
  image_composite(
    final_canvas,
    text_img,
    gravity = "Center",
    # offset = "+50+0" # 50px horizontal padding
    )} 


# ───────────────────────────────────────
#             Generate Grid
# ───────────────────────────────────────

#' Generate and save a composite grid image.
#'
#' This function orchestrates the entire process for a single outcome. It builds
#' the 3x6 grid by creating each model row individually (plots + global text) and
#' then stacking them vertically.
#'
#' @param models A named list of model objects. Names are used for labeling.
#' @param rest_map A tibble mapping restaurant IDs to their order.
#' @param outcome_name The name of the outcome being processed (e.g., "nonvegan").
#' @param base_model_paths A character vector of base paths for each model set.
#' @param analysis_name The name of the analysis subfolder (e.g., "its").
#' @param output_file The full path where the final PNG image will be saved.
#' @param save_annotated_cells A logical flag, if TRUE saves individual annotated plots
#' @return NULL. The final image is saved to `output_file`.
generate_model_comparison_grid <- function(
  models, 
  rest_map, 
  outcome_name, 
  base_model_paths,
  analysis_name,
  output_file,
  save_annotated_cells = FALSE) {
  
  # Pre-calculate all gamma parameters for all models to avoid repetition
  all_gammas <- map(models, ~ .x %>%
    find_betas() %>% 
    filter(!is.na(model_col) & str_detect(model_col, "exposure")) %>%
    exp_betas(unit='year') %>%
    round_params() %>%
    mutate(
      id  = str_extract(model_col, "(?<=exposure_)[A-Za-z0-9]+"),
      num = str_extract(model_col, "(?<=_)\\d+(?=($|_slope))")))
  
  # This list will hold the final "model blocks" (plot row + text row)
  model_blocks <- list()
  
  # --- Outer Loop: Iterate through each model to build its row ---
  for (i in seq_along(models)) {
    model_name <- names(models)[i]
    cat(blue$bold(paste("\n--- Processing Model:", model_name, "---\n")))
    
    # --- Inner Loop: Create each annotated cell for the current model's row ---
    annotated_cells <- map(rest_map$rest_id, function(current_rest_id) {
      cat(paste("  Annotating restaurant:", current_rest_id, "\n"))
      
      # Get the correct plot path
      plot_path <- file.path(base_model_paths[i], analysis_name, outcome_name, "plots", paste0(current_rest_id, ".png"))
      
      # Filter the pre-calculated gammas for this specific restaurant
      restaurant_gammas <- all_gammas[[i]] %>% 
        filter(id == current_rest_id)
        
      # Generate the annotation text
      exposure_text <- make_exposure_text(restaurant_gammas)
      
      # Conditionally define the output path based on the function's argument
      annotated_output_path <- if (save_annotated_cells) {
        file.path(
          base_model_paths[i], 
          analysis_name, 
          outcome_name, 
          "plots_annotated", 
          paste0(current_rest_id, ".png"))
      } else {NULL}

      # Create the annotated cell image
      annotate_single_plot(plot_path, exposure_text, output_path=annotated_output_path)})
    
    # --- Standardize heights and combine cells into a single row image ---
    heights <- map_dbl(annotated_cells, ~ image_info(.x)$height)
    target_height <- min(heights[heights > 0]) # Avoid issues with failed images
    
    cells_resized <- map(annotated_cells, ~ image_resize(.x, geometry_size_pixels(height = target_height)))
    
    restaurant_row_img <- image_append(image_join(cells_resized), stack = FALSE)
    
    # --- Create the mu_gamma text image for this model ---
    row_info <- image_info(restaurant_row_img)
    mu_gamma_img <- create_mu_gamma_image(
      model = models[[i]],
      model_name = model_name,
      target_width = row_info$width)
    
    # --- Vertically stack the plot row and its text row ---
    complete_model_block <- image_append(
      c(restaurant_row_img, mu_gamma_img),
      stack = TRUE)
    
    model_blocks <- c(model_blocks, list(complete_model_block))}
  
  # --- Final Assembly: Stack all model blocks vertically ---
  cat(green$bold("\n--- Assembling Final Grid ---\n"))
  
  # Standardize widths before final stacking
  widths <- map_dbl(model_blocks, ~ image_info(.x)$width)
  target_width <- min(widths[widths > 0])
  
  blocks_resized <- map(model_blocks, ~ image_resize(.x, geometry_size_pixels(width = target_width)))
  
  final_image <- image_append(image_join(blocks_resized), stack = TRUE)
  
  # --- Save the final image ---
  output_dir <- dirname(output_file)
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
  
  image_write(final_image, output_file)
  cat(green$bold("Successfully created composite image:"), green(output_file), "\n")
}

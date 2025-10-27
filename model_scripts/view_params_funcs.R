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

model_items <- function(model_path, analysis, outcome) {
  analyses <- list.dirs(model_path, recursive = FALSE, full.names = TRUE)
  models <- map(analyses, read_analyses) %>% 
    set_names(basename(analyses))
  model <- models %>% 
    find_model(analysis, outcome)
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
        location = "+0-10",
        size = 45,
        color = "black"
      ) %>%
      image_write(file_out)
    message("Annotated ", file_out)
  } else {
    warning("File not found: ", file_in)}}

annotate_stacked_with_mugamma_rows <- function(models, stacked_file, margin = 50, size = 70) {
  if (!file.exists(stacked_file)) {
    warning("Stacked file not found: ", stacked_file)
    return(invisible(NULL))
  }

  # Collect one mu_gamma per model (row)
  texts <- purrr::map(models, function(m) {
    g <- find_gammas(m)
    if (is.null(g) || nrow(g) == 0) return(NA_character_)
    sprintf(
      "Average: Level %.2f (%.2f, %.2f); Slope: %.2f (%.2f, %.2f)", 
      g$mean[1], g$q5[1], g$q95[1], 
      g$mean[2], g$q5[2], g$q95[2])
  })

  # Read image and compute row heights
  img <- magick::image_read(stacked_file)
  info <- magick::image_info(img)
  H <- info$height
  R <- length(models)
  if (R == 0) return(invisible(NULL))
  row_h <- floor(H / R)

  # Annotate each row near its bottom-center
  for (i in seq_len(R)) {
    txt <- texts[[i]]
    if (is.na(txt)) next
    # y position: bottom of the i-th row minus margin
    y <- (i - 1) * row_h + (row_h - margin)
    img <- magick::image_annotate(
      img,
      text     = txt,
      gravity  = "north",     # center horizontally; y is from top
      location = paste0("+0+", y),
      size     = size,
      color    = "black"
    )
  }

  magick::image_write(img, stacked_file)
  message("Annotated mu_gamma for ", R, " rows → ", stacked_file)
}

annotate_all_exposures <- function(model, plot_paths, plots_annotated_paths) {
 
  if (length(plot_paths) != length(plots_annotated_paths)) {
    stop("plot_paths and plots_annotated_paths must have the same length.")
  }

  pwalk(
    list(plot_paths, plots_annotated_paths),
    function(plot_path, plots_annotated_path) {
      if (!dir.exists(plot_path)) {
        warning("Skipping missing directory: ", plot_path)
        return(NULL)
      }

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
  )
}

stack_exposure_across_sets_by_outcome <- function(id, plots_annotated_paths, output_dir) {
  # detect unique outcomes by their parent folder name (e.g., "nonvegan")
  outcomes <- basename(dirname(plots_annotated_paths))
  
  # group paths by outcome
  grouped <- split(plots_annotated_paths, outcomes)

  # process each outcome separately
  walk(names(grouped), function(outcome) {
    paths <- grouped[[outcome]]
    files <- map_chr(paths, ~ file.path(.x, paste0(id, ".png")))
    existing_files <- files[file.exists(files)]

    if (length(existing_files) == 0) {
      warning("No files found for ", id, " in outcome ", outcome)
      return(NULL)
    }

    imgs <- map(existing_files, ~ tryCatch(image_read(.x), error = function(e) NULL))
    imgs <- compact(imgs)
    if (length(imgs) == 0) return(NULL)

    widths <- map_dbl(imgs, ~ image_info(.x)[[1, "width"]])
    target_width <- min(widths)
    imgs_resized <- map(
      imgs,
      ~ image_resize(.x, geometry = geometry_size_pixels(width = target_width))
    )

    separator <- image_blank(width = target_width, height = 100, color = "white")
    imgs_with_gaps <- unlist(
      lapply(seq_along(imgs_resized), function(i) {
        if (i < length(imgs_resized))
          list(imgs_resized[[i]], separator)
        else
          list(imgs_resized[[i]])
      }),
      recursive = FALSE
    )

    stacked <- image_append(image_join(imgs_with_gaps), stack = TRUE)

    outcome_dir <- file.path(output_dir, outcome)
    if (!dir.exists(outcome_dir)) dir.create(outcome_dir, recursive = TRUE)

    file_out <- file.path(outcome_dir, paste0(id, "_stacked.png"))
    image_write(stacked, file_out)
    message("Stacked ", outcome, " → ", file_out)
  })
}

stack_restaurants_horizontal <- function(outcome_dir, rest_map, output_file) {
  # derive expected filenames in order
  ordered_files <- file.path(outcome_dir, paste0(rest_map$rest_id, "_stacked.png"))
  existing_files <- ordered_files[file.exists(ordered_files)]
  
  if (length(existing_files) == 0) {
    warning("No PNGs found in ", outcome_dir)
    return(NULL)
  }
  
  imgs <- map(existing_files, ~ tryCatch(image_read(.x), error = function(e) NULL))
  imgs <- compact(imgs)
  if (length(imgs) == 0) {
    warning("No readable magick images in ", outcome_dir)
    return(NULL)
  }
  
  # match height for clean alignment
  heights <- map_dbl(imgs, ~ image_info(.x)[[1, "height"]])
  target_height <- min(heights)
  imgs_resized <- map(imgs, ~ image_resize(.x, geometry = geometry_size_pixels(height = target_height)))
  
  # optional white gaps between restaurants
  separator <- image_blank(height = target_height, width = 50, color = "white")
  imgs_with_gaps <- unlist(
    lapply(seq_along(imgs_resized), function(i) {
      if (i < length(imgs_resized))
        list(imgs_resized[[i]], separator)
      else
        list(imgs_resized[[i]])
    }),
    recursive = FALSE
  )
  
  combined <- image_append(image_join(imgs_with_gaps), stack = FALSE)
  image_write(combined, output_file)
  
  message("Horizontally stacked ", length(imgs_resized), " restaurants → ", output_file)
}
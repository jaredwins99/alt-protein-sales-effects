# Processing and visualizing
library(fpp3) # tibble, dplyr, tidyr, lubridate, ggplot2, tsibble, tsibbledata, feasts, fable
library(tidyverse)
library(arrow)
library(skimr)
library(shiny)
library(grid)
library(gridExtra)
library(png)
library(conflicted)
c("select", "filter") %>% walk(~ conflict_prefer(.x, "dplyr"))
c("year", "month") %>% walk(~ conflict_prefer(.x, "lubridate"))

# Modeling
library(tscount)
library(sandwich)
library(lmtest)
library(MASS)
library(bayesforecast)

# Custom
source("tools/modeling_functions.R")

# # Set the folder path
# folder <- "D:/My Stuff/HSFL/restaurant-sales-testing/modeling_results/grid_search"

# # First part: Insert nonvegan_outcome before last underscore
# insert_str <- "nonvegan_outcome"
# all_entries <- list.files(folder, full.names = TRUE)
# files <- all_entries[file.info(all_entries)$isdir == FALSE]
# base_names <- basename(files)

# new_base_names <- sub(
#   "^(.+)_([^_]+)$",
#   paste0("\\1_", insert_str, "_\\2"),
#   base_names)
# new_files <- file.path(folder, new_base_names)
# file.rename(files, new_files)

# # Second part: Remove nonvegan_outcome that was just inserted
# all_entries <- list.files(folder, full.names = TRUE)
# files <- all_entries[file.info(all_entries)$isdir == FALSE]
# base_names <- basename(files)

# original_base_names <- sub(
#   paste0("_", insert_str, "_([^_]+)$"),  # Match the pattern we added
#   "_\\1",  # Replace with just the last segment
#   base_names)
# original_files <- file.path(folder, original_base_names)
# file.rename(files, original_files)

# ===============================
#             Set Up
# ===============================

# ===== Data =====

before_after_details_true <- read.csv("data/before_after_details_true.csv")

bad_restaurants <- c(
  "AQD04SM0J92WA", "LBMCPAYT7W36V", "L3XS7WSJ4AJA3", "1G5AJ17XCH2A8",
  "3AXDVZJYN9DRS", "MS8R16DY0JQAM", "N0PC58FB2XAZ3", "ADPFRN3QZRCXK",
  "WJA3YCD4QBWRX", "0RJH3FFPYBPEY", "LZ5MR1TS37E7W"
)

restaurants_by_coverage <- read.csv("data/2_palate_data_parquet_cleaned/restaurants_by_4m_coverage.csv") %>%
  filter(!(location_id %in% bad_restaurants)) %>%
  filter(!(location_id %in% c("75WYSXR9QBK5M",
                              "V3Q26BHF3SE2H",
                              "CB2KHY1C2G9PT",
                              "LFZFT3VASXPED",
                              "LQ5EH4BKGV61T"))) %>%
  pull(location_id)

df_all_daily <- read_parquet("data/3_palate_data_parquet_modeling/all_locations_daily_weather_inflation.parquet")


# ===== Subset Data =====

num_weeks_before <- 25 # 8
num_weeks_after <- 17 # 2

# Filter each restaurants to k months before to k months after the promo date in before_after_details_true
df_all_intervention_period <- df_all_daily %>%
  left_join(before_after_details_true %>%
              mutate(cross_over_date = as.Date(cross_over_date)),
            by = "location_id") %>%
  group_by(location_id) %>%
  filter(created_at >= (cross_over_date %m-% weeks(num_weeks_before)) &
           created_at <= (cross_over_date %m+% weeks(num_weeks_after))) %>%
  ungroup()


# ===== Predictors =====

predictors <- c(
  "vegan_price_real",
  "meat_price_real",
  "day_of_week_cat",
  "weekend",
  "month_cat",
  "season",
  "year",
  "inflation",
  "temp",
  "precip"
)


# ===============================
#       AR/Mean Lag options
# ===============================

#list_of_best_params_intervention <- list()
list_of_best_params_entire <- list()

# # Loop over restaurant IDs (here using the first 6 in restaurants_by_coverage)
# for (loc_id in restaurants_by_coverage) {
#   # Read intervention-specific parameter grid
#   file_intervention <- paste0("param_grid_lags_", loc_id, ".rds")
#   param_grid_intervention <- readRDS(file_intervention)
#   best_params_intervention <- param_grid_intervention[which.min(unlist(param_grid_intervention$cv_results)), ]
#   list_of_best_params_intervention[[loc_id]] <- best_params_intervention
# }

# Define outcomes and data types
outcomes <- c("nonvegan_outcome", "vegan_outcome")
data_types <- c("entire", "intervention")

# Initialize the restaurant_lag_options list
restaurant_lag_options <- list()

# Loop through restaurants to populate lag options
for (loc_id in restaurants_by_coverage[1:6]) {
  # Read parameters
  file_entire <- paste0("validation_results/", "param_grid_lags_", loc_id, ".rds")
  param_grid_entire <- readRDS(file_entire)
  best_params_entire <- param_grid_entire[which.min(unlist(param_grid_entire$cv_results)), ]

  # Get AR and Mean lags
  ar_lags <- if (!is.null(best_params_entire$ar_lags[[1]]) && length(best_params_entire$ar_lags[[1]]) > 0) {
    best_params_entire$ar_lags[[1]]}
  else {
    numeric(0)}

  mean_lags <- if (!is.null(best_params_entire$mean_lags[[1]]) && length(best_params_entire$mean_lags[[1]]) > 0) {
    best_params_entire$mean_lags[[1]]}
  else {
    numeric(0)}

  # Create lag combination string
  ar_str <- if (length(ar_lags) > 0) {
    paste("AR:", paste(ar_lags, collapse = ","))}
  else {
    "AR: none"}

  mean_str <- if (length(mean_lags) > 0) {
    paste("Mean:", paste(mean_lags, collapse = ","))}
  else {
    "Mean: none"}

  lag_combo <- paste(ar_str, mean_str)

  # Create the lag combination list
  lag_combo_list <- list(
    ar = ar_lags,
    mean = mean_lags
  )

  # Build nested structure for this restaurant
  restaurant_lag_options[[loc_id]] <- list()
  for (outcome in outcomes) {
    restaurant_lag_options[[loc_id]][[outcome]] <- list()
    for (data_type in data_types) {
      restaurant_lag_options[[loc_id]][[outcome]][[data_type]] <- setNames(
        list(lag_combo_list),
        lag_combo
      )
    }
  }
}

# Create default options for restaurants without optimized parameters
default_lag_options <- list()
for (outcome in outcomes) {
  default_lag_options[[outcome]] <- list()
  for (data_type in data_types) {
    default_lag_options[[outcome]][[data_type]] <- list(
      "AR: 1 Mean: 1" = list(
        ar = c(1),
        mean = c(1)
      )
    )
  }
}


# ===============================
#       Run and Store Models
# ===============================

# ===== Loop Over All Locations and Store Visuals =====

results_list <- list()
diag_plot_list <- list()
pred_plot_list <- list()

for (loc in restaurants_by_coverage) {
  # Get the lag options for this location
  lag_options <- if (!is.null(restaurant_lag_options[[loc]])) {
    restaurant_lag_options[[loc]]}
  else {
    default_lag_options}

  results_list[[loc]] <- list()
  diag_plot_list[[loc]] <- list()
  pred_plot_list[[loc]] <- list()

  # Process each outcome
  for (outcome in outcomes) {
    results_list[[loc]][[outcome]] <- list()
    diag_plot_list[[loc]][[outcome]] <- list()
    pred_plot_list[[loc]][[outcome]] <- list()

    # Process each data type
    for (data_type in data_types) {
      results_list[[loc]][[outcome]][[data_type]] <- list()
      diag_plot_list[[loc]][[outcome]][[data_type]] <- list()
      pred_plot_list[[loc]][[outcome]][[data_type]] <- list()

      # Process each lag combination
      for (lag_combo in names(lag_options[[outcome]][[data_type]])) {
        # Get the AR and Mean lags for this combination
        current_lags <- lag_options[[outcome]][[data_type]][[lag_combo]]
        ar_lags <- current_lags$ar
        mean_lags <- current_lags$mean

        # Construct file paths
        model_path <- file.path(
          "modeling_results/grid_search",
          paste0(loc, "_", data_type, "_", outcome, "_model.rds")
        )
        diag_path <- file.path(
          "modeling_results/grid_search",
          paste0(loc, "_", data_type, "_", outcome, "_diagplot.png")
        )
        pred_path <- file.path(
          "modeling_results/grid_search",
          paste0(loc, "_", data_type, "_", outcome, "_predplot.png")
        )

        # If files exist, retrieve them; otherwise process new model
        if (file.exists(model_path) && file.exists(diag_path) && file.exists(pred_path)) {
          # Load existing model and plots
          res <- list(
            model = readRDS(model_path),
            diag_plot = grid::rasterGrob(readPNG(diag_path), interpolate = TRUE),
            pred_plot = grid::rasterGrob(readPNG(pred_path), interpolate = TRUE)
          )
          cat(
            "Retrieved | Restaurant:", loc, "Outcome:", outcome,
            "| Data:", data_type, "| Lags:", lag_combo, "\n"
          )
        }
        else {
          # Process new model
          cat("Processing | Restaurant:", loc, "Outcome:", outcome,
              "| Data:", data_type, "| Lags:", lag_combo, "\n")

          # Select appropriate data based on data_type
          data_to_use <- if (data_type == "entire") {
            df_all_daily}
          else {
            df_all_intervention_period}

          res <- process_models(
            data_to_use,
            loc = loc,
            outcome = outcome,
            predictors = predictors,
            ar_lags = ar_lags,
            mean_lags = mean_lags,
            model_type = "nbar",
            sample = FALSE,
            standardize = TRUE,
            train_frac = 0.7)}

        # Store results
        results_list[[loc]][[outcome]][[data_type]][[lag_combo]] <- res$model
        diag_plot_list[[loc]][[outcome]][[data_type]][[lag_combo]] <- res$diag_plot
        pred_plot_list[[loc]][[outcome]][[data_type]][[lag_combo]] <- res$pred_plot

        # Save results if needed
        save <- TRUE
        if (save) {
          saveRDS(res$model, file = model_path)

          png(diag_path, width = 2400, height = 1600, res = 300)
          grid.draw(res$diag_plot)
          dev.off()

          png(pred_path, width = 2400, height = 1600, res = 300)
          grid.draw(res$pred_plot)
          dev.off()}
      }
    }
  }
}



# ===============================
#           Run Server
# ===============================

# ===== Shiny App UI and Server =====

ui <- fluidPage(
  titlePanel("Restaurant Sales Model Dashboard"),
  sidebarLayout(
    sidebarPanel(
      # Restaurant selection
      selectInput("restaurant_id", "Choose a restaurant:",
                  choices = restaurants_by_coverage,
                  selected = restaurants_by_coverage[1]),

      # Outcome selection
      selectInput("outcome", "Choose outcome:",
                  choices = outcomes,
                  selected = outcomes[1]),

      # Data type selection
      selectInput("data_type", "Choose data period:",
                  choices = data_types,
                  selected = data_types[1]),

      # Lag combination selection
      uiOutput("lag_combo_ui")
    ),
    mainPanel(
      h3(textOutput("restaurant_info")),
      plotOutput("selected_plot")
    )
  )
)

server <- function(input, output, session) {
  # Get available lag combinations based on selected outcome and data type
  available_lag_combos <- reactive({
    if (!is.null(restaurant_lag_options[[input$restaurant_id]])) {
      names(restaurant_lag_options[[input$restaurant_id]][[input$outcome]][[input$data_type]])}
    else {
      names(default_lag_options[[input$outcome]][[input$data_type]])}})

  # Render UI for lag combination selection
  output$lag_combo_ui <- renderUI({
    selectInput("lag_combo", "Choose lag combination:",
                choices = available_lag_combos(),
                selected = available_lag_combos()[1])
  })

  # Display restaurant information
  output$restaurant_info <- renderText({
    paste("Restaurant:", input$restaurant_id,
          "| Outcome:", input$outcome,
          "| Data:", input$data_type,
          "| Lags:", input$lag_combo)
  })

  # Display the selected plot
  output$selected_plot <- renderPlot({
    selected_plot <- pred_plot_list[[input$restaurant_id]][[input$outcome]][[input$data_type]][[input$lag_combo]]
    grid::grid.draw(selected_plot)
  }, height = 800)
}

shinyApp(ui = ui, server = server)

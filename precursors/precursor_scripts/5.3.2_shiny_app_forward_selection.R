# Processing and visualizing
library(fpp3) # tibble, dplyr, tidyr, lubridate, ggplot2, tsibble, tsibbledata, feasts, fable
library(tidyverse)
library(arrow)
library(skimr)
library(shiny)
library(grid)
library(gridExtra)
library(conflicted)
c("select","filter") %>% walk(~ conflict_prefer(.x, "dplyr"))
c("year","month") %>% walk(~ conflict_prefer(.x, "lubridate"))

# Modeling
library(tscount)
library(sandwich)
library(lmtest)
library(MASS)
library(bayesforecast)

# Custom
source("tools/modeling_functions.R")


# ===============================
#             Set Up
# ===============================

# ===== Data =====

before_after_details_true <- read.csv("data/before_after_details_true.csv")

bad_restaurants <- c('AQD04SM0J92WA','LBMCPAYT7W36V','L3XS7WSJ4AJA3','1G5AJ17XCH2A8','3AXDVZJYN9DRS','MS8R16DY0JQAM','N0PC58FB2XAZ3','ADPFRN3QZRCXK','WJA3YCD4QBWRX','0RJH3FFPYBPEY','LZ5MR1TS37E7W')

restaurants_by_coverage <- read.csv('data/2_palate_data_parquet_cleaned/restaurants_by_4m_coverage.csv') %>%
  filter(!(location_id %in% bad_restaurants)) %>%
  filter(!(location_id %in% c("75WYSXR9QBK5M", "V3Q26BHF3SE2H", "CB2KHY1C2G9PT", "LFZFT3VASXPED"))) %>%
  pull(location_id)

df_all_daily <- read_parquet("data/3_palate_data_parquet_modeling/all_locations_daily_weather_inflation.parquet")


# ===== Predictors & Outcome =====

outcome <- "nonvegan_outcome"

predictors <- c(
  "vegan_price_real",
  "meat_price_real",
  "day_of_week_cat",
  "weekend",
  "month_cat",
  "season",
  "year",
  "inflation"#,
  #"temp",
  #"precip"
)


# ===============================
#       Comparing CV Results
# ===============================

readRDS("param_grid_lags_ED5J990H5VAZT.rds")[which.min(unlist(readRDS("param_grid_lags_ED5J990H5VAZT.rds")$cv_results)), ]
readRDS("param_grid_lags_ED5J990H5VAZT.rds")
readRDS("param_grid_lags_forward_selection_ED5J990H5VAZT.rds")

mylist <- readRDS("param_grid_lags_JHDN7CF1C03X5.rds")

mylist %>%
  mutate(ar_lags = paste("ar:", map_chr(mylist$ar_lags, ~ paste(.x, collapse = ","))),
         mean_lags = paste("mean:", map_chr(mylist$mean_lags, ~ paste(.x, collapse = ","))),
         lags = paste(ar_lags, mean_lags),
         cv_results = unlist(cv_results)) %>%
  select(lags, cv_results) %>%
  as.data.frame() %>%
  arrange(cv_results)


# ===============================
#       AR/Mean Lag options
# ===============================

# Populate restaurant lag options based on best params
restaurant_lag_options <- list()
for (loc_id in restaurants_by_coverage) {
  
  file_entire <- paste0("validation_results/forward_selection/","param_grid_lags_forward_selection_", loc_id, ".rds")
  best_params <- readRDS(file_entire)
  
  # Create AR lag options for both sources
  ar_lag_options <- list()
  if (!is.null(best_params$AR) && length(best_params$AR) > 0) {
    ar_lag_options[["entire_data"]] <- best_params$AR} 
  else {
    ar_lag_options[["entire_data"]] <- numeric(0)}
  
  # Create Mean lag options for both sources
  mean_lag_options <- list()
  if (!is.null(best_params$Mean) && length(best_params$Mean) > 0) {
    mean_lag_options[["entire_data"]] <- best_params$Mean} 
  else {
    mean_lag_options[["entire_data"]] <- numeric(0)}
  
  # Store the options in the main list for this restaurant location
  restaurant_lag_options[[loc_id]] <- list(ar = ar_lag_options, mean = mean_lag_options)
  
}

# For any restaurant not defined in restaurant_lag_options, use a default set.
default_lag_options <- list(
  ar   = list("1" = c(1)),
  mean = list("1" = c(1))
)


# ===============================
#       Run and Store Models
# ===============================

# ===== Loop Over All Locations and Store Visuals =====

results_list <- list()
plot_list <- list()
pred_plot_list <- list()

for(loc in restaurants_by_coverage) {
  
  # If the location doesn't have specific options, use defaults
  lag_options <- if (!is.null(restaurant_lag_options[[loc]])) {
    restaurant_lag_options[[loc]]} 
  else {
    default_lag_options}
  
  results_list[[loc]] <- list()
  plot_list[[loc]] <- list()
  for(ar_label in names(lag_options$ar)) {
    for(mean_label in names(lag_options$mean)) {
      
      cat("Processing location:", loc, 
          "with AR lags:", ar_label, 
          "and Mean lags:", mean_label, "\n")
      
      res <- process_models(
        df_all_daily, 
        loc         = loc, 
        outcome     = outcome,
        predictors  = predictors,
        ar_lags     = lag_options$ar[[ar_label]], 
        mean_lags   = lag_options$mean[[mean_label]],
        model_type  = "nbar", 
        sample      = FALSE, 
        standardize = TRUE, 
        train_frac  = 0.7
      )
      
      # Create a combined label for both AR and mean lags
      combined_label <- paste0("AR: ", ar_label, " | Mean: ", mean_label)
      
      # Store results in the nested lists
      results_list[[loc]][[combined_label]] <- res$model
      plot_list[[loc]][[combined_label]] <- res$diag_plot
      pred_plot_list[[loc]] <- res$pred_plot
      
      # Save the diagnostic plot as a PNG file (with loc, AR, and mean lag labels in the name)
      png_filename <- file.path("modeling_results/forward_selection", paste0("optimal_",loc, "_pred_plot.png"))
      png(png_filename, width = 1200, height = 800)
      grid.draw(res$pred_plot)
      dev.off()
      
      # Save the model object as an RDS file
      rds_filename <- file.path("modeling_results/forward_selection", paste0("optimal_",loc, "_model.rds"))
      saveRDS(res$model, file = rds_filename)
      
    }
  }
}


# ===============================
#           Run Server
# ===============================

## ===== Shiny App UI and Server =====
# 
# ui <- fluidPage(
#   titlePanel("Dashboard: Select a Restaurant Location"),
#   sidebarLayout(
#     sidebarPanel(
#       selectInput("restaurant_id", "Choose a restaurant ID:", 
#                   choices = restaurants_by_coverage, selected = restaurants_by_coverage[1]),
#       # Use UI outputs for lag options so they update based on the selected restaurant
#       uiOutput("ar_lags_ui"),
#       uiOutput("mean_lags_ui")
#     ),
#     mainPanel(
#       h3(textOutput("restaurant_info")),
#       plotOutput("selected_plot")
#     )
#   )
# )
# 
# server <- function(input, output, session) {
#   
#   # A reactive expression to retrieve the lag options for the selected restaurant
#   restaurant_options <- reactive({
#     if (!is.null(restaurant_lag_options[[input$restaurant_id]])) {
#       restaurant_lag_options[[input$restaurant_id]]
#     } else {
#       default_lag_options
#     }
#   })
#   
#   # Render UI for AR lag selection based on the selected restaurant
#   output$ar_lags_ui <- renderUI({
#     selectInput("ar_lags", "Choose AR lag set:",
#                 choices = names(restaurant_options()$ar),
#                 selected = names(restaurant_options()$ar)[1])
#   })
#   
#   # Render UI for Mean lag selection based on the selected restaurant
#   output$mean_lags_ui <- renderUI({
#     selectInput("mean_lags", "Choose Mean lag set:",
#                 choices = names(restaurant_options()$mean),
#                 selected = names(restaurant_options()$mean)[1])
#   })
#   
#   output$restaurant_info <- renderText({
#     paste("Restaurant Location ID:", input$restaurant_id,
#           "| AR lag set:", input$ar_lags,
#           "| Mean lag set:", input$mean_lags)
#   })
#   
#   output$selected_plot <- renderPlot({
#     # Construct the combined label to access the correct plot
#     combined_label <- paste0("AR: ", input$ar_lags, " | Mean: ", input$mean_lags)
#     selected_plot <- plot_list[[ input$restaurant_id ]][[ combined_label ]]
#     grid::grid.draw(selected_plot)
#   })
# }
# 
# shinyApp(ui = ui, server = server)




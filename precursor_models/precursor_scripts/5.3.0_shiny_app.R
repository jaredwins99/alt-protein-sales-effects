# Processing and visualizing
library(fpp3) # tibble, dplyr, tidyr, lubridate, ggplot2, tsibble, tsibbledata, feasts, fable
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

# ===== Data, Predictors, Outcome =====

before_after_details_true <- read.csv("data/before_after_details_true.csv")

bad_restaurants <- c('AQD04SM0J92WA','LBMCPAYT7W36V','L3XS7WSJ4AJA3','1G5AJ17XCH2A8','3AXDVZJYN9DRS','MS8R16DY0JQAM','N0PC58FB2XAZ3','ADPFRN3QZRCXK','WJA3YCD4QBWRX','0RJH3FFPYBPEY','LZ5MR1TS37E7W')

restaurants_by_coverage <- read.csv('data/2_palate_data_parquet_cleaned/restaurants_by_4m_coverage.csv') %>%
  filter(!(location_id %in% bad_restaurants)) %>%
  pull(location_id)

outcome <- "nonvegan_outcome"

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

# ===== Define AR Lag Options =====

ar_lags_options <- list(
  "0"           = c(),
  #"1"           = c(1),
  #"1,2"         = c(1,2),
  #"1,2,3"       = c(1,2,3),
  #"1,7"         = c(1,7),
  #"1,7,14"      = c(1,7,14),
  #"1,2,7"       = c(1,2,7),
  #"1,2,3,7,14"  = c(1,2,3,7,14),
  "1,2,3,7,14,21"  = c(1,2,3,7,14,21)
)

mean_lags_options <- list(
  "0"           = c(),
  "1"           = c(1)
)


# ===============================
#       Run and Store Models
# ===============================

# ===== Loop Over All Locations and Store Visuals =====

results_list <- list()
plot_list <- list()

for(loc in location_ids[1:2]) {
  results_list[[loc]] <- list()
  plot_list[[loc]] <- list()
  
  for(ar_label in names(ar_lags_options)) {
    for(mean_label in names(mean_lags_options)) {
      cat("Processing location:", loc, 
          "with AR lags:", ar_label, 
          "and Mean lags:", mean_label, "\n")
      
      res <- process_models(df_all_daily, 
                            loc = loc, 
                            outcome = outcome,
                            predictors = predictors,
                            ar_lags = ar_lags_options[[ar_label]], 
                            mean_lags = mean_lags_options[[mean_label]],
                            model_type = "nbar", 
                            sample = FALSE, 
                            standardize = TRUE, 
                            train_frac = 0.5)
      
      # Create a combined label for both AR and mean lags
      combined_label <- paste0("AR: ", ar_label, " | Mean: ", mean_label)
      
      # Store results in the nested lists
      results_list[[loc]][[combined_label]] <- res$model
      plot_list[[loc]][[combined_label]] <- res$diag_plot
      
      # Save the diagnostic plot as a PNG file (with loc, AR, and mean lag labels in the name)
      png_filename <- file.path("modeling_results", paste0(loc, "_diagnostics_", ar_label, "_", mean_label, ".png"))
      # png(png_filename, width = 1200, height = 800)
      # grid.draw(res$diag_plot)
      # dev.off()
      
      # Save the model object as an RDS file
      rds_filename <- file.path("modeling_results", paste0(loc, "_model_", ar_label, "_", mean_label, ".rds"))
      # saveRDS(res$model, file = rds_filename)
    }
  }
}


# ===============================
#           Run Server
# ===============================

# ===== Shiny App UI =====

ui <- fluidPage(
  titlePanel("Dashboard: Select a Restaurant Location"),
  sidebarLayout(
    sidebarPanel(
      selectInput("restaurant_id", "Choose a restaurant ID:", 
                  choices = names(plot_list), selected = names(plot_list)[1]),
      selectInput("ar_lags", "Choose AR lag set:", 
                  choices = names(ar_lags_options), selected = names(ar_lags_options)[1]),
      selectInput("mean_lags", "Choose Mean lag set:", 
                  choices = names(mean_lags_options), selected = names(mean_lags_options)[1])
    ),
    mainPanel(
      h3(textOutput("restaurant_info")),
      plotOutput("selected_plot")
    )
  )
)


# ===== Shiny App Server =====

server <- function(input, output, session) {
  
  output$restaurant_info <- renderText({
    paste("Restaurant Location ID:", input$restaurant_id,
          "| AR lag set:", input$ar_lags,
          "| Mean lag set:", input$mean_lags)
  })
  
  output$selected_plot <- renderPlot({
    # Construct the combined label to access the correct plot
    combined_label <- paste0("AR: ", input$ar_lags, " | Mean: ", input$mean_lags)
    selected_plot <- plot_list[[ input$restaurant_id ]][[ combined_label ]]
    
    grid::grid.draw(selected_plot)
  })
}

shinyApp(ui = ui, server = server)

source("renv/activate.R")

library(conflicted)
library(tidyverse)

c("select", "filter") %>% walk(~ conflict_prefer(.x, "dplyr"))
c("year", "month") %>% walk(~ conflict_prefer(.x, "lubridate"))
c("map") %>% walk( ~ conflict_prefer(.x, "purrr"))
c("sd") %>%  walk(~ conflict_prefer(.x, "stats"))
c("match") %>%  walk(~ conflict_prefer(.x, "base"))

# Ensure lintr reads config from project root to avoid invalid path errors in tools
if (requireNamespace("lintr", quietly = TRUE)) {
	try(options(lintr.linter_file = file.path(getwd(), ".lintr")), silent = TRUE)
}
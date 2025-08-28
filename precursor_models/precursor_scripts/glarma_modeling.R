library(arrow)
library(fpp3)
library(glarma)

df1 <- read_parquet("data/3_palate_data_parquet_modeling/SRQS8F7JWA9MZ.parquet")

colnames(df1)

df1 <- df1 %>%
  mutate(
    meal_period = as.factor(meal_period),
    day_of_week = as.factor(day_of_week),
    weekend = as.factor(weekend),
    day_of_month = as.factor(day_of_month),
    month = as.factor(month),
    season = as.factor(season),
    date = as.numeric(date)
  ) %>% 
  drop_na(
    vegan_window_avg, 
    vegetarian_window_avg, 
    meat_window_avg
  )%>%
  slice(1:100)

# fit standard glm to covariates
glm1 <- glm(vegan_outcome ~ 
              vegan_window_avg + 
              vegetarian_window_avg + 
              meat_window_avg +
              # hour_of_day +
              # meal_period +
              # day_of_week +
              # weekend +
              # day_of_month +
              # month +
              # season +
              date, 
            data = df1, 
            family = binomial)

summary(glm1)
glm_residuals <- residuals(glm1, type = "pearson")
glm_pred <- predict(glm1)

acf(glm_residuals, lag.max = 20, main = "ACF of Pearson residuals")
pacf(glm_residuals, lag.max = 20, main = "PACF of Pearson residuals")

y <- cbind(df$vegan_outcome, 
           1 - df$vegan_outcome)
X <- model.matrix(~ 1 +
                    vegan_window_avg*meat_window_avg + 
                    vegetarian_window_avg*meat_window_avg +
                    # hour_of_day +
                    # meal_period +
                    # day_of_week +
                    # weekend +
                    # day_of_month +
                    # month +
                    # season +
                    date
                  ,
                  data = df
)

glarma1 <- glarma(
  y = y,
  X = X,
  type = "Bin", # Logistic regression
  phiLags = 1, #1:3, # AR(1) through AR(3)
  thetaLags = 1, #1:3, # MA(1) through MA(3)
  method = "NR",  # Newton-Raphson optimization
  beta = rep(0, ncol(X)), # Starting values for beta
  residuals = "Pearson"
)

pred <- fitted(glarma1)
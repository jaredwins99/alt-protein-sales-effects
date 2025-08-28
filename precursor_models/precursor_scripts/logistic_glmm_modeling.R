library(arrow)
library(fpp3)
library(lme4)
library(glmmTMB)

set.seed(123)

df_all <- read_parquet("data/3_palate_data_parquet_modeling/all_locations.parquet")
df_all_daily <- read_parquet("data/3_palate_data_parquet_modeling/all_locations_daily.parquet")
df_all_subset <- df_all %>%
  mutate(
    meat_window_avg = scale(meat_window_avg),
    vegetarian_window_avg = scale(vegetarian_window_avg),
    vegan_window_avg = scale(vegan_window_avg),
    date = scale(date),
    day_of_week = as.factor(day_of_week),
  ) %>% 
  filter(location_id != 'W8T41JZK0ZMEP') %>%
  slice_sample(n=1000)

summary(df_all_subset$predicted_prob)
hist(df_all_subset$predicted_prob, breaks = 50, main = "Histogram of Predicted Probabilities")

glmer_all <- glmer(vegan_outcome ~ 
                     vegan_window_avg + 
                     #vegetarian_window_avg + 
                     meat_window_avg +
                     #hour_of_day +
                     meal_period +
                     day_of_week +
                     #weekend +
                     #day_of_month +
                     month +
                     season +
                     #date + 
                     (1 + meal_period + day_of_week + season | location_id),
                   data = df_all_subset,
                   family = binomial)

summary(glmer_all)
summary(glmer_all)$varcor

df_all_subset <- df_all_subset %>%
  mutate(
    predicted_prob = predict(glmer_all, newdata = df_all_subset, type = "response"),
    predicted_outcome = ifelse(predicted_prob > 0.25, 1, 0),
    created_at = as.Date(created_at),
    week = floor_date(created_at, "month")
  )

weekly_summary <- df_all_subset %>%
  group_by(location_id, week) %>%
  summarize(
    actual_sum = sum(vegan_outcome),
    predicted_sum = sum(predicted_outcome),
    .groups = "drop"
  )

table(df_all_subset$vegan_outcome, df_all_subset$predicted_outcome)
table(df_all_subset %>% 
        filter(location_id=='SRQS8F7JWA9MZ') %>% 
        pull(predicted_outcome))
table(df_all_subset %>% 
  filter(location_id=='W8T41JZK0ZMEP') %>% 
  pull(predicted_outcome))
df_all_subset %>% 
  filter(predicted_outcome==1)

ggplot(weekly_summary, aes(x = week)) +
  geom_line(aes(y = actual_sum, color = "Actual"), 
            size = .8) +
  geom_line(aes(y = predicted_sum, color = "Predicted"), 
            size = .8) +
  scale_color_manual(values = c("Actual" = "#1f77b4", 
                                "Predicted" = "#aec7e8")) +
  facet_wrap(~location_id, scales = "free_y") +
  theme_minimal() +
  labs(
    title = "Weekly Sum of Actual vs. Predicted Vegan Outcomes",
    x = "Week",
    y = "Sum of Vegan Outcomes",
    color = "Legend"
  ) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

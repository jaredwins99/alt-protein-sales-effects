
1. There are six analyses, four of which will use aggregated data. The last two will use completely different models.

## Data Structure
- **Unit of time**: Daily
- **Entities**: Restaurants (≈20), dishes, customers (subset)
- **Sales data**: Counts per dish/day, prices, customer IDs (partial), weather, calendar variables
- **Pre/Post windows**: Typically 2–6 months around MPBA introduction

---

## Key Definitions
- **MPBA**: Modern vegan analog mimicking specific ABF (e.g., Impossible Burger)
- **Outcomes**: Dish sales counts (non-vegan, meat, targeted ABF categories, etc.)
- **Exposure**:
  - Menu presence (counts/proportions)
  - MPBA introduction (ITS: pre vs post)
- **Targeted ABF**: ABF directly emulated by MPBA (e.g., beef burger ↔ Impossible)

---

## Analyses Structure
Six analyses (A1–A6), each run on:
- **Tier 1**: High-quality restaurants
- **Tier 2**: All restaurants

### A1–A2: Menu Presence (Global Effects)
- A1: Overall MPBA / vegan menu presence → general ABF sales
- A2: Animal-specific MPBA presence → targeted ABF sales

### A3–A4: Interrupted Time Series (ITS)
- A3: MPBA introduction → general ABF sales
- A4: MPBA introduction → targeted ABF sales

### A5–A6: Fixed-Customer ITS
- Same as A3–A4 but:
  - Customer fixed effects via within-customer mean-centering
  - Gender interaction terms

---

## Outcomes (Y)
- Counts, no offsets:
  - Non-vegan sales
  - Meat sales
  - Chicken + fish
  - Vegan / vegetarian (secondary)
  - Targeted ABF categories (6 classes)

---

## Exposures (X)
- Menu presence:
  - Counts & proportions (vegan, vegetarian, MPBA-modifiable)
- ITS:
  - Binary indicator (post vs pre introduction)
- Fixed-customer:
  - Exposure × gender interaction

---

## Covariates (C)
- Lagged prices (7-day avg, inflation-adjusted, by dish type)
- Inflation
- Weather (temperature, precipitation)
- Calendar effects (DoW, weekend, holidays, month, season, year)
- Linear date trend
- Lagged outcomes & latent intensity (1–7 days, 1–8 weeks)

---

## Shared Conventions (All Analyses)
- **Time index**: day `t`
- **Outcome type**: count (non-negative integer), no offset
- **Model**: Negative Binomial INGARCH with log link
- **Lag structure**:
  - Outcome AR lags: 1–7 days, 1–8 weeks
  - Latent intensity AR lags: same
- **Calendar variables**: categorical unless noted

---

## A1 — Overall Menu Presence → General ABF Sales

### Outcomes (Y_t)
1. `non_vegan_sales`
2. `meat_sales`
3. `chicken_fish_sales`
4. `vegan_sales` *(secondary)*
5. `vegetarian_sales` *(secondary)*
6. `total_dish_sales` *(secondary; customer-base sensitivity)*

### Exposures (X_t) *(one per model; never combined)*
1. `prop_vegan_menu`
2. `prop_vegetarian_menu`
3. `prop_mpba_modifiable_menu`
4. `count_vegan_menu`
5. `count_vegetarian_menu`
6. `count_mpba_modifiable_menu`

### Covariates (C_t)
- `avg_price_vegan_7d`
- `avg_price_veg_nonvegan_7d`
- `avg_price_meat_7d`
- `inflation`
- `temperature`
- `precipitation`
- `day_of_week`
- `weekend`
- `holiday`
- `month`
- `season`
- `year`
- `date_trend` *(continuous)*

---

## A2 — Animal-Specific Menu Presence → Targeted ABF

### Outcomes (Y_t)
- `sales_Ai` for each **animal product class**:
  1. Whole muscle meat
  2. Ground meat
  3. Breakfast meats
  4. Chicken
  5. Food-based dairy
  6. Egg

### Exposures (X_t)
1. `has_mpba_for_Ai` *(binary)*
2. `count_mpba_for_Ai`

### Covariates (C_t)
- `avg_price_mpba_Ai`
- **All covariates from A1**

---

## A3 — ITS: MPBA Introduction → General ABF

### Outcomes (Y_t)
Same **primary outcomes** as A1:
1. `non_vegan_sales`
2. `meat_sales`
3. `chicken_fish_sales`

### Exposure (X_t)
- `post_introduction` *(0 = pre, 1 = post)*

### Covariates (C_t)
- **All covariates from A1**

### Extra Structure
- Parameters estimated:
  - Level change (intercept)
  - Trend change (slope)
- Multiple MPBA introductions per restaurant = multiple shocks

---

## A4 — ITS: MPBA Introduction → Targeted ABF

### Outcomes (Y_t)
- `sales_Ai` for targeted animal classes (egg excluded)

### Exposure (X_t)
- `post_introduction`

### Covariates (C_t)
- **All covariates from A1**

2. Enough of the background. Now the IMPORTANT part. We have the data for the analyses here.

Data: data/4_data_parquet_modeling/
With that, we have
A1: proportion/
A2: proportion_targeted/
A3: its/
A4: its/
An important thing to do is view the header of the datasets to understand the columns.

3. The model we will use is a multilevel nb-ingarch, found in
Model: models/model_multilevel_transfer.stan

ITS-ML-NB-INGARCHX

Features
    Distributional correctness
        Count distribution
        Overdispersion  
    Dynamics
        Autoregressive
        Mean recursion
    Multilevel pooling
        Hierarchical pooling
    Interrupted time series
        Multiple interruptions
    Transfer functions

More granular
    Allows one or more exposure per restaurant (doesn't force multiple)
    Random and fixed predictors
    Restaurant index
    Predictor index
    Transfer index
    Time index


4. Model scripts are in
Scripts: model_scripts/ingarch_scripts
At a high level, we have specific formulations of the script in
model_scripts/analysis_scripts

a. Highest level, are using the model_starters folder

b. Next highest level, we are using model_scripts/analysis_scripts/run_analysis_finalized.R

c. Next highest level, and the primary function, we are using run_ingarch.R

d. The run_ingarch is made of 4 parts, separated into 4 files
- 1_data_ingarch.R
- 2_index_ingarch.R
- 3_init_ingarch.R
- 4_plot_ingarch.R

They respectively accomplish the parts of the task as their names imply. When the run_ingarch function is run, it spits out diagnositics, most importantly the data list that is given to the stan fitting function.

You will notice within 1_data_ingarch there is the standardizing of variables. It is important that the exposures do not be standardized since they need to be interpretable later. Other things should be when they can be.

5. Viewing params
They should be checked in this order:

Viewing and plotting: model_scripts/
view_params_funcs.R
plot_params_funcs.R

Forest plots:
forest_plots/create_forest_plots.R
forest_plots_restaurants/create_forest_plots_restaurants.R


In the end, we have 2 tiers, and each tier will have 70 models, minus a few


(tier 2 is same except different restaurants)
A1: 6 outcomes x 6 exposures = 36 models just make each its own starter file cuz we'll later run a bash script for a bunch of tmux sessions
A2: 12 exposures / outcomes = 12 models
A3: 6 outcomes = 6 models
A4: 5 exposures / outcomes = 5 models
A5: 6 outcomes = 6 models
A6: 5 exposures / outcomes = 5 models
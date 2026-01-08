# Data Quality Issues in Exposure Variables - Recommendations

## Quick Reference

**All files organized in:**
- 📊 **`data_diagnostics/`** - 5 CSV files with analysis results
- 📝 **`diagnostic_scripts/`** - 10 R scripts for checking issues

**Key files:**
- `data_diagnostics/all_exposures.csv` - Complete dataset (248 exposures)
- `data_diagnostics/low_cardinality.csv` - ≤7 distinct values (96 exposures)
- `data_diagnostics/outliers.csv` - Out-of-range values (66 exposures)
- `data_diagnostics/quality_issues.csv` - Sparse/separation flags (72 exposures)
- `data_diagnostics/standardization.csv` - Standardization errors (120 exposures)

---

## File Organization

All data quality analysis files are organized in two folders:
- **`data_diagnostics/`** - CSV output files with analysis results
- **`diagnostic_scripts/`** - R scripts for checking and investigating issues

## Summary of Issues Found

### 1. **Standardization Issues** (120 cases)
- **Count variables have decimals** (should be integers)
- **Proportion variables outside [0,1]** (incorrectly standardized/z-scored)
- See: `data_diagnostics/standardization.csv`

### 2. **Data Quality Issues** (72 cases)
- **Very sparse (≤2 values)**: 29 cases
- **High zero proportion (>90%)**: 44 cases
- **Potential separation**: 0 detected (at pooled level)
- See: `data_diagnostics/quality_issues.csv`

### 3. **Low Cardinality** (96 cases)
- **Exposures with ≤7 distinct values**: Limited variation
- See: `data_diagnostics/low_cardinality.csv`

### 4. **Outliers** (66 cases)
- **Values outside expected range**: Extreme standardization issues
- See: `data_diagnostics/outliers.csv`

### 5. **Restaurant-Specific Separation** (53 problematic cases)
Based on restaurant-specific analysis:
- **33 complete separation cases** (≥95% outcome=0 when exposure=0)
- **2 quasi-separation cases** (90-95% outcome=0 when exposure=0)
- **29 very sparse cases** (≤2 distinct values per restaurant)

**Restaurants with most issues:**
1. **SRQS8F7JWA9MZ (SRQ)**: 20 complete separation cases
2. **ED5J990H5VAZT (ED5)**: 5 complete separation cases + 2 quasi-separation
3. **JHDN7CF1C03X5 (JHD)**: 4 complete separation cases
4. **W8T41JZK0ZMEP (W8)**: 2 complete separation cases
5. **L69HYJ4Y3TR91 (L69)**: 2 complete separation cases

---

## Data Files Available

### ✅ In `data_diagnostics/`:
1. **`all_exposures.csv`** (248 rows) - Complete dataset with all flags for every exposure (POOLED across restaurants)
2. **`standardization.csv`** (120 rows) - Filtered to standardization problems only
3. **`quality_issues.csv`** (72 rows) - Filtered to sparsity/separation issues (POOLED)
4. **`low_cardinality.csv`** (96 rows) - Exposures with ≤7 distinct values
5. **`outliers.csv`** (66 rows) - Out-of-range values (min/max issues)
6. **`restaurant_specific_all.csv`** (248 rows) - **RESTAURANT-SPECIFIC** analysis for each exposure
7. **`restaurant_specific_problematic.csv`** (53 rows) - **Restaurant-exposure combinations with data issues**
8. **`restaurant_specific_separation.csv`** (35 rows) - **Complete/quasi-separation cases only**

### ✅ Diagnostic Scripts in `diagnostic_scripts/`:
1. **`analyze_exposures.R`** - Main pooled-level analysis (generates files 1-5)
2. **`analyze_restaurant_specific.R`** - **Restaurant-specific analysis (generates files 6-8)**
3. **`summarize_problematic_restaurants.R`** - **Summary of which restaurants to remove**
4. **`check_outliers.R`** - Check for outlier values
5. **`investigate_outliers.R`** - Investigate specific outlier cases
6. **`check_actual_values.R`** - Verify actual data values
7. **`check_breakfast_w8.R`** - W8 breakfast separation check
8. **`check_restaurant_gammas.R`** - Restaurant-level gamma checks
9. **`check_all_restaurant_gammas.R`** - All restaurant gamma summary
10. **`check_srq_separation.R`** - SRQ separation investigation
11. **`investigate_paradox.R`** - Simpson's paradox investigation
12. **`summary_cardinality.R`** - Cardinality summary statistics

### 🔲 Should Also Add To:

#### 1. **Forest Plot Data Files**
Add flags to the forest plot CSV outputs:
- `forest_plots/A1_proportion_mu_gamma.csv`
- `forest_plots/A2_proportion_targeted_mu_gamma.csv`
- `forest_plots/A3_its_mu_gamma.csv`
- `forest_plots/A4_its_targeted_mu_gamma.csv`

**How**: Join the data quality flags when creating forest plots based on:
- `analysis + outcome + exposure` for population-level estimates
- Need restaurant-specific version for `forest_plots_restaurants/` files

#### 2. **Restaurant-Level Forest Plot Data**
Add flags to:
- `forest_plots_restaurants/A1_proportion_restaurants.csv`
- `forest_plots_restaurants/A2_proportion_targeted_restaurants.csv`

**Columns to add**:
- `very_sparse`
- `high_zero_prop`
- `potential_separation_pooled`
- `potential_separation_restaurant` (needs restaurant-specific check)
- `data_quality_warning`

#### 3. **Visual Markers in Forest Plots**
Modify `create_forest_plots.R` and `create_forest_plots_restaurants.R`:
- Add **shape** to distinguish problematic estimates (triangle for issues)
- Add **color** (red/orange for data quality warnings)
- Add **annotation** for extreme outliers (RR > 50 or < 0.02)

#### 4. **Model Diagnostics Summary File**
Create: `model_diagnostics_summary.csv`

Columns:
- `analysis`, `outcome`, `exposure`, `restaurant_id`
- `gamma_mean`, `gamma_rr` (exponentiated)
- `gamma_q5`, `gamma_q95`
- `rhat`, `ess_bulk`
- `distinct_values`
- `very_sparse`, `high_zero_prop`, `potential_separation`
- `standardization_issue`
- `data_quality_warning`
- `extreme_estimate` (flag if RR > 50 or < 0.02)
- `wide_ci` (flag if q95/q5 > 100)

---

## Additional Checks to Implement

### Current Limitations:
The **separation check** currently only works at the **pooled level** (all restaurants combined). This misses restaurant-specific separation like W8 and SRQ.

### Suggested Additional Checks:

#### 1. **Restaurant-Specific Separation** (most important!)
For each restaurant in each model:
```r
# Subset to restaurant r's data
r_data <- subset_to_restaurant(data_list, restaurant_id = r)

# Check separation
prop_zero_when_zero <- mean(r_data$outcome == 0 when r_data$exposure == 0)
prop_zero_exposure <- mean(r_data$exposure == 0)

# Flag if >95% separation
restaurant_separation <- prop_zero_when_zero > 0.95 && prop_zero_exposure > 0.10
```

#### 2. **Sample Size Checks**
- **Very small exposed group**: Count of observations with exposure > 0 < 100
- **Very small unexposed group**: Count of observations with exposure = 0 < 100
- **Imbalanced exposure**: min(n_exposed, n_unexposed) / max(...) < 0.05

#### 3. **Extreme Estimate Flags** (from model outputs)
In the model `summ.rds` files, flag:
- **Extreme gamma**: |gamma| > 5 (RR > 148 or < 0.0067)
- **Wide credible intervals**: q95/q5 > 100 (or q95 - q5 > 10 on log scale)
- **Poor convergence**: rhat > 1.01
- **Low effective sample size**: ess_bulk < 400

#### 4. **Correlation Checks**
For each restaurant:
- **Negative raw correlation but positive gamma**: suggests Simpson's paradox or confounding
- **Zero correlation but extreme gamma**: suggests separation

#### 5. **Leverage/Influence**
- **Highly influential observations**: Single exposure change drives the entire effect
- **Count**: How many distinct exposure values exist per restaurant?

---

## Implementation Priority

### High Priority (Do Now):
1. ✅ Add flags to `data_diagnostics/all_exposures.csv` (DONE)
2. ✅ Create low cardinality and outliers files (DONE)
3. ✅ Organize files into logical folders (DONE)
4. 🔲 Add restaurant-specific separation check
5. 🔲 Create `data_diagnostics/model_diagnostics_summary.csv` combining:
   - Model estimates (from summ.rds)
   - Data quality flags (from exposure analysis)
   - Convergence diagnostics (rhat, ess)

### Medium Priority:
6. 🔲 Add flags to forest plot CSV files
7. 🔲 Add visual markers to forest plots (shapes, colors, annotations)
8. 🔲 Add sample size checks

### Lower Priority:
9. 🔲 Add correlation checks
10. 🔲 Add leverage/influence diagnostics

---

## Restaurant Removal Recommendations

### **Key File to Use:**
**`data_diagnostics/restaurant_specific_problematic.csv`** - Shows all 53 restaurant-exposure combinations with data issues

### **How to Identify Problematic Restaurants:**

Look for these flags in the file:
- `complete_separation = TRUE`: ≥95% of outcome=0 when exposure=0 (structural zeros)
- `quasi_separation = TRUE`: 90-95% of outcome=0 when exposure=0
- `very_sparse = TRUE`: ≤2 distinct exposure values for this restaurant
- `n_obs < 100`: Small sample size
- Check the `warning` column for human-readable summary

### **Restaurants to Consider Removing:**

Based on **complete separation** (the most serious issue):

1. **SRQ (SRQS8F7JWA9MZ)** - 20 complete separation cases
   - Affects: All proportion analyses (vegan, vegetarian, mpbamod exposures)
   - **Recommendation**: Remove from restaurant-specific analyses, keep for population-level

2. **ED5 (ED5J990H5VAZT)** - 5 complete separation + 2 quasi-separation
   - Affects: vegan_dishes_count, dairy_presence, egg_presence
   - **Recommendation**: Remove from affected analyses

3. **JHD (JHDN7CF1C03X5)** - 4 complete separation cases
   - Affects: breakfast and untextured in proportion_targeted
   - **Recommendation**: Remove from breakfast and untextured restaurant-level plots

4. **W8 (W8T41JZK0ZMEP)** - 2 complete separation cases
   - Affects: breakfast_dishes (count and presence)
   - **Recommendation**: Remove from breakfast restaurant-level plots

5. **L69 (L69HYJ4Y3TR91)** - 2 complete separation cases
   - Affects: breakfast_dishes (count and presence)
   - **Recommendation**: Remove from breakfast restaurant-level plots

### **Important Notes:**

- These restaurants can **still be included** in population-level estimates (mu_gamma)
- Only **exclude from restaurant-specific (gamma) plots and estimates**
- The separation issue means you **cannot estimate** their individual effects reliably
- The hierarchical model will still **borrow information** from them for the population mean

---

## How to Use These Flags

### For Interpretation:
- **Standardization issues** → Estimates are uninterpretable, must fix data preparation
- **Very sparse (≤2 values)** → Limited power, wide CIs expected, treat estimates cautiously
- **High zero proportion** → Few menu changes, limited variation, weak evidence
- **Potential separation** → Extreme estimates likely, CIs may be falsely narrow
- **Extreme estimates (RR > 50)** → Likely separation or data issue, investigate before reporting

### For Reporting:
Consider **excluding** or **flagging with caveats**:
- Any estimate with `standardization_issue != "OK"`
- Any estimate with `potential_separation = TRUE`
- Any estimate with `extreme_estimate = TRUE` (RR > 50 or < 0.02)
- Restaurant-specific estimates with `very_sparse = TRUE` and `distinct_values <= 2`

### For Model Development:
- Use **penalized priors** for restaurants with sparse data
- Consider **excluding** restaurants with separation from restaurant-specific plots
- Focus interpretation on **population-level (mu_gamma)** estimates when restaurant-level data is sparse

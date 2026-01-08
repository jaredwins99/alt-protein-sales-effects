# Quick Guide: Which Restaurants to Remove

## Files You Need

1. **`data_diagnostics/restaurant_specific_problematic.csv`** - All problematic cases
2. **`data_diagnostics/restaurant_specific_separation.csv`** - Just separation cases

## Summary

**52 total problematic restaurant-exposure combinations**
- 33 complete separation (≥98% structural zeros OR ≤3 non-zero outcomes when unexposed)
- 0 quasi-separation (95-98% structural zeros)
- 29 very sparse (≤2 distinct values)

## Restaurants Ranked by Severity

| Restaurant | Code | Complete Sep. | Quasi Sep. | Total Issues |
|---|---|---|---|---|
| SRQ | SRQS8F7JWA9MZ | 20 | 0 | 25 |
| ED5 | ED5J990H5VAZT | 5 | 2 | 7 |
| JHD | JHDN7CF1C03X5 | 4 | 0 | 6 |
| W8 | W8T41JZK0ZMEP | 2 | 0 | 6 |
| L69 | L69HYJ4Y3TR91 | 2 | 0 | 2 |
| 2HR | 2HRX9P6HKXA8V | 0 | 0 | 7 |

## Action Items

### Immediate Removals (Complete Separation):

**For restaurant-specific forest plots, EXCLUDE:**

1. **SRQ** from:
   - All proportion analyses (all outcomes)
   - Exposures: mpbamod, vegan, vegetarian
   - Both count and prop types

2. **ED5** from:
   - Proportion: vegan_dishes_count (chicken_fish, meat, nonvegan outcomes)
   - Proportion_targeted: dairy_presence, egg_presence

3. **JHD** from:
   - Proportion_targeted: breakfast (both count and presence)
   - Proportion_targeted: untextured (both count and presence)

4. **W8** from:
   - Proportion_targeted: breakfast (both count and presence)

5. **L69** from:
   - Proportion_targeted: breakfast (both count and presence)

### Notes:

- **Keep all restaurants in population-level (mu_gamma) estimates**
- Only remove from **restaurant-specific (gamma) estimates and plots**
- These have structural zeros: can't sell items not on menu
- Rate ratios are mathematically correct but uninterpretable

## What "Complete Separation" Means

**Definition**: Complete separation occurs when exposure=0 AND either:
1. Outcome=0 in ≥98% of observations, **OR**
2. ≤3 non-zero outcomes total when unexposed

**Distribution of separation cases:**
- 23 cases with 0 non-zero outcomes (100% separation)
- 8 cases with 1 non-zero outcome (near-perfect separation)
- 2 cases with 3 non-zero outcomes (SRQ vegan - the boundary case)

**Key Examples:**
- **W8 breakfast**: 100% separation (387 obs with exposure=0, **0 had outcome>0**)
- **SRQ vegan**: 98.1% separation (161 obs with exposure=0, **only 3 had outcome>0**)

**Why this matters:**
- Can't sell menu items that aren't offered (structural zeros)
- Creates infinite or near-infinite estimates in standard models
- Hierarchical model shrinks them but they're still extreme (RR=92, RR=342)
- Individual restaurant estimates are unreliable and shouldn't be reported
- Can still contribute to population-level (mu_gamma) estimates

## How to Use the CSV Files

```r
# Load problematic cases
library(tidyverse)
prob <- read_csv("data_diagnostics/restaurant_specific_problematic.csv")

# Filter to just complete separation
complete_sep <- prob %>% 
  filter(complete_separation == TRUE)

# See which restaurants to exclude for a specific analysis
breakfast_issues <- prob %>%
  filter(analysis == "proportion_targeted",
         exposure == "breakfast_dishes_count",
         complete_separation == TRUE) %>%
  pull(restaurant_id)

print(breakfast_issues)
# [1] "JHDN7CF1C03X5" "L69HYJ4Y3TR91" "W8T41JZK0ZMEP"
```

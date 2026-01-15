# Overlap Plot Clipping Notes - Tier 1 Only

## Tier 1 Restaurants
VLZX7K2M9QD4T, SRQS8F7JWA9MZ, 2HRX9P6HKXA8V, JHDN7CF1C03X5, L69HYJ4Y3TR91, ED5J990H5VAZT, W8T41JZK0ZMEP

Note: VLZX7K2M9QD4T only in A3/A4 (ITS data), not in A1/A2 (proportion data)

---

# Summary by Restaurant (applies across all analyses where present)

| Restaurant | Start Clip | End Clip | Start Date | End Date | Notes |
|------------|------------|----------|------------|----------|-------|
| 2HRX9P6HKXA8V | YES | YES | mid-2019 | varies | A1: end 2023 drops; A4 egg: end mid-2021 |
| ED5J990H5VAZT | YES | - | mid-2021 | - | Exposure=0 until mid-2021 across all |
| SRQS8F7JWA9MZ | YES | - | mid-2020 | - | Exposure=0 before mid-2020 |
| JHDN7CF1C03X5 | YES | - | early 2019 | - | Aberrant spike at beginning |
| L69HYJ4Y3TR91 | minor | - | - | - | Minor initial dip |
| W8T41JZK0ZMEP | - | - | - | - | OK - no clipping needed |
| VLZX7K2M9QD4T | YES | - | Oct 2021 | - | Exposure=0 before Oct 2021; short series |

---

# A1 - Proportion (all outcomes, all exposures)

Same as summary above. Applies to all outcome/exposure combinations:
- meat, vegan, vegetarian, nonvegan, total, chicken_fish outcomes
- mpbamod_dishes_prop/count, vegan_dishes_prop/count, vegetarian_dishes_prop/count exposures

**2HRX9P6HKXA8V special**: End clip needed - drops to 0 at end of 2023

---

# A2 - Proportion Targeted

Same patterns as A1 for restaurants present.
Variable coverage - not all restaurants have all categories.

---

# A3 - ITS (meat, vegan, vegetarian, nonvegan, total, chicken_fish)

Same as summary above. VLZX7K2M9QD4T included here.

---

# A4 - ITS Targeted

Same as summary above. VLZX7K2M9QD4T included here.

### Special Cases:
| Restaurant | Category | Start Clip | End Clip | Notes |
|------------|----------|------------|----------|-------|
| 2HRX9P6HKXA8V | egg | YES | YES | End drops to 0 after mid-2021 |
| 2HRX9P6HKXA8V | dairy | YES | - | End OK |
| 2HRX9P6HKXA8V | chicken | YES | - | End OK |

### Categories with limited usable data (consider excluding):
- **textured**: Most restaurants have flat/zero outcome
- **untextured**: Most restaurants have flat/zero outcome
- **breakfast**: Many restaurants have flat/zero outcome

---

# Clipping Dates Reference

| Restaurant | Clip Start After | Clip End Before |
|------------|------------------|-----------------|
| 2HRX9P6HKXA8V | 2019-06-01 | 2023-06-01 (A1) or 2021-06-01 (A4 egg) |
| ED5J990H5VAZT | 2021-06-01 | - |
| SRQS8F7JWA9MZ | 2020-06-01 | - |
| JHDN7CF1C03X5 | 2019-03-01 | - |
| VLZX7K2M9QD4T | 2021-10-01 | - |

# Tier 1 manual-vs-AI accuracy — checkpoint

## Sources (this matters; I got it wrong twice before)
| field | manual side | AI side | unit |
|---|---|---|---|
| vegan, vegetarian | `vegan`/`vegetarian` cols in `restaurant-sales/data/3_data_parquet_relabeled/7_truly_consolidated/{id}.parquet` | `automating-labeling/ai_labeled_data/{id}_*.csv` (all versions unioned, higher version wins) | **item_name x item_modifications** |
| 14 animal categories, mpbamod | `restaurant-sales/scripts/labeling/dish_labels/{id}.csv` | `automating-labeling/dish_labels/{id}_1.csv` (from `ai_targeted/`) | **item_name** |

`dish_labels/` is the Task-1 animal-category artifact. Its `vegan`/`vegetarian` columns are a
by-product and must NOT be used for vegan/vegetarian accuracy.

## Headline (exact-match keys, before any normalisation)

| field | agreement | basis |
|---|---|---|
| vegan | **99.96%** | 90,556 pairs, 82.4% coverage |
| vegetarian | **99.98%** | 90,556 pairs, 82.4% coverage |
| 14 categories | **98.72%** | pair-weighted, 82,023 pairs |
| mpbamod | **91.32%** | pair-weighted, 82,023 pairs |

## Per restaurant, vegan / vegetarian (per-pair)

| restaurant | data pairs | AI pairs | compared | cov% | vegan | vegetarian |
|---|---|---|---|---|---|---|
| VLZX7K2M9QD4T | 12,333 | 12,311 | 12,297 | 99.7 | 100.00 | 100.00 |
| SRQS8F7JWA9MZ | 7,695 | 7,787 | 7,695 | 100.0 | 99.68 | 99.84 |
| 2HRX9P6HKXA8V | 60,045 | 69,422 | 51,047 | 85.0 | 100.00 | 100.00 |
| JHDN7CF1C03X5 | 11,399 | 17,867 | 6,428 | 56.4 | 99.98 | 100.00 |
| L69HYJ4Y3TR91 | 1,451 | 1,498 | 1,100 | 75.8 | 100.00 | 100.00 |
| ED5J990H5VAZT | 12,201 | 16,292 | 10,148 | 83.2 | 100.00 | 100.00 |
| W8T41JZK0ZMEP | 4,739 | 7,748 | 1,841 | 38.9 | 99.40 | 99.78 |

Base rates match: manual 8.4% vegan / 22.5% vegetarian; AI 8.4% / 22.5%.

## ai_labeled_data version semantics (measured, not assumed)
Mostly ADDITIVE batches, not re-runs. Corrective only: SRQS8F `_3` (95.7% overlap, 37 conflicts),
W8T41J `_2`/`_3` (61-66% overlap, 7 conflicts), plus trivial ED5J99 `_3`. Union with
higher-version-wins is correct for both patterns. `2HRX9P6HKXA8V_worse.csv` excluded.

## Open caveats
- Coverage 82.4% and uneven (W8T41J 38.9%, JHDN7CF 56.4%). AI files hold MORE pairs than the data,
  so this is key mismatch (modification-string formatting), not missing labels.
- Not yet verified whether the manual vegan/vegetarian column was seeded from `ai_labeled_data`
  and then hand-corrected. If so these are correction rates, not blind agreement.

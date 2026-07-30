# Retired extractors — do not run

## `extract_adj_95ci.R.RETIRED`

Superseded by `../slim_extract_one.R` (pass 1) + `../adj_join_pass2.R` (pass 2).

It contained a defect that silently corrupted every adjusted restaurant-level
estimate whenever the outcome and total models held different restaurant sets.
At line 192 it built the coefficient name from the **outcome** model's indices
and applied it unchanged to the **total** model:

```r
col_idx <- data_list_o$idx_exposure[k]     # OUTCOME model index
r_idx   <- data_list_o$expo_to_rest[k]     # OUTCOME model index
vn      <- sprintf("beta[%d,%d]", col_idx, r_idx)
d <- beta_draws_o[seq_len(nb), vn] - beta_draws_t[seq_len(nb), vn]   # same name on BOTH
```

The two fits have different `predictor_map`s and different `restaurants_order`,
so this read a different predictor at a different restaurant. Since a
restaurant's `beta` is structurally 0 for another restaurant's exposure column,
the subtraction was usually **minus zero** — leaving the raw, unadjusted effect
while the pooled row was correctly adjusted.

Impact: 15% of Tier-1 and 20% of Tier-2 restaurant estimates moved by >5% on the
log scale once fixed; the largest single correction was RR 2.72 -> 0.107.

The replacement joins on `(model_col name, restaurant name)` and asserts every
match with `stopifnot`, so a future mismatch fails loudly instead of silently
subtracting zero.

Kept only for provenance — to reproduce a historical figure, or to re-verify the
defect. Running it would overwrite `publication/forest_data_adj_95ci.csv` with
corrupted values.

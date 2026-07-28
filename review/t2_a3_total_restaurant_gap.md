# T2 A3 total is missing the 4 Tier-1 restaurants

Found while re-extracting the adjusted (RRR) estimates. This one **does** need a
model re-fit — it cannot be repaired in post-processing.

## What is wrong

The T2 A3 **outcome** models carry all 17 restaurants. The T2 A3 **total** model
that the RRR divides by carries only **13** — the four Tier-1 restaurants
(`VLZX7K2M9QD4T`, `SRQS8F7JWA9MZ`, `2HRX9P6HKXA8V`, `JHDN7CF1C03X5`) are absent.

| fit | restaurants |
|---|---|
| `_trunc/t2_a3_its/{meat,nonvegan,vegan,vegetarian,total}` | 17 |
| `_trunc/t2_a3_its/chicken_fish` | 16 |
| `_cp/t2_a3_its/{meat,nonvegan,total}` | **13** |

So for those four restaurants there is no total-model coefficient to divide by,
and their restaurant-level RRR is **undefined**.

## Why

`model_starters/t2_its/A3_T2_total.R` calls `run_its_t2(outcome = "total", ...)`
without passing `restaurants_to_model`, so it inherits the function default in
`model_scripts/analysis_scripts/run_analysis_finalized.R`, which has the Tier-1
block commented out:

```r
run_its_t2 <- function(outcome, restaurants_to_model = c(
            # Tier 1
            #'VLZX7K2M9QD4T', 'SRQS8F7JWA9MZ', '2HRX9P6HKXA8V', 'JHDN7CF1C03X5',
            'L69HYJ4Y3TR91','ED5J990H5VAZT','W8T41JZK0ZMEP',
            ...
```

None of the six `model_starters/t2_its/A3_T2_*.R` files pass an explicit list
(only `A3_T2_chicken_fish.R` mentions the argument at all), so every `_cp` T2 A3
fit inherited the 13-restaurant default.

## This is not the root-preference design

Preferring `_cp` over `_trunc` per fit is intentional and correct, and mixing
roots across outcomes is fine. The problem is only that the **specific total fit
being used** has fewer restaurants than the outcomes paired against it.

`_trunc/t2_a3_its/total` *does* list all 17 — but it is a prep-only shell
(`data_list.rds` + `restaurants_order.rds`, no `fit.rds`), so the normal
`_trunc` fallback cannot resolve it either.

## What the extraction does about it

`adj_join_pass2.R` **drops** those rows and reports them, rather than borrowing a
coefficient from a different fit. Substituting the T1 total would mix effects
across models; an RRR is only defined against its own matching total fit. (An
earlier draft of the extractor did borrow from the T1 total — that was wrong and
has been removed; the fallback is now off unless explicitly requested for
diagnostics.)

The committed `forest_data_adj_95ci_t2_a3_a4.csv` contains values for these four
restaurants today, but they are **raw / unadjusted** — the old extractor
subtracted a structural zero for them (see
`pooled_outside_restaurants_diagnosis.md`, Bug 1).

## Fix

Re-fit **one** model with all 17 restaurants:

```r
# model_starters/t2_its/A3_T2_total.R
run_its_t2(
    outcome = "total",
    restaurants_to_model = c(
        'VLZX7K2M9QD4T','SRQS8F7JWA9MZ','2HRX9P6HKXA8V','JHDN7CF1C03X5',
        'L69HYJ4Y3TR91','ED5J990H5VAZT','W8T41JZK0ZMEP',
        'EMBVNVD207CC6','C0BE4NDSW26QN','V3Q26BHF3SE2H','LBZEEFSBJNB3Z',
        'SAFK7ND1HR6XS','S8MT0YGD2KTN9','1SQPTEGYPH0GA','9XKJD8DQTH559',
        'LQ5EH4BKGV61T','78AY09MVJVTYE'),
    directory = "finalized_redone_trunc_cp",
    apply_truncation = TRUE,
    thin = 2)
```

Then re-run pass 1 for that fit and pass 2, and the 4 dropped restaurants
resolve. Until then, T2 A3/A4 restaurant-level estimates for those four are
absent from the corrected CSV by design.

## Worth checking before re-fitting

The same default-list inheritance may affect other `_cp` T2 fits. `t2_a1_proportion`
and `t2_a2_proportion_t` totals should be audited the same way — do their
restaurant sets match their outcomes?

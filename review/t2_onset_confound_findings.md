# T2 onset-confound audit — what the overlap review missed, and why

Question: the Tier-2 overlap review was supposed to catch restaurant×dish pairs
where the outcome only starts at the introduction. Did it find them and not
apply the fix, or not find them at all?

Answer: **both, plus a third cause — the clip config never executes for most
analyses.** Three independent failures stack up.

---

## 1. The A1 clip table is dead code (path-match bug)

`model_scripts/ingarch_scripts/1_data_ingarch.R`

```r
is_proportion           <- grepl("/a1_proportion/",   data_dir)   # never TRUE
is_proportion_targeted  <- grepl("/a2_proportion_t/", data_dir)   # TRUE
```

The real paths come from `run_ingarch.R:114`
(`DATA_DIR <- file.path("data","4_data_parquet_modeling", data_file)`):

| analysis | actual data_dir | `is_proportion` | `is_prop_targeted` |
|---|---|---|---|
| A1 (T1 + T2) | `.../proportion/finalized_<expo>.parquet` | **FALSE** | FALSE |
| A2 (T1 + T2) | `.../a2_proportion_t/finalized_<expo>.parquet` | FALSE | **TRUE** |
| A3 / A4 | `.../its/finalized.parquet` | FALSE | FALSE |

The directory is `proportion/`, not `a1_proportion/`, so **`clip_dates_proportion`
has never been applied to any model, in either tier.** A2's clips do fire.

## 2. A3/A4 get no category clips by design

`apply_proportion_clips()` returns `df` unchanged for `its/` paths, so the
entire `clip_dates_proportion_targeted` table is bypassed for A3 and A4 — the
two analyses where onset confounding actually matters, because they are the
ITS/pre-post designs.

## 3. JHDN7CF1C03X5's start clip is commented out

`1_data_ingarch.R:143`

```r
filter(location_id != "JHDN7CF1C03X5" | (date < '2023-06-01')) %>% # '2019-04-01' < date &
```

Only the end clip survives. This is the universal filter that *does* apply to
A3/A4, so R4 keeps its entire early history everywhere.

---

## 4. Coverage gaps in the overlap review itself

Reviewed = union of all four `review/overlap_plots*` trees.
Compared against the restaurants actually inside each plotted fit
(`restaurants_order.rds`).

| analysis | outcome | in the fit but never plotted |
|---|---|---|
| t2_a4_its_t | untextured_t2 | **JHDN7CF1C03X5** |
| t2_a4_its_t | dairy_t2 | W8T41JZK0ZMEP |
| t2_a3_its | chicken_fish, meat, nonvegan, vegan, vegetarian | W8T41JZK0ZMEP |

`review/overlap_clipping_notes.md` is headed **"Tier 1 Only"** and no Tier-2
equivalent was ever written, so the T2-only pairs were never triaged.

Tier 1 has **no** such gaps — every T1 fit restaurant was reviewed.

---

## 5. The confounded pairs (systematic scan)

For every T2 A3/A4 restaurant×outcome in the plotted fits: pre-period stats
before the restaurant's first introduction, and the date the outcome actually
becomes non-trivial (first 30-day rolling mean > 25% of the post-intro mean).

| analysis | outcome | restaurant | pre-days | pre mean/day | % zero | first intro | outcome onset |
|---|---|---|---|---|---|---|---|
| t2_a3_its | chicken_fish | EMBVNVD207CC6 | 2521 | 0.000 | 100% | 2020-09-03 | 2020-08-27 |
| t2_a4_its_t | chicken_t2 | V3Q26BHF3SE2H | 515 | 0.000 | 100% | 2021-03-06 | 2021-02-13 |
| t2_a4_its_t | untextured_t2 | 9XKJD8DQTH559 | 664 | 0.005 | 100% | 2021-03-26 | 2019-11-01 |
| t2_a4_its_t | breakfast_t2 | V3Q26BHF3SE2H | 515 | 0.006 | 99% | 2021-03-06 | 2021-03-01 |
| **t2_a4_its_t** | **untextured_t2** | **JHDN7CF1C03X5** | 244 | 0.008 | 99% | **2019-09-06** | **2019-08-12** |
| t2_a4_its_t | dairy_t2 | EMBVNVD207CC6 | 2521 | 0.066 | 95% | 2020-09-03 | 2020-08-13 |
| t2_a3_its | chicken_fish | ED5J990H5VAZT | 2073 | 0.187 | 90% | 2021-10-01 | 2016-06-03 |
| t2_a3_its | vegan | EMBVNVD207CC6 | 2521 | 0.242 | 90% | 2020-09-03 | 2020-08-21 |
| t2_a3_its | vegetarian | EMBVNVD207CC6 | 2521 | 0.317 | 85% | 2020-09-03 | 2020-08-08 |
| t2_a3_its | nonvegan | EMBVNVD207CC6 | 2521 | 0.462 | 82% | 2020-09-03 | 2020-08-13 |

10 of 94 pairs. Tier 1 has none.

### R4 / ground meat — clipping cannot fix this one

Monthly mean, JHDN7CF1C03X5 `untextured_outcome`:

```
2019-01  0.00   2019-04  0.00   2019-07  0.00   2019-10  6.26
2019-02  0.04   2019-05  0.00   2019-08  0.03   2019-11  4.87
2019-03  0.00   2019-06  0.00   2019-09  5.27   2019-12  4.06
```

Beyond Burger launched **2019-09-06**; ground meat goes 0 → 5.27/day the same
month. Every clip date in the notes (2019-01-26 / 2019-03-01 / 2019-04-01) sits
*before* the flat stretch, so none of them removes it. Exposure onset and
outcome onset are the same event — the effect is not identifiable at this
restaurant, which is exactly why **T1 excludes it** (`A4_untextured.R` has
`#'JHDN7CF1C03X5'` commented out). T2 never got that edit.

### EMBVNVD207CC6 — clip start is ~4 years too early

Universal filter keeps `'2016-06-01' < date < '2022-09-01'`, but yearly mean
`total_outcome` is 0.1–2.0/day for 2013–2019 and only reaches 3.8 (2020),
26.6 (2021), 31.2 (2022). The pre-2020 rows are a data-coverage ramp-up, not
trading history, and they enter 5 T2 models plus the RRR denominator.
Suggested start ≈ **2020-08-01**.

---

## 6. Re-run list

Config edits first (no re-fit needed to make them, but they change the data):

1. `1_data_ingarch.R:56-57` — fix the gate to `grepl("a1_proportion|/proportion/", data_dir)`
   so `clip_dates_proportion` fires. (Or delete the table if the universal
   filters are meant to be authoritative — but decide, don't leave it dead.)
2. `1_data_ingarch.R:143` — uncomment JHDN7CF1C03X5's start clip.
3. `1_data_ingarch.R:144` — EMBVNVD207CC6 start `2016-06-01` → `2020-08-01`.
4. `model_starters/t2_its_targeted/A4_T2_untextured.R` — comment out
   `'JHDN7CF1C03X5'`, mirroring the T1 starter.

Minimal high-value re-fit set (**10 models**), all writing to
`finalized_redone_trunc_cp`:

| # | analysis | outcome | reason |
|---|---|---|---|
| 1 | t2_a4_its_t | untextured_t2 | drop R4 (match T1); 9XKJD8 onset |
| 2 | t2_a4_its_t | dairy_t2 | EMBVNVD clip; W8T41J never reviewed |
| 3 | t2_a4_its_t | breakfast_t2 | V3Q26B onset |
| 4 | t2_a4_its_t | chicken_t2 | V3Q26B is the *only* restaurant and is onset-confounded → recommend dropping the outcome rather than re-fitting |
| 5–9 | t2_a3_its | nonvegan, meat, chicken_fish, vegan, vegetarian | EMBVNVD clip (+ED5J99 on chicken_fish) |
| 10 | t2_a3_its | **total** | RRR denominator — must be re-fit or every A3/A4 RRR stays stale |

Note (10): the adjusted RRR subtracts the T2 A3 `total` draws, so re-fitting an
outcome without re-fitting `total` leaves the pairing inconsistent.

Not in scope here, but flagged separately: T2 A5/A6 have severe non-convergence
(pooled R-hat up to 3.75) that no clip fixes.

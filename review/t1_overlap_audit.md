# Tier 1 overlap / onset audit — read-only

Purpose: confirm Tier 1 is sound and reproducible. **No Tier 1 change is
proposed or made.** This file exists so the Tier 1 position is documented and
can be defended, and so Tier 2 decisions can be made consistent with it.

Scope: A1–A4, the analyses that feed the RRR figures, using the fits actually
plotted (per `fit_dir` in `publication/forest_data_adj_95ci.csv`).

---

## Verdict: Tier 1 is clean. Nothing needs re-running.

Three independent checks, all passed.

### 1. No fundamental mismatch (restaurant lacks the counterpart product)

**A2 (targeted counterpart outcomes)** — every restaurant×outcome pair in the
fits carries real volume. Worst case is 42% zero-days; smallest mean is
9.8 purchases/day.

| outcome | restaurant | mean/day | % zero |
|---|---|---|---|
| breakfast_p | ED5J990H5VAZT | 10.04 | 42 |
| chicken_p | JHDN7CF1C03X5 | 29.22 | 22 |
| dairy_p | JHDN7CF1C03X5 | 37.48 | 21 |
| chicken_p | W8T41JZK0ZMEP | 9.80 | 16 |
| … 7 more, all ≥ 9.8/day | | | |

**A1 (general outcomes)** — two genuinely thin cells, both `chicken_fish` at
venues that barely sell it:

| outcome | restaurant | mean/day | % zero |
|---|---|---|---|
| chicken_fish | ED5J990H5VAZT (coffee shop) | 0.57 | 78 |
| chicken_fish | L69HYJ4Y3TR91 (breakfast café) | 0.88 | 54 |

These are *low volume*, not *absent*, and A1/A3 include every restaurant for
every general outcome by design — so this is expected, not a mismatch.

### 2. No onset confounding in the ITS analyses

Pre-introduction window for each restaurant×outcome pair, 34 pairs total:

- **A4 (targeted ITS): max pre-period zero-share is 52%** (ED5J990H5VAZT /
  breakfast). No pair approaches the ≥90% signature that indicates the outcome
  only begins at the introduction.
- **A3 (general ITS): 2 of 29 pairs above 70%**, both `chicken_fish` —
  ED5J990H5VAZT (90% zero, 0.187/day pre) and L69HYJ4Y3TR91 (71%, 0.444/day).
  Same thin-cell situation as A1; these restaurants are in A3 for all five
  general outcomes and are substantial on the other four.

No Tier 1 pair has outcome-onset coinciding with exposure-onset.

### 3. No outrageous estimates

Restaurant-level adjusted estimates across all of A1–A4:

| analysis | n | max RR | widest 95% CI |
|---|---|---|---|
| a1_proportion | 20 | 3.07 | 13× |
| a2_proportion_t | 8 | 0.23 | 22× |
| a3_its | 66 | 3.33 | 21× |
| a4_its_t | 12 | 1.22 | 13× |

**Max RR anywhere in Tier 1 is 3.33; widest CI is 22×.** For contrast, Tier 2
A4 reaches RR 134 with CIs up to 1675×. The two thin `chicken_fish` cells
produce the widest A3 intervals (L69HYJ slope, RR 2.07, 21×) — wide, as they
should be, but not degenerate.

---

## Known defects that do NOT affect the Tier 1 conclusions

Recorded for completeness; none of these justify a re-run.

**The A1 clip table never executes.** In `1_data_ingarch.R`,
`is_proportion <- grepl("/a1_proportion/", data_dir)` never matches, because the
real path is `.../proportion/finalized_<expo>.parquet`. So
`clip_dates_proportion` is dead code in both tiers. Had it fired, it would have
removed only edge rows:

| restaurant | data range | clip range | rows dropped |
|---|---|---|---|
| 2HRX9P6HKXA8V | 2018-11-03…2023-08-01 | 2018-12-31…2023-07-25 | 67 (4%) |
| ED5J990H5VAZT | 2016-01-28…2023-08-14 | 2016-04-20…2023-06-27 | 133 (5%) |
| JHDN7CF1C03X5 | 2019-01-05…2023-07-31 | 2019-01-26…2022-10-22 | 305 (18%) |
| L69HYJ4Y3TR91 | 2022-08-30…2023-07-30 | 2022-10-07…2023-07-23 | 47 (14%) |
| SRQS8F7JWA9MZ | 2019-03-27…2023-07-30 | 2019-04-30…2023-07-23 | 43 (3%) |
| W8T41JZK0ZMEP | 2020-02-13…2023-07-31 | 2020-02-12…2023-07-24 | 8 (1%) |

2HRX9P6HKXA8V is separately covered by the universal filter
(`'2019-01-01' < date < '2023-08-01'`), which is nearly the same window, so its
clip is effectively applied anyway.

**A3/A4 bypass the category clip table** — `apply_proportion_clips()` returns
early for `its/` paths. Tier 1 A3/A4 rely solely on the universal filters, and
the audit above shows that is sufficient here.

**JHDN7CF1C03X5's start clip is commented out** (`1_data_ingarch.R:143`).
Irrelevant to Tier 1 outcomes: R4's pre-period zero-shares in A3 are 4–6%.

---

## The one Tier 1 decision Tier 2 must inherit

`model_starters/a4_its_t/A4_untextured.R` excludes JHDN7CF1C03X5 from
ground meat:

```r
restaurants_to_model = c('SRQS8F7JWA9MZ'#,
#'JHDN7CF1C03X5'
),
```

Tier 2 is a superset of Tier 1, so the same restaurant must enter the T2 ground
meat model the same way. It currently does not — see
`t2_onset_confound_findings.md`.

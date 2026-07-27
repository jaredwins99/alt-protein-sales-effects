# Tier 2 — complete problem list (no changes made)

Every problem found, with evidence. Nothing here has been acted on.

Three **distinct mechanisms** produce the bad T2 estimates. They need different
remedies, and only one of them is a clipping question.

---

## Mechanism A — label contamination: the analog is counted as its own counterpart

**Root cause.** In `restaurant-sales/scripts/4.0_modeling_prep_2.ipynb` the
targeted outcome is a straight copy of the animal label flag, with **no
vegan/vegetarian filter**:

```python
untextured = targeted_from_map(df, untextured_map)   # == df['beef_or_pork_burger']
untextured_outcome = 1*df['untextured']
```

`untextured_map` sends R4 to `beef_or_pork_burger`, and R4's only item with
that flag is the Beyond Burger. So the outcome *is* the exposure product.

**Verified, not inferred:**

| check | result |
|---|---|
| T1 label file | `beef_or_pork_burger` = **"Fresh Beyond Burger"** only, `vegetarian=True` |
| T2 label file | `beef_or_pork_burger` = **"Beyond Burger"** only, `vegan=True` |
| outcome formula | no `& ~vegetarian` anywhere in the assign block |
| logical test | if vegetarian items were excluded, R4's outcome would be identically 0 — it is 2.37/day |
| volume test | model `untextured_t2` total = **3,958 units**; raw "Fresh Beyond Burger" = **4,465 units** (difference = the 2023-06-01 end clip) |

**Contamination by purchase volume** — share of each targeted outcome's actual
units coming from plant-based items. Computed from
`3_data_parquet_relabeled/7_truly_consolidated/` joined to the dish-label CSVs.
(Note: `7_with_targeted/` does *not* reconcile with the modelled totals — do not
use it.)

| restaurant | T2 outcome | units | plant units | **% volume** | driving items |
|---|---|---|---|---|---|
| W8T41JZK0ZMEP | breakfast_t2 | 4,240 | 4,240 | **100%** | Vegan Breakfast Sandwich |
| V3Q26BHF3SE2H | chicken_t2 | 503 | 503 | **100%** | Wings (V) |
| JHDN7CF1C03X5 | untextured_t2 | 4,465 | 4,465 | **100%** | Fresh Beyond Burger |
| W8T41JZK0ZMEP | dairy_t2 | 59,130 | 44,330 | **75%** | Pb & J Bowl, Energy Bars, Acai Bowl |
| SAFK7ND1HR6XS | textured_t2 | 21,174 | 4,437 | 21% | Jackfruit Taco |
| 1SQPTEGYPH0GA | untextured_t2 | 14,527 | 2,521 | 17% | Spaghetti No Meatball, Impossible Meatball |
| SRQS8F7JWA9MZ | untextured_t2 | 66,232 | 7,629 | 12% | Impossible Patty Melt |
| 2HRX9P6HKXA8V | breakfast_t2 | 350,937 | 22,264 | 6% | Veggie Wurst, Beyond Sausage |
| C0BE4NDSW26QN | untextured_t2 | 26,192 | 1,508 | 6% | Impossible Burger |
| 78AY09MVJVTYE | breakfast_t2 | 115,159 | 5,898 | 5% | Veggie Sausage Egg & Cheese |
| LQ5EH4BKGV61T | untextured_t2 | 2,667 | 93 | 3% | Veggie Burger |
| S8MT0YGD2KTN9 | untextured_t2 | 58,112 | 678 | 1% | V-Urger |
| EMBVNVD207CC6 | dairy_t2 | 15,373 | 174 | 1% | Vegan Chili, Vegan Spinach Dip |
| 9XKJD8DQTH559 | dairy_t2 | 7,232 | 21 | 0.3% | Vegan Pizza |
| VLZX7K2M9QD4T | textured_t2 | 180,597 | 0 | **0%** | — |
| V3Q26BHF3SE2H | breakfast_t2 | 2,867 | 0 | **0%** | — |
| L69HYJ4Y3TR91 | breakfast_t2 | 6,284 | 0 | **0%** | — |
| ED5J990H5VAZT | breakfast_t2 | 14,162 | 0 | **0%** | — |
| 9XKJD8DQTH559 | untextured_t2 | 318 | 0 | **0%** | — |

Clipping cannot fix any of these — the contaminated units are spread across the
whole series, not confined to an edge.

---

## Mechanism B — onset confound: counterpart sales begin at the introduction

Restaurant genuinely had no counterpart sales before the analog launched, so
there is no pre-period to compare against. Distinct from A: the labels are
correct.

| restaurant | outcome | pre-days | pre mean/day | % zero | first intro | outcome onset |
|---|---|---|---|---|---|---|
| V3Q26BHF3SE2H | breakfast_t2 | 515 | 0.006 | 99% | 2021-03-06 | 2021-03-01 |
| 9XKJD8DQTH559 | untextured_t2 | 664 | 0.005 | 100% | 2021-03-26 | 2019-11-01 |

---

## Mechanism C — data-coverage ramp: clip candidate

The restaurant's series starts years before it has usable trading volume.
**This is the only mechanism where clipping is the right answer.**

**EMBVNVD207CC6** — universal filter keeps `2016-06-01 … 2022-09-01`, but yearly
mean *total* sales are:

```
2013 0.2   2015 0.3   2017 1.1   2019 1.0   2021 26.6
2014 0.1   2016 0.3   2018 2.0   2020 3.8   2022 31.2
```

Pre-2020 is a data ramp-up, not trading history. It enters 5 T2 models plus the
RRR denominator. Candidate start ≈ 2020-08-01 — **needs your eyes, not an
automatic rule.**

**ED5J990H5VAZT / chicken_fish** (A3) — 2,073 pre-days at 90% zero, 0.187/day.
Low-volume category, not obviously a clip.

---

## How the mechanisms line up with the outrageous estimates

Essentially perfect once contamination is measured **by volume** rather than by
item count.

| restaurant / outcome | level RR | CI width | %vol contaminated | mechanism |
|---|---|---|---|---|
| JHDN7CF1C03X5 / untextured | **134** | 5× | **100%** | A |
| V3Q26BHF3SE2H / chicken | **103** | 259× | **100%** | A |
| V3Q26BHF3SE2H / breakfast | **19.2** | 12× | 0% | B |
| EMBVNVD207CC6 / dairy | **6.9** | 21× | 1% | C |
| W8T41JZK0ZMEP / dairy | 1.21 | 1.5× | 75% | A (tame) |
| 1SQPTEGYPH0GA / untextured | 0.45 | 1.9× | 17% | A (tame) |

- Both RR > 100 estimates are **exactly** the two live 100%-contaminated pairs.
- The third 100% pair (W8T41J / breakfast) is already excluded from the starter,
  which is why it produces no estimate.
- The two remaining outliers are *not* contamination — they are B and C.
- Contamination below ~75% by volume does not blow up the estimate; item-count
  share does not predict it (W8T41J dairy is 78% by count, 75% by volume, RR 1.21).

---

## Problems in the pipeline itself

1. **A1 clip table never executes.** `is_proportion <- grepl("/a1_proportion/", data_dir)`
   never matches; the real path is `.../proportion/...`. `clip_dates_proportion`
   is dead code in **both** tiers.
2. **A3/A4 bypass the category clip table** — `apply_proportion_clips()` returns
   early for `its/` paths.
3. **JHDN7CF1C03X5 start clip is commented out** (`1_data_ingarch.R:143`):
   `# '2019-04-01' < date &`.
4. **`7_with_targeted/` does not reconcile** with the modelled outcome totals
   (V3Q26B chicken: 1 unit there vs 503 modelled). Stale artifact.

## Problems in the overlap review

5. Restaurant×outcome pairs **in the fits but never plotted**:
   - `t2_a4_its_t / untextured_t2` — **JHDN7CF1C03X5**
   - `t2_a4_its_t / dairy_t2` — **W8T41JZK0ZMEP** (the 75%-contaminated one)
   - `t2_a3_its / {chicken_fish, meat, nonvegan, vegan, vegetarian}` — W8T41JZK0ZMEP
6. `overlap_clipping_notes.md` is headed **"Tier 1 Only"**; no Tier-2 triage was
   ever written down.

## Consistency problems between tiers

7. **R4 is excluded from T1 ground meat but included in T2 ground meat.** T1's
   `A4_untextured.R` has `#'JHDN7CF1C03X5'`; the T2 starter does not.
8. Restaurants already excluded from *some* T2 starters
   (`A4_T2_breakfast.R` drops JHDN7CF, SRQS8F, W8T41J) but not from others —
   no single rule was applied across T2.

## For awareness only — Tier 1 (no action, per your instruction)

Tier 1's live contamination is bounded and its estimates stay sane (max RR 3.33):

| restaurant | T1 outcome | % volume contaminated |
|---|---|---|
| SRQS8F7JWA9MZ | untextured (the **only** restaurant in T1 A4 ground meat) | **12%** |
| 2HRX9P6HKXA8V | breakfast | 6% |
| VLZX7K2M9QD4T / ED5J99 / L69HYJ | textured, breakfast | 0% |

JHDN7CF1C03X5's breakfast is ~100% contaminated (Beyond Sausage, 116 units vs
113 modelled) but it is **not** in the T1 A4 breakfast fit, so it does no harm.

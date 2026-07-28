# Contamination fix — the case, the change, the cost

**Nothing has been changed.** Single authoritative simulation, scoped to outcomes
that actually feed a model. Supersedes all earlier numbers in this file.

---

## The problem, in one line

The anti-keyword lists in `category_mappings` already contain `vegan`, `beyond`,
`impossible`, `veggie`, `black sheep`. They are tested against
**`item_modifications` only** — never against `item_name`. So a dish whose
plant-based identity is in its *name* keeps the animal-counterpart flag it
inherited from the label-CSV join, and gets counted as its own counterpart.

Worst case: `JHDN7CF1C03X5`'s entire "ground meat" outcome is the Beyond Burger.
The restaurant has exactly one item containing "burger" in its whole history.
Model outcome 3,958 units vs Beyond Burger sales 3,947 after the mods mask —
an 11-unit gap. That is the RR 134 estimate.

---

## The change — one added line

`restaurant-sales/scripts/4.0_modeling_prep_2.ipynb`, **cell 2**:

```python
for cat, (keywords, anti_keywords) in category_mappings.items():
    df[cat] = (
        df[cat]
        .mask(df["item_modifications"].str.contains(keywords,      case=False, na=False), True)
        .mask(df["item_modifications"].str.contains(anti_keywords, case=False, na=False), False)
        .mask(df["item_name"].str.contains(anti_keywords, case=False, na=False), False))   # NEW
```

Must be last, so exclusion wins over the keyword promotion. Everything
downstream (`untextured_p`, `targeted_from_map`, …) reads these same columns, so
re-running the notebook regenerates the model-ready parquets with no other edit.

---

## What it does

| | units before | removed | % | **contamination removed** | **genuine units lost** |
|---|---|---|---|---|---|
| **A4** (targeted ITS) | 961,939 | 64,709 | 6.7% | **64,709** | **0** |
| **A2** (targeted availability) | 1,819,603 | 85,066 | 4.7% | 64,300 | 20,766 |

**A4 — the analysis with the RR 134 and RR 103 blow-ups — is cleaned with zero
collateral damage.** Not one genuine animal unit is lost anywhere in A4.

A1 and A3 are untouched: they read `vegan` / `vegetarian` / `chicken_fish`,
which this loop never modifies.

### A4, per outcome

| restaurant | outcome | before | removed | % |
|---|---|---|---|---|
| W8T41JZK0ZMEP | breakfast_sausage_patty | 3,810 | 3,810 | **100.0%** |
| JHDN7CF1C03X5 | sausage | 113 | 113 | **100.0%** |
| JHDN7CF1C03X5 | beef_or_pork_burger | 3,956 | 3,947 | **99.8%** |
| SAFK7ND1HR6XS | pulled_pork | 23,009 | 4,436 | 19.3% |
| SRQS8F7JWA9MZ | beef_or_pork_burger | 66,268 | 7,634 | 11.5% |
| VLZX7K2M9QD4T | lamb | 187,914 | 14,987 | 8.0% |
| 2HRX9P6HKXA8V | sausage | 350,467 | 20,618 | 5.9% |
| C0BE4NDSW26QN | beef_or_pork_burger | 26,021 | 1,499 | 5.8% |
| 78AY09MVJVTYE | sausage | 112,879 | 4,857 | 4.3% |
| LQ5EH4BKGV61T | beef_or_pork_burger | 2,666 | 90 | 3.4% |
| W8T41JZK0ZMEP | sweet_dairy | 55,686 | 1,537 | 2.8% |
| 1SQPTEGYPH0GA | meatballs | 15,079 | 306 | 2.0% |
| S8MT0YGD2KTN9 | beef_or_pork_burger | 57,778 | 666 | 1.2% |
| EMBVNVD207CC6 | savory_dairy | 14,864 | 173 | 1.2% |
| 9XKJD8DQTH559 | savory_dairy | 8,785 | 27 | 0.3% |
| ED5J990H5VAZT | bacon | 23,000 | 9 | 0.0% |
| L69HYJ4Y3TR91 / V3Q26BHF3SE2H | breakfast_sausage_patty | — | 0 | 0% |

**Two pairs collapse rather than get corrected** — `JHDN7CF1C03X5 / ground meat`
(3,956 → 9 units) and `W8T41JZK0ZMEP / breakfast` (3,810 → 0). Neither
restaurant ever sold the animal counterpart. These need removing from the model
lists, not re-fitting.

---

## The cost — 3 outcomes, 6 items, all in A2

Every genuinely-animal unit the fix would wrongly drop, verified item by item:

| units | restaurant | A2 outcome | item | token that fired |
|---|---|---|---|---|
| 16,781 | SAFK7ND1HR6XS | textured_p | Pastor Taco | `pastor` |
| 2,898 | LFZFT3VASXPED | untextured_p | Smashville | `smash` |
| 1,073 | LFZFT3VASXPED | untextured_p | Quad Smash | `smash` |
| 14 | ED5J990H5VAZT | dairy_p | Croissant Almond | `almond` |
| **20,766** | | | | |

Two further false removals exist but **reach no model**: VLZX7K2M9QD4T's Cretan
Wildflower Honey Frozen Yogurt (26,616 units, `df` matching "wil**df**lower" —
VLZX7K2M9QD4T is in no dairy analysis) and C0BE4N's Pork Veggie Sandwich (1,037 units,
`veggie` — C0BE4N is not in the A2 breakfast list).

Everything else removed is genuinely plant-based: Black Sheep (mock lamb),
Fresh Beyond Burger, Impossible Patty Melt, Veggie Wurst, Vegan Sandwich,
V-Urger, Jackfruit Taco, Black Bean Burger, and the rest.

---

## Two token edits remove 99.9% of that cost

Same file, `category_mappings`:

```python
'chunked_beef_or_pork': (..., '|'.join(['-v','v-','^v ',' v$','vegan','tofu','seitan','vegetarian'])),
#                                        drop 'pastor'  ^
'beef_or_pork_burger':  (..., '|'.join(['-v','v-','^v ',' v$','vegan','impossible','beyond','veggie','black bean','beet'])),
#                                        drop 'smash'   ^
```

| edit | recovers | costs |
|---|---|---|
| drop `pastor` | 16,781 | **0** — the only "pastor" item in all 20 restaurants is SAFK7N's Pastor Taco, real pork. No vegan pastor exists. |
| drop `smash` | 3,971 | **131** — W8T41JZK0ZMEP's "Smash Burger" is `vegan=True` and would be readmitted to its `untextured_p` (3,336 units, so ~4% contamination in that one outcome) |

`pastor` also can't cause double-counting: Pastor Taco is `pulled_pork=False`, so
without the token it lands in `chunked_beef_or_pork`, its correct category.

### Final position after all three edits

| | contamination removed | genuine units lost |
|---|---|---|
| A4 | 64,709 | **0** |
| A2 | 64,300 | **14** (Croissant Almond) + 131 readmitted vegan |

---

## What this does not fix

Different mechanisms, not addressed by any labelling change:

- **Pairs that cease to exist** — `JHDN7CF1C03X5 / ground meat`,
  `W8T41JZK0ZMEP / breakfast`. Remove from the model lists.
- **Onset confound** — `V3Q26BHF3SE2H / breakfast`, `9XKJD8DQTH559 / untextured`:
  counterpart sales genuinely begin at the introduction, so there is no
  pre-period.
- **Data-coverage ramp** — `EMBVNVD207CC6`: usable trading starts ~2020-08 but
  the series is kept from 2016-06. A clipping decision, still open.

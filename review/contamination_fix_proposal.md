# Contamination fix — exact code change and impact report

**Nothing has been changed.** This is the proposal plus a full simulation of what
it would do, across all restaurants in both tiers.

---

## 1. The change

**File:** `restaurant-sales/scripts/4.0_modeling_prep_2.ipynb`, **cell 2**
(the `for loc_id in location_ids_by_coverage:` loop, inner category loop).

Current:

```python
for cat, (keywords, anti_keywords) in category_mappings.items():
    df[cat] = (
        df[cat]
        .mask(df["item_modifications"].str.contains(keywords,      case=False, na=False), True)
        .mask(df["item_modifications"].str.contains(anti_keywords, case=False, na=False), False))
```

Proposed — **one added line**:

```python
for cat, (keywords, anti_keywords) in category_mappings.items():
    df[cat] = (
        df[cat]
        .mask(df["item_modifications"].str.contains(keywords,      case=False, na=False), True)
        .mask(df["item_modifications"].str.contains(anti_keywords, case=False, na=False), False)
        .mask(df["item_name"].str.contains(anti_keywords, case=False, na=False), False))   # NEW
```

Rationale: the anti-keyword lists are already correct and already contain
`vegan`, `beyond`, `impossible`, `veggie`, `black sheep`, etc. They were only
ever tested against `item_modifications`, so a dish whose plant-based identity
lives in its **name** kept the animal flag it inherited from the label-CSV join.
The new mask must come **last** so exclusion wins over the keyword promotion.

Nothing downstream changes: `untextured_p`, `breakfast_p`, … and
`targeted_from_map(...)` all read these same columns, so re-running the notebook
regenerates the model-ready parquets directly.

---

## 2. Overall impact

| | outcomes touched | units before | removed | % | plant-flagged (correct) | animal-flagged (review) |
|---|---|---|---|---|---|---|
| **A4** (targeted ITS) | 16 / 20 | 961,939 | 64,709 | **6.7%** | 52,908 | 11,801 |
| **A2** (targeted availability) | 31 / 49 | 1,819,603 | 85,066 | **4.7%** | 63,606 | 21,460 |

A1 and A3 are untouched — they read `vegan` / `vegetarian` / `chicken_fish`,
which this loop never modifies.

---

## 3. Per-restaurant impact, A4 outcomes

| restaurant | outcome | before | removed | % | correct | review |
|---|---|---|---|---|---|---|
| W8T41JZK0ZMEP | breakfast_sausage_patty | 3,810 | 3,810 | **100.0%** | 3,810 | 0 |
| JHDN7CF1C03X5 | sausage | 113 | 113 | **100.0%** | 93 | 20 |
| JHDN7CF1C03X5 | beef_or_pork_burger | 3,956 | 3,947 | **99.8%** | 3,608 | 339 |
| SAFK7ND1HR6XS | pulled_pork | 23,009 | 4,436 | 19.3% | 4,428 | 8 |
| SRQS8F7JWA9MZ | beef_or_pork_burger | 66,268 | 7,634 | 11.5% | 7,518 | 116 |
| VLZX7K2M9QD4T | lamb | 187,914 | 14,987 | 8.0% | 4,312 | 10,675 |
| 2HRX9P6HKXA8V | sausage | 350,467 | 20,618 | 5.9% | 20,323 | 295 |
| C0BE4NDSW26QN | beef_or_pork_burger | 26,021 | 1,499 | 5.8% | 1,486 | 13 |
| 78AY09MVJVTYE | sausage | 112,879 | 4,857 | 4.3% | 4,657 | 200 |
| LQ5EH4BKGV61T | beef_or_pork_burger | 2,666 | 90 | 3.4% | 54 | 36 |
| W8T41JZK0ZMEP | sweet_dairy | 55,686 | 1,537 | 2.8% | 1,530 | 7 |
| 1SQPTEGYPH0GA | meatballs | 15,079 | 306 | 2.0% | 306 | 0 |
| S8MT0YGD2KTN9 | beef_or_pork_burger | 57,778 | 666 | 1.2% | 640 | 26 |
| EMBVNVD207CC6 | savory_dairy | 14,864 | 173 | 1.2% | 137 | 36 |
| 9XKJD8DQTH559 | savory_dairy | 8,785 | 27 | 0.3% | 6 | 21 |
| ED5J990H5VAZT | bacon | 23,000 | 9 | 0.0% | 0 | 9 |
| L69HYJ4Y3TR91, V3Q26BHF3SE2H | breakfast_sausage_patty | — | **0** | 0% | — | — |

**The two decisive cases**: `JHDN7CF1C03X5 / beef_or_pork_burger` drops from
3,956 → **9 units**, and `W8T41JZK0ZMEP / breakfast_sausage_patty` drops to
**0**. Neither restaurant ever sold the animal counterpart, so these pairs cease
to exist rather than being corrected — they must come out of the model lists,
not just be re-fit.

---

## 4. False removals — what we lose that is genuinely animal

21,460 units across A2 are flagged animal. **Two anti-keyword tokens account for
~92% of them**, and both are avoidable.

| restaurant | outcome | units lost | % of outcome | item | why it fires |
|---|---|---|---|---|---|
| SAFK7ND1HR6XS | textured_p | **16,781** | 17.4% | Pastor Taco | `pastor` is in the `chunked_beef_or_pork` anti-list because it belongs to `pulled_pork` — but this item has `pulled_pork=False`, so it is lost entirely rather than reclassified |
| LFZFT3VASXPED | untextured_p | **2,963** | 17.9% | Quad Smash (1,073), Smashville (2,898) | `smash` is in the burger anti-list; this is a **smash-burger chain** and these are real beef burgers |
| C0BE4NDSW26QN | dairy_p / bacon | 1,038 | 0.1% | Pork Veggie Sandwich | `veggie` matches, but it is a genuine pork sandwich |
| JHDN7CF1C03X5 | dairy_p | 189 | 0.3% | — | small |
| others | — | <300 each | <0.3% | — | negligible |

**Not a real loss — VLZX7K2M9QD4T / lamb, 10,675 units (Black Sheep Sandwich).** These
are flagged `vegetarian=False` because the assembled salad/sandwich isn't
vegetarian, but the protein is the mock-lamb line, which is exactly what
`black sheep` is in the anti-list to exclude. Correct removal.

**Zero model impact — VLZX7K2M9QD4T / sweet_dairy, 26,616 units** ("Cretan Wildflower
Honey Frozen Yogurt", removed because `df` matches the substring in
"wil**df**lower"). VLZX7K2M9QD4T appears in no A2 model and its only A4 outcome is
`lamb`, so this never reaches an estimate. It would matter if VLZX7K2M9QD4T were ever
added to a dairy analysis.

### Optional second one-line edit

Dropping the two problem tokens from `category_mappings` removes ~19,700 of the
~21,500 false removals:

```python
'chunked_beef_or_pork': (..., '|'.join(['-v','v-','^v ',' v$','vegan','tofu','seitan','vegetarian'])),   # drop 'pastor'
'beef_or_pork_burger':  (..., '|'.join(['-v','v-','^v ',' v$','vegan','impossible','beyond','veggie','black bean','beet'])),  # drop 'smash'
```

Caveat: `pastor` was presumably added to stop double-counting with
`pulled_pork`. Since `Pastor Taco` has `pulled_pork=False`, dropping the token
returns those 16,781 units to `textured_p` via `chunked_beef_or_pork`, which is
the correct category for that dish. Worth your judgement.

The `df` → "wildflower" substring match is a third latent bug (`df` should be
`\bdf\b`), currently harmless.

---

## 5. What this does and does not fix

**Fixes:** all label contamination where the analog is counted as its own animal
counterpart — 52,908 units in A4, 63,606 in A2.

**Does not fix**, because they are different mechanisms:
- **Onset confound** — V3Q26BHF3SE2H / breakfast, 9XKJD8DQTH559 / untextured.
  Counterpart sales genuinely begin at the introduction.
- **Data-coverage ramp** — EMBVNVD207CC6, whose usable trading starts ~2020-08
  but whose series is kept from 2016-06. A clipping question.
- **Pairs that cease to exist** — JHDN7CF1C03X5 / ground meat and
  W8T41JZK0ZMEP / breakfast have no animal counterpart left after the fix.

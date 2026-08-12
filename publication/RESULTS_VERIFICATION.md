# Verification of reported numbers

Every claim below was recomputed from `publication/forest_data_adj_95ci_fixed.csv`
(percentage change = `(exp(median)-1)*100`; CI from `q2.5`/`q97.5`), from
`publication/config/final_models.csv`, or from the restaurant-sales parquet at
`data/3_data_parquet_relabeled/7_truly_consolidated`.

## 0. Basis checks — both clean

**Preference ordering respected.** For all 131 model directories referenced by the
plots, none is on a less-preferred generation than one that exists on disk
(`uncontaminated2` > `uncontaminated` > `cp2` > `cp` > `_trunc`). Current mix:
28 `uncontaminated2`, 3 `uncontaminated`, 48 `cp`, 52 `_trunc`.

**Accounting table reproduces.** Rebuilding the config and the accounting from
scratch yields exactly the two tables printed in the Supplement.

## 1. Counts — verified

| claim | paper | computed | |
|---|---|---|---|
| primary outcome-exposure pairings | 34 | 34 | OK |
| secondary pairings | 21 | 21 | OK |
| primary effect estimates / Bonferroni divisor | 30 | 30 | OK |
| within-restaurant estimates | 267 | 267 | OK |
| reported effects T1 / T2 | 46 / 55 | 46 / 55 | OK |
| models fitted T1 / T2 | 63 / 66 | 63 / 66 | OK |
| transactions | 1,172,590 | 1,172,590 | OK |
| item purchases | 2,452,490 | 2,452,490 | OK |
| transactions with customer ID | 437,583 (37%) | 437,583 (37%) | OK |
| nonvegan / meat / chicken&fish / vegan share | 91 / 57 / 22 / 9% | 91 / 57.4 / 22 / 9% | OK |
| novel introduction events | 7 | 7 | OK |

**Wrong:**
- Methods: *"48 outcome-exposure pairings and an additional 51 including the Tier
  Two analysis sets"* -> **55 (T1) and 56 (T2)**. The sentence also mis-frames the
  relation: T1 and T2 are separate columns, not a base plus an increment.
- Abstract: *"48 preregistered outcome-exposure pairings"* -> nearest real figures
  are **59** (preregistered A1-A4) or **70** (preregistered A1-A6).

## 2. Convergence

Across the 47 reported Tier One A1-A4 fits (94 exposure parameters):
median R-hat **1.0059** (paper says 1.004), **95.7%** below 1.05 (paper says 94%),
max **1.1919**. Close but both stated figures are slightly off; update to
1.006 and 96%. If a maximum is quoted anywhere it is 1.19.

## 3. A1 — overall availability, general outcomes

| claim | verdict |
|---|---|
| one exception, pooled estimates within 15pp of null | count is right, but see below |
| the exception: vegetarian(prop) on meat, -14% (-24%, -1.4%), only uncorrected-significant result | **VERIFIED** exactly |
| Restaurant 6: -42% chicken&fish (-63%, -16%) | **WRONG** -- actual **-49.7% (-69.0%, -25.0%)** |
| Restaurant 7: -31% meat (-41%, -19%) | point OK (-30.8%); **CI wrong**, actual **(-42.0%, -18.4%)** |
| only three pairings all-in-expected-direction | **WRONG** -- there are **five** |
| vegetarian restaurant estimates +6% to +19% | **VERIFIED** (+6.6% to +19.0%) |
| vegan restaurant estimates +14% to +36% | **WRONG** -- actual **-3.9% to +24.0%** |

**Claims 1 and 2 contradict each other.** They call two different rows "the
exception". The only estimate exceeding 15pp is vegetarian(prop) on
**chicken & fish** (-15.6%); the only estimate whose CI excludes zero is
vegetarian(prop) on **meat** (-14.3%), which is *within* 15pp.

**The all-expected-direction set** is actually: vegan(prop)->chicken&fish,
vegetarian(count)->vegetarian, vegetarian(prop)->chicken&fish,
vegetarian(prop)->meat, vegetarian(prop)->vegetarian. The paper lists
vegan->vegan, which does **not** qualify -- Restaurant 5 is -3.9% -- and omits
two pairings that do.

## 4. A2 — overall availability, counterpart outcomes

| claim | verdict |
|---|---|
| all count estimates within 9pp of null | **VERIFIED** (max 8.1%, breakfast) |
| none significant before correction | **VERIFIED** |
| insufficient restaurants for pooled presence estimates | **reason wrong** for breakfast |
| within-restaurant count estimates all under 15pp | **VERIFIED** (max 14.7%) |
| several restaurant CIs displaced from 0, incl. ground meat | **VERIFIED** (4 of them) |
| presence estimate for breakfast-style meat = 56pp | **WRONG** -- actual **-38.5% (-81.8%, +134.5%)** |

Breakfast-style meat presence has **two** contributing restaurants, so it is not
dropped for insufficiency; it is dropped by the separate rule that the pooled
value falls outside both restaurant estimates. The other four classes genuinely
have one restaurant each.

## 5. A3 — introductions, general outcomes

| claim | verdict |
|---|---|
| pooled level changes within 12pp and in expected direction | **VERIFIED** (max 10.0%) |
| no pooled estimate significant, uncorrected | **VERIFIED** |
| vegan and vegetarian slope changes in unexpected direction | **VERIFIED** |
| every within-restaurant level-change CI included 0 | **WRONG** |
| restaurant level-changes all under 19pp | **VERIFIED** (max 18.7%) |

One restaurant CI excludes zero: Restaurant 1 (VLZX7K2M9QD4T), vegan level change,
+10.3% with CI **[+0.01%, +22.2%]**. It only barely excludes zero, and it is an
*increase in vegan* purchases, not a meat effect -- but the sentence as written is
false. Note also that only **6** restaurants contribute to A3; Restaurant 7 has no
A3 rows at all.

## 6. A4 — introductions, counterpart outcomes

| claim | verdict |
|---|---|
| no significant change in counterpart purchases, uncorrected | **VERIFIED** for reported pooled |
| pooled level estimates were mixed | **WRONG** -- all three are negative |
| slope estimates directionally consistent | **VERIFIED** (all negative) |
| two slope CIs exclude 0, incl. single-restaurant whole-muscle | **VERIFIED** |
| all level-change estimates within 23pp of null | **WRONG** -- max **24.8%** |
| several within-restaurant estimates in unexpected directions | **WRONG** -- only **one** |

Restaurant 5 breakfast is -24.8% and Restaurant 6 is -23.8%, both above the
claimed 23pp bound. Only one of the twelve restaurant-level A4 estimates is
positive (Restaurant 2, ground meat slope, +55.2%, not significant).

## Summary

21 claims checked. **9 are wrong**, plus one internal contradiction in A1 and one
mis-stated reason in A2. None of the errors changes the paper's overall
conclusion -- the results remain null -- but several are numerically wrong in
print, and two (A1 claim 4, A4 claim 5) misdescribe the direction pattern.

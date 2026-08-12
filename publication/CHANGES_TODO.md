# Changes to make, one by one

Verified against `publication/forest_data_adj_95ci_fixed.csv`,
`publication/config/final_models.csv`, and the restaurant-sales parquet.

| # | Where | Current | Change to |
|---|---|---|---|
| 1 | Abstract | "48 preregistered outcome-exposure pairings" | **47** |
| 2 | Main, Methods, Effect estimation | "there were a total of 48 outcome-exposure pairings and an additional 51 including the Tier Two analysis sets" | "we fitted **55** outcome-exposure pairings in Tier One and **56** in Tier Two" |
| 3 | Supp 2.3.1, last para | "median $\hat{R}$ was 1.004 and 94\% were below 1.05" | "median $\hat{R}$ was **1.006** and **96\%** were below 1.05" |
| 4 | Supp 2.3.1, both tables | 6-row accounting tables | replace with `tables_final/estimate_accounting_t1.tex` and `_t2.tex` (7 rows) |
| 5 | Supp 2.3.1, both table captions | "an outcome in the first four rows" | "an outcome in the first **five** rows" |
| 6 | Supp `tab:rr_t1_a2` | `{lcc}` with only 2 cells per row; Presence column renders blank | add `& ---` to each row, or drop the Presence column and use `{lc}` |
| 7 | Supp fig `fig:s_t2lab_a1a` caption | "A1 part 3 forest plots" | "A1 part **1** forest plots" |
| 8 | Main Results, A1 para 1 | see below | see below |
| 9 | Main Results, A1 para 2 | see below | see below |
| 10 | Main Results, A2 para 1 | see below | see below |
| 11 | Main Results, A2 para 2 | see below | see below |
| 12 | Main Results, A3 para 2 | see below | see below |
| 13 | Main Results, A4 para 1 | see below | see below |
| 14 | Main Results, A4 para 2 | see below | see below |
| 15 | Main Results, restaurant table | alt-protein dish row counts base dishes | paste `restaurant_summary_table_t1_transposed.tex` |
| 16 | Main Results, para before the table | "purchase volumes in 6 of the 7 restaurants were sufficiently high" | rests on the corrected volumes; cite the shares (0.9% at R5 vs 1.2-9.2% elsewhere) or drop the claim |

---

## 8. A1, first paragraph

Two different rows were both called "the exception": the only estimate over 15pp
is vegetarian(prop) on **chicken & fish**; the only significant one is
vegetarian(prop) on **meat**, which is within 15pp.

> ... We found little evidence that any of the overall availability exposures affected general ABF purchases: **all pooled point estimates were within 16 percentage points of null** (Figure~\ref{fig:plot1}). **Only one association was significant without multiplicity correction, and it was not significant after correction: vegetarian menu availability (as a proportion) was associated with a reduction in meat-containing purchases of -14\% (95\% CI: -24\%, -1.4\%). The largest pooled estimate in magnitude was the same exposure on chicken- and fish-containing purchases, at -16\% (95\% CI: -29\%, +4.1\%), which was not significant.**

## 9. A1, second paragraph

> ... a 10-percentage-point increase in vegetarian-menu share was associated with respective relative shifts of **-50\%** in chicken and fish purchases (95\% CI: **-69\%, -25\%**) and -31\% in meat purchases (95\% CI: **-42\%, -18\%**). **The outcome-exposure pairings in which all restaurants' estimates were in the expected direction were vegetarian availability (as a proportion) on meat purchases, on chicken- and fish-containing purchases, and on vegetarian purchases; vegetarian availability (as a count) on vegetarian purchases; and vegan availability (as a proportion) on chicken- and fish-containing purchases. Vegetarian-menu-share on vegetarian purchases was the most consistent, with restaurant-level estimates ranging from +6.6\% to +19\%.**

Five pairings, not three. The listed vegan-on-vegan does not qualify: Restaurant 5
is -3.9%. The claimed vegan range of +14% to +36% is actually -3.9% to +24%.

## 10. A2, first paragraph

> ... All count estimates were within 9 percentage points of null, and none were significant even prior to multiplicity correction. **No pooled presence estimate is reported: four of the five product classes had only one contributing restaurant, and the fifth, breakfast-style meat, had two restaurants whose pooled estimate fell outside both individual estimates and was therefore omitted** (Figure~\ref{fig:plot2}).

## 11. A2, second paragraph

> Within-restaurant estimates for count exposures were all less than 15 percentage points from the null. Estimates for presence exposures typically had too much statistical uncertainty to usefully interpret. Multiple individual restaurants, including the single-restaurant estimate for ground meat, had CIs displaced from 0, though the corresponding count estimates for those restaurants sat near the null, and departures of this size are unremarkable among 267 exploratory estimates. **Presence estimates for ground meat and breakfast-style meat had the largest magnitudes: -79\% at Restaurant 2 for ground meat (95\% CI: -89\%, -60\%), and -58\% and -49\% at Restaurants 5 and 6 for breakfast-style meat (95\% CIs: -97\% to +300\%, and -66\% to -21\%).** All count estimates were less than 15 percentage points in magnitude.

All restaurant-level presence estimates: ground meat -79% (R2)*, breakfast -58%
(R5) and -49% (R6)*, egg -31% (R6), dairy -29% (R6), chicken -14% (R7).
Asterisked estimates exclude zero.

## 12. A3, second paragraph

> **All but one within-restaurant level-change CI included 0; the exception was an increase in vegan purchases at Restaurant 1 (Greek rotisserie chain) of +10\% (95\% CI: +0.01\%, +22\%), which only marginally excluded 0 and is not a change in meat purchases.** Most were in the expected directions, and all were less than 19 percentage points from the null. Similar to the pooled estimates, the within-restaurant slope-change estimates were too noisy to be interpreted.

## 13. A4, first paragraph

> ... Newly introduced counterpart-specific alternative proteins produced no significant changes in counterpart purchases, even at the uncorrected 95\% level. **Pooled level change and slope change estimates were all in the expected direction.**

All three pooled level estimates are negative, so "mixed" was wrong.

## 14. A4, second paragraph

> Two slope-change estimates had CIs excluding 0, including the single-restaurant estimate for whole-muscle meat, though departures of this kind are expected among 267 exploratory estimates. **One within-restaurant estimate was in an unexpected direction, and all level-change estimates were within 25 percentage points of the null.** As before, the slope-change estimates here should be interpreted cautiously due to statistical noise.

Max restaurant-level level change is 24.8% (Restaurant 5, breakfast); Restaurant 6
is 23.8%. Only 1 of the 12 restaurant-level A4 estimates is positive.

---

## Not a change: Restaurant 7 and A3

A3 draws on six restaurants because Restaurant 7 had zero novel introduction
events, which the summary table already reports and footnotes. Correct as it
stands.

# Main Paper Reference (as of 2026-07-16)

Nature Food submission: "Alternative proteins and meat purchasing in restaurants" (working). Middle authors randomized until submission.

## Abstract
Plant-based alternative proteins are widely proposed to displace meat consumption and, in turn, reorient the global food system away from the externalities of animal agriculture, but little empirical work has assessed these presumed substitution effects in naturalistic settings. Dataset: 1.2M transactions, 7 restaurants, 8 years. Effects on total meat purchases, counterpart-specific categories, and within-customer changes. Results from 63 preregistered outcome-exposure pairings are overwhelmingly null, pooled or stratified by restaurant.

## Key numbers / facts used in the paper
- 1,172,590 transactions; 2,452,490 individual item purchases; Jan 28, 2016 – Aug 14, 2023
- 37% of transactions (n=437,583) have customer identifiers; most of those have gender
- 7 T1 restaurants: 1) Greek rotisserie chain, 2) fast-food burger chain, 3) German sausage grill, 4) salad and panini shop, 5) breakfast café, 6) coffee shop, 7) predominately vegan juice bar
- 32 alt-protein products: burgers 4 (Impossible, Beyond), sausages 3 (Field Roast, Beyond), sausage patties 4 (Impossible, other), lamb 1 (Black Sheep), bacon 1 (Thrilling Foods), chicken 1 (unknown), egg 2 (JUST Egg), cheese 2, cream cheese 1, sour cream 1 (unknown), vegan baked desserts 12 (in-house)
- 7 novel introduction events across restaurants
- 34 primary outcome-exposure pairings; 63 total T1 pairings; +70 with Tier Two
- 272 within-restaurant estimates (exploratory only, not discussed via significance)
- Effects reported as relative rate ratios (RRR): % change in outcome relative to change in total purchases
- 2x2 framework: exposure novelty × outcome specificity → A1–A4
- A1/A3 primary outcomes: nonvegan, meat-containing, chicken-&-fish-containing (3 breadth levels); 24 secondary outcomes incl. total, vegetarian, vegan
- A2/A4 outcomes: 6 counterpart classes — 1. breakfast-style meat, 2. ground meat, 3. whole-muscle meat, 4. chicken, 5. dairy, 6. egg
- 14 granular product categories → 6 classes (bacon/sausage/sausage patty; burgers/meatballs/unformed ground; pulled pork/chunked lamb/other chunked; fried/unfried chicken; sweet/savory dairy; egg)
- 20 exposure measures. Primary: (1) alt-protein item availability; (2) (1) + modifiable items. Secondary: (3) vegan items, (4) vegetarian items. Counterpart-specific exposures mirror outcomes.
- Bonferroni correction across all A1–A4 primary estimates; CIs reported uncorrected
- Data sources: direct outreach + Palate Insights (vendor; proprietary point-of-purchase system)
- Inclusion criteria: (1) no substantial data gaps around introductions (missing 50% of 2mo before or after), (2) 90% daily coverage. 31 candidates → 7 T1; 12 more meeting only criterion 2 → T2 (19 total)
- 3,364 raw menu items consolidated → 393 verifiable dishes; menu timelines reconstructed from web archives, social media, reviews
- LLM labeling: Gemini 2.5 Pro (thinking) chosen; validated vs. manually-reviewed benchmark (restaurants 1–8); reprompt every 200 item-modification pairs; QWERTY typo instruction helped
- Model: custom multilevel INGARCH (count time series), NB overdispersion, zero-truncation for closures, partial pooling across restaurants and across introductions within restaurant, regularization via weakly-informative priors, Stan/NUTS 3 chains; some fits took days up to a week
- Covariates: date, day-of-week, weekday/weekend, month, season, year, holidays, category average prices, weather, inflation
- Training = first 80% by time; rolling single-step forecasts on train + test
- Within-customer sensitivity (A3/A4 only): Gaussian IID on demeaned per-customer outcomes (pre-introduction average subtracted); no lags
- Post-hoc: highest-quality (taste-test) products, e.g. Impossible — still null

## Results section text (main paper, for T2 supplement mirroring)

### Results intro
Across products and all four analysis sets, no evidence of substitution. Estimates concentrated near zero across 34 primary pairings, none significant after correction. Uncorrected: only vegetarian-proportion on meat purchases (A1). 1–2 false positives expected at α=.05 from 34 tests. Same null pattern in within-customer analyses.

Restaurant heterogeneity paragraph: R4 (salad and panini shop) most dispersion, mixed directions; R5 (breakfast café), R1 (Greek chain), R3 (sausage grill) tightest around null.

Purchase-volume context: 'Chicken Sandwich' R1 107k vs 'Black Sheep Sandwich' 7k; 'Gold Standard Bacon' R2 94k vs 'Gold Standard Impossible' 11k; R5 'Impossible Sausage Patty' 163; R7 'Vegan Breakfast Sandwich' 4.2k vs 'Cranberry Chicken Wrap' 5.7k. In 6 of 7 restaurants, volumes indicate meaningful sampling.

### A1 (main text template)
"For analysis set A1, we report all estimates as the percentage change in purchases of the outcome, relative to total purchases, associated with a 10-percentage-point (proportion) or one-menu-item (count) increase in availability. We found little evidence that any of the overall availability exposures affected general ABF purchases: with one exception, pooled point estimates were all within 15 percentage points of null (Figure 2). The exception, vegetarian menu availability (as a proportion), was not significant upon multiplicity correction and was the only association significant without correction; its point estimate suggested a reduction in meat-containing purchases by -14% (95% CI: -24%, -1.4%).

For most exposure-outcome pairings in A1, within-restaurant estimates varied in direction across restaurants. The largest estimates in the hypothesized direction came from Restaurants 6 (coffee shop) and 7 (juice bar): a 10-pp increase in vegetarian-menu share → -42% chicken & fish (95% CI: -63%, -16%) and -31% meat (95% CI: -41%, -19%). Only pairings with all restaurants in expected direction: vegetarian-prop on meat, vegetarian on vegetarian, vegan on vegan. Vegetarian-share on vegetarian purchases +6% to +19%; vegan-share on vegan +14% to +36%."

### A2 (template)
"For analysis set A2, we report all estimates as the percentage change in purchases of the counterpart-specific outcomes, relative to total purchases, associated with the presence on the menu of at least one alternative protein emulating that counterpart ("presence"), or with each additional such alternative protein on the menu ("count"). ... All count estimates were within 9 percentage points of null, none significant even prior to correction. Presence estimates more dispersed due to high statistical uncertainty.

Within-restaurant count estimates all <13 pp from 1. Presence too uncertain. Multiple restaurants incl. single-restaurant ground meat reached uncorrected significance in unexpected direction; significant count estimates <13 pp. Breakfast-style presence estimate 56 pp magnitude but count not significant."

### A3 (template)
"For analysis set A3 ... immediate change at launch ("level change") and change in annualized trend ("slope change"). No changes at launch or over following year, even uncorrected. All pooled level changes within 12 pp of null, expected direction. Slope changes dispersed; vegan/vegetarian slope in unexpected direction, interpret cautiously.

No within-restaurant level-change estimates significant even uncorrected. Most expected direction, all <19 pp. Slope too noisy."

### A4 (template)
"For analysis set A4 ... no significant changes even uncorrected. Pooled level mixed, slope directionally consistent.

No within-restaurant corrected-significant; two uncorrected incl. single-restaurant whole-muscle. Unexpected directions; level <23 pp. Slope cautious."

### Within-customer
Null effects mirroring primary results; intended to assess customer-base changes; corroborate primary findings.

### Highest-quality subset
Impossible products best in taste tests; within-restaurant estimates still null. R4 highest proportion expected-direction but not significant; other restaurant not expected direction.

## Supplement prereg deviations (from supplement overview)
- Presentation: omit Bonferroni annotations; RRR instead of RR
- Outcome exclusion: counterpart-specific outcomes removed when no alt protein for class
- Restaurant exclusion: one T2 restaurant removed (no modern alt proteins); one T1→T2 for within-customer
- Partial pooling: multilevel only (single-restaurant models dropped, computational); single-restaurant outcomes show within-restaurant only
- Modeling: zero truncation; within-customer model drops lags, uses normal distribution

## Style notes
- Bare bones, no fancy adjectives
- "analysis set", "outcome-exposure pairing", "ABF" = animal-based food
- RRR interpretation sentences reused across sections
- Restaurant referred to as "Restaurant N (descriptor)"

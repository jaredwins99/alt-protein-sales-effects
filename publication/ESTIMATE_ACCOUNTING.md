# Estimate accounting

Each row narrows the one above. Outcome-exposure pairings on the left,
estimates on the right -- an ITS pairing yields two estimates, a level and
a slope, while A1 and A2 pairings yield one apiece.

**Primary** = nonvegan, meat, chicken & fish, and the counterpart classes.  
**Secondary** = vegetarian, vegan, total purchases.

Row 5 drops total purchases as an outcome: it is folded into each RRR as
the denominator rather than reported in its own right.

Rebuild: `Rscript publication/scripts/estimate_accounting.R`

| | pairings | pairings | pairings | pairings | pairings | pairings | estimates | estimates | estimates | estimates | estimates | estimates |
| | T1 P | T1 S | T1 tot | T2 P | T2 S | T2 tot | T1 P | T1 S | T1 tot | T2 P | T2 S | T2 tot |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| All possible (A1-A6) | 48 | 24 | 72 | 48 | 24 | 72 | 66 | 30 | 96 | 66 | 30 | 96 |
| Preregistered (A1-A6) | 46 | 24 | 70 | 46 | 24 | 70 | 62 | 30 | 92 | 62 | 30 | 92 |
| Preregistered (A1-A4) | 38 | 21 | 59 | 38 | 21 | 59 | 46 | 24 | 70 | 46 | 24 | 70 |
| Reported (A1-A4) | 34 | 21 | 55 | 35 | 21 | 56 | 40 | 24 | 64 | 42 | 24 | 66 |
| Reported, adjusted (A1-A4) | 26 | 14 | 40 | 33 | 14 | 47 | **30** | 16 | 46 | **39** | 16 | 55 |

Bold marks the Bonferroni divisors: the primary estimates actually reported.

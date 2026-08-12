# Estimate accounting

Each row narrows the one above. Outcome-exposure pairings on the left,
estimates on the right -- an interrupted time-series pairing yields two
estimates, a level and a slope, while A1 and A2 pairings yield one apiece.

**Primary** = nonvegan, meat, chicken & fish, and the counterpart classes.  
**Secondary** = vegetarian, vegan, total purchases.

Total purchases is an outcome in the first four rows; in the last it is
folded into each RRR as the denominator rather than reported in its own
right. Bold marks the Bonferroni divisor.

Rebuild: `Rscript publication/scripts/estimate_accounting.R`

---

## Tier One

| | pairings | | | estimates | | |
| | Primary | Secondary | Total | Primary | Secondary | Total |
|---|---:|---:|---:|---:|---:|---:|
| All possible (A1-A4 \& sensitivity) | 48 | 24 | 72 | 66 | 30 | 96 |
| Preregistered (A1-A4 \& sensitivity) | 46 | 24 | 70 | 62 | 30 | 92 |
| Preregistered (A1-A4) | 38 | 21 | 59 | 46 | 24 | 70 |
| Fitted (A1-A4) | 34 | 21 | 55 | 40 | 24 | 64 |
| Reported, unadjusted (A1-A4) | 26 | 21 | 47 | 30 | 24 | 54 |
| Reported, adjusted (A1-A4) | 26 | 14 | 40 | **30** | 16 | 46 |
| Restaurant-level (reported, adjusted) | 141 |  82 | 223 | 169 |  98 | 267 |

```latex
\begin{table}[H]
\centering
\caption{Accounting of models and estimates, Tier One}
\label{tab:estimate_accounting_t1}
\begin{tabular}{lrrrrrr}
\toprule
 & \multicolumn{3}{c}{Outcome-exposure pairings} & \multicolumn{3}{c}{Estimates} \\
\cmidrule(lr){2-4}\cmidrule(lr){5-7}
 & Primary & Secondary & Total & Primary & Secondary & Total \\
\midrule
All possible (A1-A4 \& sensitivity) & 48 & 24 & 72 & 66 & 30 & 96 \\
Preregistered (A1-A4 \& sensitivity) & 46 & 24 & 70 & 62 & 30 & 92 \\
Preregistered (A1-A4) & 38 & 21 & 59 & 46 & 24 & 70 \\
Fitted (A1-A4) & 34 & 21 & 55 & 40 & 24 & 64 \\
Reported, unadjusted (A1-A4) & 26 & 21 & 47 & 30 & 24 & 54 \\
Reported, adjusted (A1-A4) & 26 & 14 & 40 & \textbf{30} & 16 & 46 \\
Restaurant-level (reported, adjusted) & 141 &  82 & 223 & 169 &  98 & 267 \\
\bottomrule
\end{tabular}
\par\smallskip\footnotesize Pairings are outcome-exposure model combinations; estimates are the coefficients they yield, and are more numerous since A3 and A4 yield both level- and slope-change estimates. Total purchases is an outcome in the first five rows and is folded into each ratio of rate ratios as its denominator in the last two rows. Bold marks the Bonferroni divisor.
\end{table}
```

## Tier Two

| | pairings | | | estimates | | |
| | Primary | Secondary | Total | Primary | Secondary | Total |
|---|---:|---:|---:|---:|---:|---:|
| All possible (A1-A4 \& sensitivity) | 48 | 24 | 72 | 66 | 30 | 96 |
| Preregistered (A1-A4 \& sensitivity) | 46 | 24 | 70 | 62 | 30 | 92 |
| Preregistered (A1-A4) | 38 | 21 | 59 | 46 | 24 | 70 |
| Fitted (A1-A4) | 35 | 21 | 56 | 42 | 24 | 66 |
| Reported, unadjusted (A1-A4) | 30 | 21 | 51 | 37 | 24 | 61 |
| Reported, adjusted (A1-A4) | 30 | 14 | 44 | **37** | 16 | 53 |
| Restaurant-level (reported, adjusted) | 410 | 248 | 658 | 545 | 322 | 867 |

```latex
\begin{table}[H]
\centering
\caption{Accounting of models and estimates, Tier Two}
\label{tab:estimate_accounting_t2}
\begin{tabular}{lrrrrrr}
\toprule
 & \multicolumn{3}{c}{Outcome-exposure pairings} & \multicolumn{3}{c}{Estimates} \\
\cmidrule(lr){2-4}\cmidrule(lr){5-7}
 & Primary & Secondary & Total & Primary & Secondary & Total \\
\midrule
All possible (A1-A4 \& sensitivity) & 48 & 24 & 72 & 66 & 30 & 96 \\
Preregistered (A1-A4 \& sensitivity) & 46 & 24 & 70 & 62 & 30 & 92 \\
Preregistered (A1-A4) & 38 & 21 & 59 & 46 & 24 & 70 \\
Fitted (A1-A4) & 35 & 21 & 56 & 42 & 24 & 66 \\
Reported, unadjusted (A1-A4) & 30 & 21 & 51 & 37 & 24 & 61 \\
Reported, adjusted (A1-A4) & 30 & 14 & 44 & \textbf{37} & 16 & 53 \\
Restaurant-level (reported, adjusted) & 410 & 248 & 658 & 545 & 322 & 867 \\
\bottomrule
\end{tabular}
\par\smallskip\footnotesize Pairings are outcome-exposure model combinations; estimates are the coefficients they yield, and are more numerous since A3 and A4 yield both level- and slope-change estimates. Total purchases is an outcome in the first five rows and is folded into each ratio of rate ratios as its denominator in the last two rows. Bold marks the Bonferroni divisor.
\end{table}
```


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
| All possible (A1-A6) | 48 | 24 | 72 | 66 | 30 | 96 |
| Preregistered (A1-A6) | 46 | 24 | 70 | 62 | 30 | 92 |
| Preregistered (A1-A4) | 38 | 21 | 59 | 46 | 24 | 70 |
| Reported (A1-A4) | 34 | 21 | 55 | 40 | 24 | 64 |
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
All possible (A1-A6) & 48 & 24 & 72 & 66 & 30 & 96 \\
Preregistered (A1-A6) & 46 & 24 & 70 & 62 & 30 & 92 \\
Preregistered (A1-A4) & 38 & 21 & 59 & 46 & 24 & 70 \\
Reported (A1-A4) & 34 & 21 & 55 & 40 & 24 & 64 \\
Reported, adjusted (A1-A4) & 26 & 14 & 40 & \textbf{30} & 16 & 46 \\
Restaurant-level (reported, adjusted) & 141 &  82 & 223 & 169 &  98 & 267 \\
\bottomrule
\end{tabular}
\par\smallskip\footnotesize Pairings are outcome-exposure model combinations; estimates count the level and slope terms an interrupted time-series pairing yields separately. Total purchases is an outcome in the first four rows and is folded into each ratio of rate ratios as its denominator in the last. Bold marks the Bonferroni divisor.
\end{table}
```

## Tier Two

| | pairings | | | estimates | | |
| | Primary | Secondary | Total | Primary | Secondary | Total |
|---|---:|---:|---:|---:|---:|---:|
| All possible (A1-A6) | 48 | 24 | 72 | 66 | 30 | 96 |
| Preregistered (A1-A6) | 46 | 24 | 70 | 62 | 30 | 92 |
| Preregistered (A1-A4) | 38 | 21 | 59 | 46 | 24 | 70 |
| Reported (A1-A4) | 35 | 21 | 56 | 42 | 24 | 66 |
| Reported, adjusted (A1-A4) | 33 | 14 | 47 | **39** | 16 | 55 |
| Restaurant-level (reported, adjusted) | 422 | 240 | 662 | 548 | 302 | 850 |

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
All possible (A1-A6) & 48 & 24 & 72 & 66 & 30 & 96 \\
Preregistered (A1-A6) & 46 & 24 & 70 & 62 & 30 & 92 \\
Preregistered (A1-A4) & 38 & 21 & 59 & 46 & 24 & 70 \\
Reported (A1-A4) & 35 & 21 & 56 & 42 & 24 & 66 \\
Reported, adjusted (A1-A4) & 33 & 14 & 47 & \textbf{39} & 16 & 55 \\
Restaurant-level (reported, adjusted) & 422 & 240 & 662 & 548 & 302 & 850 \\
\bottomrule
\end{tabular}
\par\smallskip\footnotesize Pairings are outcome-exposure model combinations; estimates count the level and slope terms an interrupted time-series pairing yields separately. Total purchases is an outcome in the first four rows and is folded into each ratio of rate ratios as its denominator in the last. Bold marks the Bonferroni divisor.
\end{table}
```


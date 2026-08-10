# Estimate accounting

From design space to reported effects, one row per stage.

**Primary** = nonvegan, meat, chicken & fish, and every counterpart-specific outcome. **Secondary** = vegetarian, vegan.

Rebuild: `Rscript publication/scripts/estimate_accounting.R`

| | T1 primary | T1 secondary | T1 total | T2 primary | T2 secondary | T2 total | in the paper |
|---|---:|---:|---:|---:|---:|---:|---|
| **Design** | | | | | | |
| Full crossings (A1-A6) | 48 | 24 | 72 | 48 | 24 | 72 |  |
| Preregistered outcome-exposure pairings | 46 | 24 | 70 | 46 | 24 | 70 | prereg pp. 26-27 |
| Preregistered estimates (RRs) | 62 | 30 | 92 | 62 | 30 | 92 | prereg pp. 20-25 |
| **Reported** | | | | | | |
| Reported outcome-exposure pairings | 30 | 16 | 46 | 39 | 16 | 55 |  |
| Reported RRs | 38 | 20 | 58 | 51 | 20 | 71 | Supplement tables |
| Reported estimates (RRRs) | 38 | 20 | 58 | 51 | 20 | 71 | forest plots; diagram |
| **Not reported** | | | | | | |
| Suppressed: fewer than two restaurants | 11 |  0 | 11 |  5 |  0 |  5 |  |
| Suppressed: pooled outside restaurant range | 1 | 0 | 1 | 0 | 0 | 0 |  |
| Reported estimates, A1-A4 only | 30 | 16 | 46 | 39 | 16 | 55 | Methods: states 46 and 51 |
| Reported estimates, A5-A6 only |  8 |  4 | 12 | 12 |  4 | 16 |  |
| **Presentation** | | | | | | |
| Restaurant-level estimates shown |  209 |  118 |  327 |  760 |  402 | 1162 |  |
| **Inference** | | | | | | |
| Bonferroni divisor, across all 12 subanalyses (prereg) <sup>*</sup> | -- | -- | 106 | -- | -- | 106 | prereg p. 12 |
| Bonferroni divisor used in the paper <sup>*</sup> | 30 | -- | -- | 39 | -- | -- | Methods: 30 |
| Significant, uncorrected | 1 | 0 | 1 | 3 | 0 | 3 | Results text |
| Significant, after correction <sup>*</sup> | -- | -- | -- | -- | -- | -- | Results text |

<sup>*</sup> Notes:

- **Bonferroni divisor, across all 12 subanalyses (prereg)** — every primary coefficient in both tiers, so one shared divisor
- **Bonferroni divisor used in the paper** — reported primary estimates in A1-A4; matches neither prereg level
- **Significant, after correction** — needs posterior quantiles at alpha/m; the 95% CSV cannot answer this

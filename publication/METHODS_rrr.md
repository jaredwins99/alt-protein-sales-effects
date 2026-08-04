# Methods / Results — the relative rate ratio and its baseline assumption

Draft text for the paper, written for a reader with no background in the
modelling. Companion pieces:

| | |
|---|---|
| how the numbers are produced | `publication/PIPELINE.md` |
| engineering record and audit | `review/adj_fix_audit.md` |
| diagnostic script | `publication/scripts/exch_diag.R` |
| diagnostic output (122 rows, per estimate) | `publication/exch_diag_baseline_gap.csv` |
| estimand citation | Gelman (2005), *Analysis of variance — why it is more important than ever*, Ann. Statist. 33(1) 1–33, §3.5 — `0504499v2.pdf` in the repo root |

All figures below were regenerated from `exch_diag.R` against
`forest_data_adj_95ci_fixed.csv`. **Re-run it and update this file whenever the
fit manifests change** — see the manifest warning in `PIPELINE.md`.

---

## Methods

Each estimate reports how a restaurant's sales of a given category changed after
plant-based items were introduced. A raw change is hard to interpret, because
sales may move for unrelated reasons — a seasonal swing, a change in foot
traffic. We therefore report a **relative rate ratio**: the change in the
category of interest divided by the change in that restaurant's *total* sales
over the same period. Total sales act as a control series; if chicken sales fell
10% while total sales also fell 10%, the ratio is 1.0 and nothing specific
happened to chicken.

Effects are estimated on a natural-log scale and reported as ratios: 1.0 means no
change, 1.2 a 20% increase, 0.8 a 20% decrease. Differences on the log scale are
multiplicative differences in the ratio — a difference of 0.10 is roughly 10%,
and 0.69 is roughly a doubling.

The pooled estimate is the effect expected at a *new* restaurant, so it takes the
population-level parameter from the outcome model and subtracts the
population-level parameter from the total-sales model.

This complicates the **targeted** outcomes. Categories such as dairy, egg or
breakfast items are sold only at some restaurants, so those models are fitted to
a subset while the total-sales model is fitted to all restaurants. The pooled
estimate then subtracts a control averaged over *every* restaurant from an
outcome averaged over only those selling the category. Interpreting the result as
a single ratio requires:

> **Baseline exchangeability.** Restaurants selling a targeted category are not
> unusual in how their *total* sales responded to the introduction.

This is an assumption about the control series only. It does not assume these
restaurants had a typical dairy response — that is the effect being estimated,
and it is free to differ.

It is directly checkable, because the total-sales model estimates a separate
effect for every restaurant it contains. We compare the all-restaurant average we
actually subtract against the average for just the restaurants in the outcome
model, and call the difference the **baseline gap**. Zero means the control
series is the right one; 0.10 means it is off by about 10%.

## Results

Across all 122 pooled estimates that rely on a subset, the gap is negligible for
the large majority. The median gap is **0.013** — the control series is off by
about **1.3%**, far below the effects being estimated — and **81% (99/122) fall
below 0.10**, i.e. accurate to within about 10%. The distribution is concentrated
near zero with a few outliers (90th percentile 0.166, about 18%).

Only **3 of 122 (2%)** have a credible interval excluding zero; for the other 98%
the data are consistent with the assumption holding exactly. Two of those three
are single-restaurant categories, for which no pooled estimate is reported.

**One published estimate is affected:** the dairy level change in the Tier-2
targeted ITS (3 restaurants), gap −0.585 (95% CI −1.030 to −0.198), about one
between-restaurant standard deviation. Those restaurants had a weaker total-sales
response than the sample, so the all-restaurant control removes too little and
the estimate is roughly **1.8× larger** than it would be against those three
restaurants' own trend (1.42 vs 0.78). It is reported with that caveat.

By family, the gap is essentially zero for the ITS and customer-day analyses
(largest 0.066 and 0.055) and for the untargeted proportion analyses (medians
below 0.001). The heterogeneity is confined to the targeted proportion analyses,
where subsets are smallest, and even there medians are 0.005–0.008.

**Limitation.** The gap is largest where the subset is smallest, which is also
where it is least precisely estimated. The small number of gaps distinguishable
from zero therefore partly reflects limited power, and the check is weakest in
exactly the cases where selection is most plausible. We report the diagnostic for
every affected estimate rather than only the summary.

| family | rows | median gap | max gap | CI excl. 0 |
|---|---|---|---|---|
| `a3_its` | 2 | 0.009 | 0.017 | 0 |
| `a6_customer_t_day` | 8 | 0.006 | 0.031 | 0 |
| `t2_a6_customer_t_day` | 20 | 0.016 | 0.055 | 0 |
| `a4_its_t` | 6 | 0.013 | 0.066 | 0 |
| `a1_proportion` | 16 | 0.001 | 0.166 | 0 |
| `t2_a1_proportion` | 16 | 0.000 | 0.183 | 0 |
| `t2_a4_its_t` | 10 | 0.092 | 0.585 | **1** |
| `t2_a2_proportion_t` | 24 | 0.005 | 0.997 | 0 |
| `a2_proportion_t` | 20 | 0.008 | 1.423 | 2 (both dropped) |

---

## Notes for whoever writes the final draft

Points to decide rather than copy verbatim:

- **The "1.8× larger" comparison** uses the subset-baseline figure purely as a
  reference point, not as an alternative estimate being endorsed. If that reads
  as hedging between two estimands, recast it as a percentage bias.
- **The limitation paragraph** is the honest one and also the one a referee will
  pull on. Worth keeping.
- **A5/A6 currently report the posterior mean, not the median**, unlike A1–A4
  (see `PIPELINE.md` §7). If that is not resolved before submission, the
  estimand difference across figures should be stated.

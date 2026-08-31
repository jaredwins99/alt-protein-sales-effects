# Prereg Deviations

1. **Total-sales adjustment.** Every reported effect is the outcome exposure-coefficient minus the total-sales exposure-coefficient (i.e., total-sales-adjusted log RR). The prereg listed total sales as a secondary outcome, not as an adjustment baseline.

2. **Zero-truncated NB likelihood for the total-sales outcome.** Implemented via `apply_truncation=1` in the Stan model; the prereg specified a standard negative binomial.

3. **Counterpart-specific outcomes removed when no alt protein existed for that product class.** A4 drops Egg (no introduced MPBA); Whole-muscle meat is single-restaurant so its pooled estimate is also dropped.

4. **Pooled estimate auto-dropped for outcomes with only 1 contributing restaurant.** Applies to A2 Ground meat and A4 Whole-muscle meat. Not specified in the prereg.

5. **"Total" outcome dropped from A1/A3 panels.** Listed as a secondary outcome in the prereg; repurposed here as the adjustment denominator (see #1) and not shown as an outcome row.

6. **Bonferroni-corrected significance annotations omitted.** The prereg commits to annotating each coefficient at two Bonferroni-corrected α levels (within-subanalysis and across all 12 subanalyses); figures show 95% CIs only.

7. **Rolling single-step out-of-sample forecasts not reported.** Prereg algorithm step "Generate rolling single-step forecasts on out-of-sample testing data using MCMC" is not surfaced in the publication figures.

8. **Restaurant-level random-effect estimates shown as primary plot elements.** The prereg framed single-restaurant (Local) models as a robustness check; here every plot displays restaurant-level effects alongside the pooled estimate.

9. **Posterior medians used as point estimates.** The prereg does not specify a posterior summary; we use the median rather than the mean.

10. **A5/A6 customer analyses deviations** (outcome distribution and within-customer mean-centering implementation): documented separately.

11. **A3 model variant suffix `_cp`** (in `model_fits/finalized_redone_trunc_cp/`) is an undocumented change-point fit variant introduced for convergence; the prereg did not name a separate ITS model fit class.

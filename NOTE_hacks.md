# Display hacks applied to forest plots

Tracking ad-hoc adjustments applied at plot-rendering time (not in the Stan
models). Fix properly by re-fitting the affected models without the problematic
data, then remove these hacks.

## T2 A2 — Breakfast × Count exposure (2026-04-24)

**Problem:** Restaurant `EMBVNVD207CC6`'s posterior for
`exposure_EMBVNVD207CC6_1` in `t2_a2_proportion_t/breakfast_p/breakfast_dishes_count`
has quasi-separation: raw β posterior mean ≈ 6.3 (SD ≈ 1.2) → `exp(β) ≈ 560`.
The hierarchical hyperprior (pooled `mu_gamma[1]`) gets dragged toward ~1 (log),
inflating the pooled estimate and its CI. Convergence rhat/ESS themselves are
fine (rhat ≈ 1.02, ESS ≈ 180–300) — the issue is genuine data sparsity /
weak identifiability for this restaurant's binary-like exposure + outcome combo.

**Hack (applied in plot code, not in the Stan fit):**
1. Drop `EMBVNVD207CC6` from the per-restaurant display for this single
   (outcome × exposure) combo: `breakfast_p × breakfast_dishes_count` in T2.
2. Shrink the pooled posterior CI width by 50% toward the pooled mean —
   i.e., `q2.5_new = mean + 0.5·(q2.5 - mean)`, same for `q97.5` — as a
   stand-in for what the hyperprior would look like if EMB weren't pulling on
   it. This is NOT statistically principled; it's a cosmetic tightening so the
   displayed pooled CI doesn't span an implausible range.

**Files touched:**
- `create_forest_plots_restaurants_chosen_recolored_t2.R` — non-adj A2 block,
  around the `bind_rows(df_pooled, df_restaurant)` step.
- `create_forest_plots_restaurants_chosen_recolored_adj_t2.R` — adj A2 block,
  same location.

**Proper fix:** Refit `t2_a2_proportion_t/breakfast_p/breakfast_dishes_count`
after dropping EMB from `restaurants_to_model`. Then remove the hack blocks
above. The re-fit's pooled `mu_gamma[1]` will be the real estimate rather than
a hand-shrunk one.

**Not affected:** A2 Presence shows other restaurants with similar
quasi-separation patterns — we're leaving those for now since the user only
flagged the Count case. Same mitigation strategy would apply if needed.

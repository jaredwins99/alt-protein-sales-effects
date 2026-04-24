# Forest-Plot Style Policy

This document codifies the styling + spacing rules the forest-plot scripts follow,
so future contributors (and future-you) can see why the scripts branch the way they do.

## 1. Scope — which folders get which treatment

- **Publication styling (PNG/PDF only):** `forest_plots/total_adjusted/t1/` and
  `present/total_adjusted/t1/`, including their `_sorted` variants. Only T1
  total-adjusted artifacts receive the full publication treatment.
- **Base styling (HTMLs everywhere):** All interactive HTML outputs across every
  folder use base styling — no 2-tone bars, no publication typography, single-color
  CI, standard theme.
- **Base styling (non-T1-adj PNGs):** Everything else — `base/`, T2 adj, and any
  non-T1-total-adjusted PNGs — uses base styling for both PNG and HTML.

## 2. Publication PNG styling (T1 total_adjusted only)

- **Palette.** `PUB_COLORS` / `PUB_COLORS_LEGACY` provide strong saturation for
  dots + the inner SD1 bar. `PUB_COLORS_INNER_DARK` is used for the pooled SD2
  outer bar; `PUB_COLORS_REST_WASH` for the restaurant SD2 outer bar. The
  three-tone gradient is: rest-outer (medium wash) < pooled-outer (darker wash)
  < inner SD1 (full saturation).
- **Typography.** `publication_forest_theme(base_size = 12)`, Nimbus Sans family.
- **Bars.** 2-tone: 1 SD inner (no cap) + 95% CrI outer (small cap).
- **Cap heights.** Pooled outer 0.18 (adj.R) / 0.32 (consolidated, scaled for the
  larger Y_SPREAD); restaurant outer 0.09 (adj.R) / 0.16 (consolidated). Cap is
  suppressed (height = 0) on any row whose CI clips past xlim.
- **Facet strips.** Lowercase: "mpba-modifiable", "proportion" / "count" /
  "presence", "level change", "gender x level".
- **Outcome rows.** No "total" row in T1 adj — dropped for publication clarity.

## 3. Base styling (HTMLs everywhere, non-T1-adj PNGs)

- **Palette.** `PUB_COLORS_LEGACY`, or the original steelblue / firebrick /
  forestgreen equivalents.
- **Typography.** `theme_minimal(11)` plus small custom tweaks (current
  `forest_theme()` in the consolidated script).
- **Bars.** Single `geom_errorbarh` per row with standard heights (0.06 rest,
  0.15 pooled), colored by category.
- **Facet strips.** TitleCase labels (unchanged from legacy).

## 4. Spacing formula (all tiers, A1–A6)

- `step_size` — vertical gap between restaurant dots: **0.32 for T1**, **0.50 for T2**.
- `Y_SPREAD` — outcome-to-outcome distance:
  `max(n_rest_max * step_size * 1.4, tier_default)` where `tier_default` is
  **6.5** (T1 base), **3.0** (T1 publication), **8.5** (T2). The 1.4 multiplier
  leaves ~40% margin so dot clouds never bleed into adjacent outcomes.
- `n_rest_max` is computed per function from the actual data (the max
  restaurants-per-outcome-facet-series cell).

## 5. PNG vs HTML split

The adj.R `create_*_forest_restaurants*()` functions and the consolidated
`build_forest()` each build **two** ggplot objects: `p_png` (full publication
style) fed to `ggsave()`, and `p_html` (base style) fed to
`ggplotly() -> saveWidget()`. This keeps PNGs publication-quality without
polluting the interactive HTMLs.

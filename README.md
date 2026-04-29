# Alt-Protein Sales Effects
**Designed and optimized a fully custom Stan model for forecasting sales and estimating the effect of introducing alternative proteins in restaurants.**

*STATUS: Modeling Pre-LLM, Plotting Post-LLM*

**Note:** This analysis consists of 6 separate analyses (done over two sets of restaurants, so 12 total), with forest plots of effects estimates that can be visualized as shown below.

## Preview

Below, are estimates from 140 separate multilevel models, each containing a varying number of restaurants. The bold point estimates represent pooled-over-restaurant rate ratios (aka multiplicative effects) for specific outcomes and exposures, while the smaller points represent the same for individual restaurants. When you click the point estimate, the prediction plot (in-sample and out-of-sample) for that restaurant is shown.

![click-to-open demo](publication/docs/demo.gif)

## Interactive HTML (recommended)

Open any of these locally to interact with the plotly widgets — click a
restaurant or pooled estimate to open its prediction plot:

- `present/base/grid_both_sorted.html` — non-adjusted, sorted
- `present/total_adjusted/grid_both_sorted.html` — adjusted by total sales, sorted
- `present/base/grid_both.html` - non-adjusted, unsorted
- `present/total_adjusted/grid_both.html` — adjusted by total sales, unsorted

The grid HTML iframes the per-analysis plot HTMLs (`A1_*.html`, `A2_*.html`, …). 
Each one carries its own plotly widget plus a click handler that opens the matching `.png` from `present/model_fits/.../plots/` in a new tab.

## Layout

- `model_scripts/` — R drivers for processing, model fitting, and fit extraction
- `model_fits/` — fitted samples + per-restaurant pred plots
- `publication/forest_plots/` — effect estimate plot directory (PNGs, PDFs, plotly HTMLs)
- `publication/` — forest plot R scripts + grid splicing + docs assets
- `present/` — self-contained bundle of HTMLs with bundled pred plots

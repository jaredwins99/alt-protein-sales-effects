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

- `present/total_adjusted/grid_sorted.html` — sorted / unlabeled (matches `professional_wide_fixed/`)
- `present/total_adjusted/grid_labeled.html` — labeled (matches `professional_labeled_v2/`)

Each grid iframes that bundle's per-analysis plot HTMLs (Tier 1: A1–A6; Tier 2:
A1a/b/c, A2, A3a/b, A4, A5, A6 — `PUB_WIDE` splits T2 A1 and A3 across pages).
Every plot carries its own plotly widget plus a click handler that opens the
matching `.png` from `present/model_fits/.../plots/` in a new tab.

The grids are **generated**, not hand-maintained — run
`python3 publication/scripts/make_present_grids.py` after `render_present.sh`.
They build themselves from whatever HTMLs each bundle actually contains, so a
change in plot count (as when T2 went from 6 plots to 9) cannot silently break
them again.

### Viewing them interactively

**These cannot be embedded in this README.** GitHub strips `<script>` and
`<iframe>` from rendered markdown, so a plotly widget will not run here — the
GIF above is a recording, not a live plot. To actually interact:

| how | what it takes |
|---|---|
| **Locally** | clone, then open either `grid_*.html` in a browser. Works offline; no server needed. |
| **GitHub Pages** | enable Pages for this repo (Settings → Pages → deploy from branch). The grids are then live at `https://<user>.github.io/<repo>/present/total_adjusted/grid_sorted.html`. Requires the repo to be public, or a plan that allows private Pages. |
| **raw.githack.com** | no setup, but public repos only: swap `github.com` for `raw.githack.com` in the file URL. |

The HTMLs are *not* self-contained — each has a sibling `*_files/` directory
holding its plotly assets — so whatever serves them must serve those too.
Relative paths resolve under all three options above.

## Layout

- `model_scripts/` — R drivers for processing, model fitting, and fit extraction
- `model_fits/` — fitted samples + per-restaurant pred plots
- `publication/forest_plots/` — effect estimate plot directory (PNGs, PDFs, plotly HTMLs)
- `publication/` — forest plot R scripts + grid splicing + docs assets
- `present/` — interactive HTML bundles (sorted + labeled) with bundled pred plots

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
GIF above is a recording, not a live plot.

**No clone required — open these:**

| | link |
|---|---|
| Sorted / unlabeled | [grid_sorted.html](https://raw.githack.com/jaredwins99/alt-protein-sales-effects/main/present/total_adjusted/grid_sorted.html) |
| Labeled | [grid_labeled.html](https://raw.githack.com/jaredwins99/alt-protein-sales-effects/main/present/total_adjusted/grid_labeled.html) |

These are served straight from this repo by [raw.githack.com](https://raw.githack.com),
which needs no setup and no GitHub Pages. Everything works: the plotly widgets,
the expand/Esc controls, and the click-through to each restaurant's prediction
plot. Verified end to end — HTML, the `*_files/` plotly assets, and the
prediction PNGs all serve correctly.

Two caveats:

- `raw.githack.com` is the *development* host: uncached, rate-limited, and it
  always reflects the current `main`. For a link you intend to share widely,
  swap the host for `rawcdn.githack.com`, which is CDN-cached — but note it
  caches per ref, so a `main` URL may serve a stale copy after you push.
  Pin a commit SHA in place of `main` for a link that is both fast and stable.
- It only works because this repo is public.

**Locally:** clone and open either `grid_*.html` in a browser. Works offline.

**GitHub Pages** is not required, and is awkward here anyway: Pages publishes at
most 1 GB, and `present/` alone is 1.3 GB (147 MB of plots plus 548 MB of
click-through images), so it would need a dedicated `gh-pages` branch carrying
only a subset rather than a deploy-from-`main`.

The HTMLs are *not* self-contained — each has a sibling `*_files/` directory
holding its plotly assets — so whatever serves them must serve those too.
Relative paths resolve under all of the above.

## Layout

- `model_scripts/` — R drivers for processing, model fitting, and fit extraction
- `model_fits/` — fitted samples + per-restaurant pred plots
- `publication/forest_plots/` — effect estimate plot directory (PNGs, PDFs, plotly HTMLs)
- `publication/` — forest plot R scripts + grid splicing + docs assets
- `present/` — interactive HTML bundles (sorted + labeled) with bundled pred plots

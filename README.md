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
| Sorted / unlabeled | https://jaredwins99.github.io/alt-protein-sales-effects/total_adjusted/grid_sorted.html |
| Labeled | https://jaredwins99.github.io/alt-protein-sales-effects/total_adjusted/grid_labeled.html |

Or start at the landing page:
https://jaredwins99.github.io/alt-protein-sales-effects/

Served from the `gh-pages` branch, which mirrors `present/`. Everything works:
the plotly widgets, the expand/Esc controls, and the click-through from any
point estimate to that restaurant's prediction plot (all 4,086 targets verified
to resolve). Published size is 570 MB, inside the 1 GB Pages limit (the plots themselves are 22 MB; the rest is the click-through prediction images).

To re-publish after a `render_present.sh` rebuild:

```bash
rsync -a --delete --exclude .git --exclude index.html present/ ~/ghp-alt-protein/ && cd ~/ghp-alt-protein && git add -A && git commit -m "publish rebuilt bundles" && git push origin gh-pages
```

**Fallback without Pages:** [raw.githack.com](https://raw.githack.com) serves the
same files straight off `main` —
[sorted](https://raw.githack.com/jaredwins99/alt-protein-sales-effects/main/present/total_adjusted/grid_sorted.html),
[labeled](https://raw.githack.com/jaredwins99/alt-protein-sales-effects/main/present/total_adjusted/grid_labeled.html).
It is the *development* host: uncached and rate-limited. For a widely shared
link use `rawcdn.githack.com` with a pinned commit SHA instead of `main`.
Both hosts work only because this repo is public.

**Locally:** clone and open either `grid_*.html` in a browser. Works offline.

The HTMLs are *not* self-contained — each has a sibling `*_files/` directory
holding its plotly assets — so whatever serves them must serve those too.
Relative paths resolve under all of the above.

## Layout

- `model_scripts/` — R drivers for processing, model fitting, and fit extraction
- `model_fits/` — fitted samples + per-restaurant pred plots
- `publication/forest_plots/` — effect estimate plot directory (PNGs, PDFs, plotly HTMLs)
- `publication/` — forest plot R scripts + grid splicing + docs assets
- `present/` — interactive HTML bundles (sorted + labeled) with bundled pred plots

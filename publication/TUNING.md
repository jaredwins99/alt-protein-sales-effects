# Changing how the plots look

Every visual property is set in one of three config files or by an environment
variable. Nothing is hardcoded in the renderers except placement rules that
differ per analysis, and those are commented at the site.

Work outward: try the per-plot override first, the global default second, the
theme last.

## 1. One plot only — `publication/config/plot_config.R`

`PLOT_CONFIG` is keyed `"<tier>_<analysis>"`, 12 keys: `T1_A1`…`T1_A6`,
`T2_A1`…`T2_A6`. Edit a value in place; it affects that plot and nothing else.
Applies to PNG/PDF only — the HTML widget computes its own height.

| I want to change | field |
|---|---|
| plot width / height (inches) | `png_w`, `png_h` |
| vertical gap between restaurant dots | `step_size` |
| overall vertical spread | `margin_mult`, `y_spread_floor` |
| CI end-cap (T-tick) size | `cap_pooled`, `cap_rest` |
| bar thickness | `pooled_bar_linewidth`, `rest_bar_linewidth` |
| padding under / over the axis range | `expand_below`, `expand_above` |
| height of the pooled numeric label | `pooled_label_dy` |

`T1_ADJ_BASE` is shared by T1 A1–A4 — edit that one block to retune all four at
once. `WIDE_OVERRIDES[[key]]` is layered on top only when `PUB_WIDE=TRUE`.

## 2. All plots — `publication/config/publication_config.R`

`PUBLICATION_CONFIG` holds the defaults every plot inherits.

| I want to change | field |
|---|---|
| base font size (pt) | `base_size` |
| title / axis / strip text sizes | `*_size_rel` (multipliers of `base_size`) |
| typeface | `font_family` (falls back to `sans` if not installed) |
| series colours | `color_total`, `color_animal`, `color_plant`, `color_male`, `color_female` |
| the muted variants | the same names with `_wash`, `_restwash`, `_innerdark` |
| default bar weight / opacity | `pooled_bar_linewidth`, `pooled_bar_alpha_outer` |

Read a value in code with `pub_cfg("field", default)`; `plot_or_pub(cfg, field)`
prefers the per-plot override and falls back here.

## 3. Palettes and ggplot theme — `publication/config/publication_theme.R`

`PUB_COLORS*` are the assembled palettes (`_INNER`, `_REST_WASH`,
`_INNER_DARK`, `_LEGACY*` for the older colourway).
`publication_forest_theme()` is the ggplot theme itself — grid lines, strips,
margins, legend. Change this only for something the two files above cannot
express.

## 4. Switches — environment variables

Set at the entry point, e.g. `PUB_WIDE=TRUE Rscript publication/render/...`.

| variable | effect |
|---|---|
| `ADJ_FIXED` | read the corrected extraction. Defaults TRUE; **leave it** — FALSE reads retired data |
| `LABELED_MODE` | per-restaurant colours + numbered legend |
| `LABELED_V2` | implies `LABELED_MODE`, adds per-restaurant estimate + CI text |
| `SORT_BY_MEAN` | order restaurants by transformed mean instead of input order |
| `PUB_WIDE` | apply `WIDE_OVERRIDES` |
| `PUB_RECENTER` | percentage-change labelling instead of RR |
| `PRESENT_MODE` | plain labels + interactive-build cap sizing, output to `present/` |
| `PRO_FAST` | PDF only, skip PNG and HTML — use while iterating |
| `PRO_ONLY` | `A1`…`A5` to render a single analysis |
| `PUB_LOG` | log-scale companion passes (archived tree only) |
| `PUB_CAP_SCALE` | CI end-cap scale, default `0.3` |

## 5. Entry points

| command | produces |
|---|---|
| `Rscript publication/render/render_professional_wide_fixed.R` | sorted forest plots |
| `Rscript publication/render/render_professional_labeled_v2.R` | labeled forest plots |
| `bash publication/render/render_present.sh` | the interactive HTML bundle |
| `python run_pipeline.py` | all of the above, plus tables and diagrams |

While iterating, `PRO_FAST=TRUE PRO_ONLY=A1` renders one PDF in seconds instead
of rebuilding everything.

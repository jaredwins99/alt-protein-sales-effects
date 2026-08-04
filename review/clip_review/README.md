# clip_review

Local pair-by-pair review server for deciding **date clips** on a per-restaurant
series, one page per (restaurant, outcome) cell. Built for the A2 targeted clip
review; reusable for any dataset that can be reduced to "one series, one
decision".

Stdlib Python + a JSON file. No build step, no dependencies.

---

## Run

```
Rscript review/clip_review/generators/gen_a2_targeted.R review/clip_review/build
python3 review/clip_review/serve.py \
    --pages     review/clip_review/build/a2_targeted.json \
    --decisions review/clip_review/decisions/a2_targeted.jsonl \
    --port 8770 --title "A2 targeted clip review"
```

`--host 0.0.0.0` (the default) exposes it on the LAN. With WSL mirrored
networking off, the Windows firewall needs the port opened before another
machine can reach it.

Decisions append to the JSONL immediately, one line per submit, so the session
is resumable and **last line wins per key**. Re-reviewing a cell overwrites it.

## Controls

| key | action |
|---|---|
| `A` / `D` | move the **start** handle left / right |
| `←` / `→` | move the **end** handle left / right |
| `shift` | 30-day step · `ctrl` 1-day step · default 7 |
| `Enter` | approve · `R` no clip · `F` flag |

Handles are also draggable. The live readout under the chart shows units and
days **cut before / kept / cut after** as you move them.

## Datasets

| generator | pages | what the decision means |
|---|---|---|
| `gen_a2_targeted.R` | 37 | start/end clip per (restaurant, category) for A2 |
| `gen_a4_its.R` | 13 | whether an ITS pre-period needs a head clip |

`decisions/a2_targeted.jsonl` is the completed A2 review (37/37 approved,
2026-08-04), applied to `clip_dates_proportion_targeted` in
`model_scripts/ingarch_scripts/1_data_ingarch.R`.

## Page schema

A generator writes `{key: page}`. Only these are **required**:

| key | type | use |
|---|---|---|
| `key` `restaurant` `outcome_label` `analysis` `models` | str | header |
| `units` `n_days` `pct_zero` | num | facts |
| `date_min` `date_max` | date | facts |
| `series` | `{d0, total[], outcome[]}` | the chart — daily, from `d0` |
| `rec` | `{start, end, why}` | initial handle positions |

Everything else is optional and its panel is skipped when absent:
`cum` (live unit accounting), `exp_steps` + `exp_max` (green exposure step),
`marks` (first/last data and outcome ticks), `universal` / `cat_clip` (existing
filters drawn on the chart), `monthly`, `runs`, `intros`, `dishes`,
`analog_dishes`, `analogs`, `n_dishes` / `n_animal` / `animal_units` /
`plant_units` / `mod_units`, `verdict_line`, and `sensitivity` (renders a
head-cut sensitivity table — see below).

## Conventions that matter

- **Smoothing is trailing, never centred.** A centred window lets the line rise
  *before* the event that caused it, which reads as a data artifact at the edge
  and invites a clip that shouldn't happen. `roll_trail()` is causal.
- **Exposure is drawn as exact step change-points**, not a smoothed line — a
  point jump must look like a point jump.
- **The series is daily and complete.** No weekly sampling; sampling offsets the
  line from the vertical markers and the two stop lining up.
- Excluded regions are a light red tint, not grey — a grey line under grey
  shading is invisible.

## Head-cut sensitivity (ITS datasets)

`gen_a4_its.R` attaches a `sensitivity` table: pre-period mean and naive step
after dropping the first 0/30/60/90/120/180 days. It separates two cases that
look identical from the plot alone:

- **converged** — a run of structural zeros (the product did not exist yet) with
  a natural stopping point at first sale. Clipping is principled.
- **no plateau** — the step slides monotonically with every cut point. That is a
  pre-trend, which the model's `date_num` term absorbs; clipping would just be
  choosing the answer.

## Notes

- `build/` is generated and gitignored. `decisions/` is the durable artifact —
  it is the human judgement and cannot be regenerated.
- Dish-level panels (`dishes`, `analogs`, animal/plant unit splits) come from the
  sibling `restaurant-sales` repo. `gen_a4_its.R` reuses them from an enriched
  `a2_targeted.json` when one is present in the output dir, and degrades to the
  introductions table when it is not.
- To kill the server, find the PID by port (`ss -ltnp | grep 8770`). Do **not**
  use `pkill -f serve.py` — the pattern matches the invoking shell and kills it.

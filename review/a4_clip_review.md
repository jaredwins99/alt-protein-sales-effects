# A4 (ITS) clip review — outcome: no clipping

Reviewed pair-by-pair 2026-08-04 on the `clip_review` server
(`review/clip_review/generators/gen_a4_its.R`, 13 cells).

**Decision: none of the 13 A4 cells are clipped.** A4 therefore keeps no
per-analysis clip table, and no new clipping mechanism is added for it.

## Why A4 is not clip-sensitive the way A2 is

- The intervention sits mid-series in every cell, so the pre/post contrast
  does not depend on the edges.
- `tail0 = 0` in all 13 cells — there are no trailing artifacts at all.
- Days with `total_outcome == 0` are already dropped from the likelihood
  (`run_ingarch.R`), so coverage gaps need no trimming.
- The model carries a `date_num` trend term, which absorbs pre-period drift
  — the thing that a head clip would otherwise be used to remove.

## Evidence

`head 0` / `tail 0` are the leading and trailing runs of zero-outcome days.
`step @0d` and `step @180d` are the naive pre/post step with 0 and 180 days
dropped from the head; a cell needing a clip would *converge*, not slide.

| restaurant | outcome | tier | pre | post | head 0 | tail 0 | ITS step | step @0d | step @180d |
|---|---|---|---|---|---|---|---|---|---|
| `ED5J990H5VAZT` | Breakfast-style meat | T1+T2 | 1798 | 517 | 270d | 0d | 2021-10-02 | +424% | +371% |
| `LQ5EH4BKGV61T` | Ground meat | T2 | 325 | 102 | 17d | 0d | 2023-01-07 | +5% | -28% |
| `L69HYJ4Y3TR91` | Breakfast-style meat | T1+T2 | 132 | 184 | 9d | 0d | 2023-01-11 | +63% | +43% |
| `1SQPTEGYPH0GA` | Ground meat | T2 | 1990 | 853 | 4d | 0d | 2020-06-15 | -63% | -61% |
| `9XKJD8DQTH559` | Dairy | T2 | 561 | 615 | 1d | 0d | 2021-07-29 | +50% | +34% |
| `S8MT0YGD2KTN9` | Ground meat | T2 | 347 | 1417 | 1d | 0d | 2019-03-12 | -5% | +1% |
| `2HRX9P6HKXA8V` | Breakfast-style meat | T1+T2 | 155 | 1382 | 0d | 0d | 2019-06-06 | +3% | -2% |
| `VLZX7K2M9QD4T` | Whole-muscle meat | T1+T2 | 182 | 158 | 0d | 0d | 2021-10-18 | -6% | -1% |
| `SRQS8F7JWA9MZ` | Ground meat | T1+T2 | 417 | 1045 | 0d | 0d | 2020-06-25 | +24% | +1% |
| `78AY09MVJVTYE` | Breakfast-style meat | T2 | 245 | 2010 | 0d | 0d | 2015-08-10 | -8% | -19% |
| `W8T41JZK0ZMEP` | Dairy | T2 | 343 | 753 | 0d | 0d | 2021-03-07 | -15% | -12% |
| `SAFK7ND1HR6XS` | Whole-muscle meat | T2 | 135 | 163 | 0d | 0d | 2019-09-12 | -16% | -2% |
| `C0BE4NDSW26QN` | Ground meat | T2 | 828 | 1285 | 0d | 0d | 2019-09-04 | +15% | +15% |

## The one case that was argued for, and rejected

`ED5J990H5VAZT` / breakfast (both tiers) has 270 consecutive zero-outcome
days at the head — the breakfast-meat product did not exist on the menu yet,
on days the restaurant was open and selling. Dropping them moves the naive
step from +424% to +371%.

Rejected on review. The zeros sit ~5 years before the 2021-10-02 step, where
an ITS with a trend term has little leverage; the pre-period remains ~34%
zeros after any cut, so the series is sparse either way rather than cleanly
split; and the sensitivity slides steadily rather than reaching a plateau,
so no cut point is more principled than another.

## Scope

A1, A3, A5 and A6 are likewise unclipped — no per-analysis clip table exists
for them and none was added. Only A2 is clipped, via
`clip_dates_proportion_targeted` in `model_scripts/ingarch_scripts/1_data_ingarch.R`,
gated on `/a2_proportion_t/` so it reaches A2 in both tiers and nothing else.
All analyses continue to apply the eight universal restaurant windows.

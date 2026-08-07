# Result tables — every generated table in one place

Regenerated 2026-08-07 from `publication/scripts/extract_mu_gamma_tables.R`.
Rebuild with:

```
ADJ_FIXED=TRUE Rscript publication/scripts/extract_mu_gamma_tables.R
```

---

## Read this first: the two columns are different estimands

Each analysis produces **two** tables, and the Supplement currently mixes up which is which.

| | file | what it is | source CSV |
|---|---|---|---|
| **Adjusted** | `*_mu_gamma_adj.tex` | **RRR** — outcome effect minus total-purchases effect. *This is exactly what the forest plots draw.* | `forest_data_adj_95ci_fixed.csv` (Aug 7) |
| **Unadjusted** | `*_mu_gamma.tex` | **RR** — the raw outcome-model effect, no control series | `forest_data_95ci.csv` (May 3) |

**The tables printed in the Supplement today are the *adjusted* ones — RRRs, not RRs.**
Their captions say so ("Pooled adjusted rate ratios"), but the Methods prose says
*"The unadjusted RRs are listed in tables within Sections 3.2.3 & 3.3.4"* — which describes
the other file. One of the two has to change; see **Decisions** at the bottom.

**Point estimates are now posterior medians** for A1–A4, matching the figures. They were
`exp(mean)` before. A5/A6 use an identity link and report the posterior **mean** — that is a
genuine estimand difference across figures, flagged in `METHODS_rrr.md`.

---

## Provenance — which fits each table rests on

| table | Supplement label | fit generation | current? |
|---|---|---|---|
| Tier One A1 | `tab:rr_t1_a1` | `finalized_redone_trunc` | **no** — pre-decontamination |
| Tier One A2 | `tab:rr_t1_a2` | `finalized_uncontaminated2` | **yes** — decontaminated + clipped |
| Tier One A3 | `tab:rr_t1_a3` | `finalized_redone_trunc_cp` | **no** — pre-decontamination |
| Tier One A4 | `tab:rr_t1_a4` | `finalized_uncontaminated` | partly — `_uncontaminated`, not `2` |
| Tier Two A1 | `tab:rr_t2_a1` | `finalized_redone_trunc*` | **no** — pre-decontamination |
| Tier Two A2 | `tab:rr_t2_a2` | `finalized_redone_trunc` | **no** — pre-decontamination |
| Tier Two A3 | `tab:rr_t2_a3` | `finalized_redone_trunc*` | **no** — pre-decontamination |
| Tier Two A4 | `tab:rr_t2_a4` | `finalized_redone_trunc*` | **no** — pre-decontamination |
| Tier One A5 (within-customer, general) | `tab:a5_mu_gamma` | `finalized_redone_trunc_cp` | **no** — pre-decontamination |
| Tier One A6 (within-customer, counterpart) | `tab:a6_mu_gamma` | `finalized_uncontaminated` | partly — `_uncontaminated`, not `2` |
| Tier Two A5 (within-customer, general) | `tab:t2_a5_mu_gamma` | `finalized_redone_trunc_cp` | **no** — pre-decontamination |
| Tier Two A6 (within-customer, counterpart) | `tab:t2_a6_mu_gamma` | `finalized_redone_trunc_cp` | **no** — pre-decontamination |

Only **T1 A2** rests on the current `finalized_uncontaminated2` fits. T1 A4/A6 are one
generation behind. Everything else predates decontamination and edge-clipping. **T2 A2 is
still refitting on Sherlock**, so its numbers will move again.

---

## Tier One A1  (`tab:rr_t1_a1`)

### Adjusted — RRR, matches the forest plots  ·  `A1_mu_gamma_adj.tex`

| Outcome | Exposure | Count | Proportion |
|---|---|---|---|
| Nonvegan | Mpbamod | 0.997 [0.752, 1.219] | 0.993 [0.855, 1.155] |
| Nonvegan | Vegan | 0.982 [0.600, 1.599] | 0.986 [0.845, 1.131] |
| Nonvegan | Vegetarian | 0.999 [0.921, 1.070] | 0.976 [0.870, 1.112] |
| Meat | Mpbamod | 0.985 [0.850, 1.162] | 1.030 [0.901, 1.175] |
| Meat | Vegan | 1.035 [0.614, 1.582] | 0.928 [0.787, 1.099] |
| Meat | Vegetarian | 0.979 [0.906, 1.040] | 0.857 [0.760, 0.986] |
| Chicken Fish | Mpbamod | 0.976 [0.835, 1.143] | 1.012 [0.838, 1.196] |
| Chicken Fish | Vegan | 0.921 [0.594, 1.427] | 0.898 [0.746, 1.085] |
| Chicken Fish | Vegetarian | 1.024 [0.892, 1.255] | 0.844 [0.706, 1.041] |
| Vegetarian | Mpbamod | 1.034 [0.756, 1.316] | 0.968 [0.810, 1.166] |
| Vegetarian | Vegan | 0.973 [0.660, 1.487] | 1.008 [0.874, 1.178] |
| Vegetarian | Vegetarian | 1.024 [0.895, 1.123] | 1.103 [0.938, 1.257] |
| Vegan | Mpbamod | 1.006 [0.843, 1.223] | 0.979 [0.845, 1.137] |
| Vegan | Vegan | 0.932 [0.633, 1.393] | 1.067 [0.902, 1.263] |
| Vegan | Vegetarian | 1.005 [0.926, 1.093] | 1.031 [0.910, 1.190] |

### Unadjusted — raw outcome RR  ·  `A1_mu_gamma.tex`

| Outcome | Exposure | Count | Proportion |
|---|---|---|---|
| Total | Mpbamod | 1.035 [0.897, 1.158] | 1.027 [0.915, 1.135] |
| Total | Vegan | 1.216 [0.858, 1.627] | 1.092 [0.970, 1.221] |
| Total | Vegetarian | 1.045 [1.003, 1.105] | 1.101 [0.987, 1.197] |
| Nonvegan | Mpbamod | 1.037 [0.793, 1.155] | 1.020 [0.914, 1.109] |
| Nonvegan | Vegan | 1.190 [0.803, 1.613] | 1.072 [0.957, 1.195] |
| Nonvegan | Vegetarian | 1.044 [0.988, 1.100] | 1.076 [0.996, 1.164] |
| Meat | Mpbamod | 1.021 [0.921, 1.141] | 1.057 [0.969, 1.127] |
| Meat | Vegan | 1.221 [0.832, 1.850] | 1.014 [0.894, 1.150] |
| Meat | Vegetarian | 1.022 [0.977, 1.071] | 0.942 [0.860, 1.053] |
| Chicken Fish | Mpbamod | 1.009 [0.906, 1.100] | 1.035 [0.881, 1.186] |
| Chicken Fish | Vegan | 1.107 [0.849, 1.504] | 0.978 [0.847, 1.142] |
| Chicken Fish | Vegetarian | 1.063 [0.927, 1.283] | 0.927 [0.791, 1.111] |
| Vegetarian | Mpbamod | 1.066 [0.818, 1.315] | 0.992 [0.859, 1.143] |
| Vegetarian | Vegan | 1.179 [0.934, 1.532] | 1.101 [1.008, 1.214] |
| Vegetarian | Vegetarian | 1.068 [0.971, 1.166] | 1.220 [1.059, 1.300] |
| Vegan | Mpbamod | 1.034 [0.909, 1.188] | 1.001 [0.890, 1.126] |
| Vegan | Vegan | 1.132 [0.916, 1.442] | 1.170 [1.019, 1.291] |
| Vegan | Vegetarian | 1.049 [0.989, 1.121] | 1.135 [1.023, 1.243] |

---

## Tier One A2  (`tab:rr_t1_a2`)

### Adjusted — RRR, matches the forest plots  ·  `A2_mu_gamma_adj.tex`

| Outcome | Count | Presence |
|---|---|---|
| Breakfast | 0.919 [0.660, 1.253] | 0.615 [0.182, 2.345] |
| Chicken | 1.043 [0.651, 1.787] | 1.133 [0.405, 3.588] |
| Dairy | 1.002 [0.860, 1.183] | 0.760 [0.275, 2.402] |
| Egg | 1.032 [0.511, 1.904] | 0.735 [0.268, 2.408] |
| Untextured | 1.078 [0.915, 1.291] | 0.855 [0.316, 2.747] |

### Unadjusted — raw outcome RR  ·  `A2_mu_gamma.tex`

| Outcome | Count | Presence |
|---|---|---|
| Breakfast | 0.921 [0.701, 1.494] | 0.782 [0.385, 2.599] |
| Chicken | 1.090 [0.696, 1.879] | 1.150 [0.395, 4.332] |
| Dairy | 1.035 [0.870, 1.078] | 1.040 [0.364, 3.446] |
| Egg | 1.043 [0.654, 1.810] | 1.099 [0.343, 3.576] |
| Untextured | 1.092 [1.006, 1.210] | 1.092 [1.006, 1.210] |

---

## Tier One A3  (`tab:rr_t1_a3`)

### Adjusted — RRR, matches the forest plots  ·  `A3_mu_gamma_adj.tex`

| Outcome | Level change | Slope change |
|---|---|---|
| Nonvegan | 0.989 [0.856, 1.135] | 0.966 [0.557, 1.835] |
| Meat | 0.955 [0.822, 1.071] | 0.933 [0.531, 1.777] |
| Chicken Fish | 0.900 [0.633, 1.074] | 0.967 [0.378, 2.066] |
| Vegetarian | 1.025 [0.813, 1.274] | 0.787 [0.486, 1.558] |
| Vegan | 1.043 [0.900, 1.287] | 0.596 [0.315, 1.307] |

### Unadjusted — raw outcome RR  ·  `A3_mu_gamma.tex`

| Outcome | Level change | Slope change |
|---|---|---|
| Total | 1.066 [0.973, 1.190] | 1.863 [1.103, 2.602] |
| Nonvegan | 1.055 [0.943, 1.174] | 1.815 [1.110, 2.596] |
| Meat | 1.018 [0.910, 1.093] | 1.741 [1.057, 2.373] |
| Chicken Fish | 0.966 [0.684, 1.114] | 1.781 [0.764, 3.296] |
| Vegetarian | 1.090 [0.899, 1.342] | 1.453 [1.045, 2.404] |
| Vegan | 1.108 [1.004, 1.347] | 1.079 [0.628, 2.007] |

---

## Tier One A4  (`tab:rr_t1_a4`)

### Adjusted — RRR, matches the forest plots  ·  `A4_mu_gamma_adj.tex`

| Outcome | Level change | Slope change |
|---|---|---|
| Breakfast | 0.783 [0.532, 1.151] | 0.437 [0.171, 1.297] |
| Textured | 0.966 [0.848, 1.087] | 0.343 [0.154, 0.800] |
| Untextured | 0.973 [0.538, 1.769] | 0.392 [0.147, 1.410] |

### Unadjusted — raw outcome RR  ·  `A4_mu_gamma.tex`

| Outcome | Level change | Slope change |
|---|---|---|
| Breakfast | 0.841 [0.530, 1.393] | 0.782 [0.339, 2.098] |
| Textured | 1.221 [1.139, 1.313] | 0.690 [0.329, 1.444] |
| Untextured | 1.060 [0.517, 2.484] | 0.681 [0.269, 1.911] |

---

## Tier Two A1  (`tab:rr_t2_a1`)

### Adjusted — RRR, matches the forest plots  ·  `A1_t2_mu_gamma_adj.tex`

| Outcome | Exposure | Count | Proportion |
|---|---|---|---|
| Nonvegan | Mpbamod | 1.004 [0.934, 1.083] | 0.998 [0.850, 1.159] |
| Nonvegan | Vegan | 1.008 [0.885, 1.136] | 0.990 [0.896, 1.082] |
| Nonvegan | Vegetarian | 1.003 [0.958, 1.045] | 0.985 [0.911, 1.070] |
| Meat | Mpbamod | 1.007 [0.940, 1.076] | 1.026 [0.882, 1.166] |
| Meat | Vegan | 1.004 [0.871, 1.157] | 0.965 [0.861, 1.087] |
| Meat | Vegetarian | 0.986 [0.949, 1.023] | 0.900 [0.828, 0.982] |
| Chicken Fish | Mpbamod | 1.017 [0.939, 1.101] | 0.997 [0.851, 1.172] |
| Chicken Fish | Vegan | 0.951 [0.850, 1.060] | 0.912 [0.792, 1.047] |
| Chicken Fish | Vegetarian | 0.979 [0.934, 1.022] | 0.831 [0.744, 0.939] |
| Vegetarian | Mpbamod | 1.007 [0.932, 1.088] | 1.010 [0.869, 1.189] |
| Vegetarian | Vegan | 0.986 [0.885, 1.085] | 0.986 [0.904, 1.081] |
| Vegetarian | Vegetarian | 1.005 [0.960, 1.050] | 1.037 [0.952, 1.130] |
| Vegan | Mpbamod | 1.020 [0.941, 1.122] | 1.030 [0.860, 1.230] |
| Vegan | Vegan | 1.019 [0.916, 1.154] | 1.032 [0.913, 1.166] |
| Vegan | Vegetarian | 1.016 [0.958, 1.064] | 0.986 [0.902, 1.086] |

### Unadjusted — raw outcome RR  ·  `A1_t2_mu_gamma.tex`

| Outcome | Exposure | Count | Proportion |
|---|---|---|---|
| Total | Mpbamod | 1.028 [0.975, 1.081] | 0.969 [0.874, 1.091] |
| Total | Vegan | 1.116 [1.042, 1.222] | 1.103 [1.031, 1.181] |
| Total | Vegetarian | 1.040 [1.013, 1.074] | 1.047 [0.988, 1.111] |
| Nonvegan | Mpbamod | 1.029 [0.975, 1.091] | 0.969 [0.867, 1.085] |
| Nonvegan | Vegan | 1.121 [1.033, 1.222] | 1.091 [1.016, 1.164] |
| Nonvegan | Vegetarian | 1.042 [1.011, 1.077] | 1.030 [0.977, 1.082] |
| Meat | Mpbamod | 1.033 [0.991, 1.081] | 1.008 [0.893, 1.081] |
| Meat | Vegan | 1.118 [1.013, 1.230] | 1.064 [0.974, 1.176] |
| Meat | Vegetarian | 1.026 [1.005, 1.051] | 0.941 [0.887, 1.010] |
| Chicken Fish | Mpbamod | 1.043 [0.982, 1.108] | 0.971 [0.857, 1.092] |
| Chicken Fish | Vegan | 1.061 [0.990, 1.140] | 1.005 [0.893, 1.131] |
| Chicken Fish | Vegetarian | 1.018 [0.983, 1.053] | 0.869 [0.792, 0.969] |
| Vegetarian | Mpbamod | 1.034 [0.973, 1.098] | 0.979 [0.886, 1.102] |
| Vegetarian | Vegan | 1.098 [1.043, 1.163] | 1.089 [1.029, 1.155] |
| Vegetarian | Vegetarian | 1.055 [1.012, 1.092] | 1.085 [1.013, 1.156] |
| Vegan | Mpbamod | 1.049 [0.978, 1.139] | 1.000 [0.877, 1.157] |
| Vegan | Vegan | 1.138 [1.054, 1.245] | 1.140 [1.028, 1.251] |
| Vegan | Vegetarian | 1.055 [1.007, 1.106] | 1.032 [0.957, 1.115] |

---

## Tier Two A2  (`tab:rr_t2_a2`)

### Adjusted — RRR, matches the forest plots  ·  `A2_t2_mu_gamma_adj.tex`

| Outcome | Count | Presence |
|---|---|---|
| Breakfast | 1.550 [0.494, 3.751] | 5.132 [0.891, 26.713] |
| Chicken | 1.053 [0.909, 1.225] | 5.716 [0.885, 29.386] |
| Dairy | 1.061 [0.963, 1.209] | 3.288 [0.814, 12.880] |
| Egg | 1.027 [0.954, 1.106] | 1.552 [0.464, 4.762] |
| Textured | 1.544 [0.696, 3.257] | 2.581 [0.369, 13.140] |
| Untextured | 1.167 [1.005, 1.817] | 6.862 [1.449, 28.877] |

### Unadjusted — raw outcome RR  ·  `A2_t2_mu_gamma.tex`

| Outcome | Count | Presence |
|---|---|---|
| Breakfast | 1.682 [0.509, 4.516] | 3.363 [0.755, 11.870] |
| Chicken | 1.080 [0.922, 1.264] | 4.324 [0.943, 15.972] |
| Dairy | 1.082 [0.984, 1.220] | 2.440 [1.127, 6.113] |
| Egg | 1.054 [0.994, 1.150] | 1.113 [0.854, 1.801] |
| Textured | 1.564 [0.682, 3.358] | 1.932 [0.402, 6.908] |
| Untextured | 1.211 [1.047, 2.063] | 5.111 [1.878, 12.823] |

---

## Tier Two A3  (`tab:rr_t2_a3`)

### Adjusted — RRR, matches the forest plots  ·  `A3_t2_mu_gamma_adj.tex`

| Outcome | Level change | Slope change |
|---|---|---|
| Nonvegan | 0.940 [0.574, 1.546] | 0.984 [0.588, 1.668] |
| Meat | 0.817 [0.537, 1.204] | 0.834 [0.508, 1.471] |
| Chicken Fish | 0.859 [0.551, 1.307] | 1.223 [0.715, 2.041] |
| Vegetarian | 0.946 [0.624, 1.571] | 0.873 [0.601, 1.210] |
| Vegan | 1.025 [0.623, 1.767] | 0.859 [0.592, 1.233] |

### Unadjusted — raw outcome RR  ·  `A3_t2_mu_gamma.tex`

| Outcome | Level change | Slope change |
|---|---|---|
| Total | 1.172 [0.823, 1.710] | 1.307 [0.926, 1.901] |
| Nonvegan | 1.105 [0.815, 1.550] | 1.297 [0.879, 1.917] |
| Meat | 0.976 [0.789, 1.152] | 1.021 [0.800, 1.739] |
| Chicken Fish | 1.017 [0.795, 1.299] | 1.595 [1.096, 2.334] |
| Vegetarian | 1.092 [0.873, 1.614] | 1.128 [1.007, 1.267] |
| Vegan | 1.230 [0.835, 1.620] | 1.111 [0.998, 1.341] |

---

## Tier Two A4  (`tab:rr_t2_a4`)

### Adjusted — RRR, matches the forest plots  ·  `A4_t2_mu_gamma_adj.tex`

| Outcome | Level change | Slope change |
|---|---|---|
| Breakfast T2 | 0.713 [0.456, 1.093] | 0.757 [0.402, 1.449] |
| Dairy T2 | 1.416 [0.430, 4.667] | 0.691 [0.266, 1.693] |
| Textured T2 | 0.970 [0.402, 2.058] | 0.543 [0.173, 2.089] |
| Untextured T2 | 1.384 [0.363, 4.722] | 0.729 [0.381, 1.295] |

### Unadjusted — raw outcome RR  ·  `A4_t2_mu_gamma.tex`

| Outcome | Level change | Slope change |
|---|---|---|
| Breakfast T2 | 0.826 [0.696, 1.097] | 0.987 [0.593, 1.714] |
| Dairy T2 | 1.680 [0.504, 5.130] | 0.898 [0.363, 2.058] |
| Textured T2 | 1.170 [0.502, 2.179] | 0.699 [0.237, 2.349] |
| Untextured T2 | 1.610 [0.470, 5.108] | 0.983 [0.556, 1.558] |

---

## Tier One A5 (within-customer, general)  (`tab:a5_mu_gamma`)

### Adjusted — RRR, matches the forest plots  ·  `A5_mu_gamma_adj.tex`

| Outcome | Level change | Slope change |
|---|---|---|
| Nonvegan | -0.017 [-0.357, 0.300] | 0.006 [-0.407, 0.366] |
| Meat | 0.018 [-0.261, 0.222] | 0.118 [-0.247, 0.601] |
| Chicken Fish | 0.104 [-0.262, 0.304] | -0.193 [-0.419, 0.081] |
| Vegan | 0.013 [-0.249, 0.219] | -0.047 [-0.349, 0.276] |
| Vegetarian | -0.024 [-0.313, 0.169] | -0.095 [-0.496, 0.392] |

### Unadjusted — raw outcome RR  ·  `A5_mu_gamma.tex`

| Outcome | Level change | Slope change |
|---|---|---|
| Total | -0.004 [-0.157, 0.257] | 0.039 [-0.236, 0.264] |
| Nonvegan | -0.017 [-0.268, 0.222] | 0.037 [-0.259, 0.332] |
| Meat | 0.016 [-0.110, 0.144] | 0.153 [-0.161, 0.584] |
| Chicken Fish | 0.117 [-0.114, 0.194] | -0.182 [-0.199, -0.076] |
| Vegan | 0.013 [-0.093, 0.109] | -0.021 [-0.163, 0.183] |
| Vegetarian | -0.024 [-0.176, 0.102] | -0.054 [-0.383, 0.272] |

---

## Tier One A6 (within-customer, counterpart)  (`tab:a6_mu_gamma`)

### Adjusted — RRR, matches the forest plots  ·  `A6_mu_gamma_adj.tex`

| Outcome | Level change | Slope change |
|---|---|---|
| Breakfast | 0.027 [-0.205, 0.466] | 0.090 [-0.407, 0.535] |
| Untextured | 0.180 [-0.262, 0.715] | -0.237 [-1.019, 0.417] |

### Unadjusted — raw outcome RR  ·  `A6_mu_gamma.tex`

| Outcome | Level change | Slope change |
|---|---|---|
| Breakfast | 0.044 [-0.105, 0.270] | 0.118 [-0.412, 0.729] |
| Untextured | 0.066 [-0.571, 1.242] | -0.023 [-0.693, 0.830] |

---

## Tier Two A5 (within-customer, general)  (`tab:t2_a5_mu_gamma`)

### Adjusted — RRR, matches the forest plots  ·  `A5_t2_mu_gamma_adj.tex`

| Outcome | Level change | Slope change |
|---|---|---|
| Nonvegan | -0.008 [-0.114, 0.089] | -0.012 [-0.135, 0.108] |
| Meat | -0.024 [-0.122, 0.069] | 0.012 [-0.107, 0.133] |
| Chicken Fish | 0.064 [-0.086, 0.146] | -0.013 [-0.127, 0.158] |
| Vegan | -0.017 [-0.095, 0.049] | -0.028 [-0.137, 0.067] |
| Vegetarian | -0.024 [-0.123, 0.083] | -0.016 [-0.151, 0.118] |

### Unadjusted — raw outcome RR  ·  `A5_t2_mu_gamma.tex`

| Outcome | Level change | Slope change |
|---|---|---|
| Total | 0.011 [-0.047, 0.082] | 0.022 [-0.062, 0.125] |
| Nonvegan | 0.007 [-0.077, 0.081] | 0.008 [-0.060, 0.097] |
| Meat | -0.012 [-0.083, 0.061] | 0.037 [-0.049, 0.124] |
| Chicken Fish | 0.080 [-0.022, 0.116] | -0.014 [-0.017, 0.117] |
| Vegan | -0.005 [-0.039, 0.023] | -0.006 [-0.035, 0.035] |
| Vegetarian | -0.013 [-0.084, 0.078] | 0.009 [-0.093, 0.117] |

---

## Tier Two A6 (within-customer, counterpart)  (`tab:t2_a6_mu_gamma`)

### Adjusted — RRR, matches the forest plots  ·  `A6_t2_mu_gamma_adj.tex`

| Outcome | Level change | Slope change |
|---|---|---|
| Breakfast T2 | -0.002 [-0.092, 0.078] | 0.020 [-0.127, 0.165] |
| Dairy T2 | 0.073 [-0.571, 0.822] | -0.158 [-0.698, 0.221] |
| Textured T2 | -0.065 [-0.274, 0.196] | -0.155 [-1.344, 1.303] |
| Untextured T2 | -0.036 [-0.204, 0.034] | -0.072 [-0.230, 0.104] |

### Unadjusted — raw outcome RR  ·  `A6_t2_mu_gamma.tex`

| Outcome | Level change | Slope change |
|---|---|---|
| Breakfast T2 | 0.010 [-0.051, 0.060] | 0.044 [-0.071, 0.159] |
| Dairy T2 | 0.096 [-0.592, 0.834] | -0.136 [-0.715, 0.385] |
| Untextured T2 | -0.007 [-0.143, -0.004] | -0.048 [-0.136, 0.064] |

---
## Which Supplement tables need changing

Every one of the eight A1–A4 tables needs at least a numeric refresh, because all
48 table files were generated in May from a CSV that predates every refit. Sorted
by how much work each needs.

### Structural — rows appear, disappear, or get renamed

| table | change |
|---|---|
| `tab:rr_t2_a3` | **Currently empty** — has a header and no rows at all. Five rows now available. |
| `tab:rr_t1_a2` | 4 rows → **5**; `Untextured` is new. Every Presence value changes (see below). |
| `tab:rr_t1_a4` | 2 rows → **3**; `Ground meat` → `Untextured`, and `Textured` is new. |
| `tab:rr_t2_a2` | 5 rows → **6**; `Textured` is new, and a whole **Presence column** now exists. |
| `tab:rr_t2_a4` | `Chicken` **disappears** (that model was retired — its outcome was identically zero); `Textured` is new. |
| `tab:a6_mu_gamma` | `Ground meat` → `Untextured`. |
| `tab:t2_a6_mu_gamma` | 5 rows → **4**; `Chicken` disappears (retired), `Whole-muscle meat` → `Textured`, `Ground meat` → `Untextured`. |

Naming throughout: **`Untextured` = ground meat**, **`Textured` = whole-muscle meat**.
Either rename the rows in the tables or keep the paper's wording — but pick one and
apply it to the figures too.

### The Presence column of `tab:rr_t1_a2` was wrong by ~10× on the log scale

Presence is a 0/1 indicator, but the generator applied the *proportion* transform
`exp(0.1x)`, pulling every presence estimate ten times closer to the null.

| outcome | Supplement prints | correct |
|---|---|---|
| Breakfast-style meat | 0.694 [0.190, 3.392] | **0.615** [0.182, 2.345] |
| Chicken | 0.999 [0.235, 4.869] | **1.133** [0.405, 3.588] |
| Dairy | 0.835 [0.205, 3.653] | **0.760** [0.275, 2.402] |
| Egg | 0.878 [0.185, 4.060] | **0.735** [0.268, 2.408] |
| Untextured | — | **0.855** [0.316, 2.747] |

### Numeric-only drift

| table | worst-moving cell | note |
|---|---|---|
| `tab:rr_t1_a1` | Meat×Vegetarian prop 0.860 → **0.857** | CIs unchanged; only points move, ≤0.02. A1 was never refit. |
| `tab:rr_t1_a3` | Chicken & fish level 0.882 → **0.900** | all 10 cells move |
| `tab:rr_t2_a1` | Meat×Vegetarian prop 0.901 → **0.900** | changes are ≤0.005 throughout |
| `tab:a5_mu_gamma` | Chicken & fish level 0.059 → **0.104** | |
| `tab:t2_a5_mu_gamma` | Chicken & fish level 0.045 → **0.064**; slope 0.003 → **−0.013** (sign flips) | |

### Two new results worth noticing

- **`tab:rr_t1_a4`, Textured slope change: 0.343 [0.154, 0.800]** — CI excludes 1.
  This is a newly significant estimate that is not in the paper.
- **`tab:rr_t2_a2` Presence** — the Supplement says *"presence exposures are omitted
  for Tier Two."* They now exist and several are large (Untextured 6.86 [1.45, 28.9]).
  Decide whether to print them or keep the omission and say why.

## Decisions you have to make before pasting anything in

1. **RR or RRR in the Supplement?** The tables there are RRRs; the prose calls them
   unadjusted RRs. Either swap in the `*_mu_gamma.tex` (unadjusted) tables — which
   are **stale, from `finalized_redone_trunc`, and would need a fresh extraction** —
   or fix the sentence to say "adjusted RRRs." The second is one line of text.
2. **Suppression rule.** The regenerated tables include single-restaurant outcomes
   that the *figures* suppress (`Untextured` in T1 A2; `Textured`/`Untextured` in
   T1 A4). The generator has no `n_rest <= 1` filter. If tables should match figures,
   those rows come out — and T1 A2/A4 drop to 4 and 2 estimates, matching the diagram.
3. **Wait on T2.** T2 A2 is still refitting; T1 A4/A6 are a generation behind. Only
   T1 A2 is safe to paste in as final today.
4. **Table note is wrong.** It reads *"Outcomes with a single contributing restaurant
   have no pooled estimate and are omitted"* — but the rule that produced these tables
   is no filter at all, and the figures' rule is `n_rest <= 1`, i.e. "fewer than two."

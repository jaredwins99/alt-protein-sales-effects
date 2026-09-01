# Final Supplement tables

**These tables report the unadjusted rate ratio (RR)** for each estimate: the raw
outcome-model effect on its own. The forest plots report the **adjusted ratio of
rate ratios (RRR)** for the same estimates. The two are different information about
the same underlying construct, so the reader can see both.

Rebuild with:

```
Rscript publication/scripts/build_final_models.R
Rscript publication/scripts/final_tables.R
python3 publication/scripts/build_final_tables_md.py
```

## Where the estimate set comes from

`publication/config/final_models.csv` is the single source of truth for which
estimates are reported and in what order. It is generated from the renderers' own
rules, so a table can never show a different set of estimates than the figure
beside it. One row per cell, carrying the `fit_dir` and `total_dir` each value
came from, the contributing-restaurant count, and the suppression reason where
one applies.

Currently **147 reported** cells and **19 suppressed**:

- fewer than two contributing restaurants — 14
- presence not estimable in Tier Two — 4
- pooled outside both restaurant estimates — 1

Labels follow the renderers: **`untextured` = Ground meat**, **`textured` =
Whole-muscle meat**. Whole-muscle is deliberately absent from A2 in both tiers.
`---` marks a suppressed cell; `TBD` marks one whose RR has not been extracted yet.

---

# Section 3.2.3 - Tier One underlying tables

## Tier One A1

`tab:rr_t1_a1` · `publication/tables_final/t1_a1.tex`

| Outcome | Exposure | Count | Proportion |
|---|---|---|---|
| Total | Alt-Protein-Modifiable | 1.035 [0.897, 1.158] | 1.027 [0.915, 1.135] |
| Nonvegan | Alt-Protein-Modifiable | 1.037 [0.793, 1.155] | 1.020 [0.914, 1.109] |
| Meat | Alt-Protein-Modifiable | 1.021 [0.921, 1.141] | 1.057 [0.969, 1.127] |
| Chicken \ | fish | Alt-Protein-Modifiable | 1.009 [0.906, 1.100] | 1.035 [0.881, 1.186] |
| Vegetarian | Alt-Protein-Modifiable | 1.066 [0.818, 1.315] | 0.992 [0.859, 1.143] |
| Vegan | Alt-Protein-Modifiable | 1.034 [0.909, 1.188] | 1.001 [0.890, 1.126] |
| Total | Vegan | 1.216 [0.858, 1.627] | 1.092 [0.970, 1.221] |
| Nonvegan | Vegan | 1.190 [0.803, 1.613] | 1.072 [0.957, 1.195] |
| Meat | Vegan | 1.221 [0.832, 1.850] | 1.014 [0.894, 1.150] |
| Chicken \ | fish | Vegan | 1.107 [0.849, 1.504] | 0.978 [0.847, 1.142] |
| Vegetarian | Vegan | 1.179 [0.934, 1.532] | 1.101 [1.008, 1.214] |
| Vegan | Vegan | 1.132 [0.916, 1.442] | 1.170 [1.019, 1.291] |
| Total | Vegetarian | 1.045 [1.003, 1.105] | 1.101 [0.987, 1.197] |
| Nonvegan | Vegetarian | 1.044 [0.988, 1.100] | 1.076 [0.996, 1.164] |
| Meat | Vegetarian | 1.022 [0.977, 1.071] | 0.942 [0.860, 1.053] |
| Chicken \ | fish | Vegetarian | 1.063 [0.927, 1.283] | 0.927 [0.791, 1.111] |
| Vegetarian | Vegetarian | 1.068 [0.971, 1.166] | 1.220 [1.059, 1.300] |
| Vegan | Vegetarian | 1.049 [0.989, 1.121] | 1.135 [1.023, 1.243] |

<details><summary>LaTeX</summary>

```latex
\begin{table}[H]
\centering
\caption{Pooled unadjusted rate ratios, Tier One A1}
\label{tab:rr_t1_a1}
\begin{tabular}{llcc}
\toprule
Outcome & Exposure & Count & Proportion \\
\midrule
Total & Alt-Protein-Modifiable & 1.035 [0.897, 1.158] & 1.027 [0.915, 1.135] \\
Nonvegan & Alt-Protein-Modifiable & 1.037 [0.793, 1.155] & 1.020 [0.914, 1.109] \\
Meat & Alt-Protein-Modifiable & 1.021 [0.921, 1.141] & 1.057 [0.969, 1.127] \\
Chicken \& fish & Alt-Protein-Modifiable & 1.009 [0.906, 1.100] & 1.035 [0.881, 1.186] \\
Vegetarian & Alt-Protein-Modifiable & 1.066 [0.818, 1.315] & 0.992 [0.859, 1.143] \\
Vegan & Alt-Protein-Modifiable & 1.034 [0.909, 1.188] & 1.001 [0.890, 1.126] \\
Total & Vegan & 1.216 [0.858, 1.627] & 1.092 [0.970, 1.221] \\
Nonvegan & Vegan & 1.190 [0.803, 1.613] & 1.072 [0.957, 1.195] \\
Meat & Vegan & 1.221 [0.832, 1.850] & 1.014 [0.894, 1.150] \\
Chicken \& fish & Vegan & 1.107 [0.849, 1.504] & 0.978 [0.847, 1.142] \\
Vegetarian & Vegan & 1.179 [0.934, 1.532] & 1.101 [1.008, 1.214] \\
Vegan & Vegan & 1.132 [0.916, 1.442] & 1.170 [1.019, 1.291] \\
Total & Vegetarian & 1.045 [1.003, 1.105] & 1.101 [0.987, 1.197] \\
Nonvegan & Vegetarian & 1.044 [0.988, 1.100] & 1.076 [0.996, 1.164] \\
Meat & Vegetarian & 1.022 [0.977, 1.071] & 0.942 [0.860, 1.053] \\
Chicken \& fish & Vegetarian & 1.063 [0.927, 1.283] & 0.927 [0.791, 1.111] \\
Vegetarian & Vegetarian & 1.068 [0.971, 1.166] & 1.220 [1.059, 1.300] \\
Vegan & Vegetarian & 1.049 [0.989, 1.121] & 1.135 [1.023, 1.243] \\
\bottomrule
\end{tabular}
\par\smallskip\footnotesize Pooled unadjusted rate ratios with 95\% credible intervals. Count: per additional menu item; Proportion: per 10-percentage-point increase. These are the outcome-model effects on their own; the corresponding figures show them adjusted for total purchases, as ratios of rate ratios. Estimates backed by fewer than two contributing restaurants are not pooled and are shown as ---.
\end{table}
```

</details>

## Tier One A2

`tab:rr_t1_a2` · `publication/tables_final/t1_a2.tex`

| Outcome | Count |
|---|---|
| Breakfast-style meat | 0.948 [0.689, 1.281] |
| Chicken | 1.073 [0.669, 1.805] |
| Dairy | 1.035 [0.929, 1.138] |
| Egg | 1.068 [0.558, 1.930] |

<details><summary>LaTeX</summary>

```latex
\begin{table}[H]
\centering
\caption{Pooled unadjusted rate ratios, Tier One A2}
\label{tab:rr_t1_a2}
\begin{tabular}{lc}
\toprule
Outcome & Count \\
\midrule
Breakfast-style meat & 0.948 [0.689, 1.281] \\
Chicken & 1.073 [0.669, 1.805] \\
Dairy & 1.035 [0.929, 1.138] \\
Egg & 1.068 [0.558, 1.930] \\
\bottomrule
\end{tabular}
\par\smallskip\footnotesize Pooled unadjusted rate ratios with 95\% credible intervals. These are the outcome-model effects on their own; the corresponding figures show them adjusted for total purchases, as ratios of rate ratios. Estimates backed by fewer than two contributing restaurants are not pooled and are shown as ---.
\end{table}
```

</details>

## Tier One A3

`tab:rr_t1_a3` · `publication/tables_final/t1_a3.tex`

| Outcome | Level change | Slope change |
|---|---|---|
| Total | 1.066 [0.973, 1.190] | 1.863 [1.103, 2.602] |
| Nonvegan | 1.055 [0.943, 1.174] | 1.815 [1.110, 2.596] |
| Meat | 1.018 [0.910, 1.093] | 1.741 [1.057, 2.373] |
| Chicken \ | fish | 0.966 [0.684, 1.114] | 1.781 [0.764, 3.296] |
| Vegetarian | 1.090 [0.899, 1.342] | 1.453 [1.045, 2.404] |
| Vegan | 1.108 [1.004, 1.347] | 1.079 [0.628, 2.007] |

<details><summary>LaTeX</summary>

```latex
\begin{table}[H]
\centering
\caption{Pooled unadjusted rate ratios, Tier One A3}
\label{tab:rr_t1_a3}
\begin{tabular}{lcc}
\toprule
Outcome & Level change & Slope change \\
\midrule
Total & 1.066 [0.973, 1.190] & 1.863 [1.103, 2.602] \\
Nonvegan & 1.055 [0.943, 1.174] & 1.815 [1.110, 2.596] \\
Meat & 1.018 [0.910, 1.093] & 1.741 [1.057, 2.373] \\
Chicken \& fish & 0.966 [0.684, 1.114] & 1.781 [0.764, 3.296] \\
Vegetarian & 1.090 [0.899, 1.342] & 1.453 [1.045, 2.404] \\
Vegan & 1.108 [1.004, 1.347] & 1.079 [0.628, 2.007] \\
\bottomrule
\end{tabular}
\par\smallskip\footnotesize Pooled unadjusted rate ratios with 95\% credible intervals. These are the outcome-model effects on their own; the corresponding figures show them adjusted for total purchases, as ratios of rate ratios. Estimates backed by fewer than two contributing restaurants are not pooled and are shown as ---.
\end{table}
```

</details>

## Tier One A4

`tab:rr_t1_a4` · `publication/tables_final/t1_a4.tex`

| Outcome | Level change | Slope change |
|---|---|---|
| Breakfast-style meat | 0.834 [0.571, 1.217] | 0.801 [0.332, 2.225] |

<details><summary>LaTeX</summary>

```latex
\begin{table}[H]
\centering
\caption{Pooled unadjusted rate ratios, Tier One A4}
\label{tab:rr_t1_a4}
\begin{tabular}{lcc}
\toprule
Outcome & Level change & Slope change \\
\midrule
Breakfast-style meat & 0.834 [0.571, 1.217] & 0.801 [0.332, 2.225] \\
\bottomrule
\end{tabular}
\par\smallskip\footnotesize Pooled unadjusted rate ratios with 95\% credible intervals. These are the outcome-model effects on their own; the corresponding figures show them adjusted for total purchases, as ratios of rate ratios. Estimates backed by fewer than two contributing restaurants are not pooled and are shown as ---.
\end{table}
```

</details>

---

# Section 3.3.4 - Tier Two underlying tables

## Tier Two A1

`tab:rr_t2_a1` · `publication/tables_final/t2_a1.tex`

| Outcome | Exposure | Count | Proportion |
|---|---|---|---|
| Total | Alt-Protein-Modifiable | 1.028 [0.975, 1.081] | 0.969 [0.874, 1.091] |
| Nonvegan | Alt-Protein-Modifiable | 1.029 [0.975, 1.091] | 0.969 [0.867, 1.085] |
| Meat | Alt-Protein-Modifiable | 1.033 [0.991, 1.081] | 1.008 [0.893, 1.081] |
| Chicken \ | fish | Alt-Protein-Modifiable | 1.043 [0.982, 1.108] | 0.971 [0.857, 1.092] |
| Vegetarian | Alt-Protein-Modifiable | 1.034 [0.973, 1.098] | 0.979 [0.886, 1.102] |
| Vegan | Alt-Protein-Modifiable | 1.049 [0.978, 1.139] | 1.000 [0.877, 1.157] |
| Total | Vegan | 1.116 [1.042, 1.222] | 1.103 [1.031, 1.181] |
| Nonvegan | Vegan | 1.121 [1.033, 1.222] | 1.091 [1.016, 1.164] |
| Meat | Vegan | 1.118 [1.013, 1.230] | 1.064 [0.974, 1.176] |
| Chicken \ | fish | Vegan | 1.061 [0.990, 1.140] | 1.005 [0.893, 1.131] |
| Vegetarian | Vegan | 1.098 [1.043, 1.163] | 1.089 [1.029, 1.155] |
| Vegan | Vegan | 1.138 [1.054, 1.245] | 1.140 [1.028, 1.251] |
| Total | Vegetarian | 1.040 [1.013, 1.074] | 1.047 [0.988, 1.111] |
| Nonvegan | Vegetarian | 1.042 [1.011, 1.077] | 1.030 [0.977, 1.082] |
| Meat | Vegetarian | 1.026 [1.005, 1.051] | 0.941 [0.887, 1.010] |
| Chicken \ | fish | Vegetarian | 1.018 [0.983, 1.053] | 0.869 [0.792, 0.969] |
| Vegetarian | Vegetarian | 1.055 [1.012, 1.092] | 1.085 [1.013, 1.156] |
| Vegan | Vegetarian | 1.055 [1.007, 1.106] | 1.032 [0.957, 1.115] |

<details><summary>LaTeX</summary>

```latex
\begin{table}[H]
\centering
\caption{Pooled unadjusted rate ratios, Tier Two A1}
\label{tab:rr_t2_a1}
\begin{tabular}{llcc}
\toprule
Outcome & Exposure & Count & Proportion \\
\midrule
Total & Alt-Protein-Modifiable & 1.028 [0.975, 1.081] & 0.969 [0.874, 1.091] \\
Nonvegan & Alt-Protein-Modifiable & 1.029 [0.975, 1.091] & 0.969 [0.867, 1.085] \\
Meat & Alt-Protein-Modifiable & 1.033 [0.991, 1.081] & 1.008 [0.893, 1.081] \\
Chicken \& fish & Alt-Protein-Modifiable & 1.043 [0.982, 1.108] & 0.971 [0.857, 1.092] \\
Vegetarian & Alt-Protein-Modifiable & 1.034 [0.973, 1.098] & 0.979 [0.886, 1.102] \\
Vegan & Alt-Protein-Modifiable & 1.049 [0.978, 1.139] & 1.000 [0.877, 1.157] \\
Total & Vegan & 1.116 [1.042, 1.222] & 1.103 [1.031, 1.181] \\
Nonvegan & Vegan & 1.121 [1.033, 1.222] & 1.091 [1.016, 1.164] \\
Meat & Vegan & 1.118 [1.013, 1.230] & 1.064 [0.974, 1.176] \\
Chicken \& fish & Vegan & 1.061 [0.990, 1.140] & 1.005 [0.893, 1.131] \\
Vegetarian & Vegan & 1.098 [1.043, 1.163] & 1.089 [1.029, 1.155] \\
Vegan & Vegan & 1.138 [1.054, 1.245] & 1.140 [1.028, 1.251] \\
Total & Vegetarian & 1.040 [1.013, 1.074] & 1.047 [0.988, 1.111] \\
Nonvegan & Vegetarian & 1.042 [1.011, 1.077] & 1.030 [0.977, 1.082] \\
Meat & Vegetarian & 1.026 [1.005, 1.051] & 0.941 [0.887, 1.010] \\
Chicken \& fish & Vegetarian & 1.018 [0.983, 1.053] & 0.869 [0.792, 0.969] \\
Vegetarian & Vegetarian & 1.055 [1.012, 1.092] & 1.085 [1.013, 1.156] \\
Vegan & Vegetarian & 1.055 [1.007, 1.106] & 1.032 [0.957, 1.115] \\
\bottomrule
\end{tabular}
\par\smallskip\footnotesize Pooled unadjusted rate ratios with 95\% credible intervals. Count: per additional menu item; Proportion: per 10-percentage-point increase. These are the outcome-model effects on their own; the corresponding figures show them adjusted for total purchases, as ratios of rate ratios. Estimates backed by fewer than two contributing restaurants are not pooled and are shown as ---.
\end{table}
```

</details>

## Tier Two A2

`tab:rr_t2_a2` · `publication/tables_final/t2_a2.tex`

| Outcome | Count |
|---|---|
| Breakfast-style meat | 1.152 [0.883, 1.512] |
| Ground meat | 1.041 [0.933, 1.169] |
| Chicken | 1.038 [0.753, 1.403] |
| Dairy | 1.036 [0.963, 1.125] |
| Egg | 1.053 [0.974, 1.122] |

<details><summary>LaTeX</summary>

```latex
\begin{table}[H]
\centering
\caption{Pooled unadjusted rate ratios, Tier Two A2}
\label{tab:rr_t2_a2}
\begin{tabular}{lc}
\toprule
Outcome & Count \\
\midrule
Breakfast-style meat & 1.152 [0.883, 1.512] \\
Ground meat & 1.041 [0.933, 1.169] \\
Chicken & 1.038 [0.753, 1.403] \\
Dairy & 1.036 [0.963, 1.125] \\
Egg & 1.053 [0.974, 1.122] \\
\bottomrule
\end{tabular}
\par\smallskip\footnotesize Pooled unadjusted rate ratios with 95\% credible intervals. These are the outcome-model effects on their own; the corresponding figures show them adjusted for total purchases, as ratios of rate ratios. Estimates backed by fewer than two contributing restaurants are not pooled and are shown as ---.
\end{table}
```

</details>

## Tier Two A3

`tab:rr_t2_a3` · `publication/tables_final/t2_a3.tex`

| Outcome | Level change | Slope change |
|---|---|---|
| Total | 1.172 [0.823, 1.710] | 1.307 [0.926, 1.901] |
| Nonvegan | 1.105 [0.815, 1.550] | 1.297 [0.879, 1.917] |
| Meat | 0.976 [0.789, 1.152] | 1.021 [0.800, 1.739] |
| Chicken \ | fish | 1.017 [0.795, 1.299] | 1.595 [1.096, 2.334] |
| Vegetarian | 1.092 [0.873, 1.614] | 1.128 [1.007, 1.267] |
| Vegan | 1.230 [0.835, 1.620] | 1.111 [0.998, 1.341] |

<details><summary>LaTeX</summary>

```latex
\begin{table}[H]
\centering
\caption{Pooled unadjusted rate ratios, Tier Two A3}
\label{tab:rr_t2_a3}
\begin{tabular}{lcc}
\toprule
Outcome & Level change & Slope change \\
\midrule
Total & 1.172 [0.823, 1.710] & 1.307 [0.926, 1.901] \\
Nonvegan & 1.105 [0.815, 1.550] & 1.297 [0.879, 1.917] \\
Meat & 0.976 [0.789, 1.152] & 1.021 [0.800, 1.739] \\
Chicken \& fish & 1.017 [0.795, 1.299] & 1.595 [1.096, 2.334] \\
Vegetarian & 1.092 [0.873, 1.614] & 1.128 [1.007, 1.267] \\
Vegan & 1.230 [0.835, 1.620] & 1.111 [0.998, 1.341] \\
\bottomrule
\end{tabular}
\par\smallskip\footnotesize Pooled unadjusted rate ratios with 95\% credible intervals. These are the outcome-model effects on their own; the corresponding figures show them adjusted for total purchases, as ratios of rate ratios. Estimates backed by fewer than two contributing restaurants are not pooled and are shown as ---.
\end{table}
```

</details>

## Tier Two A4

`tab:rr_t2_a4` · `publication/tables_final/t2_a4.tex`

| Outcome | Level change | Slope change |
|---|---|---|
| Breakfast-style meat | 0.826 [0.696, 1.097] | 0.987 [0.593, 1.714] |
| Dairy | 1.680 [0.504, 5.130] | 0.898 [0.363, 2.058] |
| Whole-muscle meat | 1.170 [0.502, 2.179] | 0.699 [0.237, 2.349] |
| Ground meat | 1.610 [0.470, 5.108] | 0.983 [0.556, 1.558] |

<details><summary>LaTeX</summary>

```latex
\begin{table}[H]
\centering
\caption{Pooled unadjusted rate ratios, Tier Two A4}
\label{tab:rr_t2_a4}
\begin{tabular}{lcc}
\toprule
Outcome & Level change & Slope change \\
\midrule
Breakfast-style meat & 0.826 [0.696, 1.097] & 0.987 [0.593, 1.714] \\
Dairy & 1.680 [0.504, 5.130] & 0.898 [0.363, 2.058] \\
Whole-muscle meat & 1.170 [0.502, 2.179] & 0.699 [0.237, 2.349] \\
Ground meat & 1.610 [0.470, 5.108] & 0.983 [0.556, 1.558] \\
\bottomrule
\end{tabular}
\par\smallskip\footnotesize Pooled unadjusted rate ratios with 95\% credible intervals. These are the outcome-model effects on their own; the corresponding figures show them adjusted for total purchases, as ratios of rate ratios. Estimates backed by fewer than two contributing restaurants are not pooled and are shown as ---.
\end{table}
```

</details>

---

# Section 3.4.1 - Within-customer, Tier One

## Tier One A5

`tab:a5_mu_gamma` · `publication/tables_final/t1_a5.tex`

| Outcome | Level change | Slope change |
|---|---|---|
| Total | -0.004 [-0.157, 0.257] | 0.039 [-0.236, 0.264] |
| Nonvegan | -0.017 [-0.268, 0.222] | 0.037 [-0.259, 0.332] |
| Meat | 0.016 [-0.110, 0.144] | 0.153 [-0.161, 0.584] |
| Chicken \ | fish | 0.117 [-0.114, 0.194] | -0.182 [-0.199, -0.076] |
| Vegetarian | -0.024 [-0.176, 0.102] | -0.054 [-0.383, 0.272] |
| Vegan | 0.013 [-0.093, 0.109] | -0.021 [-0.163, 0.183] |

<details><summary>LaTeX</summary>

```latex
\begin{table}[H]
\centering
\caption{Pooled unadjusted rate ratios, Tier One A5}
\label{tab:a5_mu_gamma}
\begin{tabular}{lcc}
\toprule
Outcome & Level change & Slope change \\
\midrule
Total & -0.004 [-0.157, 0.257] & 0.039 [-0.236, 0.264] \\
Nonvegan & -0.017 [-0.268, 0.222] & 0.037 [-0.259, 0.332] \\
Meat & 0.016 [-0.110, 0.144] & 0.153 [-0.161, 0.584] \\
Chicken \& fish & 0.117 [-0.114, 0.194] & -0.182 [-0.199, -0.076] \\
Vegetarian & -0.024 [-0.176, 0.102] & -0.054 [-0.383, 0.272] \\
Vegan & 0.013 [-0.093, 0.109] & -0.021 [-0.163, 0.183] \\
\bottomrule
\end{tabular}
\par\smallskip\footnotesize Pooled unadjusted customer-level effects (identity link) with 95\% credible intervals. These are the outcome-model effects on their own; the corresponding figures show them adjusted for total purchases, as ratios of rate ratios. Estimates backed by fewer than two contributing restaurants are not pooled and are shown as ---.
\end{table}
```

</details>

## Tier One A6

`tab:a6_mu_gamma` · `publication/tables_final/t1_a6.tex`

| Outcome | Level change | Slope change |
|---|---|---|
| Breakfast-style meat | 0.025 [-0.181, 0.320] | 0.120 [-0.363, 0.589] |

<details><summary>LaTeX</summary>

```latex
\begin{table}[H]
\centering
\caption{Pooled unadjusted rate ratios, Tier One A6}
\label{tab:a6_mu_gamma}
\begin{tabular}{lcc}
\toprule
Outcome & Level change & Slope change \\
\midrule
Breakfast-style meat & 0.025 [-0.181, 0.320] & 0.120 [-0.363, 0.589] \\
\bottomrule
\end{tabular}
\par\smallskip\footnotesize Pooled unadjusted customer-level effects (identity link) with 95\% credible intervals. These are the outcome-model effects on their own; the corresponding figures show them adjusted for total purchases, as ratios of rate ratios. Estimates backed by fewer than two contributing restaurants are not pooled and are shown as ---.
\end{table}
```

</details>

---

# Section 3.4.2 - Within-customer, Tier Two

## Tier Two A5

`tab:t2_a5_mu_gamma` · `publication/tables_final/t2_a5.tex`

| Outcome | Level change | Slope change |
|---|---|---|
| Total | 0.011 [-0.047, 0.082] | 0.022 [-0.062, 0.125] |
| Nonvegan | 0.007 [-0.077, 0.081] | 0.008 [-0.060, 0.097] |
| Meat | -0.012 [-0.083, 0.061] | 0.037 [-0.049, 0.124] |
| Chicken \ | fish | 0.080 [-0.022, 0.116] | -0.014 [-0.017, 0.117] |
| Vegetarian | -0.013 [-0.084, 0.078] | 0.009 [-0.093, 0.117] |
| Vegan | -0.005 [-0.039, 0.023] | -0.006 [-0.035, 0.035] |

<details><summary>LaTeX</summary>

```latex
\begin{table}[H]
\centering
\caption{Pooled unadjusted rate ratios, Tier Two A5}
\label{tab:t2_a5_mu_gamma}
\begin{tabular}{lcc}
\toprule
Outcome & Level change & Slope change \\
\midrule
Total & 0.011 [-0.047, 0.082] & 0.022 [-0.062, 0.125] \\
Nonvegan & 0.007 [-0.077, 0.081] & 0.008 [-0.060, 0.097] \\
Meat & -0.012 [-0.083, 0.061] & 0.037 [-0.049, 0.124] \\
Chicken \& fish & 0.080 [-0.022, 0.116] & -0.014 [-0.017, 0.117] \\
Vegetarian & -0.013 [-0.084, 0.078] & 0.009 [-0.093, 0.117] \\
Vegan & -0.005 [-0.039, 0.023] & -0.006 [-0.035, 0.035] \\
\bottomrule
\end{tabular}
\par\smallskip\footnotesize Pooled unadjusted customer-level effects (identity link) with 95\% credible intervals. These are the outcome-model effects on their own; the corresponding figures show them adjusted for total purchases, as ratios of rate ratios. Estimates backed by fewer than two contributing restaurants are not pooled and are shown as ---.
\end{table}
```

</details>

## Tier Two A6

`tab:t2_a6_mu_gamma` · `publication/tables_final/t2_a6.tex`

| Outcome | Level change | Slope change |
|---|---|---|
| Breakfast-style meat | 0.010 [-0.051, 0.060] | 0.044 [-0.071, 0.159] |
| Dairy | 0.054 [-0.548, 0.718] | -0.106 [-0.571, 0.252] |
| Ground meat | -0.081 [-0.255, 0.220] | 0.044 [-0.104, 0.055] |

<details><summary>LaTeX</summary>

```latex
\begin{table}[H]
\centering
\caption{Pooled unadjusted rate ratios, Tier Two A6}
\label{tab:t2_a6_mu_gamma}
\begin{tabular}{lcc}
\toprule
Outcome & Level change & Slope change \\
\midrule
Breakfast-style meat & 0.010 [-0.051, 0.060] & 0.044 [-0.071, 0.159] \\
Dairy & 0.054 [-0.548, 0.718] & -0.106 [-0.571, 0.252] \\
Ground meat & -0.081 [-0.255, 0.220] & 0.044 [-0.104, 0.055] \\
\bottomrule
\end{tabular}
\par\smallskip\footnotesize Pooled unadjusted customer-level effects (identity link) with 95\% credible intervals. These are the outcome-model effects on their own; the corresponding figures show them adjusted for total purchases, as ratios of rate ratios. Estimates backed by fewer than two contributing restaurants are not pooled and are shown as ---.
\end{table}
```

</details>

---

## Not covered here

`tab:impossible_estimates` is a restaurant-level table, not a pooled one, so it
falls outside this generator and still needs a separate refresh.

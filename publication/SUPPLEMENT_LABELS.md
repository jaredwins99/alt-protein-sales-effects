# Supplement labels and cross-references

## 0. The blocking problem: 22 figures share one label

Every `\begin{figure}` in the Supplement ends with `\label{fig:framework}`. LaTeX
keeps only the last definition, so every `\ref` to a Supplement figure resolves to
the same float. This must be fixed before any dynamic referencing works.

`\label{fig:framework}` is also used in **main.tex** for the framework diagram.
Separate documents, so no clash — but keep it there and rename all Supplement ones.

## 1. Enabling cross-document references

Main and Supplement compile separately, so `\ref` cannot reach across on its own.
Add to **main.tex** preamble:

```latex
\usepackage{xr-hyper}   % load BEFORE hyperref
\externaldocument[S-]{supplement}
```

Then a Supplement section is cited from Main as `\ref{S-sec:s_effect_estimation}`.
Compile the Supplement first so `supplement.aux` exists.

## 2. Where the two new accounting tables go

**Supplement Section 2.3.1 (Modeling)**, replacing the opening sentence. That
paragraph currently asserts the model and effect counts in prose; the tables are
that assertion, itemised.

Replace:

> The entire estimation process entailed fitting 63 Tier One models and 68 Tier
> Two models. These models were used to estimate the 46 reported Tier One effects
> and 51 reported Tier Two effects.

with:

```latex
Tables~\ref{tab:s_accounting_t1} and~\ref{tab:s_accounting_t2} account for every
model and estimate, from the full design through the preregistered set to what is
reported. Fitting entailed 63 Tier One and 66 Tier Two models, yielding the 46
reported Tier One and 55 reported Tier Two effects.
```

Then insert `estimate_accounting_t1.tex` and `estimate_accounting_t2.tex`, with
labels `tab:s_accounting_t1` and `tab:s_accounting_t2`.

Note two corrections folded in: **68 becomes 66** (the stated figure counts two
retired chicken models) and **51 becomes 55**.

## 3. Section labels

Add `\label{...}` immediately after each heading.

| section | heading | label |
|---|---|---|
| 1 | Overview | `sec:s_overview` |
| 1.1 | Roadmap of contents | `sec:s_roadmap` |
| 1.2 | Preregistration and code repositories | `sec:s_prereg` |
| 2 | Methods | `sec:s_methods` |
| 2.1 | Data curation | `sec:s_data_curation` |
| 2.1.1 | Data quality control | `sec:s_data_quality` |
| 2.2 | Variable measurement | `sec:s_variable_measurement` |
| 2.2.1 | Outcome measurement: automated labeling | `sec:s_outcome_labeling` |
| 2.2.2 | Exposure measurement: menu reconstruction | `sec:s_menu_reconstruction` |
| 2.2.3 | Auxiliary data | `sec:s_auxiliary` |
| 2.3 | Effect estimation | `sec:s_effect_estimation` |
| 2.3.1 | Modeling | `sec:s_modeling` |
| 2.3.2 | Model evaluation | `sec:s_model_evaluation` |
| 2.3.3 | Robustness checks | `sec:s_robustness` |
| 2.3.4 | Within-customer modeling | `sec:s_within_customer_modeling` |
| 3 | Results | `sec:s_results` |
| 3.1 | Descriptive statistics | `sec:s_descriptives` |
| 3.1.1 | Tier one | `sec:s_desc_t1` |
| 3.1.2 | Tier two | `sec:s_desc_t2` |
| 3.2 | Tier one results | `sec:s_t1_results` |
| 3.2.1 | Impossible exploratory analysis | `sec:s_impossible` |
| 3.2.2 | Restaurant-labeled T1 plots | `sec:s_t1_plots` |
| 3.2.3 | Underlying rate ratio tables | `sec:s_t1_tables` |
| 3.3 | Tier two results | `sec:s_t2_results` |
| 3.3.1 | Tier two results summary | `sec:s_t2_summary` |
| 3.3.2 | Sorted T2 plots | `sec:s_t2_plots_sorted` |
| 3.3.3 | Restaurant-labeled T2 plots | `sec:s_t2_plots_labeled` |
| 3.3.4 | Underlying rate ratio tables | `sec:s_t2_tables` |
| 3.4 | Within-customer sensitivity analysis results | `sec:s_sens_results` |
| 3.4.1 | Tier one sorted plots | `sec:s_sens_t1_plots` |
| 3.4.2 | Tier two sorted plots | `sec:s_sens_t2_plots` |
| 3.4.3 | Tier one underlying rate ratio tables | `sec:s_sens_t1_tables` |
| 3.4.4 | Tier two underlying rate ratio tables | `sec:s_sens_t2_tables` |

## 4. Figure labels — replace all 22 `fig:framework`

In document order:

| # | section | image | new label |
|---|---|---|---|
| 1 | 3.2.2 | `T1_labeled/A1_proportion` | `fig:s_t1lab_a1` |
| 2 | 3.2.2 | `T1_labeled/A2_proportion_targeted` | `fig:s_t1lab_a2` |
| 3 | 3.2.2 | `T1_labeled/A3_its` | `fig:s_t1lab_a3` |
| 4 | 3.2.2 | `T1_labeled/A4_its_targeted` | `fig:s_t1lab_a4` |
| 5 | 3.3.2 | `T2/A1a_proportion` | `fig:s_t2_a1a` |
| 6 | 3.3.2 | `T2/A1b_proportion` | `fig:s_t2_a1b` |
| 7 | 3.3.2 | `T2/A1c_proportion` | `fig:s_t2_a1c` |
| 8 | 3.3.2 | `T2/A2_proportion_targeted` | `fig:s_t2_a2` |
| 9 | 3.3.2 | `T2/A3a_its` | `fig:s_t2_a3a` |
| 10 | 3.3.2 | `T2/A3b_its` | `fig:s_t2_a3b` |
| 11 | 3.3.2 | `T2/A4_its_targeted` | `fig:s_t2_a4` |
| 12 | 3.3.3 | `T2_labeled/A1a_proportion` | `fig:s_t2lab_a1a` |
| 13 | 3.3.3 | `T2_labeled/A1b_proportion` | `fig:s_t2lab_a1b` |
| 14 | 3.3.3 | `T2_labeled/A1c_proportion` | `fig:s_t2lab_a1c` |
| 15 | 3.3.3 | `T2_labeled/A2_proportion_targeted` | `fig:s_t2lab_a2` |
| 16 | 3.3.3 | `T2_labeled/A3a_its` | `fig:s_t2lab_a3a` |
| 17 | 3.3.3 | `T2_labeled/A3b_its` | `fig:s_t2lab_a3b` |
| 18 | 3.3.3 | `T2_labeled/A4_its_targeted` | `fig:s_t2lab_a4` |
| 19 | 3.4.1 | `sensitivity_T1/A5_gaussian_iid_day` | `fig:s_t1_a5` |
| 20 | 3.4.1 | `sensitivity_T1/A6_gaussian_iid_day_targeted` | `fig:s_t1_a6` |
| 21 | 3.4.2 | `sensitivity_T2/A5_gaussian_iid_day` | `fig:s_t2_a5` |
| 22 | 3.4.2 | `sensitivity_T2/A6_gaussian_iid_day_targeted` | `fig:s_t2_a6` |

Figure captions 12 and 14 both read "A1 part 3"; 12 should be "A1 part 1".

## 5. Table labels — already unique, keep as-is

`tab:impossible_estimates`, `tab:rr_t1_a1`--`tab:rr_t1_a4`,
`tab:rr_t2_a1`--`tab:rr_t2_a4`, `tab:a5_mu_gamma`, `tab:a6_mu_gamma`,
`tab:t2_a5_mu_gamma`, `tab:t2_a6_mu_gamma`. Two new: `tab:s_accounting_t1`,
`tab:s_accounting_t2`.

## 6. Main text — replace hardcoded references

| current text | replacement |
|---|---|
| `Supplement, Sections 2.3.4 \& 3.4` | `Supplement, Sections~\ref{S-sec:s_within_customer_modeling} \& \ref{S-sec:s_sens_results}` |
| `see Supplement, Section 2.3` | `see Supplement, Section~\ref{S-sec:s_effect_estimation}` |
| `Supplement, Figures 1-4` | `Supplement, Figures~\ref{S-fig:s_t1lab_a1}--\ref{S-fig:s_t1lab_a4}` |
| `results in Supplement, Section 3.4` | `results in Supplement, Section~\ref{S-sec:s_sens_results}` |
| `Supplement, Section 3.2.1` | `Supplement, Section~\ref{S-sec:s_impossible}` |
| `Supplement, Section 1.2` | `Supplement, Section~\ref{S-sec:s_prereg}` |
| `Supplement, Section 3.3` | `Supplement, Section~\ref{S-sec:s_t2_results}` |
| `Supplement, Section 2.1.1` | `Supplement, Section~\ref{S-sec:s_data_quality}` |
| `Supplement, Section 2.2.1` | `Supplement, Section~\ref{S-sec:s_outcome_labeling}` |
| `Supplement, Section 2.2.2` | `Supplement, Section~\ref{S-sec:s_menu_reconstruction}` |
| `Supplement, Section 2.2.3` | `Supplement, Section~\ref{S-sec:s_auxiliary}` |
| `Section 2.3 of the Supplement` | `Section~\ref{S-sec:s_effect_estimation} of the Supplement` |
| `Supplement, Section 2.2` | `Supplement, Section~\ref{S-sec:s_variable_measurement}` |

## 7. Bugs found while mapping

- **Main, A2 subsection**: "insufficient restaurants ... (Figure 5)" points to the
  A4 figure. It should be the A2 figure: `(Figure~\ref{fig:plot2})`.
- **Supplement 3.2.1**: "Table reports the within-restaurant estimates" is missing
  its reference — should be `Table~\ref{tab:impossible_estimates}`.
- **Main, Results**: "(267)" within-restaurant estimates matches Tier One A1--A4
  exactly. Confirmed, no change.

# Supplement labels — reference table

All labels below are now defined in the Supplement. Cite them from the Supplement
directly, and from Main after uncommenting `\myexternaldocument{supplement}` in
`preamble_main.tex`.

## A. Sections

| label | section | what it covers |
|---|---|---|
| `sec:s_overview` | 1 | Overview |
| `sec:s_roadmap` | 1.1 | Roadmap of contents |
| `sec:s_prereg` | 1.2 | Preregistration deviations |
| `sec:s_methods` | 2 | Methods |
| `sec:s_data_curation` | 2.1 | Data curation |
| `sec:s_data_quality` | 2.1.1 | Data quality control, dish renaming |
| `sec:s_variable_measurement` | 2.2 | Variable measurement |
| `sec:s_outcome_labeling` | 2.2.1 | LLM outcome labeling |
| `sec:s_menu_reconstruction` | 2.2.2 | Menu timeline reconstruction |
| `sec:s_auxiliary` | 2.2.3 | Inflation, weather, holidays |
| `sec:s_effect_estimation` | 2.3 | Effect estimation |
| `sec:s_modeling` | 2.3.1 | Modeling, estimands, accounting tables |
| `sec:s_model_evaluation` | 2.3.2 | Model evaluation |
| `sec:s_robustness` | 2.3.3 | Robustness checks |
| `sec:s_within_customer_modeling` | 2.3.4 | Within-customer modeling |
| `sec:s_results` | 3 | Results |
| `sec:s_descriptives` | 3.1 | Descriptive statistics |
| `sec:s_desc_t1` | 3.1.1 | Tier One descriptives |
| `sec:s_desc_t2` | 3.1.2 | Tier Two descriptives |
| `sec:s_t1_results` | 3.2 | Tier One results |
| `sec:s_impossible` | 3.2.1 | Impossible exploratory analysis |
| `sec:s_t1_plots` | 3.2.2 | Restaurant-labeled T1 plots |
| `sec:s_t1_tables` | 3.2.3 | Tier One unadjusted RR tables |
| `sec:s_t2_results` | 3.3 | Tier Two results |
| `sec:s_t2_summary` | 3.3.1 | Tier Two narrative summary |
| `sec:s_t2_plots_sorted` | 3.3.2 | Sorted T2 plots |
| `sec:s_t2_plots_labeled` | 3.3.3 | Restaurant-labeled T2 plots |
| `sec:s_t2_tables` | 3.3.4 | Tier Two unadjusted RR tables |
| `sec:s_sens_results` | 3.4 | Within-customer sensitivity results |
| `sec:s_sens_t1_plots` | 3.4.1 | Sensitivity T1 plots |
| `sec:s_sens_t2_plots` | 3.4.2 | Sensitivity T2 plots |
| `sec:s_sens_t1_tables` | 3.4.3 | Sensitivity T1 tables |
| `sec:s_sens_t2_tables` | 3.4.4 | Sensitivity T2 tables |

## B. Figures

| label | what |
|---|---|
| `fig:s_t1lab_a1` .. `fig:s_t1lab_a4` | T1 restaurant-labeled forest plots, A1--A4 |
| `fig:s_t2_a1a`, `fig:s_t2_a1b`, `fig:s_t2_a1c` | T2 sorted, A1 parts 1--3 |
| `fig:s_t2_a2`, `fig:s_t2_a3a`, `fig:s_t2_a3b`, `fig:s_t2_a4` | T2 sorted, A2--A4 |
| `fig:s_t2lab_a1a` .. `fig:s_t2lab_a4` | T2 restaurant-labeled, A1--A4 |
| `fig:s_t1_a5`, `fig:s_t1_a6` | Sensitivity T1, general and counterpart |
| `fig:s_t2_a5`, `fig:s_t2_a6` | Sensitivity T2, general and counterpart |

## C. Tables

| label | what |
|---|---|
| `tab:s_accounting_t1`, `tab:s_accounting_t2` | model/estimate accounting, in 2.3.1 |
| `tab:impossible_estimates` | Impossible within-restaurant estimates |
| `tab:rr_t1_a1` .. `tab:rr_t1_a4` | Tier One unadjusted RRs |
| `tab:rr_t2_a1` .. `tab:rr_t2_a4` | Tier Two unadjusted RRs |
| `tab:a5_mu_gamma`, `tab:a6_mu_gamma` | Sensitivity T1 customer-level effects |
| `tab:t2_a5_mu_gamma`, `tab:t2_a6_mu_gamma` | Sensitivity T2 customer-level effects |

## D. Main text — replace these

| current | replacement |
|---|---|
| `Supplement, Sections 2.3.4 \& 3.4` | `Supplement, Sections~\ref{sec:s_within_customer_modeling} \& \ref{sec:s_sens_results}` |
| `see Supplement, Section 2.3` | `see Supplement, Section~\ref{sec:s_effect_estimation}` |
| `Supplement, Figures 1-4` | `Supplement, Figures~\ref{fig:s_t1lab_a1}--\ref{fig:s_t1lab_a4}` |
| `results in Supplement, Section 3.4` | `results in Supplement, Section~\ref{sec:s_sens_results}` |
| `Supplement, Section 3.2.1` | `Supplement, Section~\ref{sec:s_impossible}` |
| `Supplement, Section 1.2` | `Supplement, Section~\ref{sec:s_prereg}` |
| `Supplement, Section 3.3` | `Supplement, Section~\ref{sec:s_t2_results}` |
| `Supplement, Section 2.1.1` | `Supplement, Section~\ref{sec:s_data_quality}` |
| `Supplement, Section 2.2.1` | `Supplement, Section~\ref{sec:s_outcome_labeling}` |
| `Supplement, Section 2.2.2` | `Supplement, Section~\ref{sec:s_menu_reconstruction}` |
| `Supplement, Section 2.2.3` | `Supplement, Section~\ref{sec:s_auxiliary}` |
| `Section 2.3 of the Supplement` | `Section~\ref{sec:s_effect_estimation} of the Supplement` |
| `Supplement, Section 2.2` | `Supplement, Section~\ref{sec:s_variable_measurement}` |
| `(Figure 2)` in the A1 subsection | `(Figure~\ref{fig:plot1})` |
| `(Figure 5)` in the A2 subsection | `(Figure~\ref{fig:plot2})` -- currently points at the A4 figure |

## E. Supplement — internal references still hardcoded or missing

| location | current | replacement |
|---|---|---|
| 1.1 Roadmap | `Section 2.3.1 defines the estimands` | `Section~\ref{sec:s_modeling} defines the estimands` |
| 2.3.1 | `Sections 3.2.3 \& 3.3.4` | `Sections~\ref{sec:s_t1_tables} \& \ref{sec:s_t2_tables}` |
| 2.3.1 | `(see Robustness checks)` | `(see Section~\ref{sec:s_robustness})` |
| 3.2.1 | `Table reports the within-restaurant estimates` | `Table~\ref{tab:impossible_estimates} reports ...` |

## F. Label mismatch to fix now

The two accounting tables are labelled `tab:estimate_accounting_t1` and
`tab:estimate_accounting_t2`, but the sentence below them cites
`tab:s_accounting_t1` and `tab:s_accounting_t2`. Rename the labels to the `s_`
form so they match the rest of the scheme, and the `\ref`s resolve.

## G. Stale numbers in Supplement 2.3.1

Still to correct in the paragraph beginning "Within each of the outcome model":

- `51 reported Tier Two RRRs` should be **55**
- `68 Tier Two RRs` should be **66** (the stated figure counts two retired chicken
  models in `t2_a4_its_t` and `t2_a6_customer_t_day`)
- The R-hat sentence claims "the largest values (up to 1.49) occurred for the
  single-restaurant ground meat estimates in A2". Current A2 fits top out at
  **1.003**, so this sentence is stale and overstates the convergence problem.

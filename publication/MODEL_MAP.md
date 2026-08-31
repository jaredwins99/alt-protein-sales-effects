# Which model produces which analysis

Derived from `publication/forest_data_adj_95ci_fixed.csv` — the table the
published forest plots are drawn from — so this is what is actually published,
not what the directory names suggest.

## The twelve published analyses

| analysis | tier | model | starter directory | run function |
|---|---|---|---|---|
| `a1_proportion`      | 1 | INGARCH | `model_starters/a1_proportion/` | `run_prop` |
| `a2_proportion_t`    | 1 | INGARCH | `model_starters/a2_proportion_t/` | `run_prop_targeted` |
| `a3_its`             | 1 | INGARCH | `model_starters/a3_its/` | `run_its` |
| `a4_its_t`           | 1 | INGARCH | `model_starters/a4_its_t/` | `run_its_targeted` |
| `a5_customer_day`    | 1 | Gaussian IID | `model_starters/customer/` | `run_customer_day` |
| `a6_customer_t_day`  | 1 | Gaussian IID | `model_starters/customer_targeted/` | `run_customer_targeted_day` |
| `t2_a1_proportion`   | 2 | INGARCH | `model_starters/t2_a1_proportion/` | `run_prop` |
| `t2_a2_proportion_t` | 2 | INGARCH | `model_starters/t2_a2_proportion_t/` | `run_prop_targeted` |
| `t2_a3_its`          | 2 | INGARCH | `model_starters/t2_a3_its/` | `run_its` |
| `t2_a4_its_t`        | 2 | INGARCH | `model_starters/t2_a4_its_t/` | `run_its_targeted` |
| `t2_a5_customer_day` | 2 | Gaussian IID | `model_starters/t2_customer/` | `run_customer_day` |
| `t2_a6_customer_t_day` | 2 | Gaussian IID | `model_starters/t2_customer_targeted/` | `run_customer_targeted_day` |

## The customer models are day-level, not transaction-level

A5 and A6 each have **two** aggregation variants in `model_starters/`, and only
one of them is published:

| variant | starter directory | run function | underlying | published? |
|---|---|---|---|---|
| **customer-day** | `customer/`, `customer_targeted/` | `run_customer_day`, `run_customer_targeted_day` | `run_gaussian_iid_day.R` | **yes** |
| transaction | `customer_transaction/`, `customer_targeted_transaction/` | `run_customer`, `run_customer_targeted` | `run_gaussian_iid.R` | no |

Every A5/A6 row in the published table names a `*_customer_day` or
`*_customer_t_day` fit directory. Nothing published reads a transaction-level
fit. The transaction starters are kept because they were run during model
selection, but they are not part of the published pipeline.

The directory names are the trap: `model_starters/customer/` produces the
**day-level** A5, while `model_starters/customer_transaction/` produces the
transaction-level one that is not used.

## Fit generations

The published estimates do not all come from one fitting run:

| generation | fit directories referenced |
|---|---|
| `finalized_redone_trunc` | 46 |
| `finalized_redone_trunc_cp` | 39 |
| `finalized_uncontaminated2` | 27 |
| `finalized_uncontaminated` | 3 |

A starter writes into the generation named by its own `directory =` argument, so
re-running a starter reproduces only the generation it names. Refitting
everything means running the starters for all four.

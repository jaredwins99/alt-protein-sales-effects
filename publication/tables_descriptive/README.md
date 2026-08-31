# Descriptive tables

Hand-maintained. No script generates these — they are inputs to the paper, not
derived artifacts, so they cannot be regenerated from the fits.

- `restaurant_summary_table_t{1,2}*.tex` — per-restaurant summary of alt-protein
  introductions, menu coverage and dates. Three layouts each (default, `_long`,
  `_transposed`); pick one per venue.

These describe the restaurants. They report no estimates, which is why they are
the only paper tables kept outside the generated directories.

Generated tables live elsewhere:

| directory | contents | generator |
|---|---|---|
| `../tables_final/` | **unadjusted rate ratios (RR)** — the paper's tables | `scripts/final_tables.R` |
| `../tables/` | mu-gamma tables, plain and `_adj` | `scripts/extract_mu_gamma_tables.R` |

The forest plots report the relative rate ratio (RRR); the tables report the
unadjusted RR. See `../FINAL_TABLES.md`.

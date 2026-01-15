# Review Process Plan

## Overview
Comprehensive review of Bayesian INGARCH modeling pipeline for estimating the causal effect of introducing modern plant-based analogs (MPBAs) on animal-based food (ABF) sales.

**Primary Research Questions (from prereg):**
1. Do MPBAs that emulate ABFs reduce ABF consumption?
2. Does the proportion of MPBA items on a menu reduce ABF consumption?
3. Do MPBAs primarily displace the specific ABF they emulate, or ABFs generally?

**Key Parameters:**
- `mu_gamma`: pooled rate ratio across restaurants. exp(mu_gamma) = RR. RR = 1 is null effect.
- `eta_r`: restaurant-level rate ratio (pooled within restaurant)
- `gamma_e,r`: individual exposure coefficients (less important)

---

## Plugin Setup Status

### Linear MCP Server
- [ ] Run: `claude mcp add-json linear '{"command": "npx", "args": ["-y","mcp-remote","https://mcp.linear.app/sse"]}'`
- [ ] Authenticate via `/mcp` command
- [ ] Verify connection

### Safety Net Plugin
- [ ] Install: `claude plugin add kenryu42/claude-code-safety-net`
- [ ] Verify with `/verify-custom-rules`

---

## Subagents (3 total)

### 1. Cataloguer Agent
**Focus**: Map entire repo, document data flow, understand pipeline
**Output**: `review/catalogue.md`
**Skills**: codebase exploration, documentation

### 2. Scientist-Statistician Agent
**Focus**: Scientific interpretation, statistical validity, overlap issues, model diagnostics
**Output**: `review/statistical_review.md`
**Interactive**: Will ask user questions about scientific goals
**Key concerns**:
- Statistical overlap (covariate-outcome pairing issues)
- Model convergence diagnostics
- Forest plot interpretation
- Effect size reasonableness

### 3. Code Reviewer Agent
**Focus**: Programming bugs, typos, logical errors
**Output**: `review/code_review.md`
**Priority**:
- SKIP: Minor style issues
- FIX: Anything that changes results
- FLAG: Potential issues for discussion

---

## Pipeline Being Reviewed

```
Data (4_data_parquet_modeling/)
    ↓
Model Selection & Launch (run_t1_models.sh / run_t2_models.sh)
    ↓
Bayesian INGARCH Estimation (Stan/CmdStanR)
    ↓
Output Generation (model_fits/)
    ↓
Visualization (forest_plots_redone/)
```

---

## Key Files to Review

### Data Pipeline
- `data/4_data_parquet_modeling/` - processed modeling data
- `data/weekly_data.parquet` - primary data source

### Model Scripts
- `model_scripts/orchestrate_finalized.R` - main orchestrator
- `model_scripts/analysis_scripts/run_analysis_finalized.R` - analysis wrapper
- `model_scripts/ingarch_scripts/run_ingarch.R` - core modeler
- `model_starters/` - 133 R scripts launching specific models

### Outputs
- `forest_plots_redone/` - visualization outputs with mu_gamma CSVs
- `model_fits/finalized_redone/` - fitted model objects
- `logs/` - 90+ execution logs

---

## Decision Framework

| Issue Type | Action |
|------------|--------|
| Typo in comment | SKIP |
| Unused variable | SKIP |
| Wrong data file path | FIX |
| Incorrect formula | FIX |
| Statistical overlap concern | FLAG + DISCUSS |
| Missing data handling | REVIEW |

---

## Coordination

All agents write to their respective `.md` files in `review/`.
Main coordinator (this document) tracks:
- [x] Cataloguer complete - see [catalogue.md](catalogue.md)
- [x] Scientist-Statistician complete - questions below
- [x] Code Reviewer complete - see [code_review.md](code_review.md)
- [ ] Issues consolidated
- [ ] Fixes applied
- [ ] Ready for model re-run

---

## Statistical Overlap Investigation (In Progress)

A subagent is currently investigating statistical overlap issues by analyzing:
1. Exposure variation within restaurants over time (A1/A2 proportion analyses)
2. Pre/post observation counts for ITS analyses (A3-A6)
3. Identification of problematic restaurant-exposure combinations

Results will be written to [statistical_review.md](statistical_review.md)

---

## Issues Found

### Fixed

1. **~~Log File Collisions~~** - FIXED in run_t1_models.sh
   - Vegetarian model log files now correctly use `_vn_` suffix instead of `_v_`

### Important (Should Fix)

2. **Verify M parameter in data_list** - Stan may need this explicitly passed
3. **Verify p_max/q_max returned from run_ingarch.R** - currently may return NULL
4. **Directory inconsistency** - Some models use `finalized` vs `finalized_redone`
5. **new_fit_created flag** - May not be in return list, breaking MLflow logging

### Flag for Discussion

6. **Commented-out restaurants** - Different models exclude different restaurants (e.g., SRQS8F7JWA9MZ)
7. **Orchestration script sources wrong files** - Uses `run_analysis.R` vs `run_analysis_finalized.R`

### Minor (Can Skip)
- Style issues, unused imports, formatting

---

## Linear Integration

Once Linear is connected, issues will be tracked there with labels:
- `review:critical`
- `review:important`
- `review:minor`
- `review:question`

# Code Review: Bayesian INGARCH Modeling Pipeline

**Reviewer**: Claude Code
**Date**: 2026-01-12
**Scope**: Core modeling scripts, model starters, shell scripts

---

## Minor Issues (Fixed)

### 1. Shell Script Log File Collisions - Multiple Models Writing to Same Log (FIXED)

- **File**: [run_t1_models.sh](run_t1_models.sh), [run_t2_models.sh](run_t2_models.sh)

- **Issue**: Some vegetarian models (vn) were writing to vegan (v) log files.

- **Status**: **FIXED** - Log file names updated to match session names in both scripts.
  - `run_t1_models.sh`: Already correct
  - `run_t2_models.sh`: Fixed 16 lines (vn sessions now write to vn logs)

- **Impact**: **LOW** - User rarely checks logs; fixed since noticed.

---

### 2. Potential Missing `M` Parameter in `data_list` for Stan Model

- **File**: [model_scripts/ingarch_scripts/run_ingarch.R:134-212](model_scripts/ingarch_scripts/run_ingarch.R#L134)
- **Issue**: The `index_list` computes `M = 2` but verify it's passed to `data_list`. Stan models need all data parameters.

- **Impact**: **NEEDS VERIFICATION** - If M is missing, Stan will fail at runtime.

---

### 3. Returning `p_max` and `q_max` That May Not Exist in `data_list`

- **File**: [model_scripts/ingarch_scripts/run_ingarch.R:361](model_scripts/ingarch_scripts/run_ingarch.R#L361)
- **Issue**: Line 361 tries to return `p_max = data_list$p_max, q_max = data_list$q_max`. Verify these are added to `data_list`.

- **Impact**: **MEDIUM** - Returns `NULL` for these values, which may cause downstream issues in MLflow logging or result analysis.

---

### 4. Inconsistent `directory` Parameter Across Model Starters

- **File**: [model_starters/customer/A5_total.R:5](model_starters/customer/A5_total.R#L5)
- **File**: [model_starters/customer_targeted/A6_breakfast.R:8](model_starters/customer_targeted/A6_breakfast.R#L8)

- **Issue**: Some model starters use `directory = "finalized"` while others use `directory = "finalized_redone"`. This creates results in different output directories.
  - A5 customer models: `directory = "finalized"`
  - A6 customer_targeted models: `directory = "finalized"`
  - Most others: `directory = "finalized_redone"`

- **Impact**: **MEDIUM** - Results end up in different directories, complicating analysis.

---

## Important Issues (Should Review)

### 5. `new_fit_created` Flag May Not Be Returned

- **File**: [model_scripts/ingarch_scripts/run_ingarch.R:228, 353-364, 372](model_scripts/ingarch_scripts/run_ingarch.R#L228)
- **Issue**: `new_fit_created` is set to `TRUE` on line 234 but may not be included in the return `list()`. The MLflow logging check on line 372 looks for `result$new_fit_created`.

- **Impact**: **MEDIUM** - MLflow logging may never be triggered.

---

### 6. Commented-Out Restaurants Create Inconsistent Model Runs

- **File**: [model_starters/a3_its/A3_chicken_fish.R:5](model_starters/a3_its/A3_chicken_fish.R#L5)
- **File**: [model_starters/a1_proportion/A1_vegan_on_vegan_count.R:6](model_starters/a1_proportion/A1_vegan_on_vegan_count.R#L6)

- **Issue**: Various model starters have restaurants commented out mid-list. For example:
  - `A3_chicken_fish.R` excludes `SRQS8F7JWA9MZ`
  - `A1_vegan_on_vegan_count.R` excludes `SRQS8F7JWA9MZ`

- **Impact**: **FLAG** - Verify this is intentional. If different models use different restaurant subsets, effect comparisons may be confounded.

---

### 7. Orchestration Script Sources Different Analysis Files

- **File**: [model_scripts/orchestrate_finalized.R:12,14](model_scripts/orchestrate_finalized.R#L12)
- **Issue**: The file sources `run_analysis.R` and `run_analysis_nopred.R` but model starters use `run_analysis_finalized.R`.

- **Impact**: **FLAG** - Verify the orchestration script is not used in production, or update it.

---

## Summary

| Priority | Count | Action Required |
|----------|-------|-----------------|
| Critical | 1 confirmed, 1 verify | Fix before next model run |
| Important | 3 | Fix soon / Review |
| Flag | 2 | Discuss / Verify intentional |

**Recommended Priority:**
1. Fix Issue #1 (log file collisions) immediately - prevents log loss
2. Verify Issue #2 (M parameter) and #3 (p_max/q_max)
3. Fix Issue #4 (directory consistency) - affects result organization
4. Review Issue #6 (restaurant consistency) with domain knowledge

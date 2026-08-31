# Best practices, extracted from this project

Patterns worth carrying into a new project, each with a concrete example. Most
come from decisions already made in `restaurant-sales`; the last section is the
inverse — traps this codebase hit, with the failure each one caused.

Written so an agent can implement any bullet from scratch without reading the
original repo.

---

## Project layout and imports

- **Make the analysis code an installable package, not a folder of scripts.**
  `src/foodcast/` + `pyproject.toml`, installed with `pip install -e .`. Notebooks
  then say `from foodcast.imports import *` from any working directory.

- **One import line per notebook.** A single `imports.py` re-exports numpy,
  pandas, plotting, and every project helper, with an explicit `__all__`. Every
  notebook opens the same way; adding a helper is a one-line change in one file.

- **Gate the star-import with `__all__`.** Without it, `import *` leaks every
  transitive name and breaks unpredictably. With it, the notebook's namespace is
  a deliberate, reviewable list.

- **Centralise every data path in one function.** `return_dir()` returns all
  stage directories as constants; nothing hard-codes a path. Moving a directory
  is one edit.
  ```python
  BASE_DIR, DATA_DIR_1, DATA_DIR_2, DATA_DIR_3, DATA_DIR_4, DATA_DIR_3_x = return_dir()
  ```

- **Prefer a named constant over a literal, then a loader over a constant.**
  Best is a function that hides the layout entirely:
  ```python
  df = load_one_res_3_7_truly_consolidated(loc_id)   # not pd.read_parquet(".../7_.../x.parquet")
  ```

- **Anchor the working directory from inside the code.**
  ```python
  os.chdir(find_project_root())   # walk up for a marker file
  ```
  Notebooks then run identically from Jupyter, `nbconvert`, or CI.

- **Group helpers by domain, not by type.** `tools/labeling_functions.py`,
  `tools/coverage_functions.py`, `tools/rolling.py` — 13, 7 and 6 functions
  respectively. Not one `utils.py`.

---

## Data staging

- **Number the stage directories so the pipeline order is visible in `ls`.**
  ```
  0_data_excel/  1_data_parquet/  2_data_parquet_cleaned/
  3_data_parquet_relabeled/  4_data_parquet_modeling/
  ```

- **Sub-number within a stage when it has internal steps.**
  `3_data_parquet_relabeled/{1_rule_relabeled, 2_consolidated, 4_ai_labeled,
  5_only_food, 6_only_dinein, 7_truly_consolidated}`.

- **One script per stage transition; each reads stage N and writes stage N+1.**
  No script writes two stages, and no stage has two writers.

- **Treat each stage directory as immutable output.** Re-running overwrites it
  wholesale; nothing appends. Makes re-runs idempotent by construction.

- **Use parquet with explicit compression for intermediates.**
  ```python
  df.to_parquet(path, compression="zstd", index=True)
  ```
  Preserves dtypes and the index, which CSV silently destroys.

- **Freeze a checkpoint copy at any handoff you'll want to audit later.**
  `used_for_ai_labeling/` holds stages 1–3 exactly as they were when sent for AI
  labeling. Never regenerated, never written to — it exists so label accuracy can
  be measured against a fixed reference years later.

- **Name the checkpoint for its purpose, not its date.** `used_for_ai_labeling/`
  tells you why it exists; `backup_2024_03/` doesn't.

---

## Environments

- **Pin every language the project uses.** `environment_linux.yml` for Python,
  `renv.lock` for R. A pipeline that crosses languages needs both or it isn't
  pinned at all.

- **Pin exact versions, never ranges.** `pandas==2.1.3`, not `pandas>=2.1`. A
  minor bump changed 13 columns here without raising an error.

- **Record the runtime version too, not just packages.** `renv.lock` pins
  `R 4.4.2`; the restore fails outright on 4.3.3 because a base-recommended
  package requires ≥ 4.4.0.

- **Prefer a lockfile that fails loudly over one that resolves loosely.** The R
  restore refusing to run is better than the Python env quietly producing
  different numbers.

- **Know that a library-dependency file is not a runtime.** An env file listing
  analysis packages may still lack `ipykernel`, `nbconvert`, `pickleshare`, and
  the package itself — everything needed to execute notebooks headlessly. List
  them or document them.

- **Version stamps in output files are forensic evidence.** Parquet records its
  writer: `parquet-cpp-arrow version 14.0.1`. Reading that off committed data
  proves which environment produced it.
  ```python
  pq.ParquetFile(path).metadata.created_by
  ```

---

## Verifying reproducibility

- **Compare values, not bytes.** Parquet writes are not byte-stable: row order
  within equal keys varies between runs. Sort by a key, then compare column by
  column.
  ```python
  X = a.sort_values(key, kind="mergesort").reset_index(drop=True)
  ```

- **Use `git status` as the diff oracle for committed data.** Clean means
  byte-identical to the committed artifact. Any modification is a regression to
  explain, not an expected outcome.

- **Byte-identical is a bonus; value-identical is the bar.** Holding out for
  byte equality produces false alarms and hides real differences in the noise.

- **Take reference copies outside the repo before a run that overwrites.**
  ```bash
  cp -r data/<stage> /tmp/ref_<stage>   # then md5 against it afterwards
  ```

- **Never trust an exit code as evidence of work done.** `renv::restore()`
  returned 0 and printed "already synchronized" over an empty library, twice.
  Verify the artifact: packages import, files exist, values match.

- **Run stages in true dependency order, not the order that's convenient.**
  Verifying the tail while assuming the head proves much less than it appears to.

- **Run one pipeline at a time.** Two concurrent runs writing the same stage
  directories produce failures that look like real defects and cost hours.

- **Check running processes with `ps`, not `pgrep -f`.** `pgrep -f` matches your
  own shell's command line and reports phantoms.

---

## Human-in-the-loop labeling

- **Store hand labels as a flat matrix, one row per item.** `dish_labels/<id>.csv`
  with `item_name` plus a boolean column per category. Diffable, reviewable in a
  spreadsheet, joinable in one line.

- **Externalise hand-built rule sets to YAML.** `remapping/<loc>.yaml` holds
  name changes, category lists, and modification patterns — data, not code, so
  it can be edited without touching a notebook.

- **Give generated config a generator script.** `export_loc5_remappings.py`
  writes `loc5_remappings.yaml`. The YAML is an artifact; the script is the
  source. Without it, nobody can tell which is authoritative.

- **Keep the AI's raw output and the human-reviewed copy as separate files.**
  The diff between them *is* the review record, and it's quantifiable:
  ```
  14 of 15 files edited · 98 rows changed · mpbamod 85, ground_meat 14 …
  vegan and vegetarian never overridden
  ```

- **Split the pipeline at the non-deterministic boundary.** API-calling scripts
  are one group; pure transforms downstream are another. Here
  `generate_dish_labels.py` deterministically rebuilds all 20 label files from
  the AI's raw output — so only the raw output is a frozen source, and
  everything after it stays verifiable.

- **Treat expensive stochastic output as source, not as a step to re-run.**
  Commit it, document what produced it, and never put it in the reproduction path.

---

## Modelling and analysis code

- **Write transformations as `.pipe()` chains of named functions.** Each step
  reads as a sentence and is individually testable:
  ```python
  df_relabeled = (df
      .query("~dish_category.isin(@remove_list)")
      .pipe(fully_relabel_and_consolidate, remove=rare, name_changes=dish_names)
      .pipe(rename_items_by_modifications, modification_name_changes=mods)
      .pipe(relabel_items, vegan_list=vegan, vegetarian_list=veg, meat_list=meat))
  ```

- **Name domain operations as functions.** `infer_active_days`,
  `strict_bridge_fill`, `rolling_window_avg` — the vocabulary of the problem, not
  `process_data_2`.

- **Document the invariant a piece of code protects, in the code.**
  ```python
  .ffill()   # prevent data leakage by propagating past values forward
  ```
  This one comment is what made a silent pandas-version regression diagnosable.

- **Be explicit about leakage boundaries in time-series features.** State the
  window as a half-open interval — `[t - lookback, t)` — in the docstring, and
  make the exclusion of the current step visible in the code.

- **Commit posterior draws so downstream artifacts regenerate without refitting.**
  `published_draws/` (131 files, 53 MB) lets every plot and table be rebuilt
  without re-running the models.

- **Keep the expensive step out of the reproduction loop.** Model fits are
  reproducible in principle and re-run by nobody; the draws are what the plots
  actually need.

---

## Documentation

- **Keep a single pipeline document that states what is on the path and what is
  not.** Most of a research repo is exploration; say plainly which nine tenths
  can be ignored.

- **Document the traps, not just the happy path.** "This constant points at a
  directory that never existed" saves more time than another architecture
  overview.

- **Record what you disproved, not only what you concluded.** A corrected claim
  with its evidence stops the next person re-deriving it.

- **Draw the graph when the flow isn't linear.** Sources entering from the side,
  a repo boundary, and a feedback edge are far clearer as a picture than as prose.

---

## Anti-patterns

Each generalises beyond this project; the failure it caused here is given as
evidence, not as the point.

- **Don't pass state between notebooks with a persistent cache.** IPython's
  `%store` lives in `~/.ipython`, survives across sessions, and goes stale
  silently — a notebook failed on a dict cached under a pre-rename key while its
  own source was correct. Pass state through files on disk that the pipeline
  owns.

- **Don't let a notebook depend on a variable no cell assigns.** Interactive
  development leaks session state into files that then cannot run top to bottom.
  Test by executing headless from a cold kernel, not by re-running in the
  session you built it in.

- **Never let two scripts write the same file with different schemas.** One
  writer produced 3 columns and another 18; running the wrong one dropped 15,
  and the consumer failed three stages later with an unrelated-looking
  `AttributeError`. One artifact, one writer.

- **Never read and write the same file in one step.**
  ```python
  df = pd.concat([pd.read_csv(p), new_row]);  df.to_csv(p)   # grows every run
  ```
  Make it idempotent — drop existing rows for the key before appending — or read
  from a different file than you write.

- **Don't interleave fallible side effects with critical writes.** A plotting
  call sitting between two `to_parquet` calls aborted the cell, so one output
  existed and the other silently did not. Do the writes together, then the
  diagnostics.

- **Don't unpack a tuple positionally across a module boundary.** A shared
  accessor gained one element and every caller unpacking 6, 7 or 8 values broke
  at once. Return a dict or dataclass so callers name what they take.

- **Validate that config and reference tables agree with reality at load time.**
  A constant named a directory that was never created, and one entity was in the
  coverage list but missing from the timezone table — both surfaced far from the
  cause. One assertion turns a mystery into a message:
  ```python
  assert set(coverage) <= set(timezones.index)
  ```

- **Check case-fold stability before choosing a replacement token.** If any code
  normalises text (`.str.title()`, `.lower()`, casefold matching), a token that
  does not survive that normalisation will silently stop matching downstream
  rules. Here it changed 7,264 rows with no error.
  ```python
  assert token.title() == token == token.upper()
  ```

- **Pin exact versions, never ranges.** A minor version bump changed 13 columns
  of output across 2,031 rows without raising anything.

- **Never treat an exit code as evidence that work happened.** A dependency
  restore returned 0 and printed "already synchronized" over an empty library,
  twice. Verify the artifact — imports resolve, files exist, values match.

- **Ship every file the project needs to bootstrap, or document how to make it.**
  A startup profile sourced a generated file that was gitignored, so the runtime
  aborted before executing anything.

- **Don't `git add -A` in a repo with large generated outputs.** It swept in
  303 MB of regenerated intermediates nothing reads. Add paths explicitly and
  gitignore generated stages.

- **Run one pipeline at a time.** Two concurrent runs writing the same stage
  directories produce failures that look exactly like real defects.

- **Check for running processes with `ps`, not `pgrep -f`.** `pgrep -f` matches
  your own shell's command line and reports phantoms.

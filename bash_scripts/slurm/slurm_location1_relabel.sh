#!/bin/bash
#SBATCH --job-name=a3_loc1
#SBATCH --partition=qsu
#SBATCH --qos=normal
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=7-00:00:00
#SBATCH --output=archive/logs/a3_loc1_%A_%a.out

# A3 refits on location 1's relabelled outcomes, into model_fits/finalized_location1_relabel.
#
# From ~/testing on a Sherlock login node:
#   bash bash_scripts/slurm/slurm_location1_relabel.sh check                 # the fits in FITS below: what would run
#   srun -p dev -c 4 --mem=16G -t 00:30:00 bash bash_scripts/slurm/slurm_location1_relabel.sh smoke all
#   bash bash_scripts/slurm/slurm_location1_relabel.sh submit                # submit them, one array task each
#   bash bash_scripts/slurm/slurm_location1_relabel.sh submit A3_meat A3_T2_total     # or name the fits
#   JOB_EXCLUDE=sh02-09n10,sh02-09n11 bash bash_scripts/slurm/slurm_location1_relabel.sh submit   # keep off nodes
#
# A name is a starter in model_starters/location1_relabel/: A3_<outcome> is Tier 1
# (model_fits/<GEN>/a3_its/<outcome>) and A3_T2_<outcome> is Tier 2 (t2_a3_its/<outcome>); `all` is
# all nine. `submit` checks everything first and refuses when
#   - a name has no starter,
#   - a fit already has fit.rds or summ.rds in $SCRATCH/model_fits/<GEN>: refits never replace a fit,
#   - the relabelled table is missing, or its labels_source.txt says it was built from a label table
#     that does not cover every line of location 1 (ALLOW_PARTIAL_LABELS=1 overrides, for tests),
#   - the container image is missing;
# `smoke` runs the same checks, then builds each fit's data list in the container without fitting (into a
# throwaway folder under $SCRATCH, never the generation), prints its restaurants and location 1's series
# total, and checks that the container's precompiled Stan model is the repo's models/ source.
# `submit` then calls sbatch on this same file with `run <names>`. Each task runs its starter in the
# container, fails unless the fit wrote summ.rds (run_ingarch() catches its own errors and returns),
# and writes the fit's slim draws (publication/scripts/slim_extract_one.R) to <GEN>/_slim/ for
# bash_scripts/slurm/push_results.sh.
#
# 3 chains on 4 CPUs and 32G, as the T2 A3 jobs behind the published fits (slurm_t2_its_total.sh).
# Only git 1.8 commands (Sherlock's system git).
#
# FITS is all nine. Location 1's label table (hens study-location1, 5251e2c) moves its vegan, vegetarian
# and meat outcomes materially; non-vegan moves little (-0.26% in post-minus-pre share) but is refit too,
# because vegan + non-vegan = total and refitting one alone would leave that pair on inconsistent data,
# and because the published T2 non-vegan fit lacks the four Tier-1 restaurants. Dropping A3_nonvegan and
# A3_T2_nonvegan from FITS gives 7. T2 total is refit because its published fit lacks the same four.

FITS=(A3_meat A3_vegetarian A3_vegan A3_nonvegan A3_T2_meat A3_T2_vegetarian A3_T2_vegan A3_T2_nonvegan A3_T2_total)
ALL=(A3_meat A3_vegetarian A3_vegan A3_nonvegan A3_T2_meat A3_T2_vegetarian A3_T2_vegan A3_T2_nonvegan A3_T2_total)
GEN=finalized_location1_relabel
STARTERS=model_starters/location1_relabel
DATA=data/4_data_parquet_modeling/its_location1_relabel
SIF=${SIF:-$GROUP_HOME/testing-models.sif}
SELF=$(readlink -f "$0")

set -uo pipefail

fit_dir() {  # <name> -> <analysis>/<outcome>
  case $1 in
    A3_T2_*) echo "t2_a3_its/${1#A3_T2_}" ;;
    A3_*) echo "a3_its/${1#A3_}" ;;
  esac
}

container() {
  singularity exec \
    --bind "${SLURM_SUBMIT_DIR:-$PWD}":/app \
    --bind "${MODEL_FITS:-$SCRATCH/model_fits}":/app/model_fits \
    --pwd /app \
    --env R_LIBS_USER=/dev/null \
    --env R_LIBS="" \
    "$SIF" "$@"
}

refuse() { echo "$*; nothing submitted"; exit 2; }

check() {  # <name>...
  local name dir bad=0
  [ -f "$DATA/finalized.parquet" ] || refuse "no $DATA/finalized.parquet; build it with review/label_audit/apply_location1_labels.py"
  [ -f "$DATA/labels_source.txt" ] || refuse "no $DATA/labels_source.txt beside the table"
  if ! grep -qx 'complete: yes' "$DATA/labels_source.txt" && [ -z "${ALLOW_PARTIAL_LABELS:-}" ]; then
    refuse "$DATA was built from a label table that does not cover every line of location 1 ($DATA/labels_source.txt)"
  fi
  [ -f "$SIF" ] || refuse "no container image $SIF"
  for name in "$@"; do
    dir=$(fit_dir "$name")
    if [ ! -f "$STARTERS/$name.R" ] || [ -z "$dir" ]; then echo "no starter $STARTERS/$name.R"; bad=1; continue; fi
    if [ -e "$SCRATCH/model_fits/$GEN/$dir/fit.rds" ] || [ -e "$SCRATCH/model_fits/$GEN/$dir/summ.rds" ]; then
      echo "$GEN/$dir already holds a fit"; bad=1; continue
    fi
    echo "  $name -> \$SCRATCH/model_fits/$GEN/$dir"
  done
  [ $bad -eq 0 ] || refuse "fix the above"
  echo "table: $(grep -E '^(labels|complete|changed outcomes):' "$DATA/labels_source.txt" | tr '\n' ' ')"
  echo "commit $(git rev-parse --short HEAD) on $(git rev-parse --abbrev-ref HEAD)"
}

run() {  # <name>... ; inside the job, task i runs name i
  local names=("$@") name dir
  name=${names[$((SLURM_ARRAY_TASK_ID - 1))]}
  dir=$(fit_dir "$name")
  echo "Starting: $name -> $GEN/$dir, commit $(git rev-parse --short HEAD), $(date)"
  cat "$DATA/labels_source.txt"
  if [ -e "$SCRATCH/model_fits/$GEN/$dir/fit.rds" ] || [ -e "$SCRATCH/model_fits/$GEN/$dir/summ.rds" ]; then
    echo "$GEN/$dir already holds a fit; not refitting"; exit 2
  fi
  container Rscript "$STARTERS/$name.R"
  if [ ! -f "$SCRATCH/model_fits/$GEN/$dir/summ.rds" ]; then
    echo "FAILED: $name wrote no summ.rds, $(date)"; exit 1
  fi
  container Rscript publication/scripts/slim_extract_one.R "model_fits/$GEN/$dir" \
    "model_fits/$GEN/_slim/${GEN}__${dir//\//__}.rds" || echo "slim extraction failed for $name; the fit is kept"
  echo "Finished: $name, $(date)"
}

smoke() {  # <name>... ; data lists only, in a throwaway model_fits
  local tmp name
  tmp=$(mktemp -d "$SCRATCH/a3_loc1_smoke.XXXXXX") || exit 2
  echo "smoke: data lists into $tmp"
  MODEL_FITS=$tmp container Rscript -e '
    source(file.path("model_scripts", "analysis_scripts", "run_analysis_finalized.R"))
    cmdstan_model <- function(...) stop("smoke: data list built, stopping before compile")
    for (n in commandArgs(TRUE)) source(file.path("model_starters", "location1_relabel", paste0(n, ".R")))' "$@" \
    > "$tmp/smoke.log" 2>&1
  MODEL_FITS=$tmp container Rscript -e '
    for (n in commandArgs(TRUE)) {
      d <- file.path("model_fits", "'"$GEN"'", if (startsWith(n, "A3_T2_")) "t2_a3_its" else "a3_its", sub("^A3_(T2_)?", "", n))
      if (!file.exists(file.path(d, "data_list.rds"))) { cat(sprintf("%-18s NO DATA LIST (see smoke.log)\n", n)); next }
      dl <- readRDS(file.path(d, "data_list.rds")); ro <- readRDS(file.path(d, "restaurants_order.rds"))
      i <- match("VLZX7K2M9QD4T", ro)
      y1 <- if (is.na(i)) NA else sum(dl$y_train[dl$train_start_idx[i]:dl$train_end_idx[i]], dl$y_test[dl$test_start_idx[i]:dl$test_end_idx[i]])
      cat(sprintf("%-18s %2d restaurants, N_train %5d, location 1 units %s, truncation %d\n", n, length(ro), dl$N_train, format(y1), dl$apply_truncation))
    }' "$@"
  if container cmp -s /opt/stan_models/model_multilevel_transfer_truncated.stan models/model_multilevel_transfer_truncated.stan; then
    echo "container's precompiled Stan model matches models/model_multilevel_transfer_truncated.stan"
  else
    echo "WARNING: the container's precompiled Stan model differs from models/ (or is missing)"
  fi
  rm -rf "$tmp"
}

main() {
  local mode=${1:-check}
  [ $# -gt 0 ] && shift
  local names=("$@")
  [ ${#names[@]} -gt 0 ] || names=("${FITS[@]}")
  [ "${names[*]}" = all ] && names=("${ALL[@]}")
  case $mode in
    check | smoke | submit)
      cd "$(git rev-parse --show-toplevel)" || exit 2
      check "${names[@]}"
      case $mode in
        submit) mkdir -p archive/logs "$SCRATCH/model_fits"
                sbatch --array=1-${#names[@]} ${JOB_EXCLUDE:+--exclude="$JOB_EXCLUDE"} "$SELF" run "${names[@]}" ;;
        smoke) smoke "${names[@]}" ;;
        *) echo "check only: nothing submitted" ;;
      esac ;;
    run) run "${names[@]}" ;;
    *) echo "usage: bash $SELF check|smoke|submit [name ... | all]"; exit 2 ;;
  esac
}

main "$@"; exit

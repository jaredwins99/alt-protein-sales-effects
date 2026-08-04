#!/bin/bash
#SBATCH --job-name=stan_t2_a2
#SBATCH --partition=qsu
#SBATCH --qos=normal
#SBATCH --cpus-per-task=3
#SBATCH --mem=32G
#SBATCH --time=7-00:00:00
#SBATCH --array=1-12
#SBATCH --output=archive/logs/stan_t2_a2_%A_%a.out

# Tier 2 A2 re-fit after the clip review -- 12 models (6 categories x count/presence).
#
# Scope is A2 ONLY. The 2026-08-04 clip review rewrote
# clip_dates_proportion_targeted, which is gated on /a2_proportion_t/ -- so it
# changes the A2 analysis window in both tiers and touches nothing else. A4
# reads its/finalized.parquet and is unaffected: those fits remain valid and are
# NOT re-run here.
#
# Also folded in: restaurants whose exposure is constant across the train window
# under the new clips were removed from their starters (27 cells), and the
# zero-outcome models were retired (A4_T2_chicken, A6_T2_chicken x2).
#
# Output goes to directory = "finalized_uncontaminated2" (set in each starter).
#
# Sampler settings: defaults from run_ingarch.R -- 3 chains, iter_warmup 1500,
# iter_sampling 2000, adapt_delta 0.85, max_treedepth 12.

mkdir -p archive/logs
mkdir -p $SCRATCH/model_fits

SCRIPTS=(
    "model_starters/t2_a2_proportion_t/A2_T2_breakfast_count.R"
    "model_starters/t2_a2_proportion_t/A2_T2_chicken_count.R"
    "model_starters/t2_a2_proportion_t/A2_T2_dairy_count.R"
    "model_starters/t2_a2_proportion_t/A2_T2_egg_count.R"
    "model_starters/t2_a2_proportion_t/A2_T2_textured_count.R"
    "model_starters/t2_a2_proportion_t/A2_T2_untextured_count.R"
    "model_starters/t2_a2_proportion_t/A2_T2_breakfast_presence.R"
    "model_starters/t2_a2_proportion_t/A2_T2_chicken_presence.R"
    "model_starters/t2_a2_proportion_t/A2_T2_dairy_presence.R"
    "model_starters/t2_a2_proportion_t/A2_T2_egg_presence.R"
    "model_starters/t2_a2_proportion_t/A2_T2_textured_presence.R"
    "model_starters/t2_a2_proportion_t/A2_T2_untextured_presence.R"
)

SCRIPT=${SCRIPTS[$SLURM_ARRAY_TASK_ID - 1]}

echo "Starting: $SCRIPT"
echo "Time: $(date)"

singularity exec \
    --bind ${SLURM_SUBMIT_DIR:-$PWD}:/app \
    --bind $SCRATCH/model_fits:/app/model_fits \
    --pwd /app \
    --env R_LIBS_USER=/dev/null \
    --env R_LIBS="" \
    $GROUP_HOME/testing-models.sif \
    Rscript "$SCRIPT"

echo "Finished: $SCRIPT"
echo "Time: $(date)"

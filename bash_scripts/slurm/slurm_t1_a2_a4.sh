#!/bin/bash
#SBATCH --job-name=stan_t1_a2_a4
#SBATCH --partition=qsu
#SBATCH --qos=normal
#SBATCH --cpus-per-task=3
#SBATCH --mem=24G
#SBATCH --time=7-00:00:00
#SBATCH --array=1-13%8
#SBATCH --output=archive/logs/slurm_t1_a2_a4_%A_%a.out

# All 13 Tier 1 targeted models (A2 availability + A4 ITS).
#
# Why all 13 and not a subset: every T1 A2/A4 outcome column changed in the
# contamination + union fixes (restaurant-sales fd44b90, cac7dc4). Verified
# against the pre-fix data -- none are bit-identical, so no existing fit is
# still valid:
#   A4  breakfast   379,595 -> 356,303     A2  breakfast_p  1,033,617 -> 797,473
#       textured    187,914 -> 172,924         chicken_p      827,950 -> 773,707
#       untextured   70,226 ->  58,611         dairy_p      2,583,659 -> 2,433,193
#                                              egg_p          590,301 -> 564,947
#                                              untextured_p   295,771 -> 251,097
# All 8 price predictors changed too.
#
# The RRR denominators do NOT need re-fitting: A2 pairs against A1 total and
# A4 against A3 total, both of which are general outcomes and are bit-identical
# to pre-fix.
#
# Sampler settings: defaults from run_ingarch.R -- 3 chains, iter_warmup 1500,
# iter_sampling 2000, adapt_delta 0.85, max_treedepth 12. No starter in the repo
# overrides adapt_delta or the iteration counts; the only overrides that exist
# anywhere are `thin = 2` (81 starters, all T2/customer, for samples.rds size)
# and `apply_truncation = TRUE` (18 starters, all of them the `total` RRR
# denominators). The T1 A2/A4 starters deliberately carry neither.
#
# Resources sized from the previous run's own logs (archive/logs/A2_*.log,
# A4_*.log), not copied from the T2 scripts:
#   peak R memory  max 5.92 GB (A2_dairy); every other model under 5.4 GB
#   runtime        max 30.2 h  (A2_dairy_presence); next 29.5, 19.1, 19.1, 19.0
# cpus-per-task=3 = CORES_PER_MODEL exactly (3 chains in parallel). Memory is
# allocated per core at 8 GB, so 3 cores => 24 GB, still 4x the observed peak.
# The 4-core/32 GB pattern in the other slurm scripts exists for the T2 A1/A2
# models, which peak near 22 GB; these T1 models do not need it.
# time=7-00:00:00 -- 5.6x the slowest observed model (30.2 h). Deliberately
# generous: a TIMEOUT costs the entire 30 h over again, which dwarfs any
# scheduling delay a long request might incur. Same QoS, no extra charge.
#
# Partition: qsu. At time of writing normal had 19,585 tasks queued vs qsu's 0,
# so despite qsu being small (160 cores) it is the faster route to a start.
#
# Output goes to directory = "finalized_redone_trunc_cp" (set in each starter).
# This is non-destructive for A2 -- model_fits/finalized_redone_trunc_cp/
# a2_proportion_t/ is currently empty, and the existing A2 fits live in
# finalized_redone_trunc/. It DOES overwrite the 3 existing A4 fits in _cp, but
# copies of those remain in finalized_redone_trunc/a4_its_t/.

mkdir -p $SCRATCH/model_fits

SCRIPTS=(
    # --- A4: targeted ITS (3 models, all currently converge: rhat <= 1.012) ---
    "model_starters/a4_its_t/A4_breakfast.R"
    "model_starters/a4_its_t/A4_textured.R"
    "model_starters/a4_its_t/A4_untextured.R"

    # --- A2: targeted availability (10 models = 5 outcomes x count/presence) ---
    "model_starters/a2_proportion_t/A2_breakfast_count.R"
    "model_starters/a2_proportion_t/A2_breakfast_presence.R"
    "model_starters/a2_proportion_t/A2_chicken_count.R"
    "model_starters/a2_proportion_t/A2_chicken_presence.R"
    "model_starters/a2_proportion_t/A2_dairy_count.R"
    "model_starters/a2_proportion_t/A2_dairy_presence.R"
    "model_starters/a2_proportion_t/A2_egg_count.R"
    "model_starters/a2_proportion_t/A2_egg_presence.R"
    "model_starters/a2_proportion_t/A2_untextured_count.R"
    "model_starters/a2_proportion_t/A2_untextured_presence.R"
)

SCRIPT=${SCRIPTS[$SLURM_ARRAY_TASK_ID - 1]}

echo "Starting: $SCRIPT"
echo "Time: $(date)"

singularity exec \
    --bind $HOME/testing:/app \
    --bind $SCRATCH/model_fits:/app/model_fits \
    --pwd /app \
    --env R_LIBS_USER=/dev/null \
    --env R_LIBS="" \
    $GROUP_HOME/testing-models.sif \
    Rscript "$SCRIPT"

echo "Finished: $SCRIPT"
echo "Time: $(date)"

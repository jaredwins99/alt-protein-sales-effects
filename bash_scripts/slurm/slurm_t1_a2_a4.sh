#!/bin/bash
#SBATCH --job-name=stan_t1_a2_a4
#SBATCH --partition=qsu
#SBATCH --qos=normal
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
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
# cpus-per-task=4 = CORES_PER_MODEL (3 chains, run in parallel) + 1.
# time=7-00:00:00 because slurm_its_and_customer.sh recorded a 4-day TIMEOUT on
# the prior ITS run; 7 days is the same QoS and costs nothing extra.
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

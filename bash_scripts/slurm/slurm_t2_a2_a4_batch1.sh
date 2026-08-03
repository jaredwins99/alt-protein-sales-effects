#!/bin/bash
#SBATCH --job-name=stan_t2_b1
#SBATCH --partition=qsu
#SBATCH --qos=normal
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=7-00:00:00
#SBATCH --array=1-13
#SBATCH --output=archive/logs/slurm_t2_b1_%A_%a.out

# Tier 2 targeted models, batch 1 of 2 (13 of the 16 that need re-running).
#
# Why these 13, in this order: ranked by concentration of extreme restaurant-level
# RRRs and by whether the model's restaurant list changed. Deferred to batch 2:
# A2 textured count/presence and A4 textured -- zero extreme estimates, no
# removals, data-change-only. Dropped entirely: A4_T2_chicken (see below).
#
# All 17 T2 A2/A4 models required re-running regardless, because every
# *_outcome_p and *_t2_outcome column changed in the contamination + union fixes
# (restaurant-sales fd44b90, cac7dc4). T2 A3's general outcomes are
# bit-identical, so those 6 fits remain valid and are untouched.
#
# RESTAURANT REMOVALS APPLIED (each justified from menus / sold items, not volume):
#   A4 chicken_t2   V3Q26BHF3SE2H  0 units. Counterpart category is fried_chicken;
#                                  they sell Bbq Chicken and a chicken sandwich,
#                                  both unfried. Sole restaurant -> outcome dropped,
#                                  not in this array at all.
#   A4 untextured   9XKJD8DQTH559  no burger sold anywhere; outcome is two isolated
#                                  rectangular pulses totalling 323 units
#   A4 untextured   JHDN7CF1C03X5  Beyond Burger only (mirrors the T1 exclusion)
#   A4 breakfast    V3Q26BHF3SE2H  Turkey Sausage counterpart first sells mid-2022,
#                                  ~15 months AFTER the 2021 introductions
#   A4 dairy        EMBVNVD207CC6  usable coverage begins 2020-09, the same month
#                                  the exposure switches on -- no pre-period exists
#   A2 untextured   EMBVNVD207CC6  no ground-meat product (pizza/beer venue), 197 units
#   A2 untextured   SAFK7ND1HR6XS  burritos are asada/pastor/suadero = chunked, not
#                                  ground; that volume belongs in textured
#   A2 untextured   JHDN7CF, W8T41J  mirror the T1 exclusions
#   A2 textured     W8T41JZK0ZMEP  no lamb, chunked or pulled pork on its menu
#
# REMOVED FOR NON-IDENTIFICATION (exposure does not vary within the analysis
# window, so the restaurant contributes no information and draws from the prior --
# these produced CI widths up to 57,000x):
#   A2 breakfast    SAFK7ND1HR6XS  exposure 100% constant
#   A2 chicken      SAFK7ND1HR6XS, LBZEEFSBJNB3Z  100% constant
#   A2 untextured   LFZFT3VASXPED  99% constant
#   A2 dairy        LFZFT3VASXPED  99% constant
#
# TRIMMING: exactly one restaurant needed it. A scan of all 12 T2-only restaurants
# for years below 20% of their own peak found EMBVNVD207CC6 alone (2013-2019 at
# 3-10% of peak); every other restaurant is clean. Note run_ingarch.R:270-273
# already drops total_outcome == 0 days from the likelihood, so coverage *gaps*
# need no trimming -- only low-but-nonzero stretches do, which is why the trim
# list is this short.
#   EMBVNVD207CC6 -> start 2020-09-01 in clip_dates_proportion_targeted
#   (breakfast + dairy). That table gates on /a2_proportion_t/, so it affects A2
#   only and leaves the valid A3 fits alone. End stays 2022-09-01 per the existing
#   universal filter; its tail collapses to 1.2/day at 2022-10.
#
# Resources from the April T2 logs, not copied from T1:
#   peak memory  21.7 GB (A2 untextured) -> 4 cores x 8 GB = 32 G
#   runtime      120.9 h (A2 untextured), 97.8 (breakfast), 87.3 (dairy),
#                59.4 (egg), 38.2 (chicken)
# 7 days is required, not generous: untextured previously ran 5.0 days. The
# removals cut untextured from 12 restaurants to 7, so expect shorter.

mkdir -p $SCRATCH/model_fits

SCRIPTS=(
    # --- 1-2: A2 breakfast (7 extreme estimates, the most of any outcome) ---
    "model_starters/t2_a2_proportion_t/A2_T2_breakfast_count.R"
    "model_starters/t2_a2_proportion_t/A2_T2_breakfast_presence.R"

    # --- 3-4: A2 untextured (5 extremes; 5 restaurants removed) ---
    "model_starters/t2_a2_proportion_t/A2_T2_untextured_count.R"
    "model_starters/t2_a2_proportion_t/A2_T2_untextured_presence.R"

    # --- 5-6: A2 chicken (4 extremes; 2 constant-exposure restaurants removed) ---
    "model_starters/t2_a2_proportion_t/A2_T2_chicken_count.R"
    "model_starters/t2_a2_proportion_t/A2_T2_chicken_presence.R"

    # --- 7-9: A4 (all three with restaurant changes) ---
    "model_starters/t2_a4_its_t/A4_T2_untextured.R"
    "model_starters/t2_a4_its_t/A4_T2_breakfast.R"
    "model_starters/t2_a4_its_t/A4_T2_dairy.R"

    # --- 10-11: A2 dairy (2 extremes) ---
    "model_starters/t2_a2_proportion_t/A2_T2_dairy_count.R"
    "model_starters/t2_a2_proportion_t/A2_T2_dairy_presence.R"

    # --- 12-13: A2 egg (2 extremes) ---
    "model_starters/t2_a2_proportion_t/A2_T2_egg_count.R"
    "model_starters/t2_a2_proportion_t/A2_T2_egg_presence.R"
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

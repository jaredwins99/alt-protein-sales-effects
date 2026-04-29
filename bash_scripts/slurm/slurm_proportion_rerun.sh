#!/bin/bash
#SBATCH --job-name=stan_prop_rerun
#SBATCH --partition=qsu
#SBATCH --qos=normal
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=7-00:00:00
#SBATCH --array=1-2%2
#SBATCH --output=archive/logs/slurm_prop_rerun_%A_%a.out

mkdir -p $SCRATCH/model_fits

# 2 proportion models still outstanding (TIMEOUT'd in 19964835 after prior rerun):
#   _22 total_on_vegan_prop, _23 total_on_vegetarian_count
SCRIPTS=(
    "model_starters/t2_a1_proportion/A1_T2_total_on_vegan_prop.R"          # was 19964835_22
    "model_starters/t2_a1_proportion/A1_T2_total_on_vegetarian_count.R"    # was 19964835_23
    # Previously completed in rerun job 20923923 (all 8 successful):
    # "model_starters/t2_a1_proportion/A1_T2_meat_on_vegan_count.R"          # was 19964835_9
    # "model_starters/t2_a1_proportion/A1_T2_meat_on_vegetarian_prop.R"      # was 19964835_12
    # "model_starters/t2_a1_proportion/A1_T2_nonvegan_on_mpbamod_prop.R"     # was 19964835_14
    # "model_starters/t2_a1_proportion/A1_T2_nonvegan_on_vegan_count.R"      # was 19964835_15
    # "model_starters/t2_a1_proportion/A1_T2_nonvegan_on_vegetarian_count.R" # was 19964835_17
    # "model_starters/t2_a1_proportion/A1_T2_nonvegan_on_vegetarian_prop.R"  # was 19964835_18
    # "model_starters/t2_a1_proportion/A1_T2_total_on_vegan_count.R"         # was 19964835_21
    # "model_starters/t2_a1_proportion/A1_T2_total_on_vegetarian_prop.R"     # was 19964835_24
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

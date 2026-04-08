#!/bin/bash
#SBATCH --job-name=stan_prop_rerun
#SBATCH --partition=qsu
#SBATCH --qos=normal
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=7-00:00:00
#SBATCH --array=1-8%8
#SBATCH --output=logs/slurm_prop_rerun_%A_%a.out

mkdir -p $SCRATCH/model_fits

# 8 proportion models requiring 7-day QoS:
#   4 already-TIMEOUT: 19964835_9, _12, _14, _15
#   4 preemptive cancels (sub-family analysis predicts TIMEOUT): _17, _18, _21, _24
SCRIPTS=(
    # 4 already-TIMEOUT
    "model_starters/t2_proportion/A1_T2_meat_on_vegan_count.R"          # was _9
    "model_starters/t2_proportion/A1_T2_meat_on_vegetarian_prop.R"      # was _12
    "model_starters/t2_proportion/A1_T2_nonvegan_on_mpbamod_prop.R"     # was _14
    "model_starters/t2_proportion/A1_T2_nonvegan_on_vegan_count.R"      # was _15
    # 4 preemptive cancels
    "model_starters/t2_proportion/A1_T2_nonvegan_on_vegetarian_count.R" # was _17
    "model_starters/t2_proportion/A1_T2_nonvegan_on_vegetarian_prop.R"  # was _18
    "model_starters/t2_proportion/A1_T2_total_on_vegan_count.R"         # was _21
    "model_starters/t2_proportion/A1_T2_total_on_vegetarian_prop.R"     # was _24
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

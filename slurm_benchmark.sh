#!/bin/bash
#SBATCH --job-name=stan_bench
#SBATCH --partition=qsu
#SBATCH --qos=normal
#SBATCH --cpus-per-task=3
#SBATCH --mem=24G
#SBATCH --time=2-00:00:00
#SBATCH --array=1-2
#SBATCH --output=logs/slurm_bench_%A_%a.out

# Create output directory on scratch
mkdir -p $SCRATCH/model_fits

SCRIPTS=(
    "model_starters/t2_proportion/A1_T2_chicken_fish_on_mpbamod_count.R"
    "model_starters/t2_its/A3_T2_meat.R"
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

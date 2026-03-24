#!/bin/bash
#SBATCH --job-name=stan_bench
#SBATCH --cpus-per-task=3
#SBATCH --mem=8G
#SBATCH --time=7-00:00:00
#SBATCH --qos=long
#SBATCH --array=1-2
#SBATCH --output=logs/slurm_bench_%A_%a.out

module load singularity

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
    --bind $SCRATCH/model_fits:/app/model_fits \
    --bind $PWD:/app \
    --pwd /app \
    $GROUP_HOME/testing-models.sif \
    Rscript "$SCRIPT"

echo "Finished: $SCRIPT"
echo "Time: $(date)"

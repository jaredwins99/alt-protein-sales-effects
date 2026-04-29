#!/bin/bash
#SBATCH --job-name=stan_its_rerun
#SBATCH --partition=qsu
#SBATCH --qos=normal
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=7-00:00:00
#SBATCH --array=1-2%8
#SBATCH --output=archive/logs/slurm_its_cust_%A_%a.out

mkdir -p $SCRATCH/model_fits

SCRIPTS=(
    # A3_T2 ITS — rerun: prior run hit 4-day TIMEOUT, need 7-day QoS
    "model_starters/t2_a3_its/A3_T2_meat.R"
    "model_starters/t2_a3_its/A3_T2_nonvegan.R"
    # NOTE: A5/A6 customer models removed — running locally instead
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

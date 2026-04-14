#!/bin/bash
#SBATCH --job-name=stan_t1_cust_trans
#SBATCH --partition=qsu
#SBATCH --qos=normal
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=7-00:00:00
#SBATCH --array=1-8%8
#SBATCH --output=logs/slurm_t1_cust_trans_%A_%a.out

mkdir -p $SCRATCH/model_fits

# T1 customer transaction-level models (Gaussian IID).
# Edit this array to select which to actually run.
SCRIPTS=(
    # A5 untargeted (6)
    "model_starters/customer_transaction/A5_total.R"
    "model_starters/customer_transaction/A5_vegan.R"
    "model_starters/customer_transaction/A5_vegetarian.R"
    "model_starters/customer_transaction/A5_nonvegan.R"
    "model_starters/customer_transaction/A5_meat.R"
    "model_starters/customer_transaction/A5_chicken_fish.R"
    # A6 targeted (2)
    "model_starters/customer_targeted_transaction/A6_breakfast.R"
    "model_starters/customer_targeted_transaction/A6_untextured.R"
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

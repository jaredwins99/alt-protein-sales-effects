#!/bin/bash
#SBATCH --job-name=stan_t2_cust_day
#SBATCH --partition=qsu
#SBATCH --qos=normal
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=2-00:00:00
#SBATCH --array=1-9%9
#SBATCH --output=logs/slurm_t2_cust_day_%A_%a.out

mkdir -p $SCRATCH/model_fits

# Day-level T2 customer Gaussian IID models — too slow/RAM-intensive to run on WSL
SCRIPTS=(
    # A5_T2 untargeted (4 remaining)
    "model_starters/t2_customer/A5_T2_vegetarian.R"
    "model_starters/t2_customer/A5_T2_nonvegan.R"
    "model_starters/t2_customer/A5_T2_meat.R"
    "model_starters/t2_customer/A5_T2_chicken_fish.R"
    # A6_T2 targeted (5)
    "model_starters/t2_customer_targeted/A6_T2_breakfast.R"
    "model_starters/t2_customer_targeted/A6_T2_untextured.R"
    "model_starters/t2_customer_targeted/A6_T2_chicken.R"
    "model_starters/t2_customer_targeted/A6_T2_dairy.R"
    "model_starters/t2_customer_targeted/A6_T2_textured.R"
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

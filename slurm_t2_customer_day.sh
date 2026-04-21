#!/bin/bash
#SBATCH --job-name=stan_t2_cust_day
#SBATCH --partition=qsu
#SBATCH --qos=normal
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=2-00:00:00
#SBATCH --array=1-2%2
#SBATCH --output=logs/slurm_t2_cust_day_%A_%a.out

mkdir -p $SCRATCH/model_fits

# Day-level T2 customer Gaussian IID models — remaining 2 that no fit.rds exists
# for on Sherlock scratch OR local WSL. Everything else is done:
#   Sherlock: chicken_fish, nonvegan, meat, vegetarian (A5_T2); breakfast_t2, dairy_t2 (A6_T2)
#   WSL local: total, vegan (A5_T2); chicken_t2 (A6_T2)
SCRIPTS=(
    "model_starters/t2_customer_targeted/A6_T2_untextured.R"
    "model_starters/t2_customer_targeted/A6_T2_textured.R"
    # Already done — commented out:
    # "model_starters/t2_customer/A5_T2_vegetarian.R"            # Sherlock
    # "model_starters/t2_customer/A5_T2_nonvegan.R"              # Sherlock
    # "model_starters/t2_customer/A5_T2_meat.R"                  # Sherlock
    # "model_starters/t2_customer/A5_T2_chicken_fish.R"          # Sherlock
    # "model_starters/t2_customer/A5_T2_total.R"                 # WSL local
    # "model_starters/t2_customer/A5_T2_vegan.R"                 # WSL local
    # "model_starters/t2_customer_targeted/A6_T2_breakfast.R"    # Sherlock
    # "model_starters/t2_customer_targeted/A6_T2_chicken.R"      # WSL local
    # "model_starters/t2_customer_targeted/A6_T2_dairy.R"        # Sherlock
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

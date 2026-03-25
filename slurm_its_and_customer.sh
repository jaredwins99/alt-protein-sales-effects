#!/bin/bash
#SBATCH --job-name=stan_its_cust
#SBATCH --partition=qsu
#SBATCH --qos=long
#SBATCH --cpus-per-task=3
#SBATCH --mem=8G
#SBATCH --time=6-23:59:00
#SBATCH --array=1-15%8
#SBATCH --output=logs/slurm_its_cust_%A_%a.out

mkdir -p $SCRATCH/model_fits

SCRIPTS=(
    # A3_T2: ITS (meat already running in benchmark)
    "model_starters/t2_its/A3_T2_nonvegan.R"
    # A4_T2: ITS targeted (2)
    "model_starters/t2_its_targeted/A4_T2_breakfast.R"
    "model_starters/t2_its_targeted/A4_T2_untextured.R"
    # A5_T2: customer Gaussian IID (6)
    "model_starters/t2_customer/A5_T2_total.R"
    "model_starters/t2_customer/A5_T2_vegan.R"
    "model_starters/t2_customer/A5_T2_vegetarian.R"
    "model_starters/t2_customer/A5_T2_nonvegan.R"
    "model_starters/t2_customer/A5_T2_meat.R"
    "model_starters/t2_customer/A5_T2_chicken_fish.R"
    # A5_T1: customer Gaussian IID rerun (6) — output to _cp2
    "model_starters/customer/A5_total.R"
    "model_starters/customer/A5_vegan.R"
    "model_starters/customer/A5_vegetarian.R"
    "model_starters/customer/A5_nonvegan.R"
    "model_starters/customer/A5_meat.R"
    "model_starters/customer/A5_chicken_fish.R"
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

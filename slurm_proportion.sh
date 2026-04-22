#!/bin/bash
#SBATCH --job-name=stan_prop
#SBATCH --partition=qsu
#SBATCH --qos=normal
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=4-00:00:00
#SBATCH --array=1-24%8
#SBATCH --output=logs/slurm_prop_%A_%a.out

mkdir -p $SCRATCH/model_fits

SCRIPTS=(
    # chicken_fish
    "model_starters/t2_a1_proportion/A1_T2_chicken_fish_on_mpbamod_count.R"
    "model_starters/t2_a1_proportion/A1_T2_chicken_fish_on_mpbamod_prop.R"
    "model_starters/t2_a1_proportion/A1_T2_chicken_fish_on_vegan_count.R"
    "model_starters/t2_a1_proportion/A1_T2_chicken_fish_on_vegan_prop.R"
    "model_starters/t2_a1_proportion/A1_T2_chicken_fish_on_vegetarian_count.R"
    "model_starters/t2_a1_proportion/A1_T2_chicken_fish_on_vegetarian_prop.R"
    # meat
    "model_starters/t2_a1_proportion/A1_T2_meat_on_mpbamod_count.R"
    "model_starters/t2_a1_proportion/A1_T2_meat_on_mpbamod_prop.R"
    "model_starters/t2_a1_proportion/A1_T2_meat_on_vegan_count.R"
    "model_starters/t2_a1_proportion/A1_T2_meat_on_vegan_prop.R"
    "model_starters/t2_a1_proportion/A1_T2_meat_on_vegetarian_count.R"
    "model_starters/t2_a1_proportion/A1_T2_meat_on_vegetarian_prop.R"
    # nonvegan
    "model_starters/t2_a1_proportion/A1_T2_nonvegan_on_mpbamod_count.R"
    "model_starters/t2_a1_proportion/A1_T2_nonvegan_on_mpbamod_prop.R"
    "model_starters/t2_a1_proportion/A1_T2_nonvegan_on_vegan_count.R"
    "model_starters/t2_a1_proportion/A1_T2_nonvegan_on_vegan_prop.R"
    "model_starters/t2_a1_proportion/A1_T2_nonvegan_on_vegetarian_count.R"
    "model_starters/t2_a1_proportion/A1_T2_nonvegan_on_vegetarian_prop.R"
    # total
    "model_starters/t2_a1_proportion/A1_T2_total_on_mpbamod_count.R"
    "model_starters/t2_a1_proportion/A1_T2_total_on_mpbamod_prop.R"
    "model_starters/t2_a1_proportion/A1_T2_total_on_vegan_count.R"
    "model_starters/t2_a1_proportion/A1_T2_total_on_vegan_prop.R"
    "model_starters/t2_a1_proportion/A1_T2_total_on_vegetarian_count.R"
    "model_starters/t2_a1_proportion/A1_T2_total_on_vegetarian_prop.R"
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

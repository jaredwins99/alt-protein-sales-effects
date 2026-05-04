#!/bin/bash
# Re-render all forest-plot HTMLs + PNGs + grids across both trees
# (publication/forest_plots/ and present/), both sort modes, all 5 scripts.
# Usage: bash bash_scripts/plots/rerun_all.sh
set -e
# cd to repo root so relative paths inside the R scripts resolve consistently
# (model_fits/, publication/, etc.) regardless of caller cwd.
cd "$(dirname "$0")/../.."
for s in publication/render/create_forest_plots_restaurants_chosen_recolored.R \
         publication/render/create_forest_plots_restaurants_chosen_recolored_t2.R \
         publication/render/create_forest_plots_restaurants_chosen_recolored_adj.R \
         publication/render/create_forest_plots_restaurants_chosen_recolored_adj_t2.R \
         publication/render/create_customer_day_forest_plots_consolidated.R; do
  for pm in "" "TRUE"; do
    for sm in "" "TRUE"; do
      echo "=== PRESENT_MODE='$pm' SORT_BY_MEAN='$sm' $s ==="
      PRESENT_MODE="$pm" SORT_BY_MEAN="$sm" Rscript "$s"
    done
  done
done
python3 publication/splice_grids.py
GRID_ROOT=present python3 publication/splice_grids.py
echo "all done"

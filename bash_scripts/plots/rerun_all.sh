#!/bin/bash
# THIS SCRIPT POPULATES present/ -- THE HTML PRESENTATION, NOT THE PAPER.
#
# It runs the *_recolored{,_t2}.R renderers with PRESENT_MODE set, which routes
# present_path() to present/base/ and present/z_log_and_overlay/. Those trees
# have no other producer.
#
# It does NOT touch the publication figures. Those are rebuilt with:
#     ADJ_FIXED=TRUE Rscript publication/render/render_professional_wide_fixed.R
#
# See the header of create_forest_plots_restaurants_chosen_recolored.R, and
# PIPELINE.md section 7 item 7 on keeping *_OVERRIDES in step with the manifests
# before trusting a run of this.
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

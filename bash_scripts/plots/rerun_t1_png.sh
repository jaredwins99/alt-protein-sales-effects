#!/bin/bash
# Re-render only the T1 PNGs (publication/forest_plots/ tree, both sort modes).
# Runs the three scripts that produce T1 output:
#   - publication/render/create_forest_plots_restaurants_chosen_recolored.R       (T1 base A1-A5)
#   - publication/render/create_forest_plots_restaurants_chosen_recolored_adj.R   (T1 adj A1-A5)
#   - publication/render/create_customer_day_forest_plots_consolidated.R          (A5/A6 day, both tiers)
# Then regenerates publication/forest_plots/ grids.
# Note: the consolidated script also writes T2 A5/A6 as a side effect.
# Usage: bash bash_scripts/plots/rerun_t1_png.sh
set -e
cd "$(dirname "$0")/../.."
for sm in "" "TRUE"; do
  echo "=== SORT_BY_MEAN='$sm' T1 base ==="
  SORT_BY_MEAN="$sm" Rscript publication/render/create_forest_plots_restaurants_chosen_recolored.R
  echo "=== SORT_BY_MEAN='$sm' T1 adj ==="
  SORT_BY_MEAN="$sm" Rscript publication/render/create_forest_plots_restaurants_chosen_recolored_adj.R
  echo "=== SORT_BY_MEAN='$sm' consolidated (A5/A6 day) ==="
  SORT_BY_MEAN="$sm" Rscript publication/render/create_customer_day_forest_plots_consolidated.R
done
python3 publication/splice_grids.py
echo "T1 png done"

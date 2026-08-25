#!/bin/bash
# render_present.sh — rebuild the interactive present/ bundle.
#
# present/ is the HTML counterpart of the two FINAL publication deliverables.
# It is produced by the SAME sub-renderers, with PRESENT_MODE=TRUE, so the
# estimates are identical by construction rather than by hand-syncing.
#
# Two bundles are produced, matching the two finals. They separate themselves
# by output-dir suffix, so one run of each is all that is needed:
#
#   style    env                                    -> present/total_adjusted/...
#   sorted   SORT_BY_MEAN=TRUE                         t{1,2}_sorted_recentered_wide_fixed
#            (matches professional_wide_fixed/)
#   labeled  SORT_BY_MEAN=FALSE LABELED_MODE=TRUE      t{1,2}_recentered_wide_fixed
#            LABELED_V2=TRUE (matches professional_labeled_v2/)
#
# Why not reuse render_professional_wide_fixed.R / _labeled_v2.R: those carry
# hard-coded "publication/forest_plots/professional_*" copy destinations. Run
# under PRESENT_MODE they would read a stale source and copy over the finals.
# So the sub-renderers are sourced directly here and there is no copy step.
#
# PRO_FAST must stay OFF: it skips PNG + plotly + HTML, which is the entire
# point of present/.
set -u
cd /home/godli/testing

SUBS=(
  publication/render/create_forest_plots_restaurants_chosen_recolored_adj.R
  publication/render/create_forest_plots_restaurants_chosen_recolored_adj_t2.R
  publication/render/create_customer_day_forest_plots_consolidated.R
)

run_style () {
  local name="$1"; shift
  echo "=============================================="
  echo "  present/ style: $name"
  echo "=============================================="
  for sub in "${SUBS[@]}"; do
    echo "--- $(basename "$sub")"
    env PRESENT_MODE=TRUE ADJ_FIXED=TRUE PUB_RECENTER=TRUE PUB_WIDE=TRUE \
        PRO_FAST=FALSE PRO_ONLY=ALL PRO_TIER=BOTH "$@" \
        Rscript -e "source('$sub')" 2>&1 \
      | grep -E "Saved:|Error|Output directory" || true
  done
}

run_style "sorted (= professional_wide_fixed)"  SORT_BY_MEAN=TRUE
run_style "labeled (= professional_labeled_v2)" SORT_BY_MEAN=FALSE LABELED_MODE=TRUE LABELED_V2=TRUE

echo
echo "PRESENT DONE"

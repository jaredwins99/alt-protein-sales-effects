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
#
# PUB_WIDE stays OFF here. It is what splits T2 A1 into a/b/c and A3 into a/b,
# which keeps the printed PDFs legible but would give T2 nine tiles against
# T1's six. Without it each analysis is a single plot -- nothing is combined,
# the split simply never happens -- so the grid is a clean 2x6. The PDFs are
# unaffected: they render with PUB_WIDE=TRUE via their own entry scripts.
set -u
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && git rev-parse --show-toplevel)"

SUBS=(
  publication/render/create_forest_plots_restaurants_chosen_recolored_adj.R
  publication/render/create_forest_plots_restaurants_chosen_recolored_adj_t2.R
  publication/render/create_customer_day_forest_plots_consolidated.R
)

# Bundle output dirs, cleared before each run. Without this, output from a
# previous run with different settings survives -- e.g. the split A1a/A1b/A1c
# and A3a/A3b pages linger after switching to PUB_SPLIT=FALSE, and the grid
# then shows both the split and unsplit versions.
BUNDLE_DIRS=(
  present/total_adjusted/t1_sorted_recentered_fixed
  present/total_adjusted/t2_sorted_recentered_fixed
  present/total_adjusted/t1_recentered_fixed
  present/total_adjusted/t2_recentered_fixed
)

run_style () {
  local name="$1"; shift
  echo "=============================================="
  echo "  present/ style: $name"
  echo "=============================================="
  # One analysis per Rscript process. Rendering all of A1-A4 in a single
  # process holds every plot object and its plotly widget live at once, which
  # exceeded the memory cap on an unsplit T2 run. Separate processes let the OS
  # reclaim between analyses. PUB_LOG=FALSE drops the log-scale companion
  # passes, roughly halving the work -- present/ never uses them.
  for sub in "${SUBS[@]}"; do
    case "$(basename "$sub")" in
      *_adj.R|*_adj_t2.R) ANALYSES="A1 A2 A3 A4" ;;
      *)                  ANALYSES="ALL" ;;
    esac
    for an in $ANALYSES; do
      echo "--- $(basename "$sub")  [$an]"
      env PRESENT_MODE=TRUE ADJ_FIXED=TRUE PUB_RECENTER=TRUE PUB_WIDE=FALSE \
          PRO_FAST=FALSE PRO_ONLY="$an" PRO_TIER=BOTH PUB_LOG=FALSE "$@" \
          Rscript -e "source('$sub')" 2>&1 \
        | grep -E "Saved:|Error|Output directory" || true
    done
  done
}

for d in "${BUNDLE_DIRS[@]}"; do rm -rf "$d"; done
echo "cleared bundle output dirs"

run_style "sorted (= professional_wide_fixed)"  SORT_BY_MEAN=TRUE
run_style "labeled (= professional_labeled_v2)" SORT_BY_MEAN=FALSE LABELED_MODE=TRUE LABELED_V2=TRUE

# The sub-renderers also emit the unadjusted (base/) and log-scale
# (z_log_and_overlay/) variants on every run. present/ is meant to mirror the
# publication PDFs, which are total-adjusted only, so those are swept into
# archive/present/ rather than left sitting beside the bundles. Done here, after
# the render, because they are recreated every time.
for d in base z_log_and_overlay; do
  if [ -d "present/$d" ]; then
    mkdir -p "archive/present"
    rm -rf "archive/present/$d"
    mv "present/$d" "archive/present/$d"
    echo "archived present/$d -> archive/present/$d"
  fi
done

# The consolidated renderer also emits the TRANSACTION-level A5 alongside the
# day-level one. The publication PDFs use only the day-level A5/A6, so the
# transaction variants are moved out to keep each bundle a clean A1-A6.
for d in "${BUNDLE_DIRS[@]}"; do
  [ -d "$d" ] || continue
  dest="archive/present/a5_transaction_level/$(basename "$d")"
  mkdir -p "$dest"
  for pat in A5_gaussian_iid_forest_restaurants_adj A5_gaussian_iid_restaurants_adj_data \
             z_A5_transaction_gaussian_iid_forest_restaurants_adj z_A5_transaction_gaussian_iid_restaurants_adj_data; do
    for f in "$d/$pat"*; do [ -e "$f" ] && mv "$f" "$dest"/; done
  done
done
echo "moved transaction-level A5 variants to archive/present/a5_transaction_level"

# Every plot HTML is emitted with its own copy of the htmlwidgets/plotly
# assets. Collapse them into one shared directory: a grid page holds twelve of
# these in twelve iframes, and without this it pulls the same 3.4 MB plotly
# bundle twelve times.
bash publication/scripts/share_present_libs.sh

# Tile sizing needs each plot's natural height at the grid's render width.
# Needs a chromium; skipped with a warning if none is available, in which case
# the grids fall back to the previous measurements.
# playwright-core resolves its own browser when CHROME is unset, so just run it
# and fall back on failure rather than guessing at install paths.
node publication/scripts/measure_present_plot_sizes.js present/total_adjusted/*/A*.html \
  || echo "  measurement failed; keeping the existing present_plot_sizes.json"

# Grid entry pages are generated from whatever each bundle contains.
python3 publication/scripts/make_present_grids.py

echo
echo "PRESENT DONE"

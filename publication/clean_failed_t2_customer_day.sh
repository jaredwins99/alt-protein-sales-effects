#!/bin/bash
# Remove incomplete day-level T2 customer fit dirs on Sherlock $SCRATCH.
# A "failed" dir = no fit.rds present (Stan never finished sampling).
# Pass `--dry-run` to list without deleting.

set -u
ROOTS=(
  "$SCRATCH/model_fits/finalized_redone_trunc_cp/t2_a5_customer_day"
  "$SCRATCH/model_fits/finalized_redone_trunc_cp/t2_a6_customer_t_day"
)

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

for root in "${ROOTS[@]}"; do
  [ -d "$root" ] || { echo "(missing) $root"; continue; }
  for d in "$root"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    if [ -f "$d/fit.rds" ]; then
      echo "KEEP   $d"
    else
      if [ $DRY -eq 1 ]; then
        echo "WOULD DELETE  $d"
      else
        rm -rf "$d"
        echo "DELETED       $d"
      fi
    fi
  done
done

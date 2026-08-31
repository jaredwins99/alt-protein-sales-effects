#!/bin/bash
# Two-pass adjusted-estimate extraction, memory-bounded.
#   Pass 1: one subprocess per fit -> slim per-fit draws (peak reclaimed between fits)
#   Pass 2: join slim files by NAME into corrected RRR estimates
# Slim dir lives outside the session scratchpad, which gets wiped mid-run.
set -u
SLIM="${1:-/var/tmp/adj_slim}"
OUT="${2:-publication/forest_data_adj_95ci_fixed.csv}"
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && git rev-parse --show-toplevel)"
mkdir -p "$SLIM"
echo "=== PASS 1 -> $SLIM ==="
tail -n +2 publication/scripts/adj_fixed_dirs.csv | tr -d '"' | while IFS=, read -r dir mb; do
  [ -z "$dir" ] && continue
  out="$SLIM/$(echo "${dir#model_fits/}" | sed 's|/|__|g').rds"
  [ -f "$out" ] && { echo "[skip] $dir"; continue; }
  peak=$( { /usr/bin/time -f "%M" Rscript publication/scripts/slim_extract_one.R "$dir" "$out" >/dev/null; } 2>&1 | tail -1 )
  if [ -f "$out" ]; then echo "[ok] ${mb}MB peak$(( peak/1024 ))MB $dir"; else echo "[FAIL] $dir"; fi
done
echo "=== PASS 2 ==="
Rscript publication/scripts/adj_join_pass2.R "$SLIM" publication/scripts/adj_fixed_pairs.csv "$OUT"
echo "ALLDONE"

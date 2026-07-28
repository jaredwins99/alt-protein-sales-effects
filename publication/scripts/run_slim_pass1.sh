#!/bin/bash
# One fit per subprocess so peak RSS is reclaimed between fits.
S="$1"; cd /home/godli/testing
mkdir -p "$S/slim"
n=0; fail=0
tail -n +2 "$S/need_dirs.csv" | tr -d '"' | while IFS=, read -r dir mb; do
  [ -z "$dir" ] && continue
  n=$((n+1))
  out="$S/slim/$(echo "${dir#model_fits/}" | sed 's|/|__|g').rds"
  if [ -f "$out" ]; then echo "[skip] $dir"; continue; fi
  peak=$( { /usr/bin/time -f "%M" Rscript publication/scripts/slim_extract_one.R "$dir" "$out" >/dev/null; } 2>&1 | tail -1 )
  if [ -f "$out" ]; then
    echo "[ok] ${mb}MB peak$(( peak/1024 ))MB  $dir"
  else
    echo "[FAIL] $dir"; fail=$((fail+1))
  fi
done
echo "DONE slim pass"

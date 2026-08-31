#!/bin/bash
# Collapse the per-plot htmlwidgets asset directories into one shared copy.
#
# Every plot HTML ships its own <stem>_files/ tree, and they are byte-identical
# -- 24 copies of a 3.4 MB plotly bundle. The grid pages put twelve of those
# HTMLs in twelve iframes, so opening a grid downloaded plotly twelve times
# over: ~48 MB of identical JavaScript on one page load. Pointing every HTML at
# a single URL means the browser fetches and caches it once for the whole grid.
#
# Idempotent: reruns after a rebuild that recreated the per-plot dirs.
set -eu
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && git rev-parse --show-toplevel)"
BASE=present/total_adjusted
LIB="$BASE/lib"

first=$(find "$BASE" -maxdepth 2 -type d -name "*_files" | head -1)
[ -n "$first" ] || { echo "  no per-plot asset dirs; nothing to share"; exit 0; }

# Assert they really are interchangeable before collapsing them.
sig=$( (cd "$first" && find . -type f -exec md5sum {} + | sort -k2 | md5sum) )
for d in $(find "$BASE" -maxdepth 2 -type d -name "*_files"); do
  s=$( (cd "$d" && find . -type f -exec md5sum {} + | sort -k2 | md5sum) )
  [ "$s" = "$sig" ] || { echo "  ABORT: $d differs from $first"; exit 1; }
done

rm -rf "$LIB"; mkdir -p "$LIB"; cp -a "$first"/. "$LIB"/

n=0
for f in "$BASE"/*/*.html; do
  stem=$(basename "$f" .html)
  [ -d "$(dirname "$f")/${stem}_files" ] || continue
  sed -i "s#\"${stem}_files/#\"../lib/#g" "$f"
  rm -rf "$(dirname "$f")/${stem}_files"
  n=$((n + 1))
done
echo "  shared assets: $n plots now point at $LIB ($(du -sh "$LIB" | cut -f1))"

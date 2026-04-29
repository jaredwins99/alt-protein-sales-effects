#!/usr/bin/env python3
"""
validate_forest_html.py

Measures spacing quality across all forest-plot HTMLs. Used to programmatically
detect cramped / non-uniform HTMLs before and after changes.

Walks:
  - forest_plots/**/*.html
  - present/**/*.html

For each HTML, extracts from the embedded ggplotly JSON (inside the first
<script type="application/json" data-for="..."> tag):
  - layout.height (widget height in px)
  - primary y-axis range (yaxis.range = [lo, hi])
  - number of scatter data points

Computes:
  y_span       = hi - lo
  px_per_y_unit = height / y_span

Flags:
  NO_HEIGHT   if layout.height is missing (falls back to plotly's 400 default)
  CRAMPED     if px_per_y_unit < 30
  LOOSE       if px_per_y_unit > 200
  OK          otherwise

Writes tools/html_spacing_report.csv and prints a summary + first 10 non-OK
flagged files.

Stdlib-only: json, re, csv, pathlib, sys.
"""

from __future__ import annotations

import csv
import json
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
OUT_CSV = Path(__file__).resolve().parent / "html_spacing_report.csv"

# Thresholds
CRAMPED_THRESHOLD = 30.0
LOOSE_THRESHOLD = 200.0
PLOTLY_DEFAULT_HEIGHT = 400  # ggplotly/plotly default when layout.height is missing

# Regex for the embedded ggplotly JSON block
JSON_SCRIPT_RE = re.compile(
    r'<script\s+type="application/json"\s+data-for="[^"]*"\s*>(.*?)</script>',
    re.DOTALL,
)


def extract_metrics(html_path: Path) -> dict[str, Any]:
    """Extract spacing metrics from a single HTML. Returns dict with
    keys: path, height, y_lo, y_hi, y_span, px_per_y_unit, n_points, status.
    On any failure to parse, returns status='PARSE_ERROR' with as much info as possible.
    """
    rec: dict[str, Any] = {
        "path": str(html_path),
        "height": "",
        "y_lo": "",
        "y_hi": "",
        "y_span": "",
        "px_per_y_unit": "",
        "n_points": "",
        "status": "",
    }

    try:
        html = html_path.read_text(encoding="utf-8", errors="replace")
    except OSError as e:
        rec["status"] = f"READ_ERROR:{e.__class__.__name__}"
        return rec

    m = JSON_SCRIPT_RE.search(html)
    if not m:
        rec["status"] = "NO_JSON"
        return rec

    try:
        payload = json.loads(m.group(1))
    except json.JSONDecodeError:
        rec["status"] = "BAD_JSON"
        return rec

    x = payload.get("x")
    if not isinstance(x, dict):
        rec["status"] = "NO_X"
        return rec

    layout = x.get("layout") if isinstance(x.get("layout"), dict) else {}
    data = x.get("data") if isinstance(x.get("data"), list) else []

    # layout.height may legitimately be None / missing. Detect that separately
    # from the fallback used for the metric calculation.
    raw_height = layout.get("height") if isinstance(layout, dict) else None
    height_missing = raw_height is None
    try:
        height = float(raw_height) if raw_height is not None else float(PLOTLY_DEFAULT_HEIGHT)
    except (TypeError, ValueError):
        height_missing = True
        height = float(PLOTLY_DEFAULT_HEIGHT)

    rec["height"] = "" if height_missing else height

    # Primary y-axis range
    yaxis = layout.get("yaxis") if isinstance(layout, dict) else None
    y_lo = y_hi = None
    if isinstance(yaxis, dict):
        rng = yaxis.get("range")
        if isinstance(rng, list) and len(rng) == 2:
            try:
                y_lo = float(rng[0])
                y_hi = float(rng[1])
            except (TypeError, ValueError):
                y_lo = y_hi = None

    # Count scatter points (sum of len(y) across all scatter traces)
    n_points = 0
    for trace in data:
        if not isinstance(trace, dict):
            continue
        if trace.get("type") != "scatter":
            continue
        y = trace.get("y")
        if isinstance(y, list):
            n_points += len(y)
    rec["n_points"] = n_points

    if y_lo is None or y_hi is None:
        rec["status"] = "NO_YRANGE"
        return rec

    y_span = y_hi - y_lo
    rec["y_lo"] = y_lo
    rec["y_hi"] = y_hi
    rec["y_span"] = y_span

    if y_span <= 0:
        rec["status"] = "BAD_YSPAN"
        return rec

    px_per_y_unit = height / y_span
    rec["px_per_y_unit"] = px_per_y_unit

    # Status precedence: NO_HEIGHT takes priority over CRAMPED/LOOSE because
    # the metric is based on a fallback in that case.
    if height_missing:
        rec["status"] = "NO_HEIGHT"
    elif px_per_y_unit < CRAMPED_THRESHOLD:
        rec["status"] = "CRAMPED"
    elif px_per_y_unit > LOOSE_THRESHOLD:
        rec["status"] = "LOOSE"
    else:
        rec["status"] = "OK"

    return rec


def iter_html_files() -> list[Path]:
    """Return all forest_plots/**/*.html and present/**/*.html under ROOT."""
    files: list[Path] = []
    for sub in ("forest_plots", "present"):
        base = ROOT / sub
        if base.is_dir():
            files.extend(sorted(base.rglob("*.html")))
    return files


def main() -> int:
    html_files = iter_html_files()
    if not html_files:
        print(f"[validate_forest_html] no HTML files found under {ROOT}/forest_plots or {ROOT}/present")
        return 1

    records = [extract_metrics(p) for p in html_files]

    # Write CSV
    OUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    cols = ["path", "height", "y_lo", "y_hi", "y_span", "px_per_y_unit", "n_points", "status"]
    with OUT_CSV.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        for rec in records:
            row = {k: rec.get(k, "") for k in cols}
            # Round floats for readability in the CSV
            for fld in ("height", "y_lo", "y_hi", "y_span", "px_per_y_unit"):
                v = row[fld]
                if isinstance(v, float):
                    row[fld] = f"{v:.4f}"
            w.writerow(row)

    # Summary
    status_counts: dict[str, int] = {}
    for rec in records:
        status_counts[rec["status"]] = status_counts.get(rec["status"], 0) + 1

    total = len(records)
    non_ok = sum(c for s, c in status_counts.items() if s != "OK")

    print(f"[validate_forest_html] scanned {total} HTMLs under forest_plots/ and present/")
    print(f"[validate_forest_html] report: {OUT_CSV}")
    print("")
    print("Summary (status -> count):")
    # Stable, readable ordering: OK first, then CRAMPED/LOOSE/NO_HEIGHT, then others
    ordered_keys = ["OK", "CRAMPED", "LOOSE", "NO_HEIGHT", "NO_JSON", "BAD_JSON",
                    "NO_X", "NO_YRANGE", "BAD_YSPAN"]
    seen = set()
    for k in ordered_keys:
        if k in status_counts:
            print(f"  {k:<12} {status_counts[k]}")
            seen.add(k)
    for k in sorted(status_counts.keys()):
        if k not in seen:
            print(f"  {k:<12} {status_counts[k]}")
    print("")
    print(f"Flagged (non-OK) total: {non_ok}")
    print("")

    # First 10 flagged non-OK files with details
    flagged = [r for r in records if r["status"] != "OK"]
    print(f"First {min(10, len(flagged))} flagged files:")
    for rec in flagged[:10]:
        rel = str(Path(rec["path"]).relative_to(ROOT)) if str(rec["path"]).startswith(str(ROOT)) else rec["path"]
        h = rec["height"] if rec["height"] != "" else "NA"
        ys = rec["y_span"] if rec["y_span"] != "" else "NA"
        ppy = rec["px_per_y_unit"] if rec["px_per_y_unit"] != "" else "NA"
        np_ = rec["n_points"] if rec["n_points"] != "" else "NA"
        def fmt(v):
            return f"{v:.2f}" if isinstance(v, float) else str(v)
        print(f"  [{rec['status']:<10}] {rel}")
        print(f"      height={fmt(h)}  y_span={fmt(ys)}  px_per_y_unit={fmt(ppy)}  n_points={fmt(np_)}")

    return 0


if __name__ == "__main__":
    sys.exit(main())

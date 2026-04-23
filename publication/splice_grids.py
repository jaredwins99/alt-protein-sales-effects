#!/usr/bin/env python3
"""Compose 2x3 grids of A1..A6 PNGs into a single image, plus an HTML wrapper
that iframes the 6 HTML plotly widgets.

Scans forest_plots/{base,total_adjusted}/{t1,t2,t1_sorted,t2_sorted}/ for PNGs
matching A1_*.png .. A6_*.png (and the day-level A5/A6 variants) and writes
<dir>/grid.png and <dir>/grid.html alongside.
"""
from PIL import Image
from pathlib import Path
import os, html

ROOT = Path(__file__).resolve().parent.parent
FP = ROOT / os.environ.get("GRID_ROOT", "forest_plots")

# Which filename pattern represents each slot. The adj dirs may use *_adj.png.
SLOT_PATTERNS = {
    "A1": ["A1_proportion_forest_restaurants"],
    "A2": ["A2_proportion_targeted_forest_restaurants"],
    "A3": ["A3_its_forest_restaurants"],
    "A4": ["A4_its_targeted_forest_restaurants"],
    "A5": ["A5_gaussian_iid_day_forest_restaurants",
           "A5_gaussian_iid_day_forest_restaurants_adj"],
    "A6": ["A6_gaussian_iid_day_targeted_forest_restaurants",
           "A6_gaussian_iid_day_targeted_forest_restaurants_adj"],
}

GRID = [["A1", "A3", "A5"], ["A2", "A4", "A6"]]  # top = non-targeted, bottom = targeted

def find_file(dir_path: Path, slot: str, ext: str) -> Path | None:
    for stem in SLOT_PATTERNS[slot]:
        p = dir_path / f"{stem}.{ext}"
        if p.exists():
            return p
    return None

def compose_png(dir_path: Path) -> Path | None:
    imgs = [[find_file(dir_path, slot, "png") for slot in row] for row in GRID]
    if all(all(c is None for c in row) for row in imgs):
        return None
    # Normalize cell sizes: use max dims so all cells align
    loaded = [[Image.open(p) if p else None for p in row] for row in imgs]
    cell_w = max(im.width for row in loaded for im in row if im)
    cell_h = max(im.height for row in loaded for im in row if im)
    out = Image.new("RGB", (cell_w * 3, cell_h * 2), "white")
    for r, row in enumerate(loaded):
        for c, im in enumerate(row):
            if im is None:
                continue
            # Preserve aspect ratio, place at top-left of cell
            im = im.convert("RGB")
            scale = min(cell_w / im.width, cell_h / im.height, 1.0)
            if scale < 1.0:
                im = im.resize((int(im.width * scale), int(im.height * scale)))
            out.paste(im, (c * cell_w, r * cell_h))
    out_path = dir_path / "grid.png"
    out.save(out_path, optimize=True)
    return out_path

def compose_html(dir_path: Path) -> Path | None:
    cells = []
    any_found = False
    for row in GRID:
        for slot in row:
            h = find_file(dir_path, slot, "html")
            if h:
                any_found = True
                cells.append(
                    f'<div class="cell">'
                    f'<iframe src="{html.escape(h.name)}"></iframe>'
                    f'<button class="zoom-btn" title="Expand {slot}">⛶</button>'
                    f'<button class="close-btn" title="Close (Esc)">✕</button></div>')
            else:
                cells.append(f'<div class="missing">{slot}<br><small>(no html)</small></div>')
    if not any_found:
        return None
    tpl = """<!doctype html>
<html><head><meta charset="utf-8"><title>2x3 grid</title>
<style>
body{margin:0;font-family:sans-serif;background:#fff}
.grid{display:grid;grid-template-columns:repeat(3,1fr);grid-template-rows:repeat(2,1fr);gap:4px;width:100vw;height:100vh}
.cell{position:relative;overflow:hidden;border:1px solid #ccc}
.cell iframe{width:100%;height:100%;border:0}
.cell.expanded{position:fixed;inset:0;z-index:9999;background:#fff}
.cell.dimmed{opacity:0.15}
.missing{display:flex;align-items:center;justify-content:center;color:#999;border:1px dashed #ccc}
.zoom-btn,.close-btn{position:absolute;top:6px;right:6px;z-index:10;width:30px;height:30px;border:0;border-radius:50%;color:#fff;font-size:16px;line-height:30px;cursor:pointer;padding:0;font-weight:bold;box-shadow:0 2px 4px rgba(0,0,0,0.25)}
.zoom-btn{background:rgba(0,0,0,0.55)}
.zoom-btn:hover{background:rgba(0,100,200,0.85)}
.close-btn{background:rgba(180,0,0,0.85);display:none;width:40px;height:40px;font-size:20px;line-height:40px;top:8px;right:8px}
.close-btn:hover{background:rgba(220,0,0,1)}
.cell.expanded .zoom-btn{display:none}
.cell.expanded .close-btn{display:block}
</style></head><body><div class="grid" id="g">
__CELLS__
</div>
<script>
function toggleCell(cell){
  const expand = !cell.classList.contains('expanded');
  cell.classList.toggle('expanded', expand);
  document.querySelectorAll('#g .cell').forEach(o=>{if(o!==cell)o.classList.toggle('dimmed', expand)});
  // wire Esc inside the iframe once loaded (same-origin local files)
  if(expand){
    try{
      const ifr = cell.querySelector('iframe');
      const doc = ifr.contentDocument || ifr.contentWindow.document;
      doc.addEventListener('keydown', escHandler, {capture:true});
    }catch(e){}
  }
}
function escHandler(e){
  if(e.key==='Escape'){
    const ex=document.querySelector('#g .cell.expanded');
    if(ex) toggleCell(ex);
  }
}
document.querySelectorAll('#g .zoom-btn').forEach(b=>{
  b.addEventListener('click', e=>{e.stopPropagation(); toggleCell(b.closest('.cell'));});
});
document.querySelectorAll('#g .close-btn').forEach(b=>{
  b.addEventListener('click', e=>{e.stopPropagation(); toggleCell(b.closest('.cell'));});
});
document.addEventListener('keydown', escHandler);
</script>
</body></html>
"""
    out_path = dir_path / "grid.html"
    out_path.write_text(tpl.replace("__CELLS__", "\n".join(cells)))
    return out_path

def compose_both_tiers_png(parent_dir: Path, suffix: str) -> Path | None:
    """2x6: row 1 = T1 A1..A6, row 2 = T2 A1..A6."""
    t1_dir = parent_dir / f"t1{suffix}"
    t2_dir = parent_dir / f"t2{suffix}"
    if not (t1_dir.is_dir() and t2_dir.is_dir()):
        return None
    rows = [
        [find_file(t1_dir, slot, "png") for slot in ("A1","A2","A3","A4","A5","A6")],
        [find_file(t2_dir, slot, "png") for slot in ("A1","A2","A3","A4","A5","A6")],
    ]
    loaded = [[Image.open(p) if p else None for p in row] for row in rows]
    flat = [im for row in loaded for im in row if im]
    if not flat:
        return None
    cell_w = max(im.width  for im in flat)
    cell_h = max(im.height for im in flat)
    out = Image.new("RGB", (cell_w * 6, cell_h * 2), "white")
    for r, row in enumerate(loaded):
        for c, im in enumerate(row):
            if im is None:
                continue
            im = im.convert("RGB")
            scale = min(cell_w / im.width, cell_h / im.height, 1.0)
            if scale < 1.0:
                im = im.resize((int(im.width * scale), int(im.height * scale)))
            out.paste(im, (c * cell_w, r * cell_h))
    out_path = parent_dir / f"grid_both{suffix}.png"
    out.save(out_path, optimize=True)
    return out_path

def compose_both_tiers_html(parent_dir: Path, suffix: str) -> Path | None:
    t1_dir = parent_dir / f"t1{suffix}"
    t2_dir = parent_dir / f"t2{suffix}"
    if not (t1_dir.is_dir() and t2_dir.is_dir()):
        return None
    cells = []
    any_found = False
    for tier_dir, tier_lbl in ((t1_dir, "T1"), (t2_dir, "T2")):
        for slot in ("A1","A2","A3","A4","A5","A6"):
            h = find_file(tier_dir, slot, "html")
            label = f"{tier_lbl} {slot}"
            if h:
                any_found = True
                rel = f"{tier_dir.name}/{h.name}"
                cells.append(
                    f'<div class="cell">'
                    f'<iframe src="{html.escape(rel)}"></iframe>'
                    f'<button class="zoom-btn" title="Expand {label}">⛶</button>'
                    f'<button class="close-btn" title="Close (Esc)">✕</button></div>')
            else:
                cells.append(f'<div class="missing">{label}<br><small>(no html)</small></div>')
    if not any_found:
        return None
    tpl = """<!doctype html>
<html><head><meta charset="utf-8"><title>2x6 both-tier grid</title>
<style>
body{margin:0;font-family:sans-serif;background:#fff}
.grid{display:grid;grid-template-columns:repeat(6,1fr);grid-template-rows:repeat(2,1fr);gap:4px;width:100vw;height:100vh}
.cell{position:relative;overflow:hidden;border:1px solid #ccc}
.cell iframe{width:100%;height:100%;border:0}
.cell.expanded{position:fixed;inset:0;z-index:9999;background:#fff}
.cell.dimmed{opacity:0.15}
.missing{display:flex;align-items:center;justify-content:center;color:#999;border:1px dashed #ccc}
.zoom-btn,.close-btn{position:absolute;top:6px;right:6px;z-index:10;width:30px;height:30px;border:0;border-radius:50%;color:#fff;font-size:16px;line-height:30px;cursor:pointer;padding:0;font-weight:bold;box-shadow:0 2px 4px rgba(0,0,0,0.25)}
.zoom-btn{background:rgba(0,0,0,0.55)}
.zoom-btn:hover{background:rgba(0,100,200,0.85)}
.close-btn{background:rgba(180,0,0,0.85);display:none;width:40px;height:40px;font-size:20px;line-height:40px;top:8px;right:8px}
.close-btn:hover{background:rgba(220,0,0,1)}
.cell.expanded .zoom-btn{display:none}
.cell.expanded .close-btn{display:block}
</style></head><body><div class="grid" id="g">
__CELLS__
</div>
<script>
function toggleCell(cell){
  const expand = !cell.classList.contains('expanded');
  cell.classList.toggle('expanded', expand);
  document.querySelectorAll('#g .cell').forEach(o=>{if(o!==cell)o.classList.toggle('dimmed', expand)});
  // wire Esc inside the iframe once loaded (same-origin local files)
  if(expand){
    try{
      const ifr = cell.querySelector('iframe');
      const doc = ifr.contentDocument || ifr.contentWindow.document;
      doc.addEventListener('keydown', escHandler, {capture:true});
    }catch(e){}
  }
}
function escHandler(e){
  if(e.key==='Escape'){
    const ex=document.querySelector('#g .cell.expanded');
    if(ex) toggleCell(ex);
  }
}
document.querySelectorAll('#g .zoom-btn').forEach(b=>{
  b.addEventListener('click', e=>{e.stopPropagation(); toggleCell(b.closest('.cell'));});
});
document.querySelectorAll('#g .close-btn').forEach(b=>{
  b.addEventListener('click', e=>{e.stopPropagation(); toggleCell(b.closest('.cell'));});
});
document.addEventListener('keydown', escHandler);
</script>
</body></html>
"""
    out_path = parent_dir / f"grid_both{suffix}.html"
    out_path.write_text(tpl.replace("__CELLS__", "\n".join(cells)))
    return out_path

def main():
    for parent in ("base", "total_adjusted"):
        for tier in ("t1", "t2", "t1_sorted", "t2_sorted"):
            d = FP / parent / tier
            if not d.is_dir():
                continue
            png = compose_png(d)
            html_out = compose_html(d)
            print(f"{d}: png={'OK' if png else '—'}, html={'OK' if html_out else '—'}")
        # 2x6 both-tier grids (unsorted + sorted)
        for sfx in ("", "_sorted"):
            parent_dir = FP / parent
            png_both = compose_both_tiers_png(parent_dir, sfx)
            html_both = compose_both_tiers_html(parent_dir, sfx)
            print(f"{parent_dir}/grid_both{sfx}: png={'OK' if png_both else '—'}, html={'OK' if html_both else '—'}")

if __name__ == "__main__":
    main()

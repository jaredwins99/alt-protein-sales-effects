#!/usr/bin/env python3
"""Generate the present/ grid entry pages.

One page per bundle, each a tier-by-tier grid of iframes over whatever plot
HTMLs that bundle actually contains. Generated rather than hand-maintained:
the previous pages were a hard-coded 2x6 that silently broke when T2 grew from
6 plots to 9 (A1 splits into a/b/c and A3 into a/b under PUB_WIDE), and again
when the bundle directories were renamed.

Run after render_present.sh.
"""
import html, json, os, re, sys

ROOT = "/home/godli/testing"
BASE = os.path.join(ROOT, "present/total_adjusted")

BUNDLES = {
    "grid_sorted.html": ("Sorted / unlabeled  (= professional_wide_fixed)",
                         "t1_sorted_recentered_fixed", "t2_sorted_recentered_fixed"),
    "grid_labeled.html": ("Labeled  (= professional_labeled_v2)",
                          "t1_recentered_fixed", "t2_recentered_fixed"),
}

# Inline SVG rather than a font glyph. U+26F6 (SQUARE FOUR CORNERS) is absent
# from most default Linux/headless font stacks and renders as a tofu box; an
# inline path always draws.
ICON_EXPAND = ('<svg viewBox="0 0 24 24" width="13" height="13" fill="none" '
               'stroke="currentColor" stroke-width="2.4" stroke-linecap="round" '
               'stroke-linejoin="round"><path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/></svg>')
ICON_CLOSE  = ('<svg viewBox="0 0 24 24" width="16" height="16" fill="none" '
               'stroke="currentColor" stroke-width="2.6" stroke-linecap="round">'
               '<path d="M6 6l12 12M18 6L6 18"/></svg>')

ORDER = ["A1", "A2", "A3", "A4", "A5", "A6"]

def label(stem):
    m = re.match(r"(A\d[a-z]?)", stem)
    return m.group(1) if m else stem

def sort_key(stem):
    l = label(stem)
    base = l[:2]
    return (ORDER.index(base) if base in ORDER else 99, l)

SIZES_PATH = os.path.join(ROOT, "publication/scripts/present_plot_sizes.json")
SIZES = json.load(open(SIZES_PATH)) if os.path.exists(SIZES_PATH) else {}
FALLBACK = {"w": 1400, "h": 1400}

def cells(tier_dir, tier_name):
    """One tile per plot.

    Each tile carries its OWN aspect ratio rather than inheriting the row's
    tallest. A shared row aspect meant a 560px-tall A4 sat in a box sized for a
    1380px-tall A5, i.e. two thirds dead white. Rows now end ragged at the
    bottom and every tile is exactly the shape of its plot.

    The iframe is given a WIDE fixed size and then CSS-scaled down to the tile.
    Rendering it at tile width instead would make plotly reflow to ~300px, which
    collides the facet strip labels and pushes the x-axis out of view -- the tile
    would show a crop of a squashed plot rather than the whole thing. Sized wide
    and scaled, each tile is a faithful miniature of the full plot.

    Natural heights come from present_plot_sizes.json, measured once in a real
    browser at the same width (see the measure step in render_present.sh).
    """
    d = os.path.join(BASE, tier_dir)
    if not os.path.isdir(d):
        return [], 0, 1.0
    stems = sorted((f[:-5] for f in os.listdir(d) if f.endswith(".html")), key=sort_key)
    out = []
    tallest = [0.0]   # tallest height:width ratio in this tier, sets the row aspect
    for st in stems:
        src = html.escape(f"{tier_dir}/{st}.html")
        ttl = html.escape(f"{tier_name} {label(st)}")
        sz  = SIZES.get(f"{tier_dir}/{st}.html", FALLBACK)
        tallest[0] = max(tallest[0], sz["h"] / sz["w"])
        ar = sz["w"] / sz["h"]
        out.append(
            f'<div class="cell" data-w="{sz["w"]}" data-h="{sz["h"]}">'
            f'<div class="hdr"><span class="tag">{ttl}</span>'
            f'<button class="zoom-btn" title="Expand {ttl}">{ICON_EXPAND}</button></div>'
            f'<div class="view" style="--ar:{ar:.4f}">'
            f'<div class="scaler"><iframe src="{src}" loading="lazy" '
            f'style="width:{sz["w"]}px;height:{sz["h"]}px"></iframe></div></div>'
            f'<button class="close-btn" title="Close (Esc)">{ICON_CLOSE}</button></div>')
    return out, len(stems), (tallest[0] or 1.0)

CSS = """
body{margin:0;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;background:#f6f6f6;color:#222}
h2{font:600 12px/1.5 sans-serif;margin:10px 0 4px 10px;color:#444;letter-spacing:.02em;text-transform:uppercase}
.grid{display:grid;gap:8px;padding:0 10px 10px}
.grid{align-items:start}
.cell{position:relative;display:flex;flex-direction:column;background:#fff;border:1px solid #ddd;border-radius:6px;overflow:hidden}
/* The label used to float over the plot and land on top of its title. It gets
   its own strip instead, so nothing in the figure is covered. */
.hdr{flex:0 0 auto;display:flex;align-items:center;justify-content:space-between;gap:6px;padding:3px 4px 3px 7px;border-bottom:1px solid #eee;background:#fafafa}
.view{position:relative;overflow:hidden;aspect-ratio:var(--ar,1);max-height:74vh}
.scaler{position:absolute;top:0;left:0;transform-origin:top left}
.scaler iframe{border:0;display:block}
.cell.expanded{position:fixed;inset:0;z-index:9999;border-radius:0}
.cell.expanded .view{flex:1 1 auto;aspect-ratio:auto;max-height:none;overflow-y:auto}
.cell.dimmed{opacity:.12}
.tag{font:600 10px sans-serif;color:#666;letter-spacing:.03em}
.cell.expanded .tag{font-size:13px}
.zoom-btn{flex:0 0 auto;width:22px;height:22px;border:0;border-radius:50%;background:#333;color:#fff;cursor:pointer;padding:0;opacity:.45;transition:opacity .15s,background .15s;display:flex;align-items:center;justify-content:center}
.cell:hover .zoom-btn{opacity:1}
.zoom-btn:hover{background:#0969da}
.close-btn{position:absolute;top:8px;right:8px;z-index:10;background:#b00020;display:none;width:34px;height:34px;border:0;border-radius:50%;color:#fff;cursor:pointer;padding:0;align-items:center;justify-content:center}
.cell.expanded .zoom-btn{display:none}
.cell.expanded .close-btn{display:flex}
"""

JS = """
function fit(cell){
  const s = cell.querySelector('.scaler');
  const v = cell.querySelector('.view');
  if(!s || !v) return;
  const w = +cell.dataset.w, h = +cell.dataset.h;
  const box = v.getBoundingClientRect();
  const expanded = cell.classList.contains('expanded');
  // Tile: fit the whole plot so nothing is cropped.
  // Expanded: fill the width instead. Fitting the viewport leaves a tall plot
  // rendered small with big margins; filling the width is what you actually
  // want when reading one, and the cell scrolls vertically for the overflow.
  const k = expanded ? (box.width / w)
                     : Math.min(box.width / w, box.height / h);
  s.style.transform = 'scale(' + k + ')';
  s.style.left = Math.max(0, (box.width - w * k) / 2) + 'px';
  s.style.top = expanded ? '0px' : Math.max(0, (box.height - h * k) / 2) + 'px';
}
function fitAll(){ document.querySelectorAll('.cell').forEach(fit); }
function toggleCell(cell){
  const expand = !cell.classList.contains('expanded');
  cell.classList.toggle('expanded', expand);
  document.querySelectorAll('.cell').forEach(o=>{if(o!==cell)o.classList.toggle('dimmed', expand)});
  requestAnimationFrame(()=>{ fit(cell); if(!expand) fitAll(); });
  if(expand){
    try{ const ifr=cell.querySelector('iframe');
         const doc=ifr.contentDocument||ifr.contentWindow.document;
         doc.addEventListener('keydown', escHandler, {capture:true}); }catch(e){}
  }
}
function escHandler(e){
  if(e.key==='Escape'){ const ex=document.querySelector('.cell.expanded'); if(ex) toggleCell(ex); }
}
document.querySelectorAll('.zoom-btn').forEach(b=>b.addEventListener('click',e=>{e.stopPropagation();toggleCell(b.closest('.cell'));}));
document.querySelectorAll('.close-btn').forEach(b=>b.addEventListener('click',e=>{e.stopPropagation();toggleCell(b.closest('.cell'));}));
document.addEventListener('keydown', escHandler);
window.addEventListener('resize', fitAll);
window.addEventListener('load', fitAll);
fitAll();
document.querySelectorAll('iframe').forEach(f=>f.addEventListener('load', ()=>fit(f.closest('.cell'))));
"""

written = []
for fname, (title, t1, t2) in BUNDLES.items():
    c1, n1, ar1 = cells(t1, "T1")
    c2, n2, ar2 = cells(t2, "T2")
    if not c1 and not c2:
        print(f"  SKIP {fname}: no plot HTMLs found"); continue
    body = [f'<!doctype html><html><head><meta charset="utf-8">',
            f'<title>{html.escape(title)}</title><style>{CSS}</style></head><body>']
    for name, cs, n, ar in (("Tier 1", c1, n1, ar1), ("Tier 2", c2, n2, ar2)):
        if not cs: continue
        cols = 6 if n >= 6 else max(n, 1)
        body.append(f'<h2>{name} &mdash; {html.escape(title)}</h2>')
        body.append(f'<div class="grid" style="grid-template-columns:repeat({cols},1fr)">')
        body += cs
        body.append('</div>')
    body.append(f'<script>{JS}</script></body></html>')
    p = os.path.join(BASE, fname)
    open(p, "w", encoding="utf-8").write("\n".join(body))
    written.append((fname, n1, n2))

for f, a, b in written:
    print(f"  wrote {f}  (T1 {a} plots, T2 {b} plots)")

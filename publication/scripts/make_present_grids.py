#!/usr/bin/env python3
"""Generate the present/ grid entry pages.

One page per bundle, each a tier-by-tier grid of iframes over whatever plot
HTMLs that bundle actually contains. Generated rather than hand-maintained:
the previous pages were a hard-coded 2x6 that silently broke when T2 grew from
6 plots to 9 (A1 splits into a/b/c and A3 into a/b under PUB_WIDE), and again
when the bundle directories were renamed.

Run after render_present.sh.
"""
import html, os, re, sys

ROOT = "/home/godli/testing"
BASE = os.path.join(ROOT, "present/total_adjusted")

BUNDLES = {
    "grid_sorted.html": ("Sorted / unlabeled  (= professional_wide_fixed)",
                         "t1_sorted_recentered_fixed", "t2_sorted_recentered_fixed"),
    "grid_labeled.html": ("Labeled  (= professional_labeled_v2)",
                          "t1_recentered_fixed", "t2_recentered_fixed"),
}

ORDER = ["A1", "A2", "A3", "A4", "A5", "A6"]

def label(stem):
    m = re.match(r"(A\d[a-z]?)", stem)
    return m.group(1) if m else stem

def sort_key(stem):
    l = label(stem)
    base = l[:2]
    return (ORDER.index(base) if base in ORDER else 99, l)

def cells(tier_dir, tier_name):
    d = os.path.join(BASE, tier_dir)
    if not os.path.isdir(d):
        return [], 0
    stems = sorted((f[:-5] for f in os.listdir(d) if f.endswith(".html")), key=sort_key)
    out = []
    for s in stems:
        src = html.escape(f"{tier_dir}/{s}.html")
        ttl = html.escape(f"{tier_name} {label(s)}")
        out.append(
            f'<div class="cell"><iframe src="{src}" loading="lazy"></iframe>'
            f'<div class="tag">{ttl}</div>'
            f'<button class="zoom-btn" title="Expand {ttl}">&#9187;</button>'
            f'<button class="close-btn" title="Close (Esc)">&#10005;</button></div>')
    return out, len(stems)

CSS = """
body{margin:0;font-family:sans-serif;background:#fff}
h2{font:600 13px/1.6 sans-serif;margin:6px 0 2px 8px;color:#333}
.grid{display:grid;gap:4px;padding:0 4px 6px}
.cell{position:relative;overflow:hidden;border:1px solid #ccc;height:46vh}
.cell iframe{width:100%;height:100%;border:0}
.cell.expanded{position:fixed;inset:0;z-index:9999;background:#fff;height:100vh}
.cell.dimmed{opacity:.15}
.tag{position:absolute;top:6px;left:8px;z-index:9;font:600 11px sans-serif;color:#555;background:rgba(255,255,255,.85);padding:1px 5px;border-radius:3px}
.cell.expanded .tag{font-size:14px}
.zoom-btn,.close-btn{position:absolute;top:6px;right:6px;z-index:10;width:30px;height:30px;border:0;border-radius:50%;color:#fff;font-size:16px;line-height:30px;cursor:pointer;padding:0;font-weight:bold;box-shadow:0 2px 4px rgba(0,0,0,.25)}
.zoom-btn{background:rgba(0,0,0,.55)}
.zoom-btn:hover{background:rgba(0,100,200,.85)}
.close-btn{background:rgba(180,0,0,.85);display:none;width:40px;height:40px;font-size:20px;line-height:40px;top:8px;right:8px}
.close-btn:hover{background:rgba(220,0,0,1)}
.cell.expanded .zoom-btn{display:none}
.cell.expanded .close-btn{display:block}
"""

JS = """
function toggleCell(cell){
  const expand = !cell.classList.contains('expanded');
  cell.classList.toggle('expanded', expand);
  document.querySelectorAll('.cell').forEach(o=>{if(o!==cell)o.classList.toggle('dimmed', expand)});
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
"""

written = []
for fname, (title, t1, t2) in BUNDLES.items():
    c1, n1 = cells(t1, "T1")
    c2, n2 = cells(t2, "T2")
    if not c1 and not c2:
        print(f"  SKIP {fname}: no plot HTMLs found"); continue
    body = [f'<!doctype html><html><head><meta charset="utf-8">',
            f'<title>{html.escape(title)}</title><style>{CSS}</style></head><body>']
    for name, cs, n in (("Tier 1", c1, n1), ("Tier 2", c2, n2)):
        if not cs: continue
        cols = min(max(n, 1), 5)
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

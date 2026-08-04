#!/usr/bin/env python3
"""Local pair-by-pair clip review server.

Dataset-agnostic: a generator writes a pages JSON, this serves it and appends
one JSONL line per decision. See README.md.

    python3 serve.py --pages <pages.json> --decisions <out.jsonl> [--port 8770]

Pages that carry a "sensitivity" key additionally render a head-cut sensitivity
table (used by the ITS/A4 dataset); pages without it are unaffected.
"""
import json, os, html, urllib.parse, argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SRV = os.path.dirname(os.path.abspath(__file__))

ap = argparse.ArgumentParser()
ap.add_argument("--pages", required=True, help="pages JSON written by a generator")
ap.add_argument("--decisions", required=True, help="JSONL to append decisions to")
ap.add_argument("--port", type=int, default=8770)
ap.add_argument("--host", default="0.0.0.0", help="0.0.0.0 exposes on the LAN")
ap.add_argument("--title", default="clip review")
A = ap.parse_args()

PORT = A.port
PAGES = json.load(open(A.pages))
KEYS = list(PAGES)
DEC = A.decisions
TITLE = A.title

def decided():
    d = {}
    if os.path.exists(DEC):
        for line in open(DEC):
            try: r = json.loads(line); d[r["key"]] = r
            except: pass
    return d

CSS = """
*{box-sizing:border-box}body{font:13px/1.35 -apple-system,Segoe UI,Roboto,sans-serif;margin:0;background:#f7f7f7;color:#111}
.wrap{max-width:1250px;margin:0 auto;padding:12px}
.hdr{display:flex;align-items:center;gap:12px;flex-wrap:wrap;border-bottom:2px solid #111;padding-bottom:6px}
.hdr h1{font-size:20px;margin:0;font-family:ui-monospace,Menlo,monospace}
.tag{font-size:11px;padding:2px 7px;border:1px solid #999;border-radius:3px;background:#fff}
.tag.ok{background:#e8f6ec;border-color:#2e7d32;color:#1b5e20}
.tag.no{background:#fdeaea;border-color:#c62828;color:#b71c1c}
.tag.fl{background:#fff6e5;border-color:#e67e22;color:#a04000}
.verdict{font-size:15px;font-weight:600;background:#fffbe6;border-left:4px solid #e67e22;padding:7px 11px;margin:9px 0}
.analog{background:#eef5ff;border-left:4px solid #2980b9;padding:7px 11px;margin:9px 0;font-size:14px}
.analog b{font-family:ui-monospace,monospace}
table{border-collapse:collapse;width:100%;font-size:12px;background:#fff}
th,td{border:1px solid #ddd;padding:2px 6px;text-align:left;white-space:nowrap}
th{background:#efefef;font-weight:600}
td.n,th.n{text-align:right;font-variant-numeric:tabular-nums}
h2{font-size:11px;text-transform:uppercase;letter-spacing:.6px;color:#666;margin:11px 0 3px}
.grid{display:grid;grid-template-columns:1.05fr 1.25fr;gap:14px}
.sc{max-height:200px;overflow:auto;border:1px solid #ddd}
details{margin-top:8px}summary{cursor:pointer;font-size:11px;text-transform:uppercase;letter-spacing:.6px;color:#666}
.bar{display:flex;gap:9px;align-items:center;flex-wrap:wrap;background:#fff;border:1px solid #bbb;padding:9px;margin-top:10px;position:sticky;bottom:0}
button{font:600 13px sans-serif;padding:7px 17px;border:1px solid #444;background:#fff;cursor:pointer;border-radius:3px}
button.y{background:#2e7d32;color:#fff;border-color:#2e7d32}
button.n{background:#c62828;color:#fff;border-color:#c62828}
button.f{background:#e67e22;color:#fff;border-color:#e67e22}
button.sm{padding:3px 9px;font-size:15px;line-height:1}
.key{font-family:ui-monospace,monospace;font-size:11px}
svg{background:#fff;border:1px solid #ccc;width:100%;height:330px;touch-action:none}
.hl{cursor:ew-resize}
#kbd{font-size:11px;color:#666}
"""

JS = """
const S=SER, MK=MARKS, ST=STEPS, EMAX=EXMAX, CAT0=CATC0, CAT1=CATC1, CUM=CUMDATA, CD0=new Date(CUMDATA.d0), D0=new Date(S.d0), D1=new Date(new Date(S.d0).getTime()+(S.total.length-1)*86400000);
const W=1200,H=310,ML=42,MR=12,MT=10,MB=34;
let cs=REC0, ce=REC1;                       // clip start/end as yyyy-mm-dd or null
const day=86400000;
const toX=d=>ML+(new Date(d)-D0)/(D1-D0)*(W-ML-MR);
const fromX=x=>{let t=D0.getTime()+(x-ML)/(W-ML-MR)*(D1-D0);return new Date(Math.min(Math.max(t,D0),D1)).toISOString().slice(0,10);};
const mx=Math.max(1,...S.total,...S.outcome);
const eY=v=>H-MB-(H-MT-MB)*0.42*(EMAX?v/EMAX:0);
const toY=v=>MT+(H-MT-MB)*(1-Math.log1p(v)/Math.log1p(mx));
function path(a){const n=a.length;let o='';
 for(let i=0;i<n;i++){const x=ML+(i/(n-1))*(W-ML-MR);o+=(i?'L':'M')+x.toFixed(2)+','+toY(a[i]).toFixed(2);}
 return o;}
function draw(){
 let g=['<rect x="'+ML+'" y="'+MT+'" width="'+(W-ML-MR)+'" height="'+(H-MT-MB)+'" fill="#fff"/>'];
 for(const t of [0,1,3,10,30,100,300,1000]){if(t>mx)break;const y=toY(t);
  g.push(`<line x1="${ML}" x2="${W-MR}" y1="${y}" y2="${y}" stroke="#eee"/><text x="4" y="${y+3}" font-size="9" fill="#888">${t}</text>`);}
 // x axis: year ticks across the FULL series extent
 {const y0=D0.getUTCFullYear(), y1=D1.getUTCFullYear();
  for(let yy=y0; yy<=y1; yy++){const dt=yy+'-01-01'; if(new Date(dt)<D0||new Date(dt)>D1) continue;
   const x=toX(dt);
   g.push(`<line x1="${x}" x2="${x}" y1="${MT}" y2="${H-MB}" stroke="#f0f0f0"/>`+
          `<text x="${x}" y="${H-MB+12}" font-size="9" fill="#888" text-anchor="middle">${yy}</text>`);}
  g.push(`<text x="${ML}" y="${H-MB+21}" font-size="8" fill="#aaa" text-anchor="start">${S.d0}</text>`);
  g.push(`<text x="${W-MR}" y="${H-MB+21}" font-size="8" fill="#aaa" text-anchor="end">${D1.toISOString().slice(0,10)}</text>`);}
 for(const it of INTROS){const x=toX(it.date);if(x>=ML&&x<=W-MR)
  g.push(`<line x1="${x}" x2="${x}" y1="${MT}" y2="${H-MB}" stroke="#999" stroke-dasharray="3,3"/><text x="${x+3}" y="${MT+10}" font-size="9" fill="#666">${it.name}</text>`);}
 for(const [d,lb,col] of [[MK.first_data,'data▶','#7f8c8d'],[MK.last_data,'◀data','#7f8c8d'],
                          [MK.first_out,'outcome▶','#c0392b'],[MK.last_out,'◀outcome','#c0392b']]) if(d){
  const x=toX(d); g.push(`<line x1="${x}" x2="${x}" y1="${H-MB-8}" y2="${H-MB}" stroke="${col}" stroke-width="2"/>`+
   `<text x="${x+2}" y="${H-MB-10}" font-size="8" fill="${col}">${lb}</text>`);}
 // universal filter: shade EXCLUDED region + solid grey boundary lines
 if(UNIV0||UNIV1){
  const a=UNIV0?toX(UNIV0):ML, b=UNIV1?toX(UNIV1):W-MR;
  if(a>ML) g.push(`<rect x="${ML}" y="${MT}" width="${a-ML}" height="${H-MT-MB}" fill="#e74c3c" opacity=".10"/>`);
  if(b<W-MR) g.push(`<rect x="${b}" y="${MT}" width="${W-MR-b}" height="${H-MT-MB}" fill="#e74c3c" opacity=".10"/>`);
  for(const [x,lb] of [[a,UNIV0],[b,UNIV1]]) if(lb){
   g.push(`<line x1="${x}" x2="${x}" y1="${MT}" y2="${H-MB}" stroke="#555" stroke-width="1.5"/>`+
          `<text x="${x+3}" y="${MT+22}" font-size="9" fill="#555">univ ${lb}</text>`);}
 }
 // existing category clip: blue dashed
 for(const [d,lb] of [[CAT0,'cat start'],[CAT1,'cat end']]) if(d){const x=toX(d);
  g.push(`<line x1="${x}" x2="${x}" y1="${MT}" y2="${H-MB}" stroke="#2980b9" stroke-width="1.6" stroke-dasharray="6,3"/>`+
         `<text x="${x+3}" y="${MT+34}" font-size="9" fill="#2980b9">${lb} ${d}</text>`);}
 g.push(`<path d="${path(S.total)}" stroke="#6b6b6b" fill="none" stroke-width="1.1"/>`);
 g.push(`<path d="${path(S.outcome)}" stroke="#c0392b" fill="none" stroke-width="1.4"/>`);
 let ep='',prevY=null;
 for(let i=0;i<ST.date.length;i++){const x=toX(ST.date[i]),y=eY(ST.val[i]);
   ep += (prevY===null) ? `M${x.toFixed(1)},${y.toFixed(1)}`
                        : `L${x.toFixed(1)},${prevY.toFixed(1)}L${x.toFixed(1)},${y.toFixed(1)}`;
   prevY=y;}
 g.push(`<path d="${ep}" stroke="#27ae60" fill="none" stroke-width="1.8"/>`);
 for(let i=0;i<ST.date.length-1;i++){ if(i && ST.val[i]===ST.val[i-1]) continue;
   const x=toX(ST.date[i]);
   g.push(`<text x="${(x+3).toFixed(1)}" y="${(eY(ST.val[i])-4).toFixed(1)}" font-size="10" font-weight="600" fill="#1e8449">${ST.val[i]}</text>`);}
 for(const [d,id] of [[cs,'hs'],[ce,'he']]) if(d){const x=toX(d);
  g.push(`<line class="hl" data-h="${id}" x1="${x}" x2="${x}" y1="${MT}" y2="${H-MB}" stroke="#e67e22" stroke-width="2.5"/>`+
         `<rect class="hl" data-h="${id}" x="${x-6}" y="${MT}" width="12" height="${H-MT-MB}" fill="transparent"/>`+
         `<text x="${x+4}" y="${H-MB-4}" font-size="10" fill="#a04000">${d}</text>`);}
 document.getElementById('chart').innerHTML=g.join('');
 // ---- live unit accounting ----
 const di=d=>Math.max(0,Math.min(CUM.n-1,Math.round((new Date(d)-CD0)/day)));
 const at=(a,i)=>i<0?0:a[Math.max(0,Math.min(a.length-1,i))];
 const NT=at(CUM.out,CUM.n-1), NTOT=at(CUM.tot,CUM.n-1), NDAY=at(CUM.days,CUM.n-1);
 let bO=0,bT=0,bD=0,aO=0,aT=0,aD=0;
 if(cs){const i=di(cs)-1; bO=at(CUM.out,i); bT=at(CUM.tot,i); bD=at(CUM.days,i);}
 if(ce){const j=di(ce);   aO=NT-at(CUM.out,j); aT=NTOT-at(CUM.tot,j); aD=NDAY-at(CUM.days,j);}
 const kO=NT-bO-aO, kD=NDAY-bD-aD;
 const f=n=>n.toLocaleString();
 const pct=(n,d)=>d? (100*n/d).toFixed(1)+'%' : '0%';
 document.getElementById('lbl').innerHTML =
   `<b>${cs||'—'} → ${ce||'—'}</b> &nbsp;|&nbsp; `+
   `cut before <b style="color:#c62828">${f(bO)}u</b> (${pct(bO,NT)}, ${f(bD)}d) &nbsp;·&nbsp; `+
   `<b style="color:#1b5e20">keep ${f(kO)}u</b> (${pct(kO,NT)}, ${f(kD)}d) &nbsp;·&nbsp; `+
   `cut after <b style="color:#c62828">${f(aO)}u</b> (${pct(aO,NT)}, ${f(aD)}d)`;
}
function nudge(which,days){const d=which==='s'?cs:ce;if(!d)return;
 let t=new Date(d).getTime()+days*day;
 t=Math.min(Math.max(t,D0.getTime()),D1.getTime());       // never leave the data range
 const nd=new Date(t).toISOString().slice(0,10);
 if(which==='s')cs=nd;else ce=nd;draw();}
let drag=null;
document.addEventListener('mousedown',e=>{const t=e.target.closest('.hl');if(t)drag=t.dataset.h;});
document.addEventListener('mousemove',e=>{if(!drag)return;const sv=document.getElementById('chart');
 const r=sv.getBoundingClientRect();const x=(e.clientX-r.left)/r.width*W;
 if(drag==='hs')cs=fromX(x);else ce=fromX(x);draw();});
document.addEventListener('mouseup',()=>drag=null);
document.addEventListener('keydown',e=>{
 if(e.target.tagName==='INPUT'&&e.key!=='Enter')return;
 const step=e.shiftKey?30:(e.ctrlKey?1:7);
 const k=e.key.toLowerCase();
 if(k==='a')            nudge('s',-step);   // start  left
 else if(k==='d')       nudge('s', step);   // start  right
 else if(e.key==='ArrowLeft')  nudge('e',-step);   // end left
 else if(e.key==='ArrowRight') nudge('e', step);   // end right
 else if(e.key==='Enter') submit('approve');
 else if(k==='r')       submit('reject');
 else if(k==='f')       submit('flag');
 else return; e.preventDefault();});
function submit(v){document.getElementById('vs').value=cs||'';document.getElementById('ve').value=ce||'';
 document.getElementById('vv').value=v;document.getElementById('frm').submit();}
draw();
"""

def num(v, default=None):
    """Coerce a page value to a number, or return default. Generators that omit
    an optional field can emit null/{}/'' -- none of which may reach a format."""
    if isinstance(v, bool) or not isinstance(v, (int, float)): return default
    return v


def tbl(rows, cols, numcols=()):
    h = "".join(f"<th class='{'n' if c in numcols else ''}'>{html.escape(str(c))}</th>" for c in cols)
    b = "".join("<tr>" + "".join(f"<td class='{'n' if c in numcols else ''}'>{html.escape(str(r.get(c,'')))}</td>" for c in cols) + "</tr>" for r in rows)
    return f"<table><tr>{h}</tr>{b}</table>"

def page(i):
    k = KEYS[i]; p = PAGES[k]; d = decided(); st = d.get(k)
    badge = f"<span class='tag {'ok' if st['verdict']=='approve' else 'no' if st['verdict']=='reject' else 'fl'}'>{st['verdict']}</span>" if st else ""
    uf = p.get("universal") or {}; cc = p.get("cat_clip") or {}; rec = p["rec"]
    warn = []
    if (num(p.get("exp_mode_pct"), 0) or 0) >= 97: warn.append("CONSTANT EXPOSURE")
    if num(p.get("n_animal")) == 0: warn.append("NO ANIMAL DISH")
    if (num(p.get("animal_units")) or 1e9) < 500: warn.append("LOW ANIMAL UNITS")
    warns = " ".join(f"<span class='tag no'>{w}</span>" for w in warn)

    intro_rows = [{"analog": x["name"], "date": x["date"]} for x in p.get("intros", [])]
    facts = [{"k":"models","v":p["models"]},
             {"k":"days","v":p["n_days"]},{"k":"range","v":f'{p["date_min"]} → {p["date_max"]}'},
             {"k":"outcome units","v":f'{p["units"]:,}'},{"k":"zero days","v":f'{p["pct_zero"]}%'},
             {"k":"exp distinct / mode","v":f'{p.get("exp_distinct_count","—")} / {p.get("exp_mode_pct","—")}%'},
             {"k":"dishes · animal","v":f'{p.get("n_dishes","—")} · {p.get("n_animal","—")}'},
             {"k":"animal units","v":(f'{num(p.get("animal_units")):,}' if num(p.get("animal_units")) is not None else "—")},
             {"k":"plant units","v":(f'{num(p.get("plant_units")):,}' if num(p.get("plant_units")) is not None else "—")},
             {"k":"universal clip","v":f'{uf.get("start") or "—"} → {uf.get("end") or "—"}'},
             {"k":"category clip","v":f'{cc.get("start") or "—"} → {cc.get("end") or "—"}'}]

    if p.get("sensitivity"):
        facts[1:1] = [{"k":"intro","v":p.get("intro_date") or "—"},
                      {"k":"pre / post days","v":f'{p["n_pre"]:,} / {p["n_post"]:,}'},
                      {"k":"head / tail zero run","v":f'{p["lead0"]}d / {p["tail0"]}d'},
                      {"k":"pre → post mean","v":f'{p["pre_mean"]} → {p["post_mean"]}'},
                      {"k":"step spread across cuts","v":f'{p["spread"]} pts'}]
        sens_block = ("<h2>head-cut sensitivity</h2>"
                      + tbl(p["sensitivity"], ["drop","pre n","pre mean","zero %","naive step"],
                            ("pre n","pre mean","zero %"))
                      + ("<div class=key style='color:#1b5e20'>converged</div>" if p.get("converged")
                         else "<div class=key style='color:#a04000'>no plateau</div>"))
        if p["lead0"] >= 60: warns += "<span class='tag no'>HEAD %dd ZERO</span>" % p["lead0"]
    else:
        sens_block = ""

    nav = (f"{'<a href=/p/'+str(i-1)+'>← prev</a>' if i>0 else '← prev'} "
           f"<span class=key>{i+1}/{len(KEYS)}</span> "
           f"{'<a href=/p/'+str(i+1)+'>next →</a>' if i<len(KEYS)-1 else 'next →'} "
           f"<a href=/>index</a> <span class=key>done {len(d)}/{len(KEYS)}</span>")

    js = (JS.replace("SER", json.dumps(p["series"])).replace("MARKS", json.dumps(p.get("marks",{})))
            .replace("STEPS", json.dumps(p.get("exp_steps", {"date":[],"val":[]})))
            .replace("EXMAX", json.dumps(p.get("exp_max", 1)))
            .replace("CUMDATA", json.dumps(p.get("cum") or {"d0":p["series"]["d0"],"n":1,"out":[0],"tot":[0],"days":[0]}))
            .replace("REC0", json.dumps((st or {}).get("start") or rec.get("start")))
            .replace("REC1", json.dumps((st or {}).get("end") or rec.get("end")))
            .replace("INTROS", json.dumps(p.get("intros", [])))
            .replace("CATC0", json.dumps(cc.get("start")))
            .replace("CATC1", json.dumps(cc.get("end")))
            .replace("UNIV0", json.dumps(uf.get("start")))
            .replace("UNIV1", json.dumps(uf.get("end"))))

    return f"""<!doctype html><meta charset=utf-8><title>{k}</title><style>{CSS}</style><div class=wrap>
<div class=hdr><h1>{html.escape(p['restaurant'])} · {html.escape(p['outcome_label'])}</h1>
<span class=tag>{p['analysis']}</span>{badge}{warns}<span style='flex:1'></span><span class=key>{nav}</span></div>

<div class=analog>analog dishes: <b>{html.escape(p.get('analogs') or 'none')}</b><br>
counterpart: <b>{html.escape(p['outcome_label'])}</b> &nbsp;·&nbsp; animal {num(p.get('animal_units'), 0):,}u &nbsp;·&nbsp;
plant {num(p.get('plant_units'), 0):,}u &nbsp;·&nbsp; modifiable {num(p.get('mod_units'), 0):,}u &nbsp;·&nbsp;
sales before 1st analog ({p.get('pre_first_analog') or '—'}): <b>{(f"{p['pre_units']:,}" if p.get('pre_units') is not None else '—')}</b></div>
<div class=verdict>{html.escape(p.get('verdict_line',''))}</div>

<svg id=chart viewBox="0 0 1200 310" preserveAspectRatio="none"></svg>
<div class=key style='color:#666;margin:3px 0'>
 <span style='color:#6b6b6b'>▬</span> total purchases &nbsp; <span style='color:#c0392b'>▬</span> outcome &nbsp;
 <span style='color:#27ae60'>▬</span> exposure &nbsp; <span style='color:#e67e22'>▮</span> your clip (drag) &nbsp; <span style='color:#2980b9'>┊</span> existing category clip &nbsp; <span style='color:#555'>│</span> universal filter (red tint = excluded) &nbsp; ┆ intro &nbsp; ▏ first/last day with data (grey) or outcome (red)
 &nbsp;·&nbsp; <span id=kbd><b>A</b>/<b>D</b> start · <b>←</b>/<b>→</b> end · shift=30d ctrl=1d · <b>Enter</b> approve · <b>R</b> no clip · <b>F</b> flag</span></div>

<div class=grid>
 <div><h2>facts</h2>{tbl(facts,["k","v"])}
      <h2>analog dishes (exposure)</h2>{tbl(p.get("analog_dishes") or [{"name":"—","type":"","units":"","first":""}],["name","type","units","first"],("units",))}
      {sens_block}
      <details><summary>introduction events (A3/A4)</summary>{tbl(intro_rows or [{"analog":"—","date":"—"}],["analog","date"])}</details></div>
 <div><h2>dishes in category</h2><div class=sc>{tbl(p.get("dishes") or [{"name":"— no dish table —","type":"","units":"","first":"","flags":""}],["name","type","units","first","flags"],("units",))}</div>
      <details><summary>exposure runs</summary><div class=sc>{tbl(p.get("runs") or [],["from","to","val","days"],("val","days"))}</div></details>
      <details><summary>monthly coverage</summary><div class=sc>{tbl(p.get("monthly") or [],["mo","days","nz","tot","out","exp"],("days","nz","tot","out","exp"))}</div></details></div>
</div>

<form id=frm method=post action=/decide class=bar>
 <input type=hidden name=key value='{k}'><input type=hidden name=i value='{i}'>
 <input type=hidden id=vs name=start><input type=hidden id=ve name=end><input type=hidden id=vv name=verdict>
 <span class=key id=lbl style='flex-basis:100%;font-size:12px'></span>
 <button type=button class=sm onclick="nudge('s',-7)" title="A">◀ start</button>
 <button type=button class=sm onclick="nudge('s',7)" title="D">start ▶</button>
 <button type=button class=sm onclick="nudge('e',-7)" title="←">◀ end</button>
 <button type=button class=sm onclick="nudge('e',7)" title="→">end ▶</button>
 <button type=button class=y onclick="submit('approve')">approve (Enter)</button>
 <button type=button class=n onclick="submit('reject')">no clip (R)</button>
 <button type=button class=f onclick="submit('flag')">flag (F)</button>
 <input name=note placeholder=note style='flex:1;padding:4px'>
</form>
<script>{js}</script></div>"""

def index():
    d = decided(); rows = []
    for i, k in enumerate(KEYS):
        p = PAGES[k]; s = d.get(k, {})
        rows.append({"#":i+1,"restaurant":p["restaurant"],"outcome":p["outcome_label"],
                     "analog":p.get("analogs") or "—","units":f'{p["units"]:,}',
                     "animal u":(f'{num(p.get("animal_units")):,}' if num(p.get("animal_units")) is not None else "—"),"exp mode":f'{p.get("exp_mode_pct","—")}%',
                     "verdict":s.get("verdict",""),"start":s.get("start",""),"end":s.get("end","")})
    body = "".join("<tr><td class=n><a href='/p/"+str(r['#']-1)+"'>"+str(r['#'])+"</a></td>"
        + "".join(f"<td class='{'n' if c in ('units','animal u','exp mode') else ''}'>{html.escape(str(r[c]))}</td>"
                  for c in ["restaurant","outcome","analog","units","animal u","exp mode","verdict","start","end"])
        + "</tr>" for r in rows)
    return f"""<!doctype html><meta charset=utf-8><title>{html.escape(TITLE)}</title><style>{CSS}</style><div class=wrap>
<div class=hdr><h1>{html.escape(TITLE)}</h1><span class=tag>{len(d)} / {len(KEYS)}</span><a href=/export class=tag>export</a></div>
<table><tr><th class=n>#</th><th>restaurant</th><th>outcome</th><th>analog</th><th class=n>units</th>
<th class=n>animal u</th><th class=n>exp mode</th><th>verdict</th><th>start</th><th>end</th></tr>{body}</table></div>"""

class H(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'
    def log_message(self, *a): pass
    def _s(self, c, t, b):
        self.send_response(c); self.send_header("Content-Type", t)
        self.send_header("Content-Length", str(len(b))); self.send_header("Connection","close"); self.end_headers(); self.wfile.write(b)
    def do_GET(self):
        # An unhandled exception here would write NO response at all, leaving the
        # client hanging until it times out. Always answer, even on failure.
        try:
            return self._route(urllib.parse.urlparse(self.path).path)
        except Exception:
            import traceback
            tb = traceback.format_exc()
            self._s(500, "text/plain; charset=utf-8", tb.encode())

    def _route(self, path):
        if path == "/": return self._s(200,"text/html; charset=utf-8", index().encode())
        if path.startswith("/p/"):
            i = max(0, min(int(path[3:]), len(KEYS)-1)); return self._s(200,"text/html; charset=utf-8", page(i).encode())
        if path == "/export":
            b = open(DEC,"rb").read() if os.path.exists(DEC) else b""
            return self._s(200,"text/plain; charset=utf-8", b)
        self._s(404,"text/plain",b"404")
    def do_POST(self):
        n = int(self.headers.get("Content-Length",0))
        f = urllib.parse.parse_qs(self.rfile.read(n).decode())
        rec = {k: f.get(k,[""])[0] for k in ("key","verdict","start","end","note")}
        with open(DEC,"a") as fh: fh.write(json.dumps(rec)+"\n")
        i = int(f.get("i",["0"])[0])
        self.send_response(303); self.send_header("Location", f"/p/{min(i+1,len(KEYS)-1)}"); self.end_headers()

if __name__ == "__main__":
    os.makedirs(os.path.dirname(os.path.abspath(DEC)), exist_ok=True)
    print(f"http://{A.host}:{PORT}/  ({len(KEYS)} pages)  decisions -> {DEC}")
    # These must be set on the CLASS: listen() runs inside __init__, so setting
    # request_queue_size on the instance afterwards never reaches listen(),
    # leaving the default backlog of 5 and hanging under a burst of requests.
    ThreadingHTTPServer.request_queue_size = 128
    ThreadingHTTPServer.daemon_threads = True
    ThreadingHTTPServer.allow_reuse_address = True
    ThreadingHTTPServer((A.host, PORT), H).serve_forever()

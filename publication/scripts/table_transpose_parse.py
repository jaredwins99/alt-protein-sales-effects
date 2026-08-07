import re, sys

def cells(row):
    out, depth, cur, i = [], 0, "", 0
    while i < len(row):
        c = row[i]
        if c == "\\" and i+1 < len(row): cur += row[i:i+2]; i += 2; continue
        if c == "{": depth += 1
        elif c == "}": depth -= 1
        if c == "&" and depth == 0: out.append(cur); cur = ""
        else: cur += c
        i += 1
    out.append(cur); return [x.strip() for x in out]

def inner(cell):
    m = re.match(r"^\\makecell\[[lrc]\]\{(.*)\}$", cell, re.S)
    return m.group(1) if m else None

def flat(cell):
    x = inner(cell)
    if x is None: return cell
    parts = [p.strip() for p in x.split("\\\\") if p.strip()]
    out = ""
    for p in parts:
        if not out: out = p
        elif out.endswith("-"): out += p
        else: out += " " + p
    return re.sub(r"\\b(location) (\\d)", r", \\1 \\2", out)

def dishlines(cell):
    """name/(count) alternating -> ['Name (count)', ...]"""
    x = inner(cell)
    if x is None: return [cell] if cell else []
    parts = [p.strip() for p in x.split("\\\\") if p.strip()]
    lines, buf = [], []
    for p in parts:
        if re.match(r"^\(.*\)$", p): lines.append((" ".join(buf)+" "+p).strip()); buf = []
        else: buf.append(p)
    if buf: lines.append(" ".join(buf))
    return lines

def numbered(cell):
    x = inner(cell)
    if x is None: return [cell]
    parts = [p.strip() for p in x.split("\\\\") if p.strip()]
    lines = []
    for p in parts:
        if re.match(r"^\d+\.", p) or not lines: lines.append(p)
        else: lines[-1] += " " + p
    return lines

src = [l.rstrip() for l in open(sys.argv[1]) if l.startswith("\\includegraphics")]
R = []
for r in src:
    c = cells(r[:-2])
    R.append(dict(img=c[0], num=c[1], name=flat(c[2]), tot=c[3],
                  d1=dishlines(c[4]), d2=dishlines(c[5]), intro=numbered(c[6]),
                  counts=[x.strip() for x in c[7:12]]))
import json; print(json.dumps(R))

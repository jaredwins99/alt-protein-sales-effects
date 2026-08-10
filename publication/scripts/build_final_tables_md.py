#!/usr/bin/env python3
"""Collect publication/tables_final/*.tex into one markdown file, in Supplement order.

Each entry renders the table for reading and carries the LaTeX beneath it for
pasting. Run after final_tables.R.

Usage: python3 publication/scripts/build_final_tables_md.py
"""
import csv
import os

D   = "publication/tables_final"
CFG = "publication/config/final_models.csv"
OUT = "publication/FINAL_TABLES.md"

SECTIONS = [
    ("Section 3.2.3 - Tier One underlying tables", [
        ("t1_a1", "tab:rr_t1_a1", "Tier One A1"),
        ("t1_a2", "tab:rr_t1_a2", "Tier One A2"),
        ("t1_a3", "tab:rr_t1_a3", "Tier One A3"),
        ("t1_a4", "tab:rr_t1_a4", "Tier One A4")]),
    ("Section 3.3.4 - Tier Two underlying tables", [
        ("t2_a1", "tab:rr_t2_a1", "Tier Two A1"),
        ("t2_a2", "tab:rr_t2_a2", "Tier Two A2"),
        ("t2_a3", "tab:rr_t2_a3", "Tier Two A3"),
        ("t2_a4", "tab:rr_t2_a4", "Tier Two A4")]),
    ("Section 3.4.1 - Within-customer, Tier One", [
        ("t1_a5", "tab:a5_mu_gamma", "Tier One A5"),
        ("t1_a6", "tab:a6_mu_gamma", "Tier One A6")]),
    ("Section 3.4.2 - Within-customer, Tier Two", [
        ("t2_a5", "tab:t2_a5_mu_gamma", "Tier Two A5"),
        ("t2_a6", "tab:t2_a6_mu_gamma", "Tier Two A6")]),
]


def parse(fid):
    tex = open(os.path.join(D, fid + ".tex")).read()
    body = [l.strip() for l in tex.splitlines()
            if "&" in l and not l.startswith("\\par")]
    cells = [[c.strip() for c in l.replace("\\\\", "").strip().split("&")]
             for l in body]
    return tex, cells


def to_md(cells):
    esc = lambda s: s.replace("\\&", "&").replace("\\%", "%")
    hdr, rows = cells[0], cells[1:]
    out = "| " + " | ".join(esc(h) for h in hdr) + " |\n"
    out += "|" + "|".join(["---"] * len(hdr)) + "|\n"
    for r in rows:
        out += "| " + " | ".join(esc(c) for c in r) + " |\n"
    return out


cfg = list(csv.DictReader(open(CFG)))
reported = [r for r in cfg if r["reported"] == "TRUE"]
supp = [r for r in cfg if r["reported"] != "TRUE"]

o = []
w = o.append
w("# Final Supplement tables\n")
w("**These tables report the unadjusted rate ratio (RR)** for each estimate: the raw")
w("outcome-model effect on its own. The forest plots report the **adjusted ratio of")
w("rate ratios (RRR)** for the same estimates. The two are different information about")
w("the same underlying construct, so the reader can see both.\n")
w("Rebuild with:\n")
w("```")
w("Rscript publication/scripts/build_final_models.R")
w("Rscript publication/scripts/final_tables.R")
w("python3 publication/scripts/build_final_tables_md.py")
w("```\n")
w("## Where the estimate set comes from\n")
w("`publication/config/final_models.csv` is the single source of truth for which")
w("estimates are reported and in what order. It is generated from the renderers' own")
w("rules, so a table can never show a different set of estimates than the figure")
w("beside it. One row per cell, carrying the `fit_dir` and `total_dir` each value")
w("came from, the contributing-restaurant count, and the suppression reason where")
w("one applies.\n")
w(f"Currently **{len(reported)} reported** cells and **{len(supp)} suppressed**:\n")
seen = {}
for r in supp:
    seen[r["suppress_reason"]] = seen.get(r["suppress_reason"], 0) + 1
for k, v in sorted(seen.items(), key=lambda kv: -kv[1]):
    w(f"- {k} — {v}")
w("")
w("Labels follow the renderers: **`untextured` = Ground meat**, **`textured` =")
w("Whole-muscle meat**. Whole-muscle is deliberately absent from A2 in both tiers.")
w("`---` marks a suppressed cell; `TBD` marks one whose RR has not been extracted yet.\n")

tbd = sum(1 for _, items in SECTIONS for fid, _, _ in items
          for row in parse(fid)[1][1:] if "TBD" in " ".join(row))
if tbd:
    w(f"> **{tbd} cells still read TBD.** Those fits were refit after the May")
    w("> unadjusted extraction, so their RRs need re-extracting. All of them have")
    w("> `fit.rds` only, which needs cmdstanr, so run this on Windows:")
    w(">")
    w("> ```")
    w("> Rscript publication/scripts/extract_rr_95ci.R")
    w("> ```\n")

w("---\n")
for sect, items in SECTIONS:
    w(f"# {sect}\n")
    for fid, tag, cap in items:
        tex, cells = parse(fid)
        w(f"## {cap}\n")
        w(f"`{tag}` · `{D}/{fid}.tex`\n")
        w(to_md(cells))
        w("<details><summary>LaTeX</summary>\n")
        w("```latex")
        w(tex.rstrip())
        w("```\n")
        w("</details>\n")
    w("---\n")

w("## Not covered here\n")
w("`tab:impossible_estimates` is a restaurant-level table, not a pooled one, so it")
w("falls outside this generator and still needs a separate refresh.\n")

open(OUT, "w").write("\n".join(o))
print(f"wrote {OUT} ({len(reported)} reported, {tbd} TBD)")

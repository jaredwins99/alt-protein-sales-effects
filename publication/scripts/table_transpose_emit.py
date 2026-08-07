import json, sys

R = json.load(open(sys.argv[1]))
out_path, label, caption, ncol = sys.argv[2], sys.argv[3], sys.argv[4], int(sys.argv[5])
PAGEBREAK = len(sys.argv) > 6 and sys.argv[6] == "pagebreak"

FIELDS = [
 ("Restaurant",                                   lambda r: r["name"]),
 ("Total purchases",                              lambda r: r["tot"]),
 ("Top three dishes overall",                     lambda r: "\\newline ".join(r["d1"])),
 ("Top three dishes containing alternative protein", lambda r: "\\newline ".join(r["d2"])),
 ("Introduced alternative proteins",              lambda r: "\\newline ".join(r["intro"])),
 ("Alternative protein products introduced",      lambda r: r["counts"][0]),
 ("Introduction events",                          lambda r: r["counts"][1]),
 ("Menu items",                                   lambda r: r["counts"][2]),
 ("Menu items containing alternative protein",    lambda r: r["counts"][3]),
 ("Alternative protein products in total",        lambda r: r["counts"][4]),
]

LABELW = "3.0cm"
blocks = [R[i:i+ncol] for i in range(0, len(R), ncol)]
L = []
L.append("% Transposed variant: restaurants are COLUMNS, fields are ROWS. Portrait.")
L.append("% Requires: longtable, booktabs, makecell, array, graphicx.")
L.append("\\clearpage")
L.append("\\begingroup")
L.append("\\setlength{\\tabcolsep}{3pt}\\renewcommand{\\arraystretch}{1.0}")
L.append("\\setlength{\\LTpre}{0pt}\\setlength{\\LTpost}{\\bigskipamount}")
L.append("\\hyphenpenalty=10000\\exhyphenpenalty=50\\emergencystretch=1em\\sloppy")
L.append("\\providecommand{\\LL}{}\\renewcommand{\\LL}{}")
L.append("\\newcolumntype{V}[1]{>{\\raggedright\\arraybackslash}p{#1}}")
L.append("\\scriptsize")

for bi, blk in enumerate(blocks):
    n = len(blk)
    # exact: remaining width after the label column and all inter-column padding,
    # divided by the number of restaurants -- so it fits any page width
    each = ("V{\\dimexpr(\\linewidth-%s-%dpt)/%d\\relax}" % (LABELW, 6*(n+1), n))
    spec = "@{}V{%s}" % LABELW + each * n + "@{}"
    L.append("\\begin{longtable}{%s}" % spec)
    if bi == 0:
        L.append("\\caption{%s}" % caption)
        L.append("\\label{%s}\\\\" % label)
    else:
        L.append("\\multicolumn{%d}{@{}l}{\\textit{Table \\ref{%s} continued.}}\\\\[2pt]" % (len(blk)+1, label))
    L.append("\\toprule")
    L.append(" & " + " & ".join("\\includegraphics[height=0.5cm]{%s}" %
             r["img"].split("{")[-1].rstrip("}") for r in blk) + " \\\\")
    L.append(" & " + " & ".join("\\textbf{%s}" % r["num"] for r in blk) + " \\\\")
    L.append("\\midrule\\endfirsthead")
    L.append("\\toprule")
    L.append(" & " + " & ".join("\\textbf{%s}" % r["num"] for r in blk) + " \\\\")
    L.append("\\midrule\\endhead")
    L.append("\\bottomrule\\endfoot")
    L.append("\\bottomrule\\endlastfoot")
    for fi, (lab, get) in enumerate(FIELDS):
        term = "\\\\" if fi == len(FIELDS)-1 else "\\\\*"
        L.append("%s & %s %s" % (lab, " & ".join(get(r) for r in blk), term))
        if fi < len(FIELDS)-1: L.append("\\midrule[0.1pt]")
    L.append("\\end{longtable}")
    if bi < len(blocks) - 1:
        L.append("\\newpage" if PAGEBREAK else "")
L.append("\\endgroup")
open(out_path, "w").write("\n".join(L) + "\n")
print(f"  wrote {out_path}: {len(blocks)} block(s) of <= {ncol} restaurants")

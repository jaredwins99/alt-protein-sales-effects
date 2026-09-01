"""Clean LaTeX-style version of the MPBA exposure x outcome design diagram.

Uses serif font + hand-drawn curly braces to match the style of the original
hand sketch, laid out formally. Produces both PNG and PDF.
"""
import matplotlib.pyplot as plt
import matplotlib as mpl
from matplotlib.path import Path
from matplotlib.patches import PathPatch

mpl.rcParams["font.family"] = "serif"
mpl.rcParams["font.serif"] = ["DejaVu Serif", "Nimbus Roman", "Liberation Serif"]
mpl.rcParams["mathtext.fontset"] = "cm"

def curly_brace(ax, x, y_top, y_bot, direction="right", width=0.25, color="black", lw=1.2):
    """Draw a tall curly brace.  direction = 'right' means brace opens to the right."""
    mid = (y_top + y_bot) / 2
    s = 1 if direction == "right" else -1
    w = width * s
    # Two Bezier halves meeting at the midpoint tip
    verts_top = [
        (x,        y_top),
        (x + w,    y_top),
        (x + w,    mid + 0.10),
        (x + 2*w,  mid),
    ]
    verts_bot = [
        (x + 2*w,  mid),
        (x + w,    mid - 0.10),
        (x + w,    y_bot),
        (x,        y_bot),
    ]
    codes = [Path.MOVETO, Path.CURVE4, Path.CURVE4, Path.CURVE4]
    ax.add_patch(PathPatch(Path(verts_top, codes),
                           facecolor="none", edgecolor=color, lw=lw))
    ax.add_patch(PathPatch(Path(verts_bot, codes),
                           facecolor="none", edgecolor=color, lw=lw))


fig, ax = plt.subplots(figsize=(13, 8))
ax.set_xlim(0, 13)
ax.set_ylim(0, 8)
ax.axis("off")

# ── Column headers (underlined italics, the hand-drawn feel) ──
def head(x, y, s):
    ax.text(x, y, s, ha="center", va="center",
            fontsize=14, fontstyle="italic", fontweight="bold")
    ax.plot([x - len(s) * 0.09, x + len(s) * 0.09], [y - 0.25, y - 0.25],
            color="black", lw=0.8)

head(1.8,  7.6, "Exposure intensity metric")
head(6.6,  7.6, "Exposure item type")
head(11.5, 7.6, "Outcome")

# ── Column 1: intensity metrics ──────────────────────────────
intensity_items = ["Presence vs. absence",
                   "Count of menu items",
                   "New introduction (ITS)"]
INT_X = 1.8
y_vals_int = [6.6, 6.1, 5.6]
for y, txt in zip(y_vals_int, intensity_items):
    ax.text(INT_X, y, "\u2013 " + txt, ha="center", va="center", fontsize=11)

curly_brace(ax, 3.6, y_vals_int[0] + 0.2, y_vals_int[-1] - 0.2, "right", 0.18, lw=1.3)

# ── Column 2 (upper): Non-targeted types ─────────────────────
ax.text(6.6, 7.05, "Non-targeted types", ha="center", va="center",
        fontsize=12, fontstyle="italic", fontweight="bold")
ax.plot([6.6 - 1.1, 6.6 + 1.1], [6.95, 6.95], color="black", lw=0.7)

nt_items = ["MPBA-modifiable items", "Vegan items", "Vegetarian items"]
NT_X = 6.6
y_vals_nt = [6.5, 6.05, 5.6]
for y, txt in zip(y_vals_nt, nt_items):
    ax.text(NT_X, y, "\u2013 " + txt, ha="center", va="center", fontsize=11)
curly_brace(ax, 4.9, y_vals_nt[0] + 0.2, y_vals_nt[-1] - 0.2, "left", 0.18, lw=1.3)
curly_brace(ax, 8.3, y_vals_nt[0] + 0.2, y_vals_nt[-1] - 0.2, "right", 0.18, lw=1.3)

# ── Column 3 (upper): Outcomes ───────────────────────────────
outcomes = ["Total", "Non-vegan", "Meat", "Chicken / fish", "Vegetarian", "Vegan"]
O_X = 11.5
y_vals_out = [6.7, 6.4, 6.1, 5.8, 5.5, 5.2]
for y, txt in zip(y_vals_out, outcomes):
    ax.text(O_X, y, "\u2013 " + txt, ha="center", va="center", fontsize=11)
curly_brace(ax, 9.9, y_vals_out[0] + 0.2, y_vals_out[-1] - 0.2, "left", 0.18, lw=1.3)

# ── Crossings labels (×  fully crossed) ──────────────────────
ax.text(4.30, 6.05, r"$\times$", ha="center", va="center", fontsize=18)
ax.text(4.30, 5.65, "fully\ncrossed", ha="center", va="center", fontsize=9.5, style="italic")

ax.text(9.1, 6.05, r"$\times$", ha="center", va="center", fontsize=18)
ax.text(9.1, 5.65, "fully\ncrossed", ha="center", va="center", fontsize=9.5, style="italic")

# ── Column 2 (lower): Targeted types ─────────────────────────
ax.text(6.6, 4.55, "Targeted types", ha="center", va="center",
        fontsize=12, fontstyle="italic", fontweight="bold")
ax.plot([6.6 - 0.95, 6.6 + 0.95], [4.45, 4.45], color="black", lw=0.7)

targeted_pairs = [
    ("Breakfast analogs",   "Breakfast ABF sales"),
    ("Chicken analogs",     "Chicken sales"),
    ("Dairy analogs",       "Dairy sales"),
    ("Egg analogs",         "Egg sales"),
    ("Textured analogs",    "Textured (red-meat) sales"),
    ("Untextured analogs",  "Untextured ABF sales"),
]
T_X = 6.6
PAIR_X = 11.5
y_vals_t = [4.0 - 0.43 * i for i in range(len(targeted_pairs))]
for y, (tgt, out) in zip(y_vals_t, targeted_pairs):
    ax.text(T_X, y, "\u2013 " + tgt, ha="center", va="center", fontsize=10.5)
    ax.text(PAIR_X, y, "\u2013 " + out, ha="center", va="center", fontsize=10.5)
    # dotted connector from target -> outcome
    ax.plot([T_X + 1.6, PAIR_X - 1.65], [y, y],
            color="black", lw=0.6, linestyle=(0, (1.8, 2.2)))

curly_brace(ax, 4.9, y_vals_t[0] + 0.2, y_vals_t[-1] - 0.2, "left", 0.18, lw=1.3)

# ── Bracket on the left: intensity x (non-targeted / targeted) ──
# Big opening brace spanning both item-type groups
curly_brace(ax, 3.8, y_vals_nt[0] + 0.25, y_vals_t[-1] - 0.25, "right", 0.20, lw=1.3)

# Label on the lower crossing
ax.text(4.30, 2.7, r"$\times$", ha="center", va="center", fontsize=18)
ax.text(4.30, 2.3, "fully\ncrossed", ha="center", va="center", fontsize=9.5, style="italic")

# Right side targeted paired note
ax.text(9.1, 2.7, "paired", ha="center", va="center", fontsize=11, style="italic")
ax.text(9.1, 2.35, "(analog $\\to$ ABF category)",
        ha="center", va="center", fontsize=9.5, style="italic")

plt.subplots_adjust(left=0.02, right=0.98, top=0.95, bottom=0.02)
out_png = "publication/exposure_design_diagram_latex.png"
out_pdf = "publication/exposure_design_diagram_latex.pdf"
plt.savefig(out_png, dpi=280, bbox_inches="tight", facecolor="white")
plt.savefig(out_pdf, bbox_inches="tight", facecolor="white")
print("Saved:", out_png, out_pdf)

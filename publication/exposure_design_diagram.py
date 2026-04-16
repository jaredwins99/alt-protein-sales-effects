"""Generate formal diagram of the exposure / outcome design (A1–A6)."""
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch
import numpy as np

fig, ax = plt.subplots(figsize=(14, 9))
ax.set_xlim(0, 14)
ax.set_ylim(0, 9)
ax.axis("off")

# ── Column headers ───────────────────────────────────────────────
HEAD_Y = 8.6
ax.text(1.8,  HEAD_Y, "Exposure intensity metric",
        ha="center", va="center", fontsize=13, fontweight="bold", style="italic")
ax.text(6.9,  HEAD_Y, "Exposure item type",
        ha="center", va="center", fontsize=13, fontweight="bold", style="italic")
ax.text(12.3, HEAD_Y, "Outcome (ABF sales)",
        ha="center", va="center", fontsize=13, fontweight="bold", style="italic")

# ── Column 1: intensity metrics ─────────────────────────────────
intensity = [
    ("Presence vs. absence",        "A1, A2"),
    ("Count of menu items",         "A1, A2"),
    ("New introduction (ITS)",      "A3, A4, A5, A6"),
]
INT_X = 1.8
INT_Y0 = 6.5
INT_DY = 1.0
intensity_pos = []
for i, (label, tag) in enumerate(intensity):
    y = INT_Y0 - i * INT_DY
    intensity_pos.append(y)
    box = FancyBboxPatch((INT_X - 1.4, y - 0.30), 2.8, 0.6,
                         boxstyle="round,pad=0.04,rounding_size=0.12",
                         linewidth=1.2, edgecolor="#2c3e50", facecolor="#ecf0f1")
    ax.add_patch(box)
    ax.text(INT_X, y + 0.05, label, ha="center", va="center", fontsize=10)
    ax.text(INT_X, y - 0.20, tag,   ha="center", va="center",
            fontsize=8, color="#7f8c8d", style="italic")

# ── Column 2 (upper): Non-targeted types ────────────────────────
ax.text(6.9, 7.25, "Non-targeted types", ha="center", va="center",
        fontsize=11, fontweight="bold", color="#27ae60")
nontargeted = ["MPBA-modifiable items", "Vegan items", "Vegetarian items"]
NT_X = 6.9
NT_Y0 = 6.6
NT_DY = 0.55
nontargeted_pos = []
for i, label in enumerate(nontargeted):
    y = NT_Y0 - i * NT_DY
    nontargeted_pos.append(y)
    box = FancyBboxPatch((NT_X - 1.8, y - 0.20), 3.6, 0.42,
                         boxstyle="round,pad=0.03,rounding_size=0.1",
                         linewidth=1.0, edgecolor="#27ae60", facecolor="#e8f8f0")
    ax.add_patch(box)
    ax.text(NT_X, y + 0.01, label, ha="center", va="center", fontsize=9.5)

# ── Column 2 (lower): Targeted types ────────────────────────────
ax.text(6.9, 4.3, "Targeted types", ha="center", va="center",
        fontsize=11, fontweight="bold", color="#c0392b")
targeted_pairs = [
    ("Breakfast analogs",   "Breakfast ABF sales"),
    ("Chicken analogs",     "Chicken sales"),
    ("Dairy analogs",       "Dairy sales"),
    ("Egg analogs",         "Egg sales"),
    ("Textured analogs",    "Textured (red-meat) sales"),
    ("Untextured analogs",  "Untextured (processed) sales"),
]
T_X = 6.9
T_Y0 = 3.7
T_DY = 0.55
for i, (label, outcome) in enumerate(targeted_pairs):
    y = T_Y0 - i * T_DY
    box = FancyBboxPatch((T_X - 1.8, y - 0.20), 3.6, 0.42,
                         boxstyle="round,pad=0.03,rounding_size=0.1",
                         linewidth=1.0, edgecolor="#c0392b", facecolor="#fdecea")
    ax.add_patch(box)
    ax.text(T_X, y + 0.01, label, ha="center", va="center", fontsize=9.5)
    # Paired outcome box
    out_box = FancyBboxPatch((11.4 - 1.45, y - 0.20), 2.9, 0.42,
                             boxstyle="round,pad=0.03,rounding_size=0.1",
                             linewidth=1.0, edgecolor="#c0392b", facecolor="#fdecea")
    ax.add_patch(out_box)
    ax.text(11.4, y + 0.01, outcome, ha="center", va="center", fontsize=9.5)
    ax.plot([T_X + 1.8, 11.4 - 1.45], [y, y], color="#c0392b",
            linewidth=1.0, linestyle=":")

# ── Column 3 (upper): ABF outcomes ──────────────────────────────
ax.text(12.3, 7.25, "ABF sales outcomes",
        ha="center", va="center", fontsize=11, fontweight="bold", color="#27ae60")
outcomes = ["Total ABF", "Non-vegan", "Meat", "Chicken / fish", "Vegetarian-ABF", "Vegan-ABF"]
O_X = 12.3
O_Y0 = 6.7
O_DY = 0.42
outcomes_pos = []
for i, label in enumerate(outcomes):
    y = O_Y0 - i * O_DY
    outcomes_pos.append(y)
    box = FancyBboxPatch((O_X - 1.35, y - 0.16), 2.7, 0.34,
                         boxstyle="round,pad=0.03,rounding_size=0.1",
                         linewidth=1.0, edgecolor="#27ae60", facecolor="#e8f8f0")
    ax.add_patch(box)
    ax.text(O_X, y + 0.01, label, ha="center", va="center", fontsize=9.5)

# ── Cross-links ─────────────────────────────────────────────────
# intensity × non-targeted  (fully crossed)
for iy in intensity_pos:
    for ny in nontargeted_pos:
        ax.plot([INT_X + 1.4, NT_X - 1.8], [iy, ny],
                color="#27ae60", linewidth=0.5, alpha=0.35)

# intensity × targeted (fully crossed, but cleaner bundling)
for iy in intensity_pos:
    for ty in [T_Y0 - i * T_DY for i in range(len(targeted_pairs))]:
        ax.plot([INT_X + 1.4, T_X - 1.8], [iy, ty],
                color="#c0392b", linewidth=0.5, alpha=0.25)

# non-targeted × outcomes (fully crossed)
for ny in nontargeted_pos:
    for oy in outcomes_pos:
        ax.plot([NT_X + 1.8, O_X - 1.35], [ny, oy],
                color="#27ae60", linewidth=0.5, alpha=0.35)

# ── Legend / annotations ────────────────────────────────────────
ax.text(4.35, 6.9, "×\nfully\ncrossed", ha="center", va="center",
        fontsize=10, color="#27ae60", fontweight="bold")
ax.text(9.6, 6.9, "×\nfully\ncrossed", ha="center", va="center",
        fontsize=10, color="#27ae60", fontweight="bold")
ax.text(4.35, 2.35, "×\nfully\ncrossed", ha="center", va="center",
        fontsize=10, color="#c0392b", fontweight="bold")
ax.text(9.6, 2.35, "paired\n(analog → ABF\ncategory)",
        ha="center", va="center", fontsize=9, color="#c0392b",
        fontweight="bold", style="italic")

# Title
plt.suptitle("MPBA Exposure × Outcome Design",
             fontsize=16, fontweight="bold", y=0.98)
ax.text(7, 0.35,
        "A1–A2: proportion analyses (presence / count)   "
        "A3–A4: ITS (new introductions)   "
        "A5–A6: customer-level ITS",
        ha="center", va="center", fontsize=9.5, color="#34495e", style="italic")

plt.tight_layout()
out = "publication/exposure_design_diagram.png"
plt.savefig(out, dpi=250, bbox_inches="tight", facecolor="white")
print("Saved:", out)

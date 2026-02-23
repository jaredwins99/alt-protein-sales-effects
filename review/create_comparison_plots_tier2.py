#!/usr/bin/env python3
"""
Create Comparison Plots (Original vs Clipped) - Tier 2
Concatenates original and clipped tier2 plots horizontally with labels.
Overwrites any existing tier2 combined plots.

Reads from:
  - review/overlap_plots/*/tier2/         (unclipped originals)
  - review/overlap_plots_clipped_pretty/*/tier2/  (clipped pretty)
Writes to:
  - review/overlap_plots_combined/*/tier2/
"""

from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

original_base = Path("review/overlap_plots")
clipped_base = Path("review/overlap_plots_clipped_pretty")
output_base = Path("review/overlap_plots_combined")


def combine_plots(original_path, clipped_path, output_path):
    """Combine two images horizontally with labels"""
    try:
        if not original_path.exists():
            print(f"  Original not found: {original_path}")
            return False
        if not clipped_path.exists():
            print(f"  Clipped not found: {clipped_path}")
            return False

        img_original = Image.open(original_path)
        img_clipped = Image.open(clipped_path)

        draw_orig = ImageDraw.Draw(img_original)
        draw_clip = ImageDraw.Draw(img_clipped)

        try:
            font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 30)
        except Exception:
            font = ImageFont.load_default()

        draw_orig.text((10, 10), "ORIGINAL", fill="red", font=font)
        draw_clip.text((10, 10), "CLIPPED", fill="green", font=font)

        total_width = img_original.width + img_clipped.width
        max_height = max(img_original.height, img_clipped.height)
        combined = Image.new('RGB', (total_width, max_height), 'white')
        combined.paste(img_original, (0, 0))
        combined.paste(img_clipped, (img_original.width, 0))

        output_path.parent.mkdir(parents=True, exist_ok=True)
        combined.save(output_path)
        return True
    except Exception as e:
        print(f"  Error: {e}")
        return False


# ─────────────────────────────────────────────────────────────
# Proportion (A1_T2)
# ─────────────────────────────────────────────────────────────

print("=== Processing Proportion (A1_T2) - Tier 2 ===")

proportion_outcomes = ["meat", "vegan", "vegetarian", "nonvegan", "total", "chicken_fish"]
proportion_exposures = [
    "mpbamod_dishes_count", "mpbamod_dishes_prop",
    "vegan_dishes_count", "vegan_dishes_prop",
    "vegetarian_dishes_count", "vegetarian_dishes_prop"
]

for outcome in proportion_outcomes:
    for exp_type in proportion_exposures:
        original_dir = original_base / "proportion" / outcome / exp_type / "tier2"
        clipped_dir = clipped_base / "proportion" / outcome / exp_type / "tier2"
        output_dir = output_base / "proportion" / outcome / exp_type / "tier2"

        if not original_dir.exists():
            continue

        for f in sorted(original_dir.glob("*.png")):
            clipped_path = clipped_dir / f.name
            output_path = output_dir / f.name
            result = combine_plots(f, clipped_path, output_path)
            if result:
                print(f"  Created: {output_path}")

# ─────────────────────────────────────────────────────────────
# Proportion Targeted (A2_T2)
# ─────────────────────────────────────────────────────────────

print("\n=== Processing Proportion Targeted (A2_T2) - Tier 2 ===")

proportion_targeted_config = {
    "breakfast_p": ["breakfast_dishes_count", "breakfast_dishes_presence"],
    "chicken_p": ["chicken_dishes_count", "chicken_dishes_presence"],
    "dairy_p": ["dairy_dishes_count", "dairy_dishes_presence"],
    "egg_p": ["egg_dishes_count", "egg_dishes_presence"],
    "textured_p": ["textured_dishes_count", "textured_dishes_presence"],
    "untextured_p": ["untextured_dishes_count", "untextured_dishes_presence"]
}

for category, exposures in proportion_targeted_config.items():
    for exp_type in exposures:
        original_dir = original_base / "proportion_targeted" / category / exp_type / "tier2"
        clipped_dir = clipped_base / "proportion_targeted" / category / exp_type / "tier2"
        output_dir = output_base / "proportion_targeted" / category / exp_type / "tier2"

        if not original_dir.exists():
            continue

        for f in sorted(original_dir.glob("*.png")):
            clipped_path = clipped_dir / f.name
            output_path = output_dir / f.name
            result = combine_plots(f, clipped_path, output_path)
            if result:
                print(f"  Created: {output_path}")

# ─────────────────────────────────────────────────────────────
# ITS (A3_T2)
# ─────────────────────────────────────────────────────────────

print("\n=== Processing ITS (A3_T2) - Tier 2 ===")

its_outcomes = ["meat", "vegan", "vegetarian", "nonvegan", "total", "chicken_fish"]

for outcome in its_outcomes:
    original_dir = original_base / "its" / outcome / "tier2"
    clipped_dir = clipped_base / "its" / outcome / "tier2"
    output_dir = output_base / "its" / outcome / "tier2"

    if not original_dir.exists():
        continue

    for f in sorted(original_dir.glob("*.png")):
        clipped_path = clipped_dir / f.name
        output_path = output_dir / f.name
        result = combine_plots(f, clipped_path, output_path)
        if result:
            print(f"  Created: {output_path}")

# ─────────────────────────────────────────────────────────────
# ITS Targeted (A4_T2)
# ─────────────────────────────────────────────────────────────

print("\n=== Processing ITS Targeted (A4_T2) - Tier 2 ===")

its_targeted_categories = ["breakfast", "chicken", "dairy", "textured", "untextured"]

for category in its_targeted_categories:
    original_dir = original_base / "its_targeted" / category / "tier2"
    clipped_dir = clipped_base / "its_targeted" / category / "tier2"
    output_dir = output_base / "its_targeted" / category / "tier2"

    if not original_dir.exists():
        continue

    for f in sorted(original_dir.glob("*.png")):
        clipped_path = clipped_dir / f.name
        output_path = output_dir / f.name
        result = combine_plots(f, clipped_path, output_path)
        if result:
            print(f"  Created: {output_path}")

print("\n=== Done! ===")
print(f"Combined plots saved to: {output_base}/")

#!/usr/bin/env python3
"""
Create Comparison Plots (Original vs Clipped) - Tier 1 Only
Concatenates original and clipped plots horizontally with labels
"""

from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import os

# Configuration
original_base = Path("review/overlap_plots")
clipped_base = Path("review/overlap_plots_clipped")
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

        # Load images
        img_original = Image.open(original_path)
        img_clipped = Image.open(clipped_path)

        # Add labels
        draw_orig = ImageDraw.Draw(img_original)
        draw_clip = ImageDraw.Draw(img_clipped)

        # Use default font with larger size
        try:
            font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 30)
        except:
            font = ImageFont.load_default()

        # Draw labels
        draw_orig.text((10, 10), "ORIGINAL", fill="red", font=font)
        draw_clip.text((10, 10), "CLIPPED", fill="green", font=font)

        # Create combined image
        total_width = img_original.width + img_clipped.width
        max_height = max(img_original.height, img_clipped.height)
        combined = Image.new('RGB', (total_width, max_height), 'white')
        combined.paste(img_original, (0, 0))
        combined.paste(img_clipped, (img_original.width, 0))

        # Ensure output directory exists
        output_path.parent.mkdir(parents=True, exist_ok=True)

        # Save
        combined.save(output_path)
        return True
    except Exception as e:
        print(f"  Error: {e}")
        return False

# Process Proportion (A1) - Tier 1 Only
print("=== Processing Proportion (A1) - Tier 1 Only ===")

proportion_outcomes = ["meat", "vegan", "vegetarian", "nonvegan", "total", "chicken_fish"]
proportion_exposures = [
    "mpbamod_dishes_count", "mpbamod_dishes_prop",
    "vegan_dishes_count", "vegan_dishes_prop",
    "vegetarian_dishes_count", "vegetarian_dishes_prop"
]

for outcome in proportion_outcomes:
    for exp_type in proportion_exposures:
        print(f"Processing Proportion: {outcome}/{exp_type}")

        original_dir = original_base / "proportion" / outcome / exp_type / "tier1"
        clipped_dir = clipped_base / "proportion" / outcome / exp_type / "tier1"
        output_dir = output_base / "proportion" / outcome / exp_type / "tier1"

        if not original_dir.exists():
            continue

        for f in original_dir.glob("*.png"):
            original_path = f
            clipped_path = clipped_dir / f.name
            output_path = output_dir / f.name

            result = combine_plots(original_path, clipped_path, output_path)
            if result:
                print(f"  Created: {output_path}")

# Process Proportion Targeted (A2) - Tier 1 Only
print("\n=== Processing Proportion Targeted (A2) - Tier 1 Only ===")

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
        print(f"Processing Proportion Targeted: {category}/{exp_type}")

        original_dir = original_base / "proportion_targeted" / category / exp_type / "tier1"
        clipped_dir = clipped_base / "proportion_targeted" / category / exp_type / "tier1"
        output_dir = output_base / "proportion_targeted" / category / exp_type / "tier1"

        if not original_dir.exists():
            continue

        for f in original_dir.glob("*.png"):
            original_path = f
            clipped_path = clipped_dir / f.name
            output_path = output_dir / f.name

            result = combine_plots(original_path, clipped_path, output_path)
            if result:
                print(f"  Created: {output_path}")

print("\n=== Done! ===")
print(f"Combined plots saved to: {output_base}/")

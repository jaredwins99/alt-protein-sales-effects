#!/usr/bin/env python3
"""
Script to horizontally concatenate unclipped and clipped overlap plots.
Unclipped (left) + Clipped (right)
"""

import os
from pathlib import Path
from PIL import Image

UNCLIPPED_DIR = Path("review/overlap_plots")
CLIPPED_DIR = Path("review/overlap_plots_clipped")
OUTPUT_DIR = Path("review/overlap_plots_combined")

def concat_horizontal(img1_path, img2_path, output_path):
    """Concatenate two images horizontally (img1 on left, img2 on right)."""
    img1 = Image.open(img1_path)
    img2 = Image.open(img2_path)

    # Get dimensions
    w1, h1 = img1.size
    w2, h2 = img2.size

    # Use max height, combine widths
    new_width = w1 + w2
    new_height = max(h1, h2)

    # Create new image with white background
    combined = Image.new('RGB', (new_width, new_height), (255, 255, 255))

    # Paste images (center vertically if heights differ)
    combined.paste(img1, (0, (new_height - h1) // 2))
    combined.paste(img2, (w1, (new_height - h2) // 2))

    # Ensure output directory exists
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Save
    combined.save(output_path)
    return True

def main():
    # Find all PNGs in unclipped directory
    unclipped_pngs = list(UNCLIPPED_DIR.rglob("*.png"))

    success_count = 0
    skip_count = 0
    error_count = 0

    for unclipped_path in unclipped_pngs:
        # Get relative path from base directory
        rel_path = unclipped_path.relative_to(UNCLIPPED_DIR)

        # Construct clipped path
        clipped_path = CLIPPED_DIR / rel_path

        # Construct output path
        output_path = OUTPUT_DIR / rel_path

        if not clipped_path.exists():
            print(f"SKIP: No clipped version for {rel_path}")
            skip_count += 1
            continue

        try:
            concat_horizontal(unclipped_path, clipped_path, output_path)
            print(f"OK: {rel_path}")
            success_count += 1
        except Exception as e:
            print(f"ERROR: {rel_path} - {e}")
            error_count += 1

    print(f"\nDone! Success: {success_count}, Skipped: {skip_count}, Errors: {error_count}")

if __name__ == "__main__":
    main()

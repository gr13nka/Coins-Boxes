#!/usr/bin/env python3
"""Post-process generated icons: remove white background, crop, resize to 256x256.

Usage:
    python3 scripts/postprocess_icons.py                # process all raw icons
    python3 scripts/postprocess_icons.py --item me_3    # single item
    python3 scripts/postprocess_icons.py --threshold 40 # adjust white tolerance

Requires Pillow. If not in system Python, use ComfyUI venv:
    ~/ComfyUI/venv/bin/python3 scripts/postprocess_icons.py
"""

import argparse
import os
import sys

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("Pillow not found. Try: ~/ComfyUI/venv/bin/python3 scripts/postprocess_icons.py")
    sys.exit(1)

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
RAW_DIR = os.path.join(PROJECT_DIR, "assets", "icons", "raw")
OUT_DIR = os.path.join(PROJECT_DIR, "assets", "icons")
TARGET_SIZE = 256


def flood_fill_transparent(img, tolerance=30):
    """Replace white-ish background with transparency via flood fill from corners."""
    img = img.convert("RGBA")
    pixels = img.load()
    w, h = img.size

    visited = set()
    stack = []

    # Start from all 4 corners
    for x, y in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        stack.append((x, y))

    def is_white_ish(r, g, b, a):
        return r > (255 - tolerance) and g > (255 - tolerance) and b > (255 - tolerance) and a > 128

    while stack:
        x, y = stack.pop()
        if (x, y) in visited:
            continue
        if x < 0 or x >= w or y < 0 or y >= h:
            continue

        r, g, b, a = pixels[x, y]
        if not is_white_ish(r, g, b, a):
            continue

        visited.add((x, y))
        pixels[x, y] = (r, g, b, 0)  # make transparent

        # 4-directional neighbors
        stack.append((x + 1, y))
        stack.append((x - 1, y))
        stack.append((x, y + 1))
        stack.append((x, y - 1))

    return img


def auto_crop_with_padding(img, padding_pct=0.10):
    """Crop to content bounding box with percentage padding."""
    bbox = img.getbbox()
    if not bbox:
        return img  # fully transparent

    left, top, right, bottom = bbox
    content_w = right - left
    content_h = bottom - top
    pad = int(max(content_w, content_h) * padding_pct)

    left = max(0, left - pad)
    top = max(0, top - pad)
    right = min(img.width, right + pad)
    bottom = min(img.height, bottom + pad)

    # Make it square (centered)
    crop_w = right - left
    crop_h = bottom - top
    if crop_w != crop_h:
        size = max(crop_w, crop_h)
        cx = (left + right) // 2
        cy = (top + bottom) // 2
        left = max(0, cx - size // 2)
        top = max(0, cy - size // 2)
        right = min(img.width, left + size)
        bottom = min(img.height, top + size)

    return img.crop((left, top, right, bottom))


def process_one(raw_path, out_path, tolerance=30):
    """Process a single raw icon to final output."""
    img = Image.open(raw_path).convert("RGBA")

    # Remove white background
    img = flood_fill_transparent(img, tolerance)

    # Crop to content
    img = auto_crop_with_padding(img, padding_pct=0.08)

    # Resize to target
    img = img.resize((TARGET_SIZE, TARGET_SIZE), Image.LANCZOS)

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    img.save(out_path, "PNG")
    return True


def main():
    parser = argparse.ArgumentParser(description="Post-process raw icons")
    parser.add_argument("--item", help="Process single item (e.g. me_3)")
    parser.add_argument("--threshold", type=int, default=80,
                        help="White tolerance for background removal (default: 80)")
    parser.add_argument("--no-skip", action="store_true",
                        help="Reprocess existing output files")
    args = parser.parse_args()

    if not os.path.isdir(RAW_DIR):
        print(f"Raw directory not found: {RAW_DIR}")
        print("Run generate_icons.py first.")
        sys.exit(1)

    # Collect raw files
    raw_files = []
    for f in sorted(os.listdir(RAW_DIR)):
        if not f.endswith(".png"):
            continue
        key = f.replace(".png", "")
        if args.item and key != args.item.lower():
            continue
        raw_files.append((key, os.path.join(RAW_DIR, f)))

    if not raw_files:
        print("No raw files found to process.")
        sys.exit(1)

    total = len(raw_files)
    processed = 0
    skipped = 0
    failed = 0

    print(f"Processing {total} icons (threshold={args.threshold})...")

    for i, (key, raw_path) in enumerate(raw_files, start=1):
        out_path = os.path.join(OUT_DIR, f"{key}.png")

        if not args.no_skip and os.path.exists(out_path):
            skipped += 1
            continue

        try:
            process_one(raw_path, out_path, args.threshold)
            processed += 1
            print(f"  [{i}/{total}] {key} -- OK")
        except RecursionError:
            # Flood fill hit recursion limit on very large white areas;
            # fall back to simple threshold
            try:
                img = Image.open(raw_path).convert("RGBA")
                data = img.getdata()
                new_data = []
                tol = args.threshold
                for r, g, b, a in data:
                    if r > 255 - tol and g > 255 - tol and b > 255 - tol:
                        new_data.append((r, g, b, 0))
                    else:
                        new_data.append((r, g, b, a))
                img.putdata(new_data)
                img = auto_crop_with_padding(img, padding_pct=0.08)
                img = img.resize((TARGET_SIZE, TARGET_SIZE), Image.LANCZOS)
                img.save(out_path, "PNG")
                processed += 1
                print(f"  [{i}/{total}] {key} -- OK (threshold fallback)")
            except Exception as e2:
                failed += 1
                print(f"  [{i}/{total}] {key} -- FAILED: {e2}")
        except Exception as e:
            failed += 1
            print(f"  [{i}/{total}] {key} -- FAILED: {e}")

    print(f"\nDone. Processed: {processed}, Skipped: {skipped}, Failed: {failed}")


if __name__ == "__main__":
    main()

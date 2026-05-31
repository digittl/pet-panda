#!/usr/bin/env python3
"""Segment a cut-out pet sprite into candidate parts with FastSAM and render a
labelled overlay so the parts can be eyeballed and assigned to a rig.

Outputs:
  <name>_masks.png   — the sprite with each mask tinted + numbered
  <name>_masks/<i>.png — every individual mask as its own transparent layer

Usage: python segment_pet.py <cutout_png> <name> [outdir]
"""

import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from ultralytics import FastSAM


def main():
    if len(sys.argv) < 3:
        sys.exit("usage: segment_pet.py <cutout_png> <name> [outdir]")

    src, name = sys.argv[1], sys.argv[2]
    outdir = sys.argv[3] if len(sys.argv) > 3 else os.path.dirname(os.path.abspath(src))

    base = Image.open(src).convert("RGBA")
    w, h = base.size

    model = FastSAM("FastSAM-s.pt")
    results = model(src, device="cpu", retina_masks=True, imgsz=1024, conf=0.35, iou=0.9, verbose=False)

    masks = results[0].masks
    if masks is None:
        sys.exit("no masks found")

    data = masks.data.cpu().numpy()  # (N, H, W) at model resolution
    print(f"{len(data)} masks")

    overlay = base.copy()
    draw = ImageDraw.Draw(overlay, "RGBA")
    palette = [
        (255, 80, 80, 110), (80, 180, 255, 110), (120, 220, 120, 110),
        (255, 200, 60, 110), (200, 120, 255, 110), (80, 230, 220, 110),
        (255, 140, 200, 110), (160, 160, 90, 110), (120, 200, 255, 110),
        (240, 120, 90, 110),
    ]

    layer_dir = os.path.join(outdir, f"{name}_masks")
    os.makedirs(layer_dir, exist_ok=True)

    for i, m in enumerate(data):
        mask_img = Image.fromarray((m * 255).astype(np.uint8)).resize((w, h), Image.NEAREST)
        arr = np.array(mask_img) > 127

        # Tint + label on the overlay
        color = palette[i % len(palette)]
        tint = Image.new("RGBA", (w, h), color)
        overlay.paste(tint, (0, 0), Image.fromarray((arr * color[3]).astype(np.uint8)))

        ys, xs = np.where(arr)
        if len(xs):
            cx, cy = int(xs.mean()), int(ys.mean())
            draw.text((cx, cy), str(i), fill=(0, 0, 0, 255))

        # Each mask as its own cut-out layer
        layer = np.array(base).copy()
        layer[~arr, 3] = 0
        Image.fromarray(layer).save(os.path.join(layer_dir, f"{i}.png"))

    overlay_path = os.path.join(outdir, f"{name}_masks.png")
    overlay.save(overlay_path)
    print(f"wrote {overlay_path} and {len(data)} layers in {layer_dir}")


if __name__ == "__main__":
    main()

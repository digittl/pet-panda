#!/usr/bin/env python3
"""Split a cut-out pet sprite into articulated layers for the part-rig.

Lifts movable parts off the body (ears + eyes via point-prompted SAM, tail via
a manual box since it's the same colour as the body), then rebuilds a clean BASE
with each removed gap filled by the *local fur colour* sampled from a ring around
it — not a generic inpaint, which previously pulled in the dark outline and left
a grey ghost. Gaps that open onto empty space (a part sticking into the air) are
left transparent.

Layers are full-canvas-sized so the app stacks them at one frame; a manifest
records each part's pivot (unit point) and how it animates (rotate / blink).

Usage: python build_parts.py <cutout_png> <name> <outdir>
"""

import json
import os
import sys

import cv2
import numpy as np
from PIL import Image
from ultralytics import SAM

# Per-pet rig spec, tuned for the puppy at 911x1029.
#   kind:  "rotate" (ears, tail swing about a pivot) | "blink" (eyes squash)
#   pivot: unit point the part rotates / squashes about
PUPPY = {
    "ear_left":  {"points": [[120, 240]], "box": None, "kind": "rotate", "pivot": (0.24, 0.17)},
    "ear_right": {"points": [[775, 215]], "box": None, "kind": "rotate", "pivot": (0.74, 0.16)},
    "tail":      {"points": None, "box": [745, 510, 905, 720], "kind": "rotate", "pivot": (0.83, 0.66)},
    "eyes":      {"points": [[315, 375], [560, 360]], "box": None, "kind": "blink", "pivot": (0.48, 0.36), "split": True},
}


def part_mask(model, src, spec, size, body):
    if spec["box"] is not None:
        r = model(src, bboxes=[spec["box"]], device="cpu", verbose=False)
        m = r[0].masks.data[0].cpu().numpy()
        m = np.array(Image.fromarray((m * 255).astype(np.uint8)).resize(size, Image.NEAREST)) > 127
        return m & body
    # points: union a separate mask per point (so two eyes both come through)
    pts = spec["points"]
    union = np.zeros((size[1], size[0]), bool)
    for p in pts:
        r = model(src, points=[p], labels=[1], device="cpu", verbose=False)
        m = r[0].masks.data[0].cpu().numpy()
        m = np.array(Image.fromarray((m * 255).astype(np.uint8)).resize(size, Image.NEAREST)) > 127
        union |= (m & body)
    return union


def local_fill(rgb, mask, body):
    """Fill `mask` pixels with the median colour of nearby body pixels, ignoring
    dark outline pixels so the patch matches the fur, not the ink."""
    out = rgb.copy()
    ring = cv2.dilate(mask.astype(np.uint8), np.ones((25, 25), np.uint8), 1).astype(bool)
    ring &= body & ~mask
    lum = rgb.astype(float).mean(axis=2)
    ring &= lum > 90  # drop the dark outline
    if ring.sum() == 0:
        return out
    fill = np.median(rgb[ring], axis=0).astype(np.uint8)
    out[mask] = fill
    # soften the patch so it blends
    blurred = cv2.GaussianBlur(out, (0, 0), 3)
    out[mask] = blurred[mask]
    return out


def main():
    src, name, outdir = sys.argv[1], sys.argv[2], sys.argv[3]
    os.makedirs(outdir, exist_ok=True)

    base = Image.open(src).convert("RGBA")
    W, H = base.size
    arr = np.array(base)
    body = arr[:, :, 3] > 0
    rgb = arr[:, :, :3].copy()

    model = SAM("mobile_sam.pt")
    specs = PUPPY

    part_masks = {}
    for pname, spec in specs.items():
        m = part_mask(model, src, spec, (W, H), body)
        m = cv2.dilate(m.astype(np.uint8), np.ones((3, 3), np.uint8), 1).astype(bool) & body
        part_masks[pname] = m
        layer = arr.copy()
        layer[~m, 3] = 0
        Image.fromarray(layer).save(os.path.join(outdir, f"{name}_{pname}.png"))

    removed = np.zeros((H, W), bool)
    for m in part_masks.values():
        removed |= m

    base_alpha = body.copy()
    base_alpha[removed] = False

    # Removed pixels that open onto empty space stay transparent; enclosed ones
    # (head behind an ear, rump behind the tail, socket behind an eye) get filled.
    free = (~base_alpha).astype(np.uint8)
    ff = free.copy()
    h, w = ff.shape
    fmask = np.zeros((h + 2, w + 2), np.uint8)
    for x in range(w):
        if ff[0, x]:
            cv2.floodFill(ff, fmask, (x, 0), 2)
        if ff[h - 1, x]:
            cv2.floodFill(ff, fmask, (x, h - 1), 2)
    for y in range(h):
        if ff[y, 0]:
            cv2.floodFill(ff, fmask, (0, y), 2)
        if ff[y, w - 1]:
            cv2.floodFill(ff, fmask, (w - 1, y), 2)
    outside = ff == 2
    enclosed = removed & ~outside

    base_alpha[enclosed] = True
    rgb_filled = local_fill(rgb, enclosed, body)

    base_out = np.dstack([rgb_filled, (base_alpha * 255).astype(np.uint8)])
    Image.fromarray(base_out).save(os.path.join(outdir, f"{name}_base.png"))

    manifest = {
        "size": [W, H],
        "base": f"{name}_base.png",
        "parts": [
            {"name": p, "image": f"{name}_{p}.png", "kind": specs[p]["kind"], "pivot": list(specs[p]["pivot"])}
            for p in specs
        ],
    }
    with open(os.path.join(outdir, f"{name}_manifest.json"), "w") as f:
        json.dump(manifest, f, indent=2)

    prev = Image.new("RGBA", (W, H), (255, 255, 255, 255))
    prev.alpha_composite(Image.open(os.path.join(outdir, f"{name}_base.png")))
    for p in specs:
        prev.alpha_composite(Image.open(os.path.join(outdir, f"{name}_{p}.png")))
    prev.save(os.path.join(outdir, f"{name}_stacked.png"))
    print(f"built base + {len(specs)} parts for {name}")


if __name__ == "__main__":
    main()

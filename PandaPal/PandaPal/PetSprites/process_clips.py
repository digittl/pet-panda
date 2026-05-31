#!/usr/bin/env python3
"""Turn the 50 separate puppy frames into animation clips for the app.

Per frame: flood-fill the white background to transparent (keeps interior
whites like the chest, and keeps confetti / ZZZ which a salient cutout would
drop), then Real-ESRGAN anime-4x for crisp edges, then install as an
asset-catalog imageset named puppy_<anim>_<k>.

Also reports any frame whose art touches the canvas edge (clipped), and writes
a clips manifest the app uses to play each animation.

Usage: python process_clips.py <frames_dir>
"""

import json
import os
import subprocess
import sys

import cv2
import numpy as np
from PIL import Image
from rembg import new_session, remove

_SESSION = new_session("u2net")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "Assets.xcassets")
TOOLS = os.path.join(os.path.dirname(ROOT), "..", "tools", "realesrgan")
RESR = os.path.abspath(os.path.join(TOOLS, "realesrgan-ncnn-vulkan"))
MODELS = os.path.abspath(os.path.join(TOOLS, "models"))

ANIMS = ["idle", "tail_wag", "head_tilt", "play_bow", "pounce",
         "happy_bounce", "paw_wave", "roll_over", "sleep", "excited_celebration"]
TARGET = 768  # final frame size after upscale + downsample


def cutout(path):
    """Lift just the puppy with rembg (salient-object ML). Flood-fill can't be
    used: each frame has a black-bordered white card, and the border fences the
    interior white off from the canvas edge. rembg ignores the card entirely.
    Returns RGBA numpy array + whether the puppy touches the canvas edge."""
    im = Image.open(path).convert("RGB")
    out = remove(
        im, session=_SESSION,
        alpha_matting=True,
        alpha_matting_foreground_threshold=240,
        alpha_matting_background_threshold=15,
        alpha_matting_erode_size=8,
    ).convert("RGBA")

    rgba = np.array(out)
    alpha = rgba[:, :, 3]
    h, w = alpha.shape

    # Keep only the largest opaque blob (drops any stray bits of the card border
    # rembg might leave, plus speckle).
    solid = (alpha > 30).astype(np.uint8)
    n, lab, stats, _ = cv2.connectedComponentsWithStats(solid, 8)
    if n > 1:
        biggest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
        rgba[lab != biggest, 3] = 0
        alpha = rgba[:, :, 3]

    ring = np.zeros((h, w), bool)
    ring[:2, :] = ring[-2:, :] = ring[:, :2] = ring[:, -2:] = True
    clipped = bool((alpha[ring] > 40).any())
    return rgba, clipped


def main():
    frames_dir = sys.argv[1]
    cut_dir, up_dir = "/tmp/clip_cut", "/tmp/clip_up"
    os.makedirs(cut_dir, exist_ok=True)
    os.makedirs(up_dir, exist_ok=True)

    clipped = []
    for anim in ANIMS:
        for k in range(1, 6):
            src = os.path.join(frames_dir, f"{anim}_{k:02d}.png")
            rgba, is_clipped = cutout(src)
            Image.fromarray(rgba).save(os.path.join(cut_dir, f"{anim}_{k:02d}.png"))
            if is_clipped:
                clipped.append(f"{anim}_{k:02d}")

    # Batch upscale (Real-ESRGAN anime 4x, alpha-preserving) on the GPU.
    subprocess.run(
        [RESR, "-i", cut_dir, "-o", up_dir, "-n", "realesrgan-x4plus-anime", "-s", "4", "-m", MODELS, "-f", "png"],
        check=True, stderr=subprocess.DEVNULL,
    )

    manifest = {"fps": 12, "clips": {}}
    for anim in ANIMS:
        names = []
        for k in range(1, 6):
            up = Image.open(os.path.join(up_dir, f"{anim}_{k:02d}.png")).convert("RGBA")
            up.thumbnail((TARGET, TARGET), Image.LANCZOS)
            asset = f"puppy_{anim}_{k}"
            iset = os.path.join(ASSETS, f"{asset}.imageset")
            os.makedirs(iset, exist_ok=True)
            up.save(os.path.join(iset, f"{asset}.png"))
            json.dump(
                {"images": [{"idiom": "universal", "filename": f"{asset}.png"}], "info": {"version": 1, "author": "xcode"}},
                open(os.path.join(iset, "Contents.json"), "w"), indent=2,
            )
            names.append(asset)
        manifest["clips"][anim] = names

    with open(os.path.join(os.path.dirname(__file__), "puppy_clips.json"), "w") as f:
        json.dump(manifest, f, indent=2)

    print(f"installed 50 frames across {len(ANIMS)} clips")
    print("CLIPPED frames (art touches canvas edge):", clipped if clipped else "none")


if __name__ == "__main__":
    main()

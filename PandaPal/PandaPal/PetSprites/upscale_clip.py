#!/usr/bin/env python3
"""Upscale an installed clip's frames with Real-ESRGAN (anime model) for crisp,
fine line-art. Alpha is preserved. Re-installs in place at the target size.

Usage: python upscale_clip.py <clip> [target_px=1536]
"""

import glob
import os
import shutil
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ASSETS = os.path.join(ROOT, "Assets.xcassets")
TOOLS = os.path.abspath(os.path.join(ROOT, "..", "..", "tools", "realesrgan"))
RESR = os.path.join(TOOLS, "realesrgan-ncnn-vulkan")
MODELS = os.path.join(TOOLS, "models")


def main():
    clip = sys.argv[1]
    target = int(sys.argv[2]) if len(sys.argv) > 2 else 1536

    isets = sorted(glob.glob(os.path.join(ASSETS, f"puppy_{clip}_*.imageset")),
                   key=lambda p: int(p.rsplit("_", 1)[1].split(".")[0]))
    if not isets:
        sys.exit(f"no installed frames for {clip}")

    src, out = "/tmp/up_in", "/tmp/up_out"
    shutil.rmtree(src, ignore_errors=True)
    shutil.rmtree(out, ignore_errors=True)
    os.makedirs(src)
    os.makedirs(out)

    order = []
    for i, iset in enumerate(isets, 1):
        name = os.path.basename(iset).replace(".imageset", "")
        shutil.copy(os.path.join(iset, f"{name}.png"), os.path.join(src, f"{i:04d}.png"))
        order.append((iset, name))

    subprocess.run([RESR, "-i", src, "-o", out, "-n", "realesrgan-x4plus-anime",
                    "-s", "4", "-m", MODELS, "-f", "png"], check=True, stderr=subprocess.DEVNULL)

    for i, (iset, name) in enumerate(order, 1):
        im = Image.open(os.path.join(out, f"{i:04d}.png")).convert("RGBA")
        if max(im.size) > target:
            im.thumbnail((target, target), Image.LANCZOS)
        im.save(os.path.join(iset, f"{name}.png"))
    print(f"upscaled {clip}: {len(order)} frames -> {target}px")


if __name__ == "__main__":
    main()

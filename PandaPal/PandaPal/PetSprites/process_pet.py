#!/usr/bin/env python3
"""Turn a reference illustration into an app sprite.

Removes the background with rembg (ML cutout), trims the transparent margins,
and installs the result as a universal image-set inside Assets.xcassets so the
app can load it with Image("<name>"). No Xcode project edit needed — the asset
catalog compiles every image-set it contains.

Usage: python process_pet.py <input_image> <pet_name>
"""

import json
import os
import sys

from PIL import Image
from rembg import remove

ASSETS = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "Assets.xcassets",
)


def main():
    if len(sys.argv) < 3:
        sys.exit("usage: process_pet.py <input_image> <pet_name>")

    src, name = sys.argv[1], sys.argv[2]

    img = Image.open(src).convert("RGBA")
    cut = remove(img)

    # Trim the fully-transparent border so the sprite fills its art box.
    bbox = cut.getbbox()
    if bbox is not None:
        cut = cut.crop(bbox)

    imageset = os.path.join(ASSETS, f"{name}.imageset")
    os.makedirs(imageset, exist_ok=True)

    cut.save(os.path.join(imageset, f"{name}.png"))

    contents = {
        "images": [{"idiom": "universal", "filename": f"{name}.png"}],
        "info": {"version": 1, "author": "xcode"},
    }
    with open(os.path.join(imageset, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)

    print(f"installed {name}.imageset ({cut.width}x{cut.height})")


if __name__ == "__main__":
    main()

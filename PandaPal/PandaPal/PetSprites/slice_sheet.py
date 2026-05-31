#!/usr/bin/env python3
"""Slice the 10x5 puppy contact sheet into 50 registered frames.

Uses a fixed uniform grid (measured from the sheet's detected blob positions).
Uniform cells preserve the frame-to-frame registration the artist drew, so
playback doesn't jitter. Cutout + denoise happens later in the pipeline; here we
just crop cells and emit a montage to verify alignment.

Layout (row, half) -> animation:
  r0: idle | tail_wag        r1: head_tilt | play_bow
  r2: pounce | happy_bounce  r3: paw_wave | roll_over
  r4: sleep | excited_celebration

Usage: python slice_sheet.py <sheet.png> <outdir>
"""

import os
import sys

from PIL import Image, ImageDraw

LAYOUT = [
    ["idle", "tail_wag"],
    ["head_tilt", "play_bow"],
    ["pounce", "happy_bounce"],
    ["paw_wave", "roll_over"],
    ["sleep", "excited_celebration"],
]

LEFT_X0, LEFT_SLOT = 28, 139
RIGHT_X0, RIGHT_SLOT = 786, 145
# (y_top, height) per row band — pounce row a touch taller for the leap.
ROWS = [(108, 152), (298, 152), (466, 162), (668, 152), (852, 140)]


def cell_rect(row, half, k):
    y0, h = ROWS[row]
    if half == 0:
        x0 = LEFT_X0 + k * LEFT_SLOT
        w = LEFT_SLOT
    else:
        x0 = RIGHT_X0 + k * RIGHT_SLOT
        w = RIGHT_SLOT
    return x0, y0, x0 + w, y0 + h


def main():
    sheet, outdir = sys.argv[1], sys.argv[2]
    im = Image.open(sheet).convert("RGBA")

    montage = Image.new("RGB", (RIGHT_X0 + 5 * RIGHT_SLOT + 40, ROWS[-1][0] + ROWS[-1][1] + 40), (245, 245, 245))
    md = ImageDraw.Draw(montage)

    for ri in range(5):
        for half in (0, 1):
            anim = LAYOUT[ri][half]
            adir = os.path.join(outdir, anim)
            os.makedirs(adir, exist_ok=True)
            for k in range(5):
                x0, y0, x1, y1 = cell_rect(ri, half, k)
                cell = im.crop((x0, y0, x1, y1))
                cell.save(os.path.join(adir, f"{k + 1:02d}.png"))
                montage.paste(cell.convert("RGB"), (x0, y0))
                md.rectangle([x0, y0, x1 - 1, y1 - 1], outline=(255, 0, 0))
                md.text((x0 + 2, y0 + 2), f"{anim[:4]}{k+1}", fill=(0, 0, 200))

    montage.save(os.path.join(outdir, "_montage.png"))
    print(f"sliced 50 cells into {outdir}")


if __name__ == "__main__":
    main()

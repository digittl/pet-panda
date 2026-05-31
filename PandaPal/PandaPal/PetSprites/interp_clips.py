#!/usr/bin/env python3
"""Build butter-smooth animation clips from keyframes, using FILM interpolation.

Per clip:
  1. load each keyframe; if it has no transparency, cut the background with
     rembg (no matting, so white tail/chest survive)
  2. work at a common resolution
  3. FILM-interpolate (recursive doublings) until dense enough for 120fps. FILM
     is built for large motion, so big pose swings morph coherently instead of
     ghosting like RIFE. RIFE/FILM only do RGB, so premultiplied-over-black RGB
     and the alpha channel are interpolated separately and recombined.
  4. install each frame as puppy_<clip>_<n>

Usage:
  python interp_clips.py <clip> <frames_dir>   # one clip from a folder
  python interp_clips.py all                   # all clips from the keyframe cache
"""

import glob
import os
import shutil
import sys

import cv2
import numpy as np
from PIL import Image

import film_interp

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "Assets.xcassets")
TOOLBASE = os.path.abspath(os.path.join(ROOT, "..", "..", "tools"))
KEYFRAMES = os.path.join(TOOLBASE, "puppy_keyframes")

ANIMS = ["idle", "tail_wag", "head_tilt", "play_bow", "pounce",
         "happy_bounce", "paw_wave", "roll_over", "sleep", "excited_celebration"]

# Direct (non-recursive) interpolation to ~this many frames: every in-between
# comes straight from two real keyframes, so warp never compounds.
TARGET_FRAMES = 36
# Resolution the pipeline runs + stores at (env-overridable). High keeps detail
# end-to-end instead of crushing to a small size and faking it back later.
# No point storing larger than the biggest on-screen size (~500px at "huge");
# 768 covers retina with headroom. Bigger is just wasted disk.
WORK_RES = int(os.environ.get("PETPIPE_WORKRES", "1024"))
STORE = int(os.environ.get("PETPIPE_STORE", "768"))

_session = None


def cut(path):
    """High-quality matte with BiRefNet (SOTA dichotomous segmentation).

    Clean soft edges, no white fringe, and it keeps the white tail tip / chest
    consistently across frames — far better than flood-fill (hard halo) or
    u2net (flickered the white tail in/out).
    """
    im = Image.open(path).convert("RGBA")
    a = np.array(im)
    if a[:, :, 3].min() < 250:
        return im  # already has transparency

    global _session
    if _session is None:
        from rembg import new_session
        _session = new_session("birefnet-general")
    from rembg import remove
    return remove(Image.open(path).convert("RGB"), session=_session).convert("RGBA")


def align_frames(frames):
    """Stabilise the puppy's position AND scale across keyframes.

    The reference frames drift — the puppy is drawn a little bigger/smaller and
    shifted between drawings — which reads as the pet pulsing and sliding. We
    measure the body CORE (alpha eroded to drop the thin tail/legs so a wag can't
    drag the body), normalise every frame so the core is the same height, and
    place it so the core's centre-x and bottom (feet) match the median. Only the
    intended motion (tail, head, blink) survives.
    """
    H, W = frames[0].shape[:2]
    sized = []
    for f in frames:
        if f.shape[:2] != (H, W):
            f = np.array(Image.fromarray(f).resize((W, H), Image.LANCZOS))
        sized.append(f)

    metrics = []
    for f in sized:
        mask = (f[:, :, 3] > 128).astype(np.uint8)
        core = cv2.erode(mask, np.ones((31, 31), np.uint8), iterations=1)
        if core.sum() < 50:
            core = mask
        ys, xs = np.where(core > 0)
        metrics.append((float(xs.mean()), float(ys.max()), float(ys.max() - ys.min())))

    t_h = float(np.median([m[2] for m in metrics]))
    t_cx = float(np.median([m[0] for m in metrics]))
    t_by = float(np.median([m[1] for m in metrics]))

    out = []
    for f, (cx, by, ch) in zip(sized, metrics):
        scale = max(0.6, min(1.6, t_h / ch)) if ch > 1 else 1.0
        rw, rh = max(1, int(round(W * scale))), max(1, int(round(H * scale)))
        resized = Image.fromarray(f).resize((rw, rh), Image.LANCZOS)

        # Anchor in resized coordinates, placed so it lands on the target.
        dx = int(round(t_cx - cx * scale))
        dy = int(round(t_by - by * scale))

        canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        canvas.paste(resized, (dx, dy), resized)  # paste clips negative offsets
        out.append(np.array(canvas))
    return out


def fresh(*dirs):
    for d in dirs:
        shutil.rmtree(d, ignore_errors=True)
        os.makedirs(d)


def build_clip(clip, src_dir, work):
    srcs = sorted(glob.glob(os.path.join(src_dir, f"{clip}_*.png")))
    if not srcs:
        print(f"!! no frames for {clip} in {src_dir}")
        return 0

    rgb_dir, a_dir = os.path.join(work, "rgb"), os.path.join(work, "a")
    fresh(rgb_dir, a_dir)

    cuts = [np.array(cut(s).convert("RGBA")) for s in srcs]
    cuts = align_frames(cuts)

    for i, f in enumerate(cuts, start=1):
        im = Image.fromarray(f)
        im.thumbnail((WORK_RES, WORK_RES), Image.LANCZOS)
        f = np.array(im.convert("RGBA"))
        alpha = f[:, :, 3:4].astype(float) / 255.0
        premult = (f[:, :, :3].astype(float) * alpha).astype(np.uint8)
        Image.fromarray(premult).save(os.path.join(rgb_dir, f"{i:08d}.png"))
        Image.fromarray(np.repeat(f[:, :, 3:4], 3, axis=2)).save(os.path.join(a_dir, f"{i:08d}.png"))

    # Per-gap interpolation count from frame-diff. FILM interpolates LOCAL motion
    # cleanly (tail wag, blink, bob → many smooth in-betweens) but SMEARS a
    # whole-body change (a leap, a roll). Frame-diff tells them apart: a leap
    # changes most pixels (high ratio) → snappy clean CUT (k=0); subtle motion
    # changes few (low ratio) → smooth (k=3). This avoids the leap smears.
    n = len(srcs)
    rgb_files = sorted(glob.glob(os.path.join(rgb_dir, "*.png")))
    imgs = [np.array(Image.open(f).convert("RGB")).astype(float) for f in rgb_files]
    motion = [float(np.abs(imgs[i + 1] - imgs[i]).mean()) for i in range(n - 1)]
    m_med = float(np.median(motion)) or 1.0

    # Interpolation profile (env PETPIPE_INTERP): your drawn frames are clean;
    # the artifacts only come from FILM morphing between them. 'raw' plays just
    # your stabilised frames (zero morph). 'light' adds one in-between only on
    # near-identical gaps. 'full' is the old motion-adaptive scheme.
    profile = os.environ.get("PETPIPE_INTERP", "raw")
    ks = []
    for m in motion:
        r = m / m_med
        if profile == "raw":
            ks.append(0)
        elif profile == "light":
            ks.append(1 if r < 0.9 else 0)
        else:
            ks.append(0 if r > 1.8 else (1 if r > 1.15 else 3))

    cur_rgb, cur_a = os.path.join(work, "r"), os.path.join(work, "a_out")
    film_interp.densify_dir(rgb_dir, cur_rgb, ks)
    film_interp.densify_dir(a_dir, cur_a, ks)

    for old in os.listdir(ASSETS):
        if old.startswith(f"puppy_{clip}_") and old.endswith(".imageset"):
            shutil.rmtree(os.path.join(ASSETS, old), ignore_errors=True)

    names = sorted(os.listdir(cur_rgb))
    for i, nm in enumerate(names):
        prgb = np.array(Image.open(os.path.join(cur_rgb, nm)).convert("RGB")).astype(float)
        a = np.array(Image.open(os.path.join(cur_a, nm)).convert("L")).astype(float)
        af = np.clip(a / 255.0, 0, 1)[:, :, None]
        straight = np.where(af > 0.01, np.clip(prgb / np.where(af > 0.01, af, 1), 0, 255), 0).astype(np.uint8)
        out = Image.fromarray(np.dstack([straight, a.astype(np.uint8)]), "RGBA")
        out.thumbnail((STORE, STORE), Image.LANCZOS)
        asset = f"puppy_{clip}_{i + 1}"
        iset = os.path.join(ASSETS, f"{asset}.imageset")
        os.makedirs(iset, exist_ok=True)
        out.save(os.path.join(iset, f"{asset}.png"))
        import json
        json.dump({"images": [{"idiom": "universal", "filename": f"{asset}.png"}],
                   "info": {"version": 1, "author": "xcode"}},
                  open(os.path.join(iset, "Contents.json"), "w"), indent=2)
    return len(names)


def main():
    work = "/tmp/interp"
    os.makedirs(work, exist_ok=True)

    if sys.argv[1] == "all":
        for clip in ANIMS:
            print(f"{clip}: {build_clip(clip, KEYFRAMES, work)} frames")
        return

    clip = sys.argv[1]
    src_dir = sys.argv[2] if len(sys.argv) > 2 else KEYFRAMES
    print(f"{clip}: {build_clip(clip, src_dir, work)} frames")


if __name__ == "__main__":
    main()

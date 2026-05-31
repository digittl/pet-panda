"""FILM (Frame Interpolation for Large Motion) midpoint interpolation.

Drop-in replacement for the RIFE step: FILM is purpose-built for large motion
between frames, so it morphs the dog far more coherently than RIFE on the big
pose swings (roll, pounce, tail whip). Runs in-process on the Apple GPU (MPS).
RIFE-style folder doubling: densify_dir reads N frames and writes 2N-1 by
inserting one FILM midpoint between each consecutive pair.
"""

import glob
import os

import numpy as np
import torch
from PIL import Image

_MODEL_PATH = os.path.abspath(os.path.join(
    os.path.dirname(__file__), "..", "..", "..", "tools", "film", "film_net_fp32.pt"))

_model = None
_device = None


def _load():
    global _model, _device
    if _model is None:
        _device = "mps" if torch.backends.mps.is_available() else "cpu"
        m = torch.jit.load(_MODEL_PATH, map_location="cpu").eval().float()
        try:
            _model = m.to(_device)
        except Exception:
            _device = "cpu"
            _model = m.to("cpu")
    return _model, _device


def _pad(img, align=64):
    h, w = img.shape[:2]
    ph = (align - h % align) % align
    pw = (align - w % align) % align
    return np.pad(img, ((0, ph), (0, pw), (0, 0))), (h, w)


def interp(a, b, dt):
    """FILM frame between two HxWx3 uint8 RGB frames at time dt in (0,1)."""
    model, device = _load()
    ap, (h, w) = _pad(a)
    bp, _ = _pad(b)
    ta = torch.from_numpy(ap / 255.0).permute(2, 0, 1)[None].float().to(device)
    tb = torch.from_numpy(bp / 255.0).permute(2, 0, 1)[None].float().to(device)
    dtt = torch.full((1, 1), float(dt), device=device)
    with torch.no_grad():
        pred = model(ta, tb, dtt).clamp(0, 1)
    out = (pred[0].permute(1, 2, 0).cpu().numpy() * 255).astype(np.uint8)
    return out[:h, :w]


def densify_dir(indir, outdir, ks):
    """Insert ks[i] in-between frames into consecutive pair i. Every in-between
    is computed DIRECTLY from the two real frames (dt = j/(ks[i]+1)), never from
    another interpolated frame — so warp doesn't compound.

    ks is a per-gap list (length = #frames - 1) so motion-heavy gaps (a fast tail
    swing) can get more frames than still ones — the same schedule is passed for
    the RGB and alpha passes so they stay frame-aligned.
    """
    import shutil
    shutil.rmtree(outdir, ignore_errors=True)  # clear stale frames from prior runs
    os.makedirs(outdir, exist_ok=True)
    files = sorted(glob.glob(os.path.join(indir, "*.png")))
    imgs = [np.array(Image.open(f).convert("RGB")) for f in files]

    out = []
    for i in range(len(imgs) - 1):
        out.append(imgs[i])
        k = ks[i]
        for j in range(1, k + 1):
            out.append(interp(imgs[i], imgs[i + 1], j / (k + 1)))
    out.append(imgs[-1])

    for i, im in enumerate(out, start=1):
        Image.fromarray(im).save(os.path.join(outdir, f"{i:08d}.png"))

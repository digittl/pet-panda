#!/usr/bin/env python3
"""One-clip experiment: local image-to-video with LTX-Video on Apple MPS.

Takes ONE reference image of the puppy and a motion prompt, generates a short
video, and dumps the frames. If this looks good + coherent, the same call with
different prompts produces every animation from a single reference image.

Usage: python ltx_test.py <reference.png> "<motion prompt>" <outdir>
"""

import sys
import os

import torch
from PIL import Image
from diffusers import LTXImageToVideoPipeline
from diffusers.utils import export_to_video

ref_path, prompt, outdir = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(outdir, exist_ok=True)

device = "mps" if torch.backends.mps.is_available() else "cpu"
dtype = torch.float16 if device == "mps" else torch.float32
print(f"device={device} dtype={dtype}")

pipe = LTXImageToVideoPipeline.from_pretrained("Lightricks/LTX-Video", torch_dtype=dtype)
pipe.to(device)

# Fit the reference onto a 768x512 canvas (LTX wants /32 dims).
W, H = 768, 512
img = Image.open(ref_path).convert("RGB")
canvas = Image.new("RGB", (W, H), (255, 255, 255))
img.thumbnail((W, H), Image.LANCZOS)
canvas.paste(img, ((W - img.width) // 2, (H - img.height) // 2))

negative = "blurry, distorted, deformed, extra limbs, realistic, photo"
result = pipe(
    image=canvas,
    prompt=prompt,
    negative_prompt=negative,
    width=W, height=H,
    num_frames=49,
    num_inference_steps=30,
    guidance_scale=3.0,
).frames[0]

export_to_video(result, os.path.join(outdir, "clip.mp4"), fps=24)
for i, frame in enumerate(result):
    frame.save(os.path.join(outdir, f"f{i:03d}.png"))
print(f"wrote {len(result)} frames to {outdir}")

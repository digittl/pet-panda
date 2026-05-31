#!/usr/bin/env python3
"""Heavy image-to-video experiment: Wan 2.2 (5B) on Apple MPS.

Much larger/higher-quality than LTX. Same idea: one reference image + a motion
prompt -> a coherent animated clip.

Usage: python wan_test.py <reference.png> "<motion prompt>" <outdir>
"""

import sys
import os

import torch
from PIL import Image
from diffusers import WanImageToVideoPipeline, AutoencoderKLWan
from diffusers.utils import export_to_video

ref_path, prompt, outdir = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(outdir, exist_ok=True)

MODEL = "Wan-AI/Wan2.2-TI2V-5B-Diffusers"
device = "mps" if torch.backends.mps.is_available() else "cpu"
dtype = torch.float16 if device == "mps" else torch.float32
print(f"device={device} dtype={dtype}")

vae = AutoencoderKLWan.from_pretrained(MODEL, subfolder="vae", torch_dtype=torch.float32)
pipe = WanImageToVideoPipeline.from_pretrained(MODEL, vae=vae, torch_dtype=dtype)
pipe.to(device)

W, H = 704, 480
img = Image.open(ref_path).convert("RGB")
canvas = Image.new("RGB", (W, H), (255, 255, 255))
img.thumbnail((W, H), Image.LANCZOS)
canvas.paste(img, ((W - img.width) // 2, (H - img.height) // 2))

negative = "blurry, distorted, deformed, extra limbs, realistic photo, low quality"
result = pipe(
    image=canvas,
    prompt=prompt,
    negative_prompt=negative,
    height=H, width=W,
    num_frames=49,
    guidance_scale=5.0,
    num_inference_steps=30,
).frames[0]

export_to_video(result, os.path.join(outdir, "clip.mp4"), fps=24)
for i, frame in enumerate(result):
    frame.save(os.path.join(outdir, f"f{i:03d}.png"))
print(f"wrote {len(result)} frames to {outdir}")

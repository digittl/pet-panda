#!/usr/bin/env python3
"""End-to-end LOCAL clip generation: FLUX Kontext keyframes -> app clip.

Loads FLUX.1 Kontext (open 4-bit, on the Apple GPU via mflux) ONCE, then for
each pose prompt edits the reference puppy into that pose. The generated
keyframes are handed to interp_clips.py (cut + align + install) to become a
playable clip — all on-device, no cloud.

Generation is small/fast (512px, few steps); upscale later if wanted.

Usage:
  python generate_clip.py <clip> <reference.png> <prompts.txt> [steps] [size]
  prompts.txt: one pose prompt per line (each line = one keyframe), # comments ok
"""

import os
import subprocess
import sys

from huggingface_hub import snapshot_download
from mflux.models.flux.variants.kontext.flux_kontext import Flux1Kontext
from mflux.models.common.config.model_config import ModelConfig

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = "akx/FLUX.1-Kontext-dev-mflux-4bit"


def main():
    clip = sys.argv[1]
    ref = sys.argv[2]
    prompts_file = sys.argv[3]
    steps = int(sys.argv[4]) if len(sys.argv) > 4 else 8
    size = int(sys.argv[5]) if len(sys.argv) > 5 else 512

    prompts = [ln.strip() for ln in open(prompts_file) if ln.strip() and not ln.startswith("#")]
    print(f"{clip}: {len(prompts)} keyframes @ {size}px / {steps} steps")

    model_path = snapshot_download(REPO)
    flux = Flux1Kontext(quantize=4, model_path=model_path, model_config=ModelConfig.dev_kontext())

    gendir = f"/tmp/gen/{clip}"
    os.makedirs(gendir, exist_ok=True)
    for i, prompt in enumerate(prompts, start=1):
        # Anchor every edit on the SAME reference + seed so the character stays
        # as consistent as possible across the sequence.
        gi = flux.generate_image(
            seed=42,
            prompt=prompt,
            num_inference_steps=steps,
            width=size, height=size,
            image_path=ref,
        )
        out = os.path.join(gendir, f"{clip}_{i:02d}.png")
        try:
            gi.image.save(out)
        except AttributeError:
            gi.save(path=out, export_json_metadata=False)
        print(f"  frame {i}/{len(prompts)}: {prompt[:50]}")

    # Hand the generated keyframes to the existing cut/align/install pipeline.
    env = {**os.environ, "PETPIPE_INTERP": os.environ.get("PETPIPE_INTERP", "raw")}
    subprocess.run([sys.executable, os.path.join(HERE, "interp_clips.py"), clip, gendir], env=env, check=True)
    print(f"installed clip '{clip}' from {len(prompts)} locally-generated keyframes")


if __name__ == "__main__":
    main()

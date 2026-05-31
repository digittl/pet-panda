#!/usr/bin/env bash
#
# Turn generated reference videos into pet sprite-clip frames.
#
# Each source video is one continuous motion (e.g. a sitting pup tilting its
# head). This samples it down to a handful of evenly-spaced frames, wipes the
# "AI generated" watermark and the box border the generator stamps on, scales
# to a uniform size, then runs strip_white to flood-fill the white background to
# transparency — leaving the pet's *interior* white (chest, paws, tail tip)
# intact because the dark outline fences it off from the edges.
#
# The output is dropped straight into the asset catalog as
# <asset>_<clip>_<n>.imageset, which is exactly what PetSpriteView plays.
#
# Usage: extract_video_clips.sh
#   Edit ASSET, VIDEO_DIR, FRAMES and the CLIP_MAP below, then run. Requires
#   ffmpeg on PATH and a Swift toolchain (to compile strip_white.swift).

set -euo pipefail

ASSET="puppy"
# Keep every Nth source frame. STRIDE=1 keeps every frame — the reference videos
# are 24fps/241 frames, so each clip ships all 241 frames and plays back at the
# native rate with no skipping (no interpolation, just the source frames).
STRIDE=1
VIDEO_DIR="$HOME/Downloads/videos_puppy"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS="$HERE/../Assets.xcassets"
WORK="$(mktemp -d)"
STRIP="$WORK/strip_white"

# One video per clip. The video's filename (sans extension) IS the clip name,
# which becomes the asset prefix PetSpriteView looks for — so naming the source
# file `tail_wag.mp4` produces puppy_tail_wag_<n>.imageset. Drop new motions in
# the video dir and they get picked up automatically.
declare -a VIDEOS=(
  "look_around.mp4"
  "head_tilt.mp4"
  "tail_wag.mp4"
  "excited_jumping.mp4"
  "laying_down_waiting.mp4"
)

# Compile the background remover once and reuse the binary per frame — running
# the Swift interpreter per frame would recompile it 125 times.
swiftc "$HERE/strip_white.swift" -o "$STRIP"

# drawbox wipes the bottom-right watermark with white (it sits clear of the pet
# in every frame); crop trims the generator's box border so the flood-fill has a
# clean white edge to seed from.
WATERMARK_WIPE="drawbox=x=560:y=850:w=380:h=85:color=white:t=fill"
BORDER_CROP="crop=900:900:30:30"
FILTER="select='not(mod(n\,${STRIDE}))',${WATERMARK_WIPE},${BORDER_CROP},scale=480:480,setpts=N/TB"

for file in "${VIDEOS[@]}"; do
  clip="${file%.*}"
  echo ">> ${ASSET}_${clip}  <-  ${file}"

  raw_dir="$WORK/$clip"
  mkdir -p "$raw_dir"
  ffmpeg -v error -i "$VIDEO_DIR/$file" \
    -vf "$FILTER" -fps_mode passthrough \
    "$raw_dir/raw_%03d.png"

  n=0
  for raw in "$raw_dir"/raw_*.png; do
    n=$((n + 1))
    png="${ASSET}_${clip}_${n}.png"
    iset="$ASSETS/${ASSET}_${clip}_${n}.imageset"
    mkdir -p "$iset"
    "$STRIP" "$raw" "$iset/$png" 232 >/dev/null 2>&1
    cat > "$iset/Contents.json" <<JSON
{
  "images" : [
    {
      "idiom" : "universal",
      "filename" : "$png"
    }
  ],
  "info" : {
    "version" : 1,
    "author" : "xcode"
  }
}
JSON
  done
  echo "   wrote $n frames"
done

rm -rf "$WORK"
echo "done — ${#VIDEOS[@]} clips installed into $ASSETS"

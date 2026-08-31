#!/usr/bin/env bash
# Re-export the branding masters from the Figma identity file.
# Usage: FIGMA_TOKEN=... tool/fetch_figma_assets.sh
# The token comes from figma.com -> Settings -> Security -> Personal access tokens
# and must never be committed.
set -euo pipefail

: "${FIGMA_TOKEN:?set FIGMA_TOKEN to a Figma personal access token}"
key="yvUlnTR2KqfuHGJXAUhAol"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$repo_root/assets_source/branding"

# node id -> destination file (relative to assets_source/branding)
nodes=(
  "1:3:app-icon-master.svg"
  "1:6:glyph-dhq.svg"
  "1:11:logo-vert.svg"
  "1:17:logo-hor-badge.svg"
  "1:19:wordmark-horizontal.svg"
  "1:27:app-icon-glow.svg"
  "2:3:cover.svg"
  "1:9:mono/logo-short.svg"
  "1:5:mono/logo-short-no-bg.svg"
  "1:7:mono/logo-short-hor-no-bg.svg"
  "1:15:mono/logo-vert.svg"
  "1:13:mono/logo-vert-no-bg.svg"
  "1:21:mono/logo-hor.svg"
)

for entry in "${nodes[@]}"; do
  id="${entry%%:*}"; rest="${entry#*:}"
  id="$id:${rest%%:*}"; dest="${rest#*:}"
  url=$(curl -sf -H "X-Figma-Token: $FIGMA_TOKEN" \
    "https://api.figma.com/v1/images/$key?ids=$id&format=svg" \
    | python3 -c 'import json,sys; print(list(json.load(sys.stdin)["images"].values())[0])')
  mkdir -p "$(dirname "$out/$dest")"
  curl -sf -o "$out/$dest" "$url"
  echo "fetched $dest"
done

# Wordmark exports come out black; the master is the white variant.
python3 - "$out/wordmark-horizontal.svg" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read().replace('fill="black"', 'fill="#FFFFFF"')
open(p, "w").write(s)
EOF

# The 1024 raster master every platform bitmap is downscaled from.
rsvg-convert -w 1024 -h 1024 "$out/app-icon-master.svg" -o "$out/app-icon-master-3d.png"

echo "Masters refreshed. Derived files (app-icon-round/adaptive, banner, trays)"
echo "are hand-derived from these — see assets_source/branding/README.md — then"
echo "run tool/generate_brand_assets.sh."

#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
brand_source="$repo_root/assets_source/branding"
brand_tmp="$(mktemp -d)"
trap 'rm -rf "$brand_tmp"' EXIT

render() {
  local source="$1"
  local width="$2"
  local height="$3"
  local output="$4"
  rsvg-convert --width "$width" --height "$height" --output "$output" "$source"
}

render "$brand_source/app-icon-master.svg" 550 550 "$repo_root/assets/images/icon.png"
render "$brand_source/app-icon-master.svg" 256 256 "$brand_tmp/app-icon-256.png"
sips -s format ico "$brand_tmp/app-icon-256.png" --out "$repo_root/assets/images/icon.ico" >/dev/null
cp "$repo_root/assets/images/icon.ico" "$repo_root/windows/runner/resources/app_icon.ico"

for size in 16 32 64 128 256 512 1024; do
  render "$brand_source/app-icon-master.svg" "$size" "$size" \
    "$repo_root/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_${size}.png"
done

# Future iOS target source (the current Flutter project has no ios/ directory).
mkdir -p "$brand_source/ios"
render "$brand_source/app-icon-master.svg" 1024 1024 "$brand_source/ios/AppIcon-1024.png"

for density_size in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  density="${density_size%%:*}"
  size="${density_size##*:}"
  render "$brand_source/app-icon-master.svg" "$size" "$size" "$brand_tmp/icon-$density.png"
  render "$brand_source/app-icon-round.svg" "$size" "$size" "$brand_tmp/icon-round-$density.png"
  cwebp -quiet -lossless "$brand_tmp/icon-$density.png" \
    -o "$repo_root/android/app/src/main/res/mipmap-$density/ic_launcher.webp"
  cwebp -quiet -lossless "$brand_tmp/icon-round-$density.png" \
    -o "$repo_root/android/app/src/main/res/mipmap-$density/ic_launcher_round.webp"
done

render "$brand_source/android-banner.svg" 320 180 \
  "$repo_root/android/app/src/main/res/mipmap-xhdpi/ic_banner.png"

for state in off proxy tun; do
  case "$state" in
    off) index=1 ;;
    proxy) index=2 ;;
    tun) index=3 ;;
  esac
  render "$brand_source/tray-$state.svg" 108 108 \
    "$repo_root/assets/images/icon/status_$index.png"
  render "$brand_source/tray-$state.svg" 256 256 "$brand_tmp/status-$index.png"
  sips -s format ico "$brand_tmp/status-$index.png" \
    --out "$repo_root/assets/images/icon/status_$index.ico" >/dev/null
done

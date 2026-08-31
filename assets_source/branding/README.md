# DHQ Clash branding

Source of truth: Figma file "DHQ Clash logo" (key `yvUlnTR2KqfuHGJXAUhAol`).
The identity is the lowercase wordmark — extra-bold "dhq" plus light "clash"
(letterforms are outlined vectors, no font needed) — on a rounded square filled
with the radial indigo gradient.

## Palette

- Icon gradient (radial, hotspot near the bottom-left corner):
  `#3737C1` @ 2% → `#130E6D` @ 38% → `#080435` @ 100%
- Accents: violet `#6B44F4`, blue `#4877F4`, cyan `#42DEE9`, lime `#C7FF3D`
- App background stays `#08091F`; text `#F7F8FF`, muted `#AEB5D3`
- Glow (marketing): blurred radial ellipse `#42DEE9` → `#6B44F4`

## Masters

- `app-icon-master.svg` — rounded-square icon (radius 48/200), exported from Figma node `1:3`
- `app-icon-master-3d.png` — 1024² raster of the master; every platform bitmap is downscaled from it
- `app-icon-adaptive.svg` — full-bleed variant with the glyph inside the Android
  adaptive-icon safe zone; source for `dhq_icon_3d.png` and the Play Store icon
- `app-icon-round.svg` — circular variant for Android `ic_launcher_round`
- `app-icon-glow.svg` — icon with the cyan/violet glow (Figma `1:27`), for marketing
- `glyph-dhq.svg` — the bare "dhq" glyph, origin-normalized 150×74
- `wordmark-horizontal.svg` — white "dhq clash" wordmark (Figma `1:19`)
- `logo-hor-badge.svg`, `logo-vert.svg` — wordmark on the gradient badge (Figma `1:17`, `1:11`)
- `mono/` — monochrome logo set from the Figma spec sheet
- `cover.svg` — the gradient cover (Figma `2:3`)
- `android-banner.svg` — 320×180 Android TV banner
- `tray-off.svg`, `tray-proxy.svg`, `tray-tun.svg` — tray states:
  off = muted gray glyph, proxy = accent-gradient glyph, tun = gradient glyph + lime dot
- `ios/AppIcon-1024.png` — staged for a future iOS target

Regenerate every derived asset with `tool/generate_brand_assets.sh`
(requires `rsvg-convert`, `sips`, `cwebp`). Hand-maintained files the script does
NOT touch: `ic_launcher_monochrome.xml`, `ic_launcher_background.xml`,
`ic_launcher-playstore.png`, `android/service/.../ic.xml`, `ic_service.xml`.

To re-export masters from Figma: `GET https://api.figma.com/v1/images/yvUlnTR2KqfuHGJXAUhAol?ids=<node>&format=svg`
with an `X-Figma-Token` header (keep the token in the `FIGMA_TOKEN` env var, never in the repo).

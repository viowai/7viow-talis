#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="$ROOT_DIR/Resources"
ICONSET="$ASSETS/AppIcon.iconset"
source "$ROOT_DIR/scripts/artifact_paths.sh"
ICON_WORK="$(talis_temp_workspace app-icon)"
trap 'rm -rf "$ICON_WORK"' EXIT
# AppIcon.icon owns the selected artwork, native full-bleed background and scale.
# Export every legacy size from that same composition rather than the old inset PNG.
"$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool" \
  "$ASSETS/AppIcon.icon" --export-image --output-file "$ASSETS/AppIconSource.png" \
  --platform macOS --rendition Default --width 1024 --height 1024 --scale 1
mkdir -p "$ICONSET"
for POINTS in 16 32 128 256 512; do
  sips -z "$POINTS" "$POINTS" "$ASSETS/AppIconSource.png" --out "$ICONSET/icon_${POINTS}x${POINTS}.png" >/dev/null
  PIXELS=$((POINTS * 2))
  sips -z "$PIXELS" "$PIXELS" "$ASSETS/AppIconSource.png" --out "$ICONSET/icon_${POINTS}x${POINTS}@2x.png" >/dev/null
done
xcrun actool "$ASSETS/AppIcon.icon" --compile "$ICON_WORK" \
  --platform macosx --minimum-deployment-target 13.0 --app-icon AppIcon \
  --standalone-icon-behavior all --output-partial-info-plist "$ICON_WORK/icon-info.plist" >/dev/null
cp "$ICON_WORK/AppIcon.icns" "$ASSETS/AppIcon.icns"

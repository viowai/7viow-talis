#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="$ROOT_DIR/Resources/Preview"
bash "$ROOT_DIR/scripts/build_app_icon.sh"
mkdir -p "$ASSETS"
cp "$ROOT_DIR/Resources/AppIconSource.png" "$ASSETS/AppIconSource.png"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$ASSETS/AppIcon.icns"
ditto "$ROOT_DIR/Resources/AppIcon.iconset" "$ASSETS/AppIcon.iconset"
echo "Built preview icon: $ASSETS/AppIcon.icns"

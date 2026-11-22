#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/artifact_paths.sh"
CACHE_DIR="$(talis_build_cache)"
OUTPUT_DIR="${1:-$CACHE_DIR/packages}"
bash "$ROOT_DIR/scripts/build_desktop_app.sh"
APP="$CACHE_DIR/desktop/Talis.app"
mkdir -p "$OUTPUT_DIR"
STAGE="$(talis_temp_workspace dmg)"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/Talis.app"
ln -s /Applications "$STAGE/Applications"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$STAGE/Talis-local.zip"
unzip -tq "$STAGE/Talis-local.zip"
mv "$STAGE/Talis-local.zip" "$OUTPUT_DIR/Talis-local.zip"
hdiutil create -ov -format UDZO -volname Talis -srcfolder "$STAGE" "$OUTPUT_DIR/Talis-local.dmg" >/dev/null
/usr/bin/unzip -tq "$OUTPUT_DIR/Talis-local.zip"
echo "Local-only packages: $OUTPUT_DIR"
echo "本地临时签名，未取得 Developer ID 签名或 Apple 公证。"

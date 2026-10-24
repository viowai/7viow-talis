#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CACHE_DIR="${TALIS_BUILD_CACHE_DIR:-$HOME/Library/Caches/Talis/Build}"
OUTPUT_DIR="${1:-$CACHE_DIR/packages}"
bash "$ROOT_DIR/scripts/build_desktop_app.sh"
APP="$CACHE_DIR/desktop/Talis.app"
mkdir -p "$OUTPUT_DIR"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/talis-dmg.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/Talis.app"
ln -s /Applications "$STAGE/Applications"
(cd "$CACHE_DIR/desktop" && /usr/bin/zip -qry -X "$OUTPUT_DIR/Talis-local.zip" Talis.app)
hdiutil create -ov -format UDZO -volname Talis -srcfolder "$STAGE" "$OUTPUT_DIR/Talis-local.dmg" >/dev/null
/usr/bin/unzip -tq "$OUTPUT_DIR/Talis-local.zip"
echo "Local-only packages: $OUTPUT_DIR"
echo "本地临时签名，未取得 Developer ID 签名或 Apple 公证。"

#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
bash "$ROOT_DIR/scripts/check_environment.sh"
CACHE_DIR="${TALIS_BUILD_CACHE_DIR:-$HOME/Library/Caches/Talis/Build}"
OUTPUT_DIR="${1:-$CACHE_DIR/desktop}"
APP_DIR="$OUTPUT_DIR/Talis.app"
cd "$ROOT_DIR"
swift build -c release --disable-sandbox --scratch-path "$CACHE_DIR/swift"
BIN_DIR="$(swift build -c release --disable-sandbox --scratch-path "$CACHE_DIR/swift" --show-bin-path)"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/PromptLibraryMac" "$APP_DIR/Contents/MacOS/PromptLibraryMac"
strip -S -x "$APP_DIR/Contents/MacOS/PromptLibraryMac"
if /usr/bin/strings "$APP_DIR/Contents/MacOS/PromptLibraryMac" | /usr/bin/grep -F -e "$HOME/" -e "$ROOT_DIR/" >/dev/null; then
  echo "构建产物仍含本机源路径，停止打包。" >&2
  exit 1
fi
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
cp Resources/AppIcon.icns Resources/StatusBarIcon.png "$APP_DIR/Contents/Resources/"
ditto Resources/Fonts "$APP_DIR/Contents/Resources/Fonts"
cp LICENSE NOTICE THIRD-PARTY-NOTICES.md "$APP_DIR/Contents/Resources/"
chmod +x "$APP_DIR/Contents/MacOS/PromptLibraryMac"
xattr -cr "$APP_DIR"
codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
echo "Built: $APP_DIR"

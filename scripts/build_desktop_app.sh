#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
bash "$ROOT_DIR/scripts/check_environment.sh"
source "$ROOT_DIR/scripts/artifact_paths.sh"
CACHE_DIR="$(talis_build_cache)"
OUTPUT_DIR="$(talis_noindex_dir "${1:-$CACHE_DIR/desktop}")"
APP_DIR="$OUTPUT_DIR/Talis.app"
MACOS_SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
MACOS_SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"
cd "$ROOT_DIR"
swift build -c release --disable-sandbox --build-system native --sdk "$MACOS_SDK_PATH" --scratch-path "$CACHE_DIR/swift"
BIN_DIR="$(swift build -c release --disable-sandbox --build-system native --sdk "$MACOS_SDK_PATH" --scratch-path "$CACHE_DIR/swift" --show-bin-path)"
bash "$ROOT_DIR/scripts/check_macos_sdk.sh" "$BIN_DIR/PromptLibraryMac" "$MACOS_SDK_VERSION"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/PromptLibraryMac" "$APP_DIR/Contents/MacOS/PromptLibraryMac"
strip -S -x "$APP_DIR/Contents/MacOS/PromptLibraryMac"
if /usr/bin/strings "$APP_DIR/Contents/MacOS/PromptLibraryMac" | /usr/bin/grep -F -e "$HOME/" -e "$ROOT_DIR/" >/dev/null; then
  echo "构建产物仍含本机源路径，停止打包。" >&2
  exit 1
fi
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
bash scripts/build_brand_assets.sh "$APP_DIR/Contents/Resources"
bash scripts/build_mode_icons.sh "$APP_DIR/Contents/Resources"
ditto Resources/Fonts "$APP_DIR/Contents/Resources/Fonts"
ditto Resources/en.lproj "$APP_DIR/Contents/Resources/en.lproj"
cp LICENSE NOTICE THIRD-PARTY-NOTICES.md "$APP_DIR/Contents/Resources/"
chmod +x "$APP_DIR/Contents/MacOS/PromptLibraryMac"
xattr -cr "$APP_DIR"
codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
echo "Built: $APP_DIR"

#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/artifact_paths.sh"
CACHE_DIR="$(talis_build_cache)"
PREVIEW_DIR="$CACHE_DIR/v1-preview"
APP_DIR="$PREVIEW_DIR/Talis.app"

# Reuse current-SDK compilation, stripping and resource packaging. This base
# stays in the cache; the production installation is never replaced here.
bash "$ROOT_DIR/scripts/build_desktop_app.sh" "$CACHE_DIR/v1-preview-base"
mkdir -p "$PREVIEW_DIR"
rm -rf "$APP_DIR"
ditto "$CACHE_DIR/v1-preview-base/Talis.app" "$APP_DIR"
python3 - "$APP_DIR/Contents/Info.plist" <<'PYINFO'
import plistlib,sys
p=sys.argv[1]
with open(p,'rb') as f: info=plistlib.load(f)
info.update(CFBundleIdentifier='local.prompt-library.overlay.v1-preview',
            CFBundleName='Talis',CFBundleDisplayName='Talis',
            TalisReleaseChannel='v1-preview')
with open(p,'wb') as f: plistlib.dump(info,f)
PYINFO
# Use the selected violet lacquer icon packaged by build_desktop_app.
xattr -cr "$APP_DIR"
codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
echo "Built local preview: $APP_DIR"

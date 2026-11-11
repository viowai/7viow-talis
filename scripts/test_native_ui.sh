#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/artifact_paths.sh"
TEST_DIR="$(talis_temp_workspace native-ui)"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc -emit-library -emit-module -module-name TalisCore \
  "$ROOT_DIR"/Sources/TalisCore/*.swift \
  -Xlinker -install_name -Xlinker @rpath/libTalisCore.dylib \
  -emit-module-path "$TEST_DIR/TalisCore.swiftmodule" -o "$TEST_DIR/libTalisCore.dylib"
python3 - "$ROOT_DIR/Sources/PromptLibraryMac/main.swift" "$TEST_DIR/UIViews.swift" <<'PY'
from pathlib import Path
import sys
source=Path(sys.argv[1]).read_text()
Path(sys.argv[2]).write_text(source[:source.index('final class AppDelegate:')])
PY
UI_SOURCES=()
for SOURCE in "$ROOT_DIR"/Sources/PromptLibraryMac/*.swift; do
  if [[ "$(basename "$SOURCE")" != "main.swift" ]]; then UI_SOURCES+=("$SOURCE"); fi
done
swiftc -O -g -I "$TEST_DIR" -L "$TEST_DIR" -lTalisCore -Xlinker -rpath -Xlinker "$TEST_DIR" \
  "${UI_SOURCES[@]}" "$TEST_DIR/UIViews.swift" "$ROOT_DIR/scripts/ui-tests/main.swift" \
  -debug-prefix-map "$ROOT_DIR=." -o "$TEST_DIR/ui-tests"
if [[ "${1:-}" == "--review" ]]; then
  REVIEW_APP="$(talis_build_cache)/ui-review/Talis UI Review.app"
  mkdir -p "$REVIEW_APP/Contents/MacOS" "$REVIEW_APP/Contents/Resources"
  bash "$ROOT_DIR/scripts/build_mode_icons.sh" "$REVIEW_APP/Contents/Resources"
  cp "$TEST_DIR/ui-tests" "$REVIEW_APP/Contents/MacOS/ui-tests"
  cp "$TEST_DIR/libTalisCore.dylib" "$REVIEW_APP/Contents/MacOS/"
  install_name_tool -add_rpath @executable_path "$REVIEW_APP/Contents/MacOS/ui-tests"
  python3 - "$REVIEW_APP/Contents/Info.plist" <<'PYINFO'
import plistlib,sys
with open(sys.argv[1],"wb") as f:
    plistlib.dump(dict(CFBundleIdentifier="local.prompt-library.overlay.preview",CFBundleName="Talis UI Review",CFBundleExecutable="ui-tests",CFBundlePackageType="APPL",NSAccentColorName="AccentColor",TalisUIReview=True,LSUIElement=True),f)
PYINFO
  bash "$ROOT_DIR/scripts/build_brand_assets.sh" "$REVIEW_APP/Contents/Resources"
  ditto "$ROOT_DIR/Resources/en.lproj" "$REVIEW_APP/Contents/Resources/en.lproj"
  xattr -cr "$REVIEW_APP"
  codesign --force --deep --sign - "$REVIEW_APP"
  echo "Built isolated fictional-HTTP review: $REVIEW_APP"
else
  TEST_APP="$TEST_DIR/Talis UI Tests.app"
  mkdir -p "$TEST_APP/Contents/MacOS"
  mkdir -p "$TEST_APP/Contents/Resources"
  cp "$TEST_DIR/ui-tests" "$TEST_APP/Contents/MacOS/ui-tests"
  python3 - "$TEST_APP/Contents/Info.plist" <<'PYINFO'
import plistlib,sys
with open(sys.argv[1],"wb") as f:
    plistlib.dump(dict(CFBundleIdentifier="local.prompt-library.overlay.preview",CFBundleName="Talis UI Tests",CFBundleExecutable="ui-tests",CFBundlePackageType="APPL",LSUIElement=True),f)
PYINFO
  bash "$ROOT_DIR/scripts/build_brand_assets.sh" "$TEST_APP/Contents/Resources"
  ditto "$ROOT_DIR/Resources/en.lproj" "$TEST_APP/Contents/Resources/en.lproj"
  "$TEST_APP/Contents/MacOS/ui-tests"
fi

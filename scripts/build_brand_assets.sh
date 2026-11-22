#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${1:?Pass the bundle resource directory}"
source "$ROOT_DIR/scripts/artifact_paths.sh"
ASSET_DIR="$(talis_temp_workspace brand-assets)"
trap 'rm -rf "$ASSET_DIR"' EXIT
for name in refine regenerate clarify; do
  qlmanage -t -s 96 -o "$ROOT_DIR/Resources/Brand.xcassets/$name.imageset" "$ROOT_DIR/Resources/Icons/$name.svg" >/dev/null
  mv "$ROOT_DIR/Resources/Brand.xcassets/$name.imageset/$name.svg.png" "$ROOT_DIR/Resources/Brand.xcassets/$name.imageset/$name.png"
done
xcrun actool "$ROOT_DIR/Resources/Brand.xcassets" "$ROOT_DIR/Resources/AppIcon.icon" --compile "$ASSET_DIR" \
  --platform macosx --minimum-deployment-target 13.0 --accent-color AccentColor \
  --app-icon AppIcon --standalone-icon-behavior all \
  --output-partial-info-plist "$ASSET_DIR/asset-info.plist" >/dev/null
mkdir -p "$OUTPUT_DIR"
cp "$ASSET_DIR/Assets.car" "$OUTPUT_DIR/Assets.car"
cp "$ASSET_DIR/AppIcon.icns" "$OUTPUT_DIR/AppIcon.icns"
python3 - "$OUTPUT_DIR/../Info.plist" "$ASSET_DIR/asset-info.plist" <<'PYINFO'
import plistlib, sys
from pathlib import Path
path = Path(sys.argv[1])
info = plistlib.loads(path.read_bytes())
info.update(plistlib.loads(Path(sys.argv[2]).read_bytes()))
path.write_bytes(plistlib.dumps(info))
PYINFO

#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/artifact_paths.sh"
CACHE_DIR="$(talis_build_cache)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$CACHE_DIR/desktop/Talis.app"
ZIP_PATH="$DIST_DIR/Talis.zip"
bash "$ROOT_DIR/scripts/build_desktop_app.sh"
mkdir -p "$DIST_DIR"
# Remove only the obsolete generated shortcut. Never export a traversable App.
if [[ -L "$DIST_DIR/Talis.app" ]]; then
  rm "$DIST_DIR/Talis.app"
elif [[ -e "$DIST_DIR/Talis.app" ]]; then
  echo "dist/Talis.app 是历史目录，请先通过 archive_backups.py 归档，再打包。" >&2
  exit 1
fi
archive_stage="$(talis_temp_workspace export)"
trap 'rm -rf "$archive_stage"' EXIT
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$archive_stage/Talis.zip"
unzip -tq "$archive_stage/Talis.zip"
mv "$archive_stage/Talis.zip" "$ZIP_PATH"
echo "Built: $APP_DIR"
echo "Portable archive: $ZIP_PATH"

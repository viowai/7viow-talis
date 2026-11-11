#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/artifact_paths.sh"
CACHE_DIR="$(talis_build_cache)"
TARGET_APP="/Applications/Talis.app"
if pgrep -f '^/Applications/Talis\.app/Contents/MacOS/PromptLibraryMac( |$)' >/dev/null; then
  echo "请先保留正在编辑的内容并退出 Talis，再更新试用版。" >&2
  exit 1
fi
bash "$ROOT_DIR/scripts/build_preview_app.sh"
source "$ROOT_DIR/scripts/install_bundle.sh"
install_bundle "$CACHE_DIR/v1-preview/Talis.app" "$TARGET_APP" "$HOME/Library/Application Support/Talis v1 Preview/Backups"
echo "本机试用版：$TARGET_APP"
echo "快捷键：Option+Shift+Space。"

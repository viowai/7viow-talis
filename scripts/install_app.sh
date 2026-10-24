#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-install}"
if [[ $# -gt 1 || ( "$MODE" != install && "$MODE" != --check && "$MODE" != --help ) ]]; then
  echo "用法：bash scripts/install_app.sh [--check | --help]" >&2
  exit 2
fi
if [[ "$MODE" == --help ]]; then
  echo "bash scripts/install_app.sh          构建并安装到 /Applications/Talis.app"
  echo "bash scripts/install_app.sh --check  只检查安装条件，不构建、不替换 App"
  exit 0
fi
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CACHE_DIR="${TALIS_BUILD_CACHE_DIR:-$HOME/Library/Caches/Talis/Build}"
TARGET_APP="/Applications/Talis.app"
bash "$ROOT_DIR/scripts/check_environment.sh"
if [[ ! -w /Applications ]]; then
  echo "当前用户不能写入 /Applications。请在 Finder 中移动构建好的 Talis.app，并完成系统管理员确认。" >&2
  exit 1
fi
if pgrep -f '^/Applications/Talis.app/Contents/MacOS/PromptLibraryMac$' >/dev/null; then
  echo "请先退出 Talis，保留需要的编辑内容后再安装。" >&2
  exit 1
fi
if [[ "$MODE" == --check ]]; then
  echo "安装条件通过。运行 bash scripts/install_app.sh 后可安装；本次没有修改 App 或用户数据。"
  exit 0
fi
bash "$ROOT_DIR/scripts/build_desktop_app.sh"
SOURCE_APP="$CACHE_DIR/desktop/Talis.app"
source "$ROOT_DIR/scripts/install_bundle.sh"
install_bundle "$SOURCE_APP" "$TARGET_APP" "$HOME/Library/Application Support/Talis/Backups"
echo "数据位于 ~/Library/Application Support/Talis；密钥由 macOS Keychain 管理。"

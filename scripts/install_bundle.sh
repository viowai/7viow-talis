#!/usr/bin/env bash
# Shared by the desktop installer and isolated installation tests.
install_bundle() (
  set -euo pipefail
  source_app="$1" target_app="$2" backup_root="$3"
  backup_dir="" old_moved=0 new_moved=0 committed=0
  stage_dir="$(mktemp -d "$(dirname "$target_app")/.talis-install.XXXXXX")" || exit $?

  cleanup() {
    local status=$?
    trap - EXIT INT TERM
    set +e
    if (( ! committed )); then
      if (( new_moved )); then rm -rf "$target_app"; fi
      if (( old_moved )); then
        if mv "$backup_dir/Talis.app" "$target_app"; then
          echo "安装未完成，已恢复原 Talis.app。" >&2
        else
          echo "恢复原 App 未成功。原 App 保留在：$backup_dir/Talis.app" >&2
        fi
      fi
      if [[ -n "$backup_dir" ]]; then rmdir "$backup_dir" 2>/dev/null; fi
    fi
    rm -rf "$stage_dir"
    exit "$status"
  }
  trap cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  # Copy and verify completely before moving the user's current App.
  ditto "$source_app" "$stage_dir/Talis.app" || exit $?
  codesign --verify --deep --strict "$stage_dir/Talis.app" || exit $?
  if [[ -e "$target_app" ]]; then
    mkdir -p "$backup_root" || exit $?
    backup_dir="$(mktemp -d "$backup_root/$(date +%Y%m%d-%H%M%S).XXXXXX")" || exit $?
    mv "$target_app" "$backup_dir/Talis.app" || exit $?
    old_moved=1
  fi
  mv "$stage_dir/Talis.app" "$target_app" || exit $?
  new_moved=1
  codesign --verify --deep --strict "$target_app" || exit $?
  committed=1
  echo "Installed: $target_app"
  if [[ -n "$backup_dir" ]]; then echo "原 App 备份：$backup_dir/Talis.app"; fi
)

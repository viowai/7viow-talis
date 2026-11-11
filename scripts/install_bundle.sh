#!/usr/bin/env bash
# Shared by the desktop installer and isolated installation tests.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/archive_bundle.sh"
install_bundle() (
  set -euo pipefail
  source_app="$1" target_app="$2" backup_root="$3"
  backup_dir="" old_moved=0 new_moved=0 committed=0
  stage_root="$(dirname "$target_app")/.talis-install.noindex"
  mkdir -p "$stage_root"
  stage_dir="$(mktemp -d "$stage_root/transaction.XXXXXX")" || exit $?

  cleanup() {
    local exit_status=$?
    trap - EXIT INT TERM
    set +e
    if (( ! committed )); then
      if (( new_moved )); then rm -rf "$target_app"; fi
      if (( old_moved )); then
        if [[ ! -e "$target_app" ]] && mv "$stage_dir/PreviousBundle" "$target_app"; then
          old_moved=0
          echo "安装未完成，已恢复原 Talis.app。" >&2
        else
          echo "恢复原 App 未成功。原包保留在：$stage_dir/PreviousBundle" >&2
          echo "已验证压缩备份：$backup_dir/AppBundle.zip" >&2
        fi
      fi
      if [[ -n "$backup_dir" ]]; then rmdir "$backup_dir" 2>/dev/null; fi
    fi
    if (( committed || ! old_moved )); then rm -rf "$stage_dir"; fi
    rmdir "$stage_root" 2>/dev/null
    exit "$exit_status"
  }
  trap cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  # Copy and verify completely before moving the user's current App.
  ditto "$source_app" "$stage_dir/Payload" || exit $?
  # Finder can add resource-fork metadata after a build was signed. Remove it
  # from the staging copy, as the builder does, before verifying the signature.
  xattr -cr "$stage_dir/Payload" || exit $?
  codesign --verify --deep --strict "$stage_dir/Payload" || exit $?
  if [[ -e "$target_app" ]]; then
    mkdir -p "$backup_root/Archives.noindex" || exit $?
    backup_dir="$(mktemp -d "$backup_root/Archives.noindex/$(date +%Y%m%d-%H%M%S).XXXXXX")" || exit $?
    # Commit a verified recovery archive BEFORE moving the installed App.
    archive_bundle "$target_app" "$backup_dir/AppBundle.zip" || exit $?
    mv "$target_app" "$stage_dir/PreviousBundle" || exit $?
    old_moved=1
  fi
  mv "$stage_dir/Payload" "$target_app" || exit $?
  new_moved=1
  codesign --verify --deep --strict "$target_app" || exit $?
  committed=1
  echo "Installed: $target_app"
  if [[ -n "$backup_dir" ]]; then echo "原 App 备份：$backup_dir/AppBundle.zip"; fi
)

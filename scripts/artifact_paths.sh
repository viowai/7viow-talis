#!/usr/bin/env bash
# All traversable build bundles live below a Spotlight-excluded component.
talis_noindex_dir() {
  local path
  path="$(python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$1")" || return $?
  case "$path/" in
    *.noindex/*) printf '%s\n' "$path" ;;
    *) printf '%s/TalisWork.noindex\n' "${path%/}" ;;
  esac
}

talis_build_cache() {
  talis_noindex_dir "${TALIS_BUILD_CACHE_DIR:-$HOME/Library/Caches/Talis/Build.noindex}"
}

talis_temp_workspace() {
  local parent
  parent="$(talis_noindex_dir "${TMPDIR:-/tmp}/Talis")" || return $?
  mkdir -p "$parent" || return $?
  mktemp -d "$parent/$1.XXXXXX"
}

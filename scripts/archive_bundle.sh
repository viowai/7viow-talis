#!/usr/bin/env bash
# ZIP contents can be restored with: ditto -x -k AppBundle.zip <staged-bundle>
archive_bundle() (
  set -euo pipefail
  source_bundle="$1" archive_path="$2"
  mkdir -p "$(dirname "$archive_path")" || exit $?
  archive_stage="$(mktemp -d "$(dirname "$archive_path")/.archive.XXXXXX")" || exit $?
  trap 'rm -rf "$archive_stage"' EXIT
  # No --keepParent: backups contain Contents/, never a traversable .app.
  ditto -c -k --rsrc --extattr --acl --sequesterRsrc "$source_bundle" "$archive_stage/AppBundle.zip" || exit $?
  unzip -tq "$archive_stage/AppBundle.zip" || exit $?
  mv "$archive_stage/AppBundle.zip" "$archive_path" || exit $?
)

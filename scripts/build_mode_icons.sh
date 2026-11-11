#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${1:?Pass the bundle resource directory}"
mkdir -p "$OUTPUT_DIR/Icons"
for name in refine regenerate clarify; do
  qlmanage -t -s 96 -o "$OUTPUT_DIR/Icons" "$ROOT_DIR/Resources/Icons/$name.svg" >/dev/null
  mv "$OUTPUT_DIR/Icons/$name.svg.png" "$OUTPUT_DIR/Icons/$name.png"
done
cp "$ROOT_DIR/Resources/Icons/PHOSPHOR-LICENSE.txt" "$OUTPUT_DIR/Icons/"

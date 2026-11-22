#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/artifact_paths.sh"
TEST_DIR="$(talis_temp_workspace template-storage)"
trap 'rm -rf "$TEST_DIR"' EXIT
python3 - "$ROOT_DIR/Sources/PromptLibraryMac/main.swift" "$TEST_DIR/ModelTypes.swift" <<'PY'
from pathlib import Path
import sys
source=Path(sys.argv[1]).read_text()
Path(sys.argv[2]).write_text(source[:source.index('enum PromptStore {')].replace('import TalisCore\n',''))
PY
swiftc "$TEST_DIR/ModelTypes.swift" \
 "$ROOT_DIR/Sources/PromptLibraryMac/AppLocalization.swift" \
 "$ROOT_DIR/Sources/PromptLibraryMac/UserTemplateStore.swift" \
 "$ROOT_DIR/Sources/PromptLibraryMac/SystemTemplateOverrideStore.swift" \
 "$ROOT_DIR/scripts/template-storage-tests/main.swift" -o "$TEST_DIR/storage-tests"
"$TEST_DIR/storage-tests"

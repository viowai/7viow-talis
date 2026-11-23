#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/talis-network.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc -emit-library -emit-module -module-name TalisCore \
  "$ROOT_DIR"/Sources/TalisCore/*.swift \
  -emit-module-path "$TEST_DIR/TalisCore.swiftmodule" -o "$TEST_DIR/libTalisCore.dylib"
swiftc -I "$TEST_DIR" -L "$TEST_DIR" -lTalisCore -Xlinker -rpath -Xlinker "$TEST_DIR" \
  "$ROOT_DIR/Sources/Talis/AppIdentity.swift" \
  "$ROOT_DIR/Sources/Talis/AIProvider.swift" \
  "$ROOT_DIR/Sources/Talis/LocalSubscriptionCatalog.swift" \
  "$ROOT_DIR/Sources/Talis/AppLocalization.swift" \
  "$ROOT_DIR/Sources/Talis/ModelResolver.swift" \
  "$ROOT_DIR/Sources/Talis/OpenAIClient.swift" \
  "$ROOT_DIR/scripts/network-tests/main.swift" -o "$TEST_DIR/network-tests"
"$TEST_DIR/network-tests"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/talis-clarification-tests.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT

swiftc \
  "$ROOT_DIR"/Sources/TalisCore/*.swift \
  "$ROOT_DIR/scripts/clarification-tests/main.swift" \
  -o "$TEST_DIR/test_clarification_logic"

"$TEST_DIR/test_clarification_logic"

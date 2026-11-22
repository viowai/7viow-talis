#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/talis-history-layout.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc "$ROOT_DIR/Sources/PromptLibraryMac/HistoryTextLayout.swift" "$ROOT_DIR/scripts/history-layout-tests/main.swift" -o "$TEST_DIR/history-layout-tests"
"$TEST_DIR/history-layout-tests"

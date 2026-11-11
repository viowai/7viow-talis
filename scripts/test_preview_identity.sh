#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/talis-identity.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc "$ROOT_DIR/Sources/PromptLibraryMac/AppIdentity.swift" "$ROOT_DIR/scripts/identity-tests/main.swift" -o "$TEST_DIR/identity-tests"
"$TEST_DIR/identity-tests"

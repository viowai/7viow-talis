#!/usr/bin/env bash
set -euo pipefail

# linked-on-or-after behavior determines the AppKit design used at runtime.
# A deployment target of 13.0 must not also become the linked SDK version.
BINARY_PATH="$1"
EXPECTED_SDK_VERSION="$2"
LINKED_SDK_VERSION="$(xcrun vtool -show-build "$BINARY_PATH" | awk '$1 == "sdk" { print $2; exit }')"
if [[ "$LINKED_SDK_VERSION" != "$EXPECTED_SDK_VERSION" ]]; then
  echo "构建产物的 SDK 为 ${LINKED_SDK_VERSION}，当前 SDK 为 ${EXPECTED_SDK_VERSION}；停止打包以避免旧版界面兼容模式。" >&2
  exit 1
fi
echo "Linked macOS SDK: $LINKED_SDK_VERSION"

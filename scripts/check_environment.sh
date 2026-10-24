#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != Darwin ]]; then
  echo "Talis 需要在要安装它的 Mac 上构建；Windows、Linux 和云端容器不能安装本机 macOS App。" >&2
  exit 1
fi
MACOS_VERSION="$(sw_vers -productVersion)"
if (( ${MACOS_VERSION%%.*} < 13 )); then
  echo "需要 macOS 13 或更新版本；当前版本：${MACOS_VERSION}。" >&2
  exit 1
fi
if ! xcode-select -p >/dev/null 2>&1; then
  echo "缺少 Apple 开发工具。请运行 xcode-select --install，在系统窗口完成安装，再重试。" >&2
  exit 1
fi
if ! command -v swift >/dev/null || ! SWIFT_VERSION="$(swift --version 2>/dev/null)"; then
  echo "Swift 工具链不可用。请完成 Xcode 或 Command Line Tools 安装后重试。" >&2
  exit 1
fi
if [[ "$SWIFT_VERSION" =~ Swift\ version\ ([0-9]+)\.([0-9]+) ]]; then
  if (( BASH_REMATCH[1] < 5 || (BASH_REMATCH[1] == 5 && BASH_REMATCH[2] < 9) )); then
    echo "需要 Swift 5.9 或更新版本，请更新 Apple 开发工具。" >&2
    exit 1
  fi
else
  echo "无法识别 Swift 版本，请检查 swift --version。" >&2
  exit 1
fi
if ! SDK_PATH="$(xcrun --sdk macosx --show-sdk-path 2>/dev/null)" || [[ ! -d "$SDK_PATH" ]]; then
  echo "macOS SDK 不可用。请检查 Xcode / Command Line Tools 的安装和选择。" >&2
  exit 1
fi
for tool in codesign ditto strip xattr; do
  if ! command -v "$tool" >/dev/null; then
    echo "缺少构建工具：${tool}。请检查 Apple 开发工具安装。" >&2
    exit 1
  fi
done
ARCH="$(uname -m)"
echo "构建环境可用：macOS ${MACOS_VERSION} / ${ARCH}。"
if [[ "$ARCH" != arm64 ]]; then
  echo "注意：当前仅 Apple Silicon 构建完成验证；此架构的构建与运行尚未验证。"
fi

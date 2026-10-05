#!/bin/bash
# 导出三平台 release 包到 builds/。
# 前置：Godot 4.7 + 导出模板（~/Library/Application Support/Godot/export_templates）。
# 用法: bash tools/export.sh [macos|windows|linux|all]   （默认 all）
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$HOME/godot47/Godot.app/Contents/MacOS/Godot}"
mkdir -p builds

export_one() {
  case "$1" in
    macos)
      "$GODOT" --headless --path game --export-release "macOS" ../builds/escape-mono-macos.zip
      ;;
    windows)
      "$GODOT" --headless --path game --export-release "Windows Desktop" ../builds/escape-mono-windows.exe
      ;;
    linux)
      "$GODOT" --headless --path game --export-release "Linux" ../builds/escape-mono-linux.x86_64
      ;;
  esac
}

target="${1:-all}"
if [[ "$target" == "all" ]]; then
  export_one macos && export_one windows && export_one linux
else
  export_one "$target"
fi

# 打包为可分发 zip（macOS 导出即 zip，直接纳入 release/）
mkdir -p builds/release
cp builds/escape-mono-macos.zip builds/release/
(cd builds && rm -f release/escape-mono-windows.zip && zip -q release/escape-mono-windows.zip escape-mono-windows.exe escape-mono-windows.pck)
(cd builds && rm -f release/escape-mono-linux.zip && zip -q release/escape-mono-linux.zip escape-mono-linux.x86_64)
ls -lh builds/release/

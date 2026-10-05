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
  BUILT=(macos windows linux)
else
  BUILT=("$target")
fi
for t in "${BUILT[@]}"; do
  export_one "$t"
done

# 只打包本次实际导出的平台（BUG_0001：单平台导出不再依赖/混入旧产物）
mkdir -p builds/release
for t in "${BUILT[@]}"; do
  case "$t" in
    macos)
      cp builds/escape-mono-macos.zip builds/release/
      ;;
    windows)
      (cd builds && rm -f release/escape-mono-windows.zip && zip -q release/escape-mono-windows.zip escape-mono-windows.exe escape-mono-windows.pck)
      ;;
    linux)
      (cd builds && rm -f release/escape-mono-linux.zip && zip -q release/escape-mono-linux.zip escape-mono-linux.x86_64)
      ;;
  esac
done
ls -lh builds/release/

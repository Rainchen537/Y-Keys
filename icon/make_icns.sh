#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="${ICON_OUTPUT_DIR:-$ROOT_DIR}"
PNG_1024="$OUTPUT_DIR/icon_1024.png"
ICNS_OUTPUT="$OUTPUT_DIR/AppIcon.icns"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/y-keys-icon.XXXXXX")"
ICONSET="$WORK_DIR/AppIcon.iconset"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$OUTPUT_DIR" "$ICONSET"
xcrun swift "$ROOT_DIR/IconGen.swift" "$PNG_1024"

sips -z 16 16     "$PNG_1024" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32     "$PNG_1024" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32     "$PNG_1024" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64     "$PNG_1024" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128   "$PNG_1024" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256   "$PNG_1024" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$PNG_1024" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512   "$PNG_1024" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$PNG_1024" --out "$ICONSET/icon_512x512.png" >/dev/null
cp "$PNG_1024" "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o "$ICNS_OUTPUT"

# 仅显式生成仓库永久图标时同步 README 资源；build.sh 的临时输出不改仓库资产。
if [[ -z "${ICON_OUTPUT_DIR:-}" ]]; then
  sips -z 256 256 "$PNG_1024" --out "$ROOT_DIR/../docs/icon-256.png" >/dev/null
fi

echo "已生成 $ICNS_OUTPUT"

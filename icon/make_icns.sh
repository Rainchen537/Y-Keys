#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PNG_1024="$ROOT_DIR/icon_1024.png"
ICONSET="$ROOT_DIR/AppIcon.iconset"

xcrun swift "$ROOT_DIR/IconGen.swift" "$PNG_1024"

rm -rf "$ICONSET"
mkdir -p "$ICONSET"

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

iconutil -c icns "$ICONSET" -o "$ROOT_DIR/AppIcon.icns"
sips -z 256 256 "$PNG_1024" --out "$ROOT_DIR/../docs/icon-256.png" >/dev/null

rm -rf "$ICONSET"
echo "已生成 $ROOT_DIR/AppIcon.icns"

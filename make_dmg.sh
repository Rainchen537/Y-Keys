#!/bin/zsh
set -euo pipefail

APP_NAME="Y-Keys"
VOL_NAME="Y-Keys"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="$ROOT_DIR/build/$APP_NAME.app"
BG_SRC="$ROOT_DIR/icon/dmg_bg.png"
DIST_DIR="$ROOT_DIR/dist"
DMG_FINAL="$DIST_DIR/$VOL_NAME.dmg"
DMG_TMP="$DIST_DIR/.tmp_$VOL_NAME.dmg"
STAGE_DIR="$DIST_DIR/.stage"
WINDOW_LEFT=200
WINDOW_TOP=150
WINDOW_WIDTH=640
WINDOW_HEIGHT=400
WINDOW_RIGHT=$((WINDOW_LEFT + WINDOW_WIDTH))
WINDOW_BOTTOM=$((WINDOW_TOP + WINDOW_HEIGHT))

if [[ ! -d "$APP_PATH" ]]; then
  "$ROOT_DIR/build.sh"
fi

if [[ ! -f "$BG_SRC" ]]; then
  xcrun swift "$ROOT_DIR/icon/DmgBgGen.swift" "$BG_SRC"
else
  BG_WIDTH="$(sips -g pixelWidth "$BG_SRC" 2>/dev/null | awk '/pixelWidth/ { print $2; exit }')"
  BG_HEIGHT="$(sips -g pixelHeight "$BG_SRC" 2>/dev/null | awk '/pixelHeight/ { print $2; exit }')"
  if [[ "$BG_WIDTH" != "$WINDOW_WIDTH" || "$BG_HEIGHT" != "$WINDOW_HEIGHT" ]]; then
    xcrun swift "$ROOT_DIR/icon/DmgBgGen.swift" "$BG_SRC"
  fi
fi

rm -rf "$DIST_DIR"
mkdir -p "$STAGE_DIR"

ditto --noextattr --noqtn "$APP_PATH" "$STAGE_DIR/$APP_NAME.app"
ln -s /Applications "$STAGE_DIR/Applications"
mkdir -p "$STAGE_DIR/.background"
cp "$BG_SRC" "$STAGE_DIR/.background/bg.png"

hdiutil create \
  -srcfolder "$STAGE_DIR" \
  -volname "$VOL_NAME" \
  -fs HFS+ \
  -format UDRW \
  -ov \
  "$DMG_TMP" >/dev/null

MOUNT_DIR="/Volumes/$VOL_NAME"
hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
hdiutil attach "$DMG_TMP" -readwrite -noverify -noautoopen >/dev/null
sleep 2

osascript <<EOF || echo "（提示：Finder 布局设置被跳过，DMG 仍可正常使用）"
set bgFile to POSIX file "$MOUNT_DIR/.background/bg.png" as alias
tell application "Finder"
  tell disk "$VOL_NAME"
    open
    delay 1
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {$WINDOW_LEFT, $WINDOW_TOP, $WINDOW_RIGHT, $WINDOW_BOTTOM}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 128
    set background picture of theViewOptions to bgFile
    set position of item "$APP_NAME.app" of container window to {165, 200}
    set position of item "Applications" of container window to {475, 200}
    set position of item ".background" of container window to {900, 900}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
EOF

sync
hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || \
  (sleep 2 && hdiutil detach "$MOUNT_DIR" -force >/dev/null 2>&1) || true

rm -f "$DMG_FINAL"
hdiutil convert "$DMG_TMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_FINAL" >/dev/null
rm -f "$DMG_TMP"
rm -rf "$STAGE_DIR"

echo "已生成：$DMG_FINAL"
hdiutil imageinfo "$DMG_FINAL" -format 2>/dev/null | head -1 || true
ls -lh "$DMG_FINAL"

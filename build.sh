#!/bin/zsh
set -euo pipefail

APP_NAME="Y-Keys"
EXECUTABLE_NAME="YKeys"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
FINAL_APP_DIR="$BUILD_DIR/$APP_NAME.app"
TMP_PARENT="${TMPDIR:-/tmp}"
TMP_BUILD_DIR="$(mktemp -d "$TMP_PARENT/y-keys-build.XXXXXX")"
APP_DIR="$TMP_BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ENTITLEMENTS="$ROOT_DIR/YKeys.entitlements"

trap 'rm -rf "$TMP_BUILD_DIR"' EXIT

RELEASE="${RELEASE:-0}"
SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-}"

if [[ "$RELEASE" == "1" ]]; then
  if [[ -z "$SIGN_IDENTITY" ]]; then
    SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
      | awk -F '"' '/Developer ID Application.*\(A94225N8T5\)/ { print $2; exit }')"
  fi
  if [[ -z "$SIGN_IDENTITY" ]]; then
    echo "错误：RELEASE=1 但找不到 Developer ID Application 证书。" >&2
    exit 1
  fi
else
  if [[ -z "$SIGN_IDENTITY" ]]; then
    SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
      | awk -F '"' '/"[^"]+"/ { print $2; exit }')"
  fi
  if [[ -z "$SIGN_IDENTITY" ]]; then
    SIGN_IDENTITY="-"
  fi
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"

"$ROOT_DIR/icon/make_icns.sh"
if [[ ! -f "$ROOT_DIR/icon/AppIcon.icns" ]]; then
  echo "错误：图标生成完成后仍找不到 icon/AppIcon.icns。" >&2
  exit 1
fi
cp "$ROOT_DIR/icon/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

SETTING_FRAMEWORK_DIR="$ROOT_DIR/Y-Framework/Setting"
PERMISSION_FRAMEWORK_DIR="$ROOT_DIR/Y-Framework/Permission"
if [[ ! -d "$SETTING_FRAMEWORK_DIR" ]]; then
  SETTING_FRAMEWORK_DIR="$ROOT_DIR/../Y-Framework/Setting"
fi
if [[ ! -d "$PERMISSION_FRAMEWORK_DIR" ]]; then
  PERMISSION_FRAMEWORK_DIR="$ROOT_DIR/../Y-Framework/Permission"
fi
FRAMEWORK_SOURCES=(
  "$SETTING_FRAMEWORK_DIR"/*.swift(N)
  "$PERMISSION_FRAMEWORK_DIR"/*.swift(N)
)
if (( ${#FRAMEWORK_SOURCES[@]} < 2 )); then
  echo "错误：找不到 Y-Framework/Setting 或 Permission Swift 源文件。" >&2
  exit 1
fi

xcrun swiftc \
  -swift-version 5 \
  -target arm64-apple-macosx13.0 \
  -framework AppKit \
  -framework Carbon \
  -framework ApplicationServices \
  -framework Security \
  -O \
  "${FRAMEWORK_SOURCES[@]}" \
  "$ROOT_DIR"/Sources/*.swift \
  -o "$MACOS_DIR/$EXECUTABLE_NAME"

xattr -cr "$APP_DIR"
xattr -d com.apple.FinderInfo "$APP_DIR" 2>/dev/null || true
xattr -d 'com.apple.fileprovider.fpfs#P' "$APP_DIR" 2>/dev/null || true

if [[ "$RELEASE" == "1" ]]; then
  codesign --force \
    --sign "$SIGN_IDENTITY" \
    --options runtime \
    --timestamp \
    --entitlements "$ENTITLEMENTS" \
    "$APP_DIR"
else
  codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR" >/dev/null
fi
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

rm -rf "$FINAL_APP_DIR"
mkdir -p "$BUILD_DIR"
ditto --noextattr --noqtn "$APP_DIR" "$FINAL_APP_DIR"
xattr -cr "$FINAL_APP_DIR"
xattr -d com.apple.FinderInfo "$FINAL_APP_DIR" 2>/dev/null || true
xattr -d 'com.apple.fileprovider.fpfs#P' "$FINAL_APP_DIR" 2>/dev/null || true
codesign --verify --deep --verbose=2 "$FINAL_APP_DIR"

# Documents 目录受 File Provider 管理时，Finder 可能立即给 App 根目录重新附加空的
# FinderInfo。通过无扩展属性的临时副本执行严格校验，确认最终复制内容仍可分发。
VERIFY_APP_DIR="$TMP_BUILD_DIR/verify/$APP_NAME.app"
mkdir -p "${VERIFY_APP_DIR:h}"
ditto --noextattr --noqtn "$FINAL_APP_DIR" "$VERIFY_APP_DIR"
xattr -cr "$VERIFY_APP_DIR"
xattr -d com.apple.FinderInfo "$VERIFY_APP_DIR" 2>/dev/null || true
xattr -d 'com.apple.fileprovider.fpfs#P' "$VERIFY_APP_DIR" 2>/dev/null || true
codesign --verify --deep --strict --verbose=2 "$VERIFY_APP_DIR"

echo "已构建：$FINAL_APP_DIR"
echo "签名身份：$SIGN_IDENTITY"
if [[ "$RELEASE" == "1" ]]; then
  echo "模式：发布（hardened runtime）"
else
  echo "模式：本地测试"
fi

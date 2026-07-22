#!/bin/zsh
set -euo pipefail

APP_NAME="Y-Keys"
EXECUTABLE_NAME="YKeys"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_ARCH="${TARGET_ARCH:-arm64}"
BUILD_DIR="${BUILD_DIR_OVERRIDE:-$ROOT_DIR/build}"
if [[ "$BUILD_DIR" != /* ]]; then
  BUILD_DIR="$ROOT_DIR/$BUILD_DIR"
fi
FINAL_APP_DIR="$BUILD_DIR/$APP_NAME.app"
TMP_PARENT="${TMPDIR:-/tmp}"
ENTITLEMENTS="$ROOT_DIR/YKeys.entitlements"

case "$TARGET_ARCH" in
  arm64|x86_64) ;;
  *)
    echo "错误：TARGET_ARCH 仅支持 arm64 或 x86_64，实际为 $TARGET_ARCH。" >&2
    exit 1
    ;;
esac

TMP_BUILD_DIR="$(mktemp -d "$TMP_PARENT/y-keys-build.$TARGET_ARCH.XXXXXX")"
APP_DIR="$TMP_BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

trap 'rm -rf "$TMP_BUILD_DIR"' EXIT

assert_thin_architecture() {
  local binary_path="$1"
  local phase="$2"
  local actual_architectures

  if [[ ! -f "$binary_path" ]]; then
    echo "错误：$phase 找不到可执行文件：$binary_path" >&2
    exit 1
  fi

  actual_architectures="$(/usr/bin/lipo -archs "$binary_path" 2>/dev/null || true)"
  if [[ "$actual_architectures" != "$TARGET_ARCH" ]]; then
    echo "错误：$phase 必须是仅含 $TARGET_ARCH 的 thin binary，实际为 ${actual_architectures:-未知}。" >&2
    exit 1
  fi
}

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
  SIGN_IDENTITY="${SIGN_IDENTITY:--}"
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"

BUILD_ICON_DIR="$TMP_BUILD_DIR/icon"
ICON_OUTPUT_DIR="$BUILD_ICON_DIR" "$ROOT_DIR/icon/make_icns.sh"
if [[ ! -f "$BUILD_ICON_DIR/AppIcon.icns" || -L "$BUILD_ICON_DIR/AppIcon.icns" ]]; then
  echo "错误：临时图标生成完成后仍找不到有效的 AppIcon.icns。" >&2
  exit 1
fi
cp "$BUILD_ICON_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

if [[ "${Y_RELEASE_REQUIRE_VENDORED:-0}" == "1" &&
      ( ! -d "$ROOT_DIR/Y-Framework" || -L "$ROOT_DIR/Y-Framework" ) ]]; then
  echo "错误：正式发布要求仓库内非符号链接 Y-Framework 根目录。" >&2
  exit 1
fi
SETTING_FRAMEWORK_DIR="$ROOT_DIR/Y-Framework/Setting"
PERMISSION_FRAMEWORK_DIR="$ROOT_DIR/Y-Framework/Permission"
if [[ ! -d "$SETTING_FRAMEWORK_DIR" ]]; then
  if [[ "${Y_RELEASE_REQUIRE_VENDORED:-0}" == "1" ]]; then
    echo "错误：正式发布要求仓库内 vendored Setting 框架，禁止回退父目录。" >&2
    exit 1
  fi
  SETTING_FRAMEWORK_DIR="$ROOT_DIR/../Y-Framework/Setting"
fi
if [[ ! -d "$PERMISSION_FRAMEWORK_DIR" ]]; then
  if [[ "${Y_RELEASE_REQUIRE_VENDORED:-0}" == "1" ]]; then
    echo "错误：正式发布要求仓库内 vendored Permission 框架，禁止回退父目录。" >&2
    exit 1
  fi
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
  -target "$TARGET_ARCH-apple-macosx13.0" \
  -framework AppKit \
  -framework Carbon \
  -framework ApplicationServices \
  -framework Security \
  -O \
  "${FRAMEWORK_SOURCES[@]}" \
  "$ROOT_DIR"/Sources/*.swift \
  -o "$MACOS_DIR/$EXECUTABLE_NAME"

assert_thin_architecture "$MACOS_DIR/$EXECUTABLE_NAME" "签名前"

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
assert_thin_architecture "$MACOS_DIR/$EXECUTABLE_NAME" "签名后"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

rm -rf "$FINAL_APP_DIR"
mkdir -p "$BUILD_DIR"
ditto --noextattr --noqtn "$APP_DIR" "$FINAL_APP_DIR"
xattr -cr "$FINAL_APP_DIR"
xattr -d com.apple.FinderInfo "$FINAL_APP_DIR" 2>/dev/null || true
xattr -d 'com.apple.fileprovider.fpfs#P' "$FINAL_APP_DIR" 2>/dev/null || true
assert_thin_architecture "$FINAL_APP_DIR/Contents/MacOS/$EXECUTABLE_NAME" "最终构建产物"
codesign --verify --deep --verbose=2 "$FINAL_APP_DIR"

# Documents 目录受 File Provider 管理时，Finder 可能立即给 App 根目录重新附加空的
# FinderInfo。通过无扩展属性的临时副本执行严格校验，确认最终复制内容仍可分发。
VERIFY_APP_DIR="$TMP_BUILD_DIR/verify/$APP_NAME.app"
mkdir -p "${VERIFY_APP_DIR:h}"
ditto --noextattr --noqtn "$FINAL_APP_DIR" "$VERIFY_APP_DIR"
xattr -cr "$VERIFY_APP_DIR"
xattr -d com.apple.FinderInfo "$VERIFY_APP_DIR" 2>/dev/null || true
xattr -d 'com.apple.fileprovider.fpfs#P' "$VERIFY_APP_DIR" 2>/dev/null || true
assert_thin_architecture "$VERIFY_APP_DIR/Contents/MacOS/$EXECUTABLE_NAME" "严格校验副本"
codesign --verify --deep --strict --verbose=2 "$VERIFY_APP_DIR"

echo "已构建：$FINAL_APP_DIR"
echo "目标架构：$TARGET_ARCH（thin）"
if [[ "$RELEASE" == "1" ]]; then
  echo "模式：发布签名（hardened runtime）"
else
  echo "模式：本地测试签名"
fi

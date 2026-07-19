#!/bin/zsh
set -euo pipefail

# 一键发布：Developer ID 签名构建 → 公证 app → 打包 DMG → 签名/公证 DMG → 装订 → 验证。
# 公证凭据使用钥匙串 profile，默认复用本机 Y-Project 已存在的 Apple notary profile。

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Y-Keys"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Info.plist")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$ROOT_DIR/Info.plist")"
BUILD_APP_PATH="$ROOT_DIR/build/$APP_NAME.app"
RELEASE_WORK="$(mktemp -d /tmp/Y-Keys-release.XXXXXX)"
APP_PATH="$RELEASE_WORK/$APP_NAME.app"
DMG_PATH="$ROOT_DIR/dist/$APP_NAME.dmg"
VERSIONED_DMG_PATH="$ROOT_DIR/dist/$APP_NAME-v$VERSION.dmg"
NOTARY_PROFILE="${NOTARY_PROFILE:-y-dock-notary}"
SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-}"
VERIFY_MOUNT=""
VERSIONED_DMG_TEMP=""
VERSIONED_DMG_TEMP_DIR=""

detach_with_retry() {
  local target="$1"
  local attempt
  for attempt in {1..5}; do
    if hdiutil detach "$target" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  hdiutil detach "$target" -force >/dev/null
}

cleanup() {
  if [[ -n "$VERIFY_MOUNT" ]]; then
    detach_with_retry "$VERIFY_MOUNT" >/dev/null 2>&1 || true
    rm -rf "$VERIFY_MOUNT"
  fi
  if [[ -n "$VERSIONED_DMG_TEMP" ]]; then
    rm -f "$VERSIONED_DMG_TEMP"
  fi
  if [[ -n "$VERSIONED_DMG_TEMP_DIR" ]]; then
    rm -rf "$VERSIONED_DMG_TEMP_DIR"
  fi
  rm -rf "$RELEASE_WORK"
}
trap cleanup EXIT

bold() { print -P "%B$1%b"; }

if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | awk -F '"' '/Developer ID Application.*\(A94225N8T5\)/ { print $2; exit }')"
fi
if [[ -z "$SIGN_IDENTITY" ]]; then
  echo "错误：找不到 Developer ID Application 证书。" >&2
  exit 1
fi

mkdir -p "$ROOT_DIR/dist"

bold "▶ 0/7 检查公证凭据…"
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  cat >&2 <<EOF
找不到公证凭据 profile：$NOTARY_PROFILE

请先使用 xcrun notarytool store-credentials 存入钥匙串，或通过环境变量指定：

  NOTARY_PROFILE=你的Profile ./release.sh
EOF
  exit 1
fi
echo "  ✓ 凭据就绪：$NOTARY_PROFILE"
rm -f "$DMG_PATH" "$VERSIONED_DMG_PATH"

notarize() {
  local target="$1"
  local log
  local sid=""
  log="$(mktemp "$RELEASE_WORK/notary.XXXXXX")"

  if xcrun notarytool submit "$target" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait 2>&1 | tee "$log"; then
    sid="$(awk '/^[[:space:]]*id:/ { print $2; exit }' "$log")"
    if grep -q "status: Accepted" "$log"; then
      rm -f "$log"
      return 0
    fi
  else
    sid="$(awk '/^[[:space:]]*id:/ { print $2; exit }' "$log")"
    if [[ -n "$sid" ]]; then
      echo "  ! 等待连接中断，改用 notarytool wait：$sid"
      if xcrun notarytool wait "$sid" \
            --keychain-profile "$NOTARY_PROFILE" \
            2>&1 | tee -a "$log" && \
          grep -q "status: Accepted" "$log"; then
        rm -f "$log"
        return 0
      fi
    fi
  fi

  if [[ -z "$sid" ]]; then
    echo "✗ 公证提交失败且没有返回 submission ID：$target" >&2
  else
    echo "✗ 公证未通过或等待失败：$target（$sid）" >&2
    xcrun notarytool info "$sid" \
      --keychain-profile "$NOTARY_PROFILE" >&2 || true
    xcrun notarytool log "$sid" \
      --keychain-profile "$NOTARY_PROFILE" >&2 || true
  fi
  return 1
}

validate_staple() {
  local target="$1"
  local output
  if ! output="$(xcrun stapler validate "$target" 2>&1)"; then
    print -u2 -- "$output"
    return 1
  fi
  print -r -- "$output"
  if [[ "$output" != *"The validate action worked!"* ]]; then
    echo "✗ 未检测到有效的 stapled ticket：$target" >&2
    return 1
  fi
}

bold "▶ 1/7 构建并签名 app…"
CODE_SIGN_IDENTITY="$SIGN_IDENTITY" RELEASE=1 "$ROOT_DIR/build.sh"
rm -rf "$APP_PATH"
ditto --noextattr --noqtn "$BUILD_APP_PATH" "$APP_PATH"
xattr -cr "$APP_PATH"
BUILT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
BUILT_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist")"
if [[ "$BUILT_VERSION" != "$VERSION" || "$BUILT_BUILD" != "$BUILD_NUMBER" ]]; then
  echo "✗ 构建版本 $BUILT_VERSION ($BUILT_BUILD) 与源版本 $VERSION ($BUILD_NUMBER) 不一致。" >&2
  exit 1
fi
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

SIG_INFO="$(codesign -dvvv "$APP_PATH" 2>&1)"
if ! grep -q "Identifier=com.lixingchen.YKeys" <<< "$SIG_INFO"; then
  echo "✗ app 签名标识不是 com.lixingchen.YKeys。" >&2
  exit 1
fi
if ! grep -q "Developer ID Application" <<< "$SIG_INFO"; then
  echo "✗ app 未用 Developer ID 签名。" >&2
  exit 1
fi
if ! grep -q "flags=.*runtime" <<< "$SIG_INFO"; then
  echo "✗ app 未启用 hardened runtime。" >&2
  exit 1
fi
if ! grep -q "TeamIdentifier=A94225N8T5" <<< "$SIG_INFO"; then
  echo "✗ app 签名团队不是 A94225N8T5。" >&2
  exit 1
fi
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
echo "  ✓ app 签名校验通过"

bold "▶ 2/7 公证 app 本体…"
APP_ZIP="$RELEASE_WORK/app.zip"
ditto -c -k --keepParent "$APP_PATH" "$APP_ZIP"
notarize "$APP_ZIP"
rm -f "$APP_ZIP"
xcrun stapler staple "$APP_PATH"
validate_staple "$APP_PATH"
echo "  ✓ app 已公证并装订"

bold "▶ 3/7 打包 DMG…"
APP_PATH_OVERRIDE="$APP_PATH" "$ROOT_DIR/make_dmg.sh"

bold "▶ 4/7 签名 DMG…"
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
codesign --verify --verbose=4 "$DMG_PATH"
echo "  ✓ DMG 签名校验通过"

bold "▶ 5/7 公证 DMG…"
notarize "$DMG_PATH"
echo "  ✓ DMG 已公证"

bold "▶ 6/7 装订 DMG 票据…"
xcrun stapler staple "$DMG_PATH"
validate_staple "$DMG_PATH"
hdiutil verify "$DMG_PATH"
echo "  ✓ DMG 已装订并通过镜像校验"

bold "▶ 7/7 Gatekeeper 验证…"
spctl -a -vvv -t open --context context:primary-signature "$DMG_PATH"
VERIFY_MOUNT="$(mktemp -d /tmp/Y-Keys-verify.XXXXXX)"
hdiutil attach "$DMG_PATH" -mountpoint "$VERIFY_MOUNT" -nobrowse -noautoopen >/dev/null
codesign --verify --deep --strict --verbose=2 "$VERIFY_MOUNT/$APP_NAME.app"
validate_staple "$VERIFY_MOUNT/$APP_NAME.app"
spctl -a -t exec -vvv "$VERIFY_MOUNT/$APP_NAME.app"
detach_with_retry "$VERIFY_MOUNT"
rm -rf "$VERIFY_MOUNT"
VERIFY_MOUNT=""
VERSIONED_DMG_TEMP_DIR="$(mktemp -d "$ROOT_DIR/dist/.Y-Keys-v$VERSION.XXXXXX")"
VERSIONED_DMG_TEMP="$VERSIONED_DMG_TEMP_DIR/Y-Keys-v$VERSION.dmg"
cp "$DMG_PATH" "$VERSIONED_DMG_TEMP"
cmp -s "$DMG_PATH" "$VERSIONED_DMG_TEMP"
codesign --verify --verbose=4 "$VERSIONED_DMG_TEMP"
validate_staple "$VERSIONED_DMG_TEMP"
spctl -a -vvv -t open --context context:primary-signature "$VERSIONED_DMG_TEMP"
mv "$VERSIONED_DMG_TEMP" "$VERSIONED_DMG_PATH"
VERSIONED_DMG_TEMP=""
rm -rf "$VERSIONED_DMG_TEMP_DIR"
VERSIONED_DMG_TEMP_DIR=""

echo ""
bold "✅ 发布产物完成"
echo "基础镜像：$DMG_PATH"
echo "Release 文件：$VERSIONED_DMG_PATH"
ls -lh "$DMG_PATH" "$VERSIONED_DMG_PATH"

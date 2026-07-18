#!/bin/zsh
set -euo pipefail

# 一键发布：Developer ID 签名构建 → 公证 app → 打包 DMG → 签名/公证 DMG → 装订 → 验证。
# 公证凭据使用钥匙串 profile，默认复用本机 Y-Project 已存在的 Apple notary profile。

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Y-Keys"
BUILD_APP_PATH="$ROOT_DIR/build/$APP_NAME.app"
RELEASE_WORK="$(mktemp -d /tmp/Y-Keys-release.XXXXXX)"
APP_PATH="$RELEASE_WORK/$APP_NAME.app"
DMG_PATH="$ROOT_DIR/dist/$APP_NAME.dmg"
NOTARY_PROFILE="${NOTARY_PROFILE:-y-dock-notary}"
SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-}"
VERIFY_MOUNT=""

cleanup() {
  if [[ -n "$VERIFY_MOUNT" ]]; then
    hdiutil detach "$VERIFY_MOUNT" >/dev/null 2>&1 || hdiutil detach "$VERIFY_MOUNT" -force >/dev/null 2>&1 || true
    rm -rf "$VERIFY_MOUNT"
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

notarize() {
  local target="$1"
  local log
  log="$(mktemp)"
  if ! xcrun notarytool submit "$target" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait 2>&1 | tee "$log"; then
    echo "✗ 公证提交失败：$target" >&2
    rm -f "$log"
    return 1
  fi

  local sid
  sid="$(grep -m1 -E "^[[:space:]]*id:" "$log" | awk '{print $2}')"
  if ! grep -q "status: Accepted" "$log"; then
    echo "✗ 公证未通过：$target" >&2
    [[ -n "$sid" ]] && xcrun notarytool log "$sid" --keychain-profile "$NOTARY_PROFILE" >&2 || true
    rm -f "$log"
    return 1
  fi

  rm -f "$log"
  return 0
}

bold "▶ 1/7 构建并签名 app…"
CODE_SIGN_IDENTITY="$SIGN_IDENTITY" RELEASE=1 "$ROOT_DIR/build.sh"
rm -rf "$APP_PATH"
ditto --noextattr --noqtn "$BUILD_APP_PATH" "$APP_PATH"
xattr -cr "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

SIG_INFO="$(codesign -dvvv "$APP_PATH" 2>&1)"
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
APP_ZIP="$(mktemp -d)/app.zip"
ditto -c -k --keepParent "$APP_PATH" "$APP_ZIP"
notarize "$APP_ZIP"
rm -f "$APP_ZIP"
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
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
xcrun stapler validate "$DMG_PATH"
echo "  ✓ DMG 已装订"

bold "▶ 7/7 Gatekeeper 验证…"
spctl -a -vvv -t open --context context:primary-signature "$DMG_PATH"
VERIFY_MOUNT="$(mktemp -d /tmp/Y-Keys-verify.XXXXXX)"
hdiutil attach "$DMG_PATH" -mountpoint "$VERIFY_MOUNT" -nobrowse -noautoopen >/dev/null
codesign --verify --deep --strict --verbose=2 "$VERIFY_MOUNT/$APP_NAME.app"
spctl -a -t exec -vvv "$VERIFY_MOUNT/$APP_NAME.app"
hdiutil detach "$VERIFY_MOUNT" >/dev/null 2>&1 || hdiutil detach "$VERIFY_MOUNT" -force >/dev/null 2>&1
rm -rf "$VERIFY_MOUNT"
VERIFY_MOUNT=""

echo ""
bold "✅ 发布产物完成"
echo "可分发文件：$DMG_PATH"
ls -lh "$DMG_PATH"

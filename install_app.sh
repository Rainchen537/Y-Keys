#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Y-Keys"
APP_PATH="$ROOT_DIR/build/$APP_NAME.app"

if [[ ! -d "$APP_PATH" ]]; then
  "$ROOT_DIR/build.sh"
fi

ditto --noextattr --noqtn "$APP_PATH" "/Applications/$APP_NAME.app"
xattr -cr "/Applications/$APP_NAME.app"
xattr -d com.apple.FinderInfo "/Applications/$APP_NAME.app" 2>/dev/null || true
xattr -d 'com.apple.fileprovider.fpfs#P' "/Applications/$APP_NAME.app" 2>/dev/null || true
echo "已安装到 /Applications/$APP_NAME.app"

#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRAMEWORK_DIR="$ROOT_DIR/Y-Framework/DMG"
if [[ ! -d "$FRAMEWORK_DIR" ]]; then
  FRAMEWORK_DIR="$ROOT_DIR/../Y-Framework/DMG"
fi
if [[ ! -f "$FRAMEWORK_DIR/YDMGFramework.zsh" ]]; then
  echo "错误：找不到 Y-Framework/DMG。" >&2
  exit 1
fi

Y_DMG_APP_NAME="${APP_NAME_OVERRIDE:-Y-Keys}"
Y_DMG_APP_PATH="${APP_PATH_OVERRIDE:-$ROOT_DIR/build/Y-Keys.app}"
Y_DMG_VOLUME_NAME="${VOLUME_NAME_OVERRIDE:-Y-Keys}"
Y_DMG_OUTPUT_PATH="${OUTPUT_PATH_OVERRIDE:-$ROOT_DIR/dist/Y-Keys.dmg}"
Y_DMG_HIDDEN_APP_NAMES=()

if [[ -d "$Y_DMG_OUTPUT_PATH" ]]; then
  echo "错误：DMG 输出路径不能指向目录：$Y_DMG_OUTPUT_PATH" >&2
  exit 1
fi

STAGED_OUTPUT_PATH="${Y_DMG_OUTPUT_PATH:h}/.${Y_DMG_OUTPUT_PATH:t}.new.$$"
if [[ -d "$STAGED_OUTPUT_PATH" ]]; then
  echo "错误：DMG 临时输出路径被目录占用：$STAGED_OUTPUT_PATH" >&2
  exit 1
fi

cleanup_staged_output() {
  if [[ -f "$STAGED_OUTPUT_PATH" || -L "$STAGED_OUTPUT_PATH" ]]; then
    rm -f "$STAGED_OUTPUT_PATH"
  fi
}
trap cleanup_staged_output EXIT
cleanup_staged_output

source "$FRAMEWORK_DIR/YDMGFramework.zsh"
y_dmg_build

if [[ ! -f "$Y_DMG_OUTPUT_PATH" || -L "$Y_DMG_OUTPUT_PATH" ]]; then
  echo "错误：DMG 产物必须是普通文件且不能是符号链接：$Y_DMG_OUTPUT_PATH" >&2
  if [[ -f "$Y_DMG_OUTPUT_PATH" || -L "$Y_DMG_OUTPUT_PATH" ]]; then
    rm -f "$Y_DMG_OUTPUT_PATH"
  fi
  exit 1
fi

cleanup_staged_output

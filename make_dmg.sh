#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ "${Y_RELEASE_REQUIRE_VENDORED:-0}" == "1" &&
      ( ! -d "$ROOT_DIR/Y-Framework" || -L "$ROOT_DIR/Y-Framework" ) ]]; then
  echo "错误：正式发布要求仓库内非符号链接 Y-Framework 根目录。" >&2
  exit 1
fi
FRAMEWORK_DIR="$ROOT_DIR/Y-Framework/DMG"
if [[ ! -d "$FRAMEWORK_DIR" ||
      ( "${Y_RELEASE_REQUIRE_VENDORED:-0}" == "1" && -L "$FRAMEWORK_DIR" ) ]]; then
  if [[ "${Y_RELEASE_REQUIRE_VENDORED:-0}" == "1" ]]; then
    echo "错误：正式发布要求仓库内非符号链接 vendored DMG 框架，禁止回退父目录。" >&2
    exit 1
  fi
  FRAMEWORK_DIR="$ROOT_DIR/../Y-Framework/DMG"
fi
if [[ ! -f "$FRAMEWORK_DIR/YDMGFramework.zsh" ]]; then
  echo "错误：找不到 Y-Framework/DMG。" >&2
  exit 1
fi
if [[ "${Y_RELEASE_REQUIRE_VENDORED:-0}" == "1" ]]; then
  if [[ -L "$FRAMEWORK_DIR/YDMGFramework.zsh" ||
        ! -f "$FRAMEWORK_DIR/DmgBackgroundGenerator.swift" ||
        -L "$FRAMEWORK_DIR/DmgBackgroundGenerator.swift" ]]; then
    echo "错误：正式发布要求仓库内普通文件形式的 DMG 框架和背景生成器。" >&2
    exit 1
  fi
  unset Y_DMG_BACKGROUND_TITLE Y_DMG_WINDOW_LEFT Y_DMG_WINDOW_TOP
  unset Y_DMG_WINDOW_WIDTH Y_DMG_WINDOW_HEIGHT Y_DMG_ICON_SIZE
  unset Y_DMG_BACKGROUND_SCALE Y_DMG_APP_ICON_X Y_DMG_APP_ICON_Y
  unset Y_DMG_APPLICATIONS_ICON_X Y_DMG_APPLICATIONS_ICON_Y
  Y_DMG_BACKGROUND_GENERATOR="$FRAMEWORK_DIR/DmgBackgroundGenerator.swift"
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

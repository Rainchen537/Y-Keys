#!/bin/zsh
set -euo pipefail

# 一次发布两份 thin 架构产物：arm64 与 x86_64。
# 每个架构都使用独立 build/stage，完成 Developer ID 签名、App/DMG 公证、staple、
# Gatekeeper 与最终挂载架构验证后，才写入 dist 的版本化文件。

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Y-Keys"
EXECUTABLE_NAME="YKeys"
BUNDLE_IDENTIFIER="com.lixingchen.YKeys"
TEAM_IDENTIFIER="A94225N8T5"
ENTITLEMENTS="$ROOT_DIR/YKeys.entitlements"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Info.plist")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$ROOT_DIR/Info.plist")"
ARCHITECTURES=(arm64 x86_64)
RELEASE_WORK="$(mktemp -d /tmp/Y-Keys-release.XXXXXX)"
DIST_STAGING_DIR=""
PUBLISH_STATE_DIR="$RELEASE_WORK/publish-state"
RELEASE_LOCK_DIR="$ROOT_DIR/dist/.$APP_NAME-v$VERSION.release.lock"
NOTARY_PROFILE="${NOTARY_PROFILE:-y-dock-notary}"
SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-}"
VERIFY_MOUNT=""
RELEASE_SUCCEEDED=0
LOCK_ACQUIRED=0
SOURCE_FINGERPRINT=""
mkdir -p "$PUBLISH_STATE_DIR"

release_dmg_name() {
  local arch="$1"
  print -r -- "$APP_NAME-v$VERSION-$arch.dmg"
}

final_dmg_path() {
  local arch="$1"
  print -r -- "$ROOT_DIR/dist/$(release_dmg_name "$arch")"
}

new_dmg_path() {
  local arch="$1"
  local dmg_name
  dmg_name="$(release_dmg_name "$arch")"
  print -r -- "$ROOT_DIR/dist/.${dmg_name%.dmg}.new.$$.dmg"
}

backup_dmg_path() {
  local arch="$1"
  local dmg_name
  dmg_name="$(release_dmg_name "$arch")"
  print -r -- "$ROOT_DIR/dist/.${dmg_name%.dmg}.backup.$$.dmg"
}

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
  local arch final_dmg new_dmg backup_dmg
  if [[ -n "$VERIFY_MOUNT" ]]; then
    detach_with_retry "$VERIFY_MOUNT" >/dev/null 2>&1 || true
    rm -rf "$VERIFY_MOUNT"
  fi

  for arch in "${ARCHITECTURES[@]}"; do
    final_dmg="$(final_dmg_path "$arch")"
    new_dmg="$(new_dmg_path "$arch")"
    backup_dmg="$(backup_dmg_path "$arch")"

    if (( RELEASE_SUCCEEDED == 0 )); then
      if [[ -f "$PUBLISH_STATE_DIR/$arch.published" ]]; then
        rm -f "$final_dmg"
      fi
      if [[ -f "$PUBLISH_STATE_DIR/$arch.backed-up" && ( -e "$backup_dmg" || -L "$backup_dmg" ) ]]; then
        mv -f "$backup_dmg" "$final_dmg" || echo "✗ 无法恢复原有 $arch DMG；备份保留在：$backup_dmg" >&2
      fi
      rm -f "$new_dmg"
    else
      rm -f "$new_dmg" "$backup_dmg"
    fi
  done

  if [[ -n "$DIST_STAGING_DIR" ]]; then
    rm -rf "$DIST_STAGING_DIR"
  fi
  if (( LOCK_ACQUIRED == 1 )); then
    rm -rf "$RELEASE_LOCK_DIR"
  fi
  rm -rf "$RELEASE_WORK"
}
trap cleanup EXIT

bold() { print -P "%B$1%b"; }

assert_vendored_release_inputs() {
  local framework_dir
  local -a setting_sources permission_sources symlinks

  if [[ ! -d "$ROOT_DIR/Y-Framework" || -L "$ROOT_DIR/Y-Framework" ]]; then
    echo "✗ 正式发布要求仓库内非符号链接 Y-Framework 根目录。" >&2
    return 1
  fi

  for framework_dir in \
    "$ROOT_DIR/Y-Framework/Setting" \
    "$ROOT_DIR/Y-Framework/Permission" \
    "$ROOT_DIR/Y-Framework/DMG"; do
    if [[ ! -d "$framework_dir" || -L "$framework_dir" ]]; then
      echo "✗ 正式发布要求仓库内非符号链接框架目录：$framework_dir" >&2
      return 1
    fi
    symlinks=("$framework_dir"/**/*(N@))
    if (( ${#symlinks[@]} != 0 )); then
      echo "✗ 正式发布的 vendored 框架不得包含符号链接：${symlinks[1]}" >&2
      return 1
    fi
  done

  setting_sources=("$ROOT_DIR/Y-Framework/Setting"/*.swift(N.))
  permission_sources=("$ROOT_DIR/Y-Framework/Permission"/*.swift(N.))
  if (( ${#setting_sources[@]} == 0 || ${#permission_sources[@]} == 0 )); then
    echo "✗ 正式发布缺少仓库内 vendored Setting 或 Permission Swift 源文件。" >&2
    return 1
  fi
  if [[ ! -f "$ROOT_DIR/Y-Framework/DMG/YDMGFramework.zsh" ||
        -L "$ROOT_DIR/Y-Framework/DMG/YDMGFramework.zsh" ||
        ! -f "$ROOT_DIR/Y-Framework/DMG/DmgBackgroundGenerator.swift" ||
        -L "$ROOT_DIR/Y-Framework/DMG/DmgBackgroundGenerator.swift" ]]; then
    echo "✗ 正式发布缺少仓库内 vendored DMG 框架脚本或背景生成器。" >&2
    return 1
  fi
}

release_source_fingerprint() {
  local file file_path list_file manifest_file repo_root hash_output content_hash fingerprint

  repo_root="$(/usr/bin/git -C "$ROOT_DIR" rev-parse --show-toplevel 2>/dev/null)" || {
    echo "✗ 无法确认发布源码仓库。" >&2
    return 1
  }
  if [[ "${repo_root:A}" != "${ROOT_DIR:A}" ]]; then
    echo "✗ 发布源码目录不是独立 Git 仓库根目录：$ROOT_DIR" >&2
    return 1
  fi

  list_file="$(mktemp "$RELEASE_WORK/source-files.XXXXXX")" || return 1
  manifest_file="$(mktemp "$RELEASE_WORK/source-manifest.XXXXXX")" || {
    rm -f "$list_file"
    return 1
  }

  if ! {
    /usr/bin/git -C "$ROOT_DIR" ls-files -z &&
      /usr/bin/git -C "$ROOT_DIR" ls-files --others --exclude-standard -z
  } > "$list_file"; then
    echo "✗ 无法完整枚举发布源码文件。" >&2
    rm -f "$list_file" "$manifest_file"
    return 1
  fi

  if ! : > "$manifest_file"; then
    echo "✗ 无法初始化发布源码清单。" >&2
    rm -f "$list_file" "$manifest_file"
    return 1
  fi
  while IFS= read -r -d '' file; do
    case "$file" in
      .claude/*|dist/*|build/*|build-*/*|.DS_Store) continue ;;
    esac

    file_path="$ROOT_DIR/$file"
    if ! /usr/bin/printf '%s\0' "$file" >> "$manifest_file"; then
      echo "✗ 无法写入发布源码清单：$file" >&2
      rm -f "$list_file" "$manifest_file"
      return 1
    fi
    if [[ -L "$file_path" ]]; then
      if ! /usr/bin/printf 'symlink:' >> "$manifest_file"; then
        echo "✗ 无法写入发布源码符号链接标记：$file" >&2
        rm -f "$list_file" "$manifest_file"
        return 1
      fi
      if ! /usr/bin/readlink -n "$file_path" >> "$manifest_file"; then
        echo "✗ 无法读取或记录发布源码符号链接：$file" >&2
        rm -f "$list_file" "$manifest_file"
        return 1
      fi
      if ! /usr/bin/printf '\0' >> "$manifest_file"; then
        echo "✗ 无法写入发布源码符号链接分隔符：$file" >&2
        rm -f "$list_file" "$manifest_file"
        return 1
      fi
    elif [[ -f "$file_path" ]]; then
      hash_output="$(/usr/bin/shasum -a 256 < "$file_path")" || {
        echo "✗ 无法计算发布源码文件摘要：$file" >&2
        rm -f "$list_file" "$manifest_file"
        return 1
      }
      content_hash="${hash_output%% *}"
      if [[ ! "$content_hash" =~ '^[0-9a-f]{64}$' ]]; then
        echo "✗ 发布源码文件摘要格式异常：$file" >&2
        rm -f "$list_file" "$manifest_file"
        return 1
      fi
      if ! /usr/bin/printf 'file:%s\0' "$content_hash" >> "$manifest_file"; then
        echo "✗ 无法写入发布源码文件摘要：$file" >&2
        rm -f "$list_file" "$manifest_file"
        return 1
      fi
    elif [[ ! -e "$file_path" ]]; then
      if ! /usr/bin/printf 'deleted\0' >> "$manifest_file"; then
        echo "✗ 无法写入发布源码删除标记：$file" >&2
        rm -f "$list_file" "$manifest_file"
        return 1
      fi
    else
      echo "✗ 发布源码包含不支持的对象类型：$file" >&2
      rm -f "$list_file" "$manifest_file"
      return 1
    fi
  done < "$list_file"

  hash_output="$(/usr/bin/shasum -a 256 "$manifest_file")" || {
    echo "✗ 无法计算发布源码清单摘要。" >&2
    rm -f "$list_file" "$manifest_file"
    return 1
  }
  fingerprint="${hash_output%% *}"
  rm -f "$list_file" "$manifest_file"
  if [[ ! "$fingerprint" =~ '^[0-9a-f]{64}$' ]]; then
    echo "✗ 发布源码指纹格式异常。" >&2
    return 1
  fi
  print -r -- "$fingerprint"
}

assert_release_source_unchanged() {
  local phase="$1"
  local current_fingerprint
  current_fingerprint="$(release_source_fingerprint)" || {
    echo "✗ 无法在 $phase 复核发布源码指纹。" >&2
    return 1
  }
  if [[ "$current_fingerprint" != "$SOURCE_FINGERPRINT" ]]; then
    echo "✗ $phase 检测到仓库源码发生变化，拒绝混合不同源码生成双架构发布包。" >&2
    return 1
  fi
}

assert_thin_architecture() {
  local binary_path="$1"
  local expected_arch="$2"
  local phase="$3"
  local actual_architectures

  if [[ ! -f "$binary_path" ]]; then
    echo "✗ $phase 找不到可执行文件：$binary_path" >&2
    exit 1
  fi

  actual_architectures="$(/usr/bin/lipo -archs "$binary_path" 2>/dev/null || true)"
  if [[ "$actual_architectures" != "$expected_arch" ]]; then
    echo "✗ $phase 必须是仅含 $expected_arch 的 thin binary，实际为 ${actual_architectures:-未知}。" >&2
    exit 1
  fi
  echo "  ✓ $phase：$expected_arch thin binary"
}

assert_app_thin_architecture() {
  local app_path="$1"
  local expected_arch="$2"
  local phase="$3"
  assert_thin_architecture "$app_path/Contents/MacOS/$EXECUTABLE_NAME" "$expected_arch" "$phase"
}

assert_app_version() {
  local app_path="$1"
  local phase="$2"
  local actual_version actual_build

  actual_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Contents/Info.plist")"
  actual_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app_path/Contents/Info.plist")"
  if [[ "$actual_version" != "$VERSION" || "$actual_build" != "$BUILD_NUMBER" ]]; then
    echo "✗ $phase 版本错误：实际 $actual_version ($actual_build)，要求 $VERSION ($BUILD_NUMBER)。" >&2
    exit 1
  fi
}

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
      echo "  ! 公证等待连接中断，继续等待既有提交。"
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
    echo "✗ 公证未通过或等待失败：$target" >&2
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

validate_release_signature() {
  local app_path="$1"
  local signature_info

  codesign --verify --deep --strict --verbose=2 "$app_path"
  signature_info="$(codesign -dvvv "$app_path" 2>&1)"
  if ! grep -q "Identifier=$BUNDLE_IDENTIFIER" <<< "$signature_info"; then
    echo "✗ app 签名标识不是 $BUNDLE_IDENTIFIER。" >&2
    exit 1
  fi
  if ! grep -q "Developer ID Application" <<< "$signature_info"; then
    echo "✗ app 未用 Developer ID 签名。" >&2
    exit 1
  fi
  if ! grep -q "flags=.*runtime" <<< "$signature_info"; then
    echo "✗ app 未启用 hardened runtime。" >&2
    exit 1
  fi
  if ! grep -q "TeamIdentifier=$TEAM_IDENTIFIER" <<< "$signature_info"; then
    echo "✗ app 签名团队不是 $TEAM_IDENTIFIER。" >&2
    exit 1
  fi
}

verify_release_dmg() {
  local dmg_path="$1"
  local arch="$2"
  local phase="$3"

  if [[ ! -f "$dmg_path" || -L "$dmg_path" ]]; then
    echo "✗ $phase 必须是普通 DMG 文件且不能是符号链接：$dmg_path" >&2
    exit 1
  fi

  codesign --verify --verbose=4 "$dmg_path"
  validate_staple "$dmg_path"
  hdiutil verify "$dmg_path"
  spctl -a -vvv -t open --context context:primary-signature "$dmg_path"

  VERIFY_MOUNT="$(mktemp -d "/tmp/Y-Keys-$arch-verify.XXXXXX")"
  hdiutil attach "$dmg_path" -mountpoint "$VERIFY_MOUNT" -nobrowse -noautoopen -readonly >/dev/null
  assert_app_version "$VERIFY_MOUNT/$APP_NAME.app" "$phase 挂载后"
  assert_app_thin_architecture "$VERIFY_MOUNT/$APP_NAME.app" "$arch" "$phase 挂载后"
  validate_release_signature "$VERIFY_MOUNT/$APP_NAME.app"
  validate_staple "$VERIFY_MOUNT/$APP_NAME.app"
  spctl -a -t exec -vvv "$VERIFY_MOUNT/$APP_NAME.app"
  detach_with_retry "$VERIFY_MOUNT"
  rm -rf "$VERIFY_MOUNT"
  VERIFY_MOUNT=""
  echo "  ✓ $phase 验证通过"
}

release_architecture() {
  local arch="$1"
  local arch_root="$RELEASE_WORK/$arch"
  local build_dir="$arch_root/build"
  local build_app_path="$build_dir/$APP_NAME.app"
  local stage_dir="$arch_root/stage"
  local app_path="$stage_dir/$APP_NAME.app"
  local app_zip="$arch_root/$APP_NAME-$arch.zip"
  local dmg_name
  local dmg_path
  local built_version
  local built_build

  dmg_name="$(release_dmg_name "$arch")"
  dmg_path="$DIST_STAGING_DIR/$dmg_name"
  mkdir -p "$build_dir" "$stage_dir"

  bold "▶ [$arch] 独立构建"
  Y_RELEASE_REQUIRE_VENDORED=1 \
    TARGET_ARCH="$arch" \
    BUILD_DIR_OVERRIDE="$build_dir" \
    RELEASE=0 \
    CODE_SIGN_IDENTITY=- \
    "$ROOT_DIR/build.sh"

  rm -rf "$app_path"
  ditto --noextattr --noqtn "$build_app_path" "$app_path"
  xattr -cr "$app_path"

  built_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Contents/Info.plist")"
  built_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app_path/Contents/Info.plist")"
  if [[ "$built_version" != "$VERSION" || "$built_build" != "$BUILD_NUMBER" ]]; then
    echo "✗ $arch 构建版本 $built_version ($built_build) 与源版本 $VERSION ($BUILD_NUMBER) 不一致。" >&2
    exit 1
  fi
  assert_app_thin_architecture "$app_path" "$arch" "$arch Developer ID 签名前"

  bold "▶ [$arch] Developer ID 签名"
  codesign --force \
    --sign "$SIGN_IDENTITY" \
    --options runtime \
    --timestamp \
    --entitlements "$ENTITLEMENTS" \
    "$app_path"
  assert_app_thin_architecture "$app_path" "$arch" "$arch Developer ID 签名后"
  validate_release_signature "$app_path"
  echo "  ✓ $arch app 签名校验通过"

  bold "▶ [$arch] 公证并装订 app"
  ditto -c -k --keepParent "$app_path" "$app_zip"
  notarize "$app_zip"
  rm -f "$app_zip"
  xcrun stapler staple "$app_path"
  validate_staple "$app_path"
  assert_app_thin_architecture "$app_path" "$arch" "$arch app 装订后"

  bold "▶ [$arch] 独立打包 DMG"
  Y_RELEASE_REQUIRE_VENDORED=1 \
    APP_NAME_OVERRIDE="$APP_NAME" \
    APP_PATH_OVERRIDE="$app_path" \
    VOLUME_NAME_OVERRIDE="$APP_NAME $arch" \
    OUTPUT_PATH_OVERRIDE="$dmg_path" \
    "$ROOT_DIR/make_dmg.sh"

  bold "▶ [$arch] 签名、公证并装订 DMG"
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$dmg_path"
  notarize "$dmg_path"
  xcrun stapler staple "$dmg_path"
  verify_release_dmg "$dmg_path" "$arch" "$arch 架构源 DMG"
  echo "  ✓ $arch 完整发布验证通过"
}

if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | awk -F '"' '/Developer ID Application.*\(A94225N8T5\)/ { print $2; exit }')"
fi
if [[ -z "$SIGN_IDENTITY" ]]; then
  echo "错误：找不到 Developer ID Application 证书。" >&2
  exit 1
fi

mkdir -p "$ROOT_DIR/dist"
if ! mkdir "$RELEASE_LOCK_DIR" 2>/dev/null; then
  echo "错误：已有同版本 Y-Keys 发布流程或上次异常退出留下的锁：$RELEASE_LOCK_DIR" >&2
  echo "请先确认没有 release.sh 正在运行，并检查 dist 中的 .backup/.new 文件后再移除该锁。" >&2
  exit 1
fi
LOCK_ACQUIRED=1
DIST_STAGING_DIR="$(mktemp -d "$ROOT_DIR/dist/.Y-Keys-v$VERSION.XXXXXX")"
assert_vendored_release_inputs || exit 1
SOURCE_FINGERPRINT="$(release_source_fingerprint)" || {
  echo "错误：无法记录发布源码指纹。" >&2
  exit 1
}
echo "  ✓ 已锁定本轮发布源码指纹"

bold "▶ 检查公证凭据"
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  print -u2 -- "错误：找不到指定的公证凭据 profile。请先存入钥匙串，或通过 NOTARY_PROFILE 指定。"
  exit 1
fi
assert_release_source_unchanged "发布前置条件检查后"
echo "  ✓ 公证凭据可用"

for arch in "${ARCHITECTURES[@]}"; do
  for target in "$(final_dmg_path "$arch")" "$(new_dmg_path "$arch")" "$(backup_dmg_path "$arch")"; do
    if [[ -d "$target" && ! -L "$target" ]]; then
      echo "错误：发布目标路径被目录占用：$target" >&2
      exit 1
    fi
  done
done

for arch in "${ARCHITECTURES[@]}"; do
  assert_release_source_unchanged "$arch 架构构建前"
  release_architecture "$arch"
  assert_release_source_unchanged "$arch 架构完整产物生成后"
done

assert_release_source_unchanged "双架构源 DMG 成套预检前"
bold "▶ 成套预检双架构源 DMG"
for arch in "${ARCHITECTURES[@]}"; do
  source_path="$DIST_STAGING_DIR/$(release_dmg_name "$arch")"
  verify_release_dmg "$source_path" "$arch" "$arch staging source"
done

bold "▶ 复制并复验双架构 .new DMG"
for arch in "${ARCHITECTURES[@]}"; do
  source_path="$DIST_STAGING_DIR/$(release_dmg_name "$arch")"
  new_path="$(new_dmg_path "$arch")"
  ditto --noextattr --noqtn "$source_path" "$new_path"
  if [[ ! -f "$new_path" || -L "$new_path" ]]; then
    echo "错误：$arch .new DMG 不是普通文件：$new_path" >&2
    exit 1
  fi
done
for arch in "${ARCHITECTURES[@]}"; do
  verify_release_dmg "$(new_dmg_path "$arch")" "$arch" "$arch .new copy"
done

assert_release_source_unchanged "双架构最终文件切换前"
bold "▶ 成套备份、切换并复验正式双架构 DMG"
for arch in "${ARCHITECTURES[@]}"; do
  final_path="$(final_dmg_path "$arch")"
  backup_path="$(backup_dmg_path "$arch")"
  rm -f "$backup_path"
  if [[ -e "$final_path" || -L "$final_path" ]]; then
    touch "$PUBLISH_STATE_DIR/$arch.backed-up"
    mv "$final_path" "$backup_path"
  fi
done
for arch in "${ARCHITECTURES[@]}"; do
  final_path="$(final_dmg_path "$arch")"
  touch "$PUBLISH_STATE_DIR/$arch.published"
  mv "$(new_dmg_path "$arch")" "$final_path"
  if [[ ! -f "$final_path" || -L "$final_path" ]]; then
    echo "错误：$arch 最终 DMG 不是普通文件：$final_path" >&2
    exit 1
  fi
done
for arch in "${ARCHITECTURES[@]}"; do
  verify_release_dmg "$(final_dmg_path "$arch")" "$arch" "$arch final asset"
done

assert_release_source_unchanged "双架构最终产物验证后"
rm -rf "$DIST_STAGING_DIR"
DIST_STAGING_DIR=""
RELEASE_SUCCEEDED=1

echo ""
bold "✅ 双架构发布产物完成"
for arch in "${ARCHITECTURES[@]}"; do
  final_path="$(final_dmg_path "$arch")"
  echo "Release 文件：$final_path"
  ls -lh "$final_path"
done

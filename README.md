<div align="center">

<img src="docs/icon-256.png" width="128" alt="Y-Keys 图标" />

# Y-Keys

**快速双击左 Command，立刻看到当前 App 和系统可用快捷键。**

一个轻量、常驻菜单栏的 macOS 快捷键速查工具。它会在你当前工作的 App 上方显示一层深色快捷键面板；按住 `⌘`、`⌥`、`⌃`、`⇧` 等按键时，所有包含这些按键的快捷键会实时高亮。

![macOS](https://img.shields.io/badge/macOS-13.0+-111827?logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white)
![AppKit](https://img.shields.io/badge/AppKit-native-0EA5E9)

<img src="docs/hero.svg" width="680" alt="Y-Keys 快捷键面板预览" />

</div>

## 功能

| 功能 | 体验 |
| --- | --- |
| 左 Command 双击呼出 | 快速连按两次左侧 `⌘`，在当前屏幕中央显示快捷键面板。 |
| 当前 App 快捷键 | 通过 Accessibility API 读取前台 App 菜单栏里的快捷键。 |
| 系统快捷键 | 内置常用系统快捷键，覆盖聚焦、截屏、辅助功能、输入法和程序坞。 |
| 单屏完整展示 | 面板会按可用屏幕空间自动拆成多列并缩放，不提供滚动条，尽量一次展示所有快捷键。 |
| 按键实时高亮 | 按住 `⌘` 会只高亮每一行里的 `⌘` 键帽，继续按 `⌥` 会同时高亮 `⌥` 键帽。 |
| 轻量关闭规则 | 点击快捷键行会保持面板；点击背景、面板外区域或按下不属于任何快捷键组合的键会关闭面板。 |
| 原生菜单栏工具 | 默认不显示 Dock 图标，不打断当前工作流。 |

## 安装和构建

需要 macOS 13+ 和 Xcode Command Line Tools。当前仓库默认面向 Apple Silicon 构建。

```zsh
git clone https://github.com/Rainchen537/Y-Keys.git
cd Y-Keys
./icon/make_icns.sh
./build.sh
./make_dmg.sh
./install_app.sh
```

构建产物位于：

```text
build/Y-Keys.app
dist/Y-Keys.dmg
```

## 权限说明

Y-Keys 需要 **Accessibility / 辅助功能** 权限：

| 权限 | 用途 |
| --- | --- |
| Accessibility | 监听左 Command 双击、读取当前 App 菜单快捷键、判断按键组合高亮。 |

授权路径：

```text
System Settings
→ Privacy & Security
→ Accessibility
→ 勾选 Y-Keys
```

如果系统设置里显示已授权但 App 仍无法监听，可以运行：

```zsh
./reset_accessibility.sh
```

然后重新打开 Y-Keys 并再次授权。

## 技术实现

```text
Swift
AppKit
Accessibility API / AXUIElement
CoreGraphics CGEventTap
NSPanel / NSVisualEffectView / NSStatusItem
```

当前版本优先读取当前 App 的菜单栏快捷键；系统快捷键先以内置清单维护，后续可以继续扩展到读取 `com.apple.symbolichotkeys` 并映射用户自定义项。

## 与 Y 系列的统一性

Y-Keys 延续了 Y-Clip 和 Y-Dock 的产品方向：

- 菜单栏常驻，不占 Dock。
- 原生 Swift + AppKit，无第三方依赖。
- 深色毛玻璃浮层、克制圆角、蓝色强调态。
- App 图标抽象为立体 `Command` 键帽，表达核心触发方式；浅色 macOS 底板、深蓝主体、粉紫到橙色渐变延续 Y-Clip / Y-Dock 的视觉家族。

## 许可

MIT License

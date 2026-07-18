# Y-Keys Agent 规范

本项目遵守父目录 `../AGENTS.md` 和 `../Y_PROJECT_APP_STANDARD.me`。开始任务前必须阅读本文件、`AI_CONTEXT.me`、`CHANGELOG.me`、`CHANGELOG.md` 和 `README.md`。

## 项目身份

- GitHub：`https://github.com/Rainchen537/Y-Keys`
- 默认分支：`main`
- Bundle ID：`com.lixingchen.YKeys`
- 可执行文件：`YKeys`
- 安装路径：`/Applications/Y-Keys.app`
- 版本位置：`Info.plist` 的 `CFBundleShortVersionString` 和 `CFBundleVersion`
- 正式 DMG：`dist/Y-Keys.dmg`；上传 Release 时使用版本化名称 `Y-Keys-vX.Y.Z.dmg`

## 每次任务的发布闭环

1. 运行 `./build.sh` 并验证快捷键扫描和浮层行为。
2. 更新版本、构建号、README 和两个 changelog。
3. 运行 `./release.sh`，确认 App/DMG 已签名、公证、staple 且 Gatekeeper 验证通过。
4. 提交源码，创建并推送 `vX.Y.Z` tag，在 `Rainchen537/Y-Keys` 创建 Release 并上传版本化 DMG。
5. 退出 `YKeys`，从最终 DMG 覆盖安装 `/Applications/Y-Keys.app`，验证签名和版本后启动。
6. 验证菜单栏、双击左 Command、当前 App 快捷键扫描、修饰键高亮、设置页和辅助功能权限。

自动更新尚未接入时也不能跳过 GitHub Release 和本机覆盖安装。

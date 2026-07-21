# Y-Keys Agent 规范

本项目遵守父目录 `../AGENTS.md` 和 `../Y_PROJECT_APP_STANDARD.me`。开始任务前阅读本文件、`AI_CONTEXT.me`、`CHANGELOG.me`、`CHANGELOG.md` 和 `README.md`。

## 项目身份

- GitHub：`https://github.com/Rainchen537/Y-Keys`
- 默认分支：`main`
- Bundle ID：`com.lixingchen.YKeys`
- 可执行文件：`YKeys`
- 安装路径：`/Applications/Y-Keys.app`
- 版本位置：`Info.plist` 的 `CFBundleShortVersionString` 和 `CFBundleVersion`
- 正式 DMG：`dist/Y-Keys.dmg`；Release 资产使用 `Y-Keys-vX.Y.Z.dmg`

## 构建、验证与发布

- 只在 Y-Keys 实际被修改时处理本项目；其他 App 或未同步进本仓库的共享框架变化不触发 Y-Keys 构建和发布。
- 本地构建使用 `./build.sh`；只验证本次受影响的快捷键扫描、浮层、菜单栏、设置或权限路径。
- 需要正式分发时递增版本和构建号，更新 README 与 changelog，并以 `./release.sh` 生成新的正式产物。
- 正式发布产物必须完成 Developer ID 签名、公证、staple 和 Gatekeeper 验证；从最终 DMG 覆盖安装后，仅对本次改动和必要核心入口做冒烟检查。

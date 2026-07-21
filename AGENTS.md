# Y-Keys Agent 规范

本项目遵守父目录 `../AGENTS.md` 和 `../Y_PROJECT_APP_STANDARD.me`。开始任务前阅读本文件、`AI_CONTEXT.me`、`CHANGELOG.me`、`CHANGELOG.md` 和 `README.md`。

## 项目身份

- GitHub：`https://github.com/Rainchen537/Y-Keys`
- 默认分支：`main`
- Bundle ID：`com.lixingchen.YKeys`
- 可执行文件：`YKeys`
- 安装路径：`/Applications/Y-Keys.app`
- 版本位置：`Info.plist` 的 `CFBundleShortVersionString` 和 `CFBundleVersion`
- 本地默认 DMG：`dist/Y-Keys.dmg`；正式 Release 必须同时提供 `Y-Keys-vX.Y.Z-arm64.dmg`（Apple Silicon）与 `Y-Keys-vX.Y.Z-x86_64.dmg`（Intel）。

## 构建、验证与发布

- 只在 Y-Keys 实际被修改时处理本项目；其他 App 或未同步进本仓库的共享框架变化不触发 Y-Keys 构建和发布。
- 本地构建使用 `./build.sh`；`TARGET_ARCH` 只允许 `arm64` 或 `x86_64`，默认 `arm64`，并行或隔离验证时通过 `BUILD_DIR_OVERRIDE` 指定独立输出目录。每次构建必须在自身临时目录生成图标，不得改写或争用仓库内永久图标产物。
- 需要正式分发时递增版本和构建号，更新 README 与 changelog，并以 `./release.sh` 一次生成两份 thin 架构正式产物。
- arm64 与 x86_64 必须分别独立 build/stage，并各自完成 Developer ID 签名、App/DMG 公证、staple、Gatekeeper、镜像挂载和 thin 架构验证；从匹配本机架构的最终 DMG 覆盖安装后，仅对本次改动和必要核心入口做冒烟检查。

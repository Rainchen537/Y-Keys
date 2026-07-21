import AppKit

final class SettingsWindowController: NSObject {
    private let contentController: SettingsContentController
    private let windowController: YSettingWindowController

    init(isKeyboardListenerRunning: @escaping () -> Bool, onShowShortcuts: @escaping () -> Void) {
        contentController = SettingsContentController(
            isKeyboardListenerRunning: isKeyboardListenerRunning,
            onShowShortcuts: onShowShortcuts
        )

        let descriptor = YSettingAppDescriptor(
            displayName: AppBranding.displayName,
            subtitle: "快捷键速查",
            version: YSettingUI.appVersionString(),
            icon: YSettingUI.bundledAppIcon()
        )
        let items = YSettingStandardSidebar.all
        let contentController = contentController
        windowController = YSettingWindowController(
            descriptor: descriptor,
            sidebarItems: items,
            initialIdentifier: "general"
        ) { identifier in
            contentController.makeContent(for: identifier)
        }

        super.init()

        windowController.onClose = { [weak self] in
            self?.contentController.stopPresentation()
        }
    }

    func show() {
        contentController.refreshForPresentation()
        contentController.startPresentation()
        windowController.showAndActivate()
    }

    func close() {
        windowController.close()
    }

    func selectItem(_ identifier: String) {
        windowController.selectItem(identifier)
    }
}

private final class SettingsContentController {
    private let triggerPill = YSettingPill(text: "双击左 ⌘", tone: .accent)
    private let accessibilityStatusPill = YSettingPill(text: "检测中", tone: .neutral)
    private let inputMonitoringStatusPill = YSettingPill(text: "检测中", tone: .neutral)
    private let keyboardListenerStatusPill = YSettingPill(text: "检测中", tone: .neutral)
    private let runtimeIdentityPill = YSettingPill(text: "检测中", tone: .neutral)
    private let versionPill = YSettingPill(text: YSettingUI.appVersionString(), tone: .neutral)
    private let updateStatusPill = YSettingPill(text: "尚未检查", tone: .neutral)
    private let updateChecker = UpdateChecker()
    private let isKeyboardListenerRunning: () -> Bool
    private let onShowShortcuts: () -> Void
    private lazy var showShortcutsButton = makeButton(title: "显示快捷键", symbolName: "keyboard", role: .primary, action: #selector(showShortcuts))
    private lazy var requestAccessibilityButton = makeButton(title: "请求", symbolName: "hand.raised", action: #selector(requestAccessibility))
    private lazy var openAccessibilityButton = makeButton(title: "打开", symbolName: "gearshape", action: #selector(openAccessibilitySettings))
    private lazy var requestInputMonitoringButton = makeButton(title: "请求", symbolName: "keyboard", action: #selector(requestInputMonitoring))
    private lazy var openInputMonitoringButton = makeButton(title: "打开", symbolName: "gearshape", action: #selector(openInputMonitoringSettings))
    private lazy var switchToInstalledButton = makeButton(title: "切换到安装版", symbolName: "arrow.right.app", role: .primary, action: #selector(switchToInstalledCopy))
    private lazy var resetAccessibilityButton = makeButton(title: "刷新记录", symbolName: "arrow.counterclockwise", action: #selector(resetAccessibility))
    private lazy var recheckButton = makeButton(title: "重新检测", symbolName: "checkmark.shield", action: #selector(recheckPermissions))
    private lazy var githubButton = makeButton(title: "GitHub", symbolName: "chevron.left.forwardslash.chevron.right", role: .link, action: #selector(openGitHub))
    private lazy var checkUpdateButton = makeButton(title: "检查更新", symbolName: "arrow.triangle.2.circlepath", role: .primary, action: #selector(checkForUpdates))
    private lazy var releasesButton = makeButton(title: "打开 Releases", symbolName: "arrow.down.circle", role: .link, action: #selector(openReleases))
    private var isObservingApplicationActivation = false

    init(isKeyboardListenerRunning: @escaping () -> Bool, onShowShortcuts: @escaping () -> Void) {
        self.isKeyboardListenerRunning = isKeyboardListenerRunning
        self.onShowShortcuts = onShowShortcuts
        refreshPermissionStatus()
    }

    deinit {
        stopPresentation()
    }

    func makeContent(for identifier: String) -> NSView {
        switch identifier {
        case "features":
            return featuresContent()
        case "permissions":
            return permissionsContent()
        case "updates":
            return updatesContent()
        case "about":
            return aboutContent()
        default:
            return generalContent()
        }
    }

    func refreshForPresentation() {
        refreshPermissionStatus()
    }

    func startPresentation() {
        if !isObservingApplicationActivation {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(recheckPermissions),
                name: NSApplication.didBecomeActiveNotification,
                object: nil
            )
            isObservingApplicationActivation = true
        }
    }

    func stopPresentation() {
        if isObservingApplicationActivation {
            NotificationCenter.default.removeObserver(self, name: NSApplication.didBecomeActiveNotification, object: nil)
            isObservingApplicationActivation = false
        }
    }

    private func generalContent() -> NSView {
        let stack = YSettingUI.makeContentStack(
            title: "通用",
            symbolName: "gearshape"
        )

        stack.addArrangedSubview(YSettingSectionView(
            title: "呼出方式",
            symbolName: "keyboard",
            views: [
                YSettingUI.row(title: "快捷触发", trailingView: triggerPill),
                YSettingUI.row(title: "立即查看", trailingView: showShortcutsButton)
            ]
        ))

        return stack
    }

    private func featuresContent() -> NSView {
        let stack = YSettingUI.makeContentStack(
            title: "功能",
            symbolName: "slider.horizontal.3"
        )

        stack.addArrangedSubview(YSettingSectionView(
            title: "内容来源",
            symbolName: "command.square",
            views: [
                YSettingUI.row(title: "当前 App 快捷键", trailingView: YSettingPill(text: "菜单栏读取", tone: .accent)),
                YSettingUI.row(title: "系统快捷键", trailingView: YSettingPill(text: "内置清单", tone: .neutral))
            ]
        ))

        stack.addArrangedSubview(YSettingSectionView(
            title: "显示行为",
            symbolName: "eye",
            views: [
                YSettingUI.row(title: "修饰键高亮", trailingView: YSettingPill(text: "实时", tone: .success)),
                YSettingUI.row(title: "前台 App 跟随", trailingView: YSettingPill(text: "自动", tone: .accent))
            ]
        ))

        return stack
    }

    private func permissionsContent() -> NSView {
        let stack = YSettingUI.makeContentStack(
            title: "权限",
            symbolName: "lock.shield"
        )

        stack.addArrangedSubview(YSettingSectionView(
            title: "键盘监听权限",
            symbolName: "keyboard.badge.ellipsis",
            views: [
                YSettingUI.row(
                    title: "当前副本",
                    trailingView: YSettingUI.horizontal([runtimeIdentityPill, switchToInstalledButton])
                ),
                YSettingUI.row(
                    title: "辅助功能",
                    trailingView: YSettingUI.horizontal([accessibilityStatusPill, requestAccessibilityButton, openAccessibilityButton])
                ),
                YSettingUI.row(
                    title: "输入监控",
                    trailingView: YSettingUI.horizontal([inputMonitoringStatusPill, requestInputMonitoringButton, openInputMonitoringButton])
                ),
                YSettingUI.row(title: "键盘监听", trailingView: keyboardListenerStatusPill),
                YSettingUI.row(
                    title: "权限修复",
                    trailingView: YSettingUI.horizontal([resetAccessibilityButton, recheckButton])
                )
            ]
        ))

        return stack
    }

    private func aboutContent() -> NSView {
        let stack = YSettingUI.makeContentStack(
            title: "关于",
            symbolName: "info.circle"
        )

        stack.addArrangedSubview(YSettingSectionView(
            title: "Y-Project",
            symbolName: "app.connected.to.app.below.fill",
            views: [
                YSettingUI.row(title: "产品定位", trailingView: YSettingPill(text: "快捷键速查", tone: .accent)),
                YSettingUI.row(title: "项目主页", trailingView: githubButton)
            ]
        ))

        return stack
    }

    private func updatesContent() -> NSView {
        let stack = YSettingUI.makeContentStack(
            title: "更新",
            symbolName: "arrow.triangle.2.circlepath"
        )

        stack.addArrangedSubview(YSettingSectionView(
            title: "版本更新",
            symbolName: "sparkles",
            views: [
                YSettingUI.row(title: "当前版本", trailingView: versionPill),
                YSettingUI.row(title: "发布渠道", trailingView: YSettingPill(text: "GitHub Release", tone: .accent)),
                YSettingUI.row(title: "下载方式", trailingView: YSettingPill(text: "手动选择架构", tone: .neutral)),
                YSettingUI.row(title: "Apple Silicon", trailingView: YSettingPill(text: "arm64 DMG", tone: .accent)),
                YSettingUI.row(title: "Intel", trailingView: YSettingPill(text: "x86_64 DMG", tone: .neutral)),
                YSettingUI.row(title: "手动检查", trailingView: YSettingUI.horizontal([updateStatusPill, checkUpdateButton])),
                YSettingUI.row(title: "下载页面", trailingView: releasesButton)
            ]
        ))

        return stack
    }

    private func makeButton(
        title: String,
        symbolName: String,
        role: YSettingButtonRole = .secondary,
        action: Selector
    ) -> NSButton {
        YSettingUI.makeButton(title: title, symbolName: symbolName, role: role, target: self, action: action)
    }

    private func refreshPermissionStatus() {
        let isInstalledCopy = YSettingRuntimeIdentity.isSignedInstalledCopy(
            expectedPath: AppBranding.installedApplicationPath,
            expectedTeamIdentifier: AppBranding.teamIdentifier,
            expectedBundleIdentifier: AppBranding.bundleIdentifier
        )
        let hasInstalledCopy = YSettingRuntimeIdentity.isValidSignedApplication(
            atPath: AppBranding.installedApplicationPath,
            expectedBundleIdentifier: AppBranding.bundleIdentifier,
            expectedTeamIdentifier: AppBranding.teamIdentifier
        )
        runtimeIdentityPill.setText(isInstalledCopy ? "正式安装版" : "开发副本", tone: isInstalledCopy ? .success : .warning)
        switchToInstalledButton.isHidden = isInstalledCopy
        switchToInstalledButton.isEnabled = hasInstalledCopy

        let accessibilityTrusted = AccessibilityPermission.isTrusted(prompt: false)
        if accessibilityTrusted {
            accessibilityStatusPill.setText("已开启", tone: .success)
        } else if !isInstalledCopy, hasInstalledCopy {
            accessibilityStatusPill.setText("当前副本未授权", tone: .warning)
        } else {
            accessibilityStatusPill.setText("未开启", tone: .warning)
        }
        requestAccessibilityButton.isEnabled = !accessibilityTrusted

        let inputMonitoringTrusted = AccessibilityPermission.isInputMonitoringTrusted()
        if inputMonitoringTrusted {
            inputMonitoringStatusPill.setText("已开启", tone: .success)
        } else if !isInstalledCopy, hasInstalledCopy {
            inputMonitoringStatusPill.setText("当前副本未授权", tone: .warning)
        } else {
            inputMonitoringStatusPill.setText("未开启", tone: .warning)
        }
        requestInputMonitoringButton.isEnabled = !inputMonitoringTrusted

        let listenerRunning = isKeyboardListenerRunning()
        keyboardListenerStatusPill.setText(listenerRunning ? "运行中" : "未运行", tone: listenerRunning ? .success : .warning)
    }

    @objc private func showShortcuts() {
        onShowShortcuts()
    }

    @objc private func requestAccessibility() {
        AccessibilityPermission.requestPrompt()
        refreshPermissionStatus()
    }

    @objc private func openAccessibilitySettings() {
        AccessibilityPermission.requestPrompt()
        AccessibilityPermission.openSettings()
    }

    @objc private func requestInputMonitoring() {
        AccessibilityPermission.requestInputMonitoring()
        refreshPermissionStatus()
    }

    @objc private func openInputMonitoringSettings() {
        AccessibilityPermission.openInputMonitoringSettings()
    }

    @objc private func switchToInstalledCopy() {
        do {
            try YSettingRuntimeIdentity.relaunchInstalledApplication(
                atPath: AppBranding.installedApplicationPath,
                expectedBundleIdentifier: AppBranding.bundleIdentifier,
                expectedTeamIdentifier: AppBranding.teamIdentifier
            )
        } catch {
            showAlert(title: "无法切换到正式安装版", message: error.localizedDescription)
        }
    }

    @objc private func resetAccessibility() {
        resetAccessibilityButton.isEnabled = false
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try AccessibilityPermission.resetAuthorization()
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.resetAccessibilityButton.isEnabled = true
                    self.refreshPermissionStatus()
                    self.showAlert(
                        title: "已刷新权限记录",
                        message: "请在系统设置中重新开启 Y-Keys 的辅助功能和输入监控权限，然后从 \(AppBranding.installedApplicationPath) 重启正式安装版。"
                    )
                }
            } catch {
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.resetAccessibilityButton.isEnabled = true
                    self.refreshPermissionStatus()
                    self.showAlert(title: "刷新失败", message: error.localizedDescription)
                }
            }
        }
    }

    @objc private func recheckPermissions() {
        refreshPermissionStatus()
    }

    @objc private func checkForUpdates() {
        checkUpdateButton.isEnabled = false
        updateStatusPill.setText("检查中", tone: .neutral)
        updateChecker.check { [weak self] status in
            guard let self else { return }
            checkUpdateButton.isEnabled = true
            switch status {
            case let .upToDate(version):
                updateStatusPill.setText("已是最新版 \(version)", tone: .success)
            case let .available(version):
                updateStatusPill.setText("发现 \(version)", tone: .accent)
            case let .failed(message):
                updateStatusPill.setText("检查失败", tone: .warning)
                showAlert(title: "检查更新失败", message: message)
            }
        }
    }

    @objc private func openGitHub() {
        NSWorkspace.shared.open(AppBranding.repositoryURL)
    }

    @objc private func openReleases() {
        NSWorkspace.shared.open(AppBranding.repositoryURL.appendingPathComponent("releases/latest"))
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
}

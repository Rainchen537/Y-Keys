import AppKit

final class SettingsWindowController: NSObject {
    private let contentController: SettingsContentController
    private let windowController: YSettingWindowController

    init(onShowShortcuts: @escaping () -> Void) {
        contentController = SettingsContentController(onShowShortcuts: onShowShortcuts)

        let descriptor = YSettingAppDescriptor(
            displayName: AppBranding.displayName,
            subtitle: "快捷键速查",
            version: YSettingUI.appVersionString(),
            icon: YSettingUI.bundledAppIcon()
        )
        let items = [
            YSettingSidebarItem("general", title: "通用", symbolName: "command"),
            YSettingSidebarItem("permissions", title: "权限", symbolName: "lock.shield"),
            YSettingSidebarItem("about", title: "关于", symbolName: "info.circle")
        ]
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
}

private final class SettingsContentController {
    private let triggerPill = YSettingPill(text: "双击左 ⌘", tone: .accent)
    private let accessibilityStatusPill = YSettingPill(text: "检测中", tone: .neutral)
    private let versionPill = YSettingPill(text: YSettingUI.appVersionString(), tone: .neutral)
    private let onShowShortcuts: () -> Void
    private lazy var showShortcutsButton = makeButton(title: "显示快捷键", symbolName: "keyboard", role: .primary, action: #selector(showShortcuts))
    private lazy var requestAccessibilityButton = makeButton(title: "请求", symbolName: "hand.raised", action: #selector(requestAccessibility))
    private lazy var openAccessibilityButton = makeButton(title: "打开", symbolName: "gearshape", action: #selector(openAccessibilitySettings))
    private lazy var resetAccessibilityButton = makeButton(title: "刷新记录", symbolName: "arrow.counterclockwise", action: #selector(resetAccessibility))
    private lazy var recheckButton = makeButton(title: "重新检测", symbolName: "checkmark.shield", action: #selector(recheckPermissions))
    private lazy var githubButton = makeButton(title: "GitHub", symbolName: "chevron.left.forwardslash.chevron.right", role: .link, action: #selector(openGitHub))
    private var permissionRefreshTimer: Timer?
    private var isObservingApplicationActivation = false

    init(onShowShortcuts: @escaping () -> Void) {
        self.onShowShortcuts = onShowShortcuts
        refreshPermissionStatus()
    }

    deinit {
        stopPresentation()
    }

    func makeContent(for identifier: String) -> NSView {
        switch identifier {
        case "permissions":
            return permissionsContent()
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
        startPermissionRefreshTimer()
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
        permissionRefreshTimer?.invalidate()
        permissionRefreshTimer = nil
        if isObservingApplicationActivation {
            NotificationCenter.default.removeObserver(self, name: NSApplication.didBecomeActiveNotification, object: nil)
            isObservingApplicationActivation = false
        }
    }

    private func generalContent() -> NSView {
        let stack = YSettingUI.makeContentStack(
            title: "通用",
            symbolName: "command",
            subtitle: "Y-Keys 常驻菜单栏，通过左 Command 双击呼出当前 App 和系统快捷键。"
        )

        let hint = YSettingUI.secondaryLabel("面板会读取前台 App 菜单栏快捷键，并在按住 Command、Option、Control、Shift 时实时高亮对应键帽。")

        stack.addArrangedSubview(YSettingSectionView(
            title: "呼出方式",
            symbolName: "keyboard",
            views: [
                YSettingUI.row(title: "快捷触发", trailingView: triggerPill),
                YSettingUI.row(title: "立即查看", trailingView: showShortcutsButton),
                hint
            ]
        ))

        return stack
    }

    private func permissionsContent() -> NSView {
        let stack = YSettingUI.makeContentStack(
            title: "权限",
            symbolName: "lock.shield",
            subtitle: "Y-Keys 需要辅助功能权限来监听左 Command 双击和读取当前 App 菜单快捷键。"
        )

        let hint = YSettingUI.secondaryLabel("如果系统设置里看起来已开启但 App 仍无法监听，可以刷新权限记录后重新勾选 Y-Keys。")

        stack.addArrangedSubview(YSettingSectionView(
            title: "辅助功能",
            symbolName: "accessibility",
            views: [
                YSettingUI.row(
                    title: "权限状态",
                    trailingView: YSettingUI.horizontal([accessibilityStatusPill, requestAccessibilityButton, openAccessibilityButton])
                ),
                YSettingUI.row(
                    title: "权限修复",
                    trailingView: YSettingUI.horizontal([resetAccessibilityButton, recheckButton])
                ),
                hint
            ]
        ))

        return stack
    }

    private func aboutContent() -> NSView {
        let stack = YSettingUI.makeContentStack(
            title: "关于",
            symbolName: "info.circle",
            subtitle: "版本和项目主页。"
        )

        stack.addArrangedSubview(YSettingSectionView(
            title: "版本",
            symbolName: "sparkles",
            views: [
                YSettingUI.row(title: "当前版本", trailingView: versionPill),
                YSettingUI.row(title: "项目主页", trailingView: githubButton)
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

    private func startPermissionRefreshTimer() {
        permissionRefreshTimer?.invalidate()
        permissionRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.refreshPermissionStatus()
        }
    }

    private func refreshPermissionStatus() {
        let trusted = AccessibilityPermission.isTrusted(prompt: false)
        accessibilityStatusPill.setText(trusted ? "已开启" : "未开启", tone: trusted ? .success : .warning)
        requestAccessibilityButton.isEnabled = !trusted
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

    @objc private func resetAccessibility() {
        do {
            try AccessibilityPermission.resetAuthorization()
            refreshPermissionStatus()
            showAlert(
                title: "已刷新权限记录",
                message: "请在系统设置中重新勾选 Y-Keys，然后重启 App。"
            )
        } catch {
            showAlert(title: "刷新失败", message: error.localizedDescription)
        }
    }

    @objc private func recheckPermissions() {
        refreshPermissionStatus()
    }

    @objc private func openGitHub() {
        NSWorkspace.shared.open(AppBranding.repositoryURL)
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

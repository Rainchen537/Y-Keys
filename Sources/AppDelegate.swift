import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private struct PermissionWarningState: Equatable {
        let accessibilityTrusted: Bool
        let inputMonitoringTrusted: Bool
        let isInstalledCopy: Bool
        let hasInstalledCopy: Bool
    }

    private let keyboardMonitor = KeyboardEventMonitor()
    private let shortcutScanner = ShortcutScanner()
    private let overlayController = ShortcutOverlayController()
    private lazy var settingsWindowController = SettingsWindowController(
        isKeyboardListenerRunning: { [weak self] in
            self?.keyboardMonitor.isRunning == true
        },
        onShowShortcuts: { [weak self] in
            self?.showShortcuts()
        }
    )
    private var statusItem: NSStatusItem?
    private var lastActivatedExternalApplication: NSRunningApplication?
    private var lastPresentedPermissionWarningState: PermissionWarningState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupExternalApplicationTracking()
        setupKeyboardMonitor()
        startKeyboardMonitor()
        showSettingsForPreviewIfRequested()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard !isSettingsPreviewRequested, !keyboardMonitor.isRunning else { return }
        startKeyboardMonitor()
    }

    func applicationWillTerminate(_ notification: Notification) {
        keyboardMonitor.stop()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = StatusBarIcon.makeImage()
        item.button?.imagePosition = .imageOnly
        item.button?.toolTip = AppBranding.displayName

        item.menu = YProjectStatusMenu.make(
            target: self,
            openSettingsAction: #selector(openSettings),
            quitAction: #selector(quit),
            appName: AppBranding.displayName
        )
        statusItem = item
    }

    private func setupExternalApplicationTracking() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        notificationCenter.addObserver(
            self,
            selector: #selector(workspaceApplicationDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(workspaceApplicationDidTerminate(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
        rememberExternalApplication(NSWorkspace.shared.frontmostApplication)
    }

    @objc private func workspaceApplicationDidActivate(_ notification: Notification) {
        rememberExternalApplication(runningApplication(from: notification))
    }

    @objc private func workspaceApplicationDidTerminate(_ notification: Notification) {
        guard
            let terminatedApplication = runningApplication(from: notification),
            terminatedApplication.processIdentifier == lastActivatedExternalApplication?.processIdentifier
        else {
            return
        }

        lastActivatedExternalApplication = nil
        rememberExternalApplication(NSWorkspace.shared.frontmostApplication)
    }

    private func runningApplication(from notification: Notification) -> NSRunningApplication? {
        notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
    }

    private func rememberExternalApplication(_ application: NSRunningApplication?) {
        guard isValidShortcutTarget(application) else { return }
        lastActivatedExternalApplication = application
    }

    private func shortcutTarget() -> NSRunningApplication? {
        if let frontmostApplication = NSWorkspace.shared.frontmostApplication,
           isValidShortcutTarget(frontmostApplication) {
            lastActivatedExternalApplication = frontmostApplication
            return frontmostApplication
        }

        guard isValidShortcutTarget(lastActivatedExternalApplication) else {
            lastActivatedExternalApplication = nil
            return nil
        }
        return lastActivatedExternalApplication
    }

    private func isValidShortcutTarget(_ application: NSRunningApplication?) -> Bool {
        guard let application, !application.isTerminated else { return false }
        guard application.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return false }
        return application.bundleIdentifier != AppBranding.bundleIdentifier
    }

    private func setupKeyboardMonitor() {
        keyboardMonitor.onDoubleTapLeftCommand = { [weak self] in
            self?.showShortcuts()
        }
        keyboardMonitor.onInputStateChanged = { [weak self] state in
            self?.overlayController.updatePressedSymbols(state.symbols)
        }
        keyboardMonitor.onKeyDown = { [weak self] state, _ in
            guard let self, self.overlayController.isVisible else { return }
            if !self.overlayController.hasShortcutMatching(state.symbols) {
                self.overlayController.close()
            }
        }
    }

    private func startKeyboardMonitor() {
        do {
            try keyboardMonitor.start()
            lastPresentedPermissionWarningState = nil
        } catch {
            if !isSettingsPreviewRequested {
                showPermissionWarningIfNeeded(message: error.localizedDescription)
            }
        }
    }

    @objc private func openSettings() {
        rememberExternalApplication(NSWorkspace.shared.frontmostApplication)
        settingsWindowController.show()
    }

    private var isSettingsPreviewRequested: Bool {
        ProcessInfo.processInfo.environment["Y_SETTINGS_PREVIEW"] == "1"
    }

    private func showSettingsForPreviewIfRequested() {
        guard isSettingsPreviewRequested else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self else { return }
            if let identifier = ProcessInfo.processInfo.environment["Y_SETTINGS_PREVIEW_SECTION"] {
                settingsWindowController.selectItem(identifier)
            }
            openSettings()
        }
    }

    private func showShortcuts() {
        let catalog = shortcutScanner.scan(application: shortcutTarget())
        overlayController.show(catalog: catalog)

        if catalog.needsAccessibilityPermission {
            AccessibilityPermission.requestPrompt()
        }
    }

    @objc private func openAccessibilitySettings() {
        AccessibilityPermission.requestPrompt()
        AccessibilityPermission.openSettings()
    }

    @objc private func openGitHub() {
        NSWorkspace.shared.open(AppBranding.repositoryURL)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showPermissionWarningIfNeeded(message: String) {
        let accessibilityTrusted = AccessibilityPermission.isTrusted(prompt: false)
        let inputMonitoringTrusted = AccessibilityPermission.isInputMonitoringTrusted()
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
        let warningState = PermissionWarningState(
            accessibilityTrusted: accessibilityTrusted,
            inputMonitoringTrusted: inputMonitoringTrusted,
            isInstalledCopy: isInstalledCopy,
            hasInstalledCopy: hasInstalledCopy
        )
        guard warningState != lastPresentedPermissionWarningState else { return }
        lastPresentedPermissionWarningState = warningState

        DispatchQueue.main.async { [weak self] in
            guard let self, self.lastPresentedPermissionWarningState == warningState else { return }
            NSApp.activate(ignoringOtherApps: true)

            let alert = NSAlert()
            alert.alertStyle = .informational

            if !isInstalledCopy, hasInstalledCopy {
                alert.messageText = "当前运行副本与系统授权不匹配"
                alert.informativeText = "\(message)\n\n系统权限会绑定 App 的签名身份和启动副本。请切换到 \(AppBranding.installedApplicationPath)，不要直接运行 DerivedData 或可执行文件。"
                alert.addButton(withTitle: "切换到安装版")
                alert.addButton(withTitle: "打开权限设置")
                alert.addButton(withTitle: "稍后")

                switch alert.runModal() {
                case .alertFirstButtonReturn:
                    do {
                        try YSettingRuntimeIdentity.relaunchInstalledApplication(
                            atPath: AppBranding.installedApplicationPath,
                            expectedBundleIdentifier: AppBranding.bundleIdentifier,
                            expectedTeamIdentifier: AppBranding.teamIdentifier
                        )
                    } catch {
                        self.showPlainAlert(title: "无法切换到正式安装版", message: error.localizedDescription)
                    }
                case .alertSecondButtonReturn:
                    self.openMissingPermissionSettings(
                        accessibilityTrusted: accessibilityTrusted,
                        inputMonitoringTrusted: inputMonitoringTrusted
                    )
                default:
                    break
                }
                return
            }

            if !accessibilityTrusted && !inputMonitoringTrusted {
                alert.messageText = "Y-Keys 需要辅助功能和输入监控权限"
                alert.informativeText = "\(message)\n\n请在 System Settings → Privacy & Security 中分别开启 Accessibility 和 Input Monitoring。"
                alert.addButton(withTitle: "打开辅助功能")
                alert.addButton(withTitle: "打开输入监控")
                alert.addButton(withTitle: "稍后")

                switch alert.runModal() {
                case .alertFirstButtonReturn:
                    AccessibilityPermission.requestPrompt()
                    AccessibilityPermission.openSettings()
                case .alertSecondButtonReturn:
                    AccessibilityPermission.requestInputMonitoring()
                    AccessibilityPermission.openInputMonitoringSettings()
                default:
                    break
                }
            } else if !accessibilityTrusted {
                alert.messageText = "Y-Keys 需要辅助功能权限"
                alert.informativeText = "\(message)\n\n路径：System Settings → Privacy & Security → Accessibility。"
                alert.addButton(withTitle: "打开辅助功能")
                alert.addButton(withTitle: "稍后")
                if alert.runModal() == .alertFirstButtonReturn {
                    AccessibilityPermission.requestPrompt()
                    AccessibilityPermission.openSettings()
                }
            } else if !inputMonitoringTrusted {
                alert.messageText = "Y-Keys 需要输入监控权限"
                alert.informativeText = "\(message)\n\n路径：System Settings → Privacy & Security → Input Monitoring。"
                alert.addButton(withTitle: "打开输入监控")
                alert.addButton(withTitle: "稍后")
                if alert.runModal() == .alertFirstButtonReturn {
                    AccessibilityPermission.requestInputMonitoring()
                    AccessibilityPermission.openInputMonitoringSettings()
                }
            } else {
                alert.messageText = "权限需要重新载入"
                alert.informativeText = "辅助功能和输入监控均显示已开启，但当前进程仍无法监听键盘。请从 \(AppBranding.installedApplicationPath) 重启正式安装版；若仍失败，可在设置的权限页刷新 Y-Keys 的权限记录。"
                alert.addButton(withTitle: "重启 Y-Keys")
                alert.addButton(withTitle: "打开输入监控")
                alert.addButton(withTitle: "稍后")

                switch alert.runModal() {
                case .alertFirstButtonReturn:
                    do {
                        try YSettingRuntimeIdentity.relaunchInstalledApplication(
                            atPath: AppBranding.installedApplicationPath,
                            expectedBundleIdentifier: AppBranding.bundleIdentifier,
                            expectedTeamIdentifier: AppBranding.teamIdentifier
                        )
                    } catch {
                        self.showPlainAlert(title: "无法重启正式安装版", message: error.localizedDescription)
                    }
                case .alertSecondButtonReturn:
                    AccessibilityPermission.openInputMonitoringSettings()
                default:
                    break
                }
            }
        }
    }

    private func openMissingPermissionSettings(accessibilityTrusted: Bool, inputMonitoringTrusted: Bool) {
        if !accessibilityTrusted {
            AccessibilityPermission.requestPrompt()
            AccessibilityPermission.openSettings()
        } else if !inputMonitoringTrusted {
            AccessibilityPermission.requestInputMonitoring()
            AccessibilityPermission.openInputMonitoringSettings()
        } else {
            AccessibilityPermission.openInputMonitoringSettings()
        }
    }

    private func showPlainAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
}

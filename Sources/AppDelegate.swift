import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let keyboardMonitor = KeyboardEventMonitor()
    private let shortcutScanner = ShortcutScanner()
    private let overlayController = ShortcutOverlayController()
    private lazy var permissionPromptCoordinator = YPermissionPromptCoordinator(
        configuration: YPermissionPromptConfiguration(
            appName: AppBranding.displayName,
            persistenceNamespace: AppBranding.bundleIdentifier
        )
    )
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
    private var lastKeyboardMonitorError: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupExternalApplicationTracking()
        setupKeyboardMonitor()
        startKeyboardMonitor(presentWarning: false)
        permissionPromptCoordinator.presentInitialGuidanceIfNeeded(
            permissions: permissionDescriptors,
            runtime: permissionRuntimeDescriptor
        )
        showSettingsForPreviewIfRequested()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard !isSettingsPreviewRequested else { return }
        if !keyboardMonitor.isRunning {
            startKeyboardMonitor(presentWarning: false)
        }
        permissionPromptCoordinator.presentMissingPermissionIfNeeded(
            permissions: permissionDescriptors,
            runtime: permissionRuntimeDescriptor,
            reason: lastKeyboardMonitorError
        )
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
        keyboardMonitor.onKeyDown = { [weak self] state, key in
            guard let self, self.overlayController.isVisible else { return false }
            return self.overlayController.handleKeyDown(
                pressedSymbols: state.symbols,
                key: key
            )
        }
    }

    private func startKeyboardMonitor(presentWarning: Bool = true) {
        do {
            try keyboardMonitor.start()
            lastKeyboardMonitorError = nil
        } catch {
            lastKeyboardMonitorError = error.localizedDescription
            if presentWarning, !isSettingsPreviewRequested {
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
            permissionPromptCoordinator.presentMissingPermissionIfNeeded(
                permissions: permissionDescriptors,
                runtime: permissionRuntimeDescriptor,
                reason: "无法读取当前 App 的菜单快捷键。",
                force: true
            )
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

    private var permissionDescriptors: [YPermissionPromptDescriptor] {
        let accessibilityTrusted = AccessibilityPermission.isTrusted(prompt: false)
        let inputMonitoringTrusted = AccessibilityPermission.isInputMonitoringTrusted()

        return [
            YPermissionPromptDescriptor(
                identifier: "accessibility",
                displayName: "辅助功能权限",
                explanation: "用于读取当前 App 的菜单和快捷键。",
                settingsLocation: "System Settings → Privacy & Security → Accessibility",
                state: {
                    AccessibilityPermission.isTrusted(prompt: false)
                        ? .granted
                        : .missing
                },
                requestAction: YPermissionPromptAction(
                    title: "打开辅助功能",
                    perform: {
                        AccessibilityPermission.requestPrompt()
                        AccessibilityPermission.openSettings()
                    }
                ),
                openSettingsAction: YPermissionPromptAction(
                    title: "打开辅助功能",
                    perform: {
                        AccessibilityPermission.openSettings()
                    }
                )
            ),
            YPermissionPromptDescriptor(
                identifier: "input-monitoring",
                displayName: "输入监控权限",
                explanation: "用于识别双击左 Command 和显示修饰键状态。",
                settingsLocation: "System Settings → Privacy & Security → Input Monitoring",
                state: {
                    AccessibilityPermission.isInputMonitoringTrusted()
                        ? .granted
                        : .missing
                },
                requestAction: YPermissionPromptAction(
                    title: "打开输入监控",
                    perform: {
                        AccessibilityPermission.requestInputMonitoring()
                        AccessibilityPermission.openInputMonitoringSettings()
                    }
                ),
                openSettingsAction: YPermissionPromptAction(
                    title: "打开输入监控",
                    perform: {
                        AccessibilityPermission.openInputMonitoringSettings()
                    }
                )
            ),
            YPermissionPromptDescriptor(
                identifier: "keyboard-listener",
                displayName: "键盘监听",
                explanation: "辅助功能和输入监控均显示已开启，但当前进程仍无法监听键盘。",
                settingsLocation: "System Settings → Privacy & Security → Input Monitoring",
                state: { [weak self] in
                    guard accessibilityTrusted, inputMonitoringTrusted else {
                        return .granted
                    }
                    return self?.keyboardMonitor.isRunning == true
                        ? .granted
                        : .restartRequired
                },
                openSettingsAction: YPermissionPromptAction(
                    title: "打开输入监控",
                    perform: {
                        AccessibilityPermission.openInputMonitoringSettings()
                    }
                ),
                restartAction: YPermissionPromptAction(
                    title: "重启 Y-Keys",
                    perform: { [weak self] in
                        self?.relaunchInstalledApplication()
                    }
                )
            )
        ]
    }

    private var permissionRuntimeDescriptor: YPermissionRuntimeDescriptor {
        YPermissionRuntimeDescriptor(
            installedApplicationPath: AppBranding.installedApplicationPath,
            isRunningPreferredCopy: {
                YSettingRuntimeIdentity.isSignedInstalledCopy(
                    expectedPath: AppBranding.installedApplicationPath,
                    expectedTeamIdentifier: AppBranding.teamIdentifier,
                    expectedBundleIdentifier: AppBranding.bundleIdentifier
                )
            },
            hasPreferredCopy: {
                YSettingRuntimeIdentity.isValidSignedApplication(
                    atPath: AppBranding.installedApplicationPath,
                    expectedBundleIdentifier: AppBranding.bundleIdentifier,
                    expectedTeamIdentifier: AppBranding.teamIdentifier
                )
            },
            switchAction: YPermissionPromptAction(
                title: "切换到安装版",
                perform: { [weak self] in
                    self?.relaunchInstalledApplication()
                }
            )
        )
    }

    private func showPermissionWarningIfNeeded(message: String) {
        permissionPromptCoordinator.presentMissingPermissionIfNeeded(
            permissions: permissionDescriptors,
            runtime: permissionRuntimeDescriptor,
            reason: message
        )
    }

    private func relaunchInstalledApplication() {
        do {
            try YSettingRuntimeIdentity.relaunchInstalledApplication(
                atPath: AppBranding.installedApplicationPath,
                expectedBundleIdentifier: AppBranding.bundleIdentifier,
                expectedTeamIdentifier: AppBranding.teamIdentifier
            )
        } catch {
            showPlainAlert(
                title: "无法重启正式安装版",
                message: error.localizedDescription
            )
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

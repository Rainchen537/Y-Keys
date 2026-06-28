import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let keyboardMonitor = KeyboardEventMonitor()
    private let shortcutScanner = ShortcutScanner()
    private let overlayController = ShortcutOverlayController()
    private lazy var settingsWindowController = SettingsWindowController { [weak self] in
        self?.showShortcuts()
    }
    private var statusItem: NSStatusItem?
    private var hasShownPermissionWarning = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupKeyboardMonitor()
        startKeyboardMonitor()
    }

    func applicationWillTerminate(_ notification: Notification) {
        keyboardMonitor.stop()
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
        } catch {
            showPermissionWarningIfNeeded(message: error.localizedDescription)
        }
    }

    @objc private func openSettings() {
        settingsWindowController.show()
    }

    private func showShortcuts() {
        let catalog = shortcutScanner.scanFrontmostApplication()
        overlayController.show(catalog: catalog)

        if catalog.needsAccessibilityPermission {
            AccessibilityPermission.requestPrompt()
        }
    }

    @objc private func openAccessibilitySettings() {
        AccessibilityPermission.requestPrompt()
        AccessibilityPermission.openSettings()
    }

    @objc private func resetAccessibility() {
        do {
            try AccessibilityPermission.resetAuthorization()
            showAlert(
                title: "已刷新权限记录",
                message: "请在系统设置中重新勾选 Y-Keys，然后重启 App。"
            )
        } catch {
            showAlert(title: "刷新失败", message: error.localizedDescription)
        }
    }

    @objc private func openGitHub() {
        NSWorkspace.shared.open(AppBranding.repositoryURL)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showPermissionWarningIfNeeded(message: String) {
        guard !hasShownPermissionWarning else { return }
        hasShownPermissionWarning = true
        DispatchQueue.main.async {
            AccessibilityPermission.requestPrompt()
            self.showAlert(
                title: "\(AppBranding.displayName) 需要辅助功能权限",
                message: "\(message)\n\n路径：System Settings → Privacy & Security → Accessibility。"
            )
        }
    }

    private func showAlert(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "打开辅助功能设置")
        alert.addButton(withTitle: "稍后")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            AccessibilityPermission.openSettings()
        }
    }
}

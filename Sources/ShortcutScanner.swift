import AppKit
import ApplicationServices
import Carbon
import Foundation

final class ShortcutScanner {
    private enum AXMenuModifier {
        static let shift = 1
        static let option = 2
        static let control = 4
        static let noCommand = 8
    }

    func scanFrontmostApplication() -> ShortcutCatalog {
        let app = NSWorkspace.shared.frontmostApplication
        let appName = app?.localizedName ?? "当前应用"
        let appIcon = app?.icon
        let trusted = AccessibilityPermission.isTrusted(prompt: false)

        let appSections: [ShortcutSection]
        if trusted, let app {
            appSections = scanApplication(app)
        } else {
            appSections = [
                ShortcutSection(title: appName, items: [
                    ShortcutItem(
                        title: "开启「辅助功能」权限后，Y-Keys 会读取当前 App 菜单快捷键",
                        subtitle: "菜单栏图标 → 打开辅助功能设置",
                        combo: KeyCombo(modifiers: [.command], key: "Space"),
                        isEnabled: false
                    )
                ])
            ]
        }

        return ShortcutCatalog(
            appName: appName,
            appIcon: appIcon,
            appSections: appSections,
            systemSections: SystemShortcutProvider.sections(),
            needsAccessibilityPermission: !trusted
        )
    }

    private func scanApplication(_ app: NSRunningApplication) -> [ShortcutSection] {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        guard let menuBar = copyAttribute(axApp, kAXMenuBarAttribute) as AXUIElement? else {
            return []
        }

        guard let menuBarItems = copyAttribute(menuBar, kAXChildrenAttribute) as [AXUIElement]? else {
            return []
        }

        var sections: [ShortcutSection] = []

        for menuBarItem in menuBarItems {
            let title = title(of: menuBarItem)
            let sectionTitle = title.isEmpty ? "菜单" : title
            var items: [ShortcutItem] = []

            let menus = copyAttribute(menuBarItem, kAXChildrenAttribute) as [AXUIElement]? ?? []
            for menu in menus {
                let children = copyAttribute(menu, kAXChildrenAttribute) as [AXUIElement]? ?? []
                for child in children {
                    collectShortcutItems(from: child, submenuPath: [], into: &items)
                }
            }

            let uniqueItems = deduplicated(items)
            if !uniqueItems.isEmpty {
                sections.append(ShortcutSection(title: sectionTitle, items: uniqueItems))
            }
        }

        return sections
    }

    private func collectShortcutItems(
        from element: AXUIElement,
        submenuPath: [String],
        into items: inout [ShortcutItem]
    ) {
        let elementTitle = title(of: element)
        let fullTitle = (submenuPath + [elementTitle])
            .filter { !$0.isEmpty }
            .joined(separator: " › ")

        if let combo = shortcutCombo(from: element), !fullTitle.isEmpty {
            let enabled = (copyAttribute(element, kAXEnabledAttribute) as Bool?) ?? true
            let subtitle = submenuPath.isEmpty ? nil : submenuPath.joined(separator: " › ")
            items.append(ShortcutItem(title: elementTitle, subtitle: subtitle, combo: combo, isEnabled: enabled))
        }

        let children = copyAttribute(element, kAXChildrenAttribute) as [AXUIElement]? ?? []
        guard !children.isEmpty else { return }

        let nextPath = elementTitle.isEmpty ? submenuPath : submenuPath + [elementTitle]
        for child in children {
            collectShortcutItems(from: child, submenuPath: nextPath, into: &items)
        }
    }

    private func shortcutCombo(from element: AXUIElement) -> KeyCombo? {
        guard let key = commandKey(from: element), !key.isEmpty else {
            return nil
        }

        let rawModifiers = copyAttribute(element, "AXMenuItemCmdModifiers") as Int? ?? 0
        var modifiers: Set<KeyModifier> = []

        if rawModifiers & AXMenuModifier.control != 0 { modifiers.insert(.control) }
        if rawModifiers & AXMenuModifier.option != 0 { modifiers.insert(.option) }
        if rawModifiers & AXMenuModifier.shift != 0 { modifiers.insert(.shift) }
        if rawModifiers & AXMenuModifier.noCommand == 0 { modifiers.insert(.command) }

        return KeyCombo(modifiers: modifiers, key: key)
    }

    private func commandKey(from element: AXUIElement) -> String? {
        if let char = copyAttribute(element, "AXMenuItemCmdChar") as String?, !char.isEmpty {
            return normalizedMenuKey(char)
        }

        if let virtualKey = copyAttribute(element, "AXMenuItemCmdVirtualKey") as Int?,
           let key = KeyCodeDisplay.displayName(for: virtualKey) {
            return key
        }

        if let glyph = copyAttribute(element, "AXMenuItemCmdGlyph") as Int? {
            return glyphName(glyph)
        }

        return nil
    }

    private func normalizedMenuKey(_ raw: String) -> String {
        switch raw {
        case "\r", "\n": return "↩"
        case "\t": return "⇥"
        case " ": return "Space"
        case "\u{1b}": return "Esc"
        case "\u{8}", "\u{7f}": return "⌫"
        default:
            return raw.count == 1 ? raw.uppercased() : raw
        }
    }

    private func glyphName(_ glyph: Int) -> String {
        switch glyph {
        case 0xF700: return "↑"
        case 0xF701: return "↓"
        case 0xF702: return "←"
        case 0xF703: return "→"
        case 0xF704: return "F1"
        case 0xF705: return "F2"
        case 0xF706: return "F3"
        case 0xF707: return "F4"
        case 0xF708: return "F5"
        case 0xF709: return "F6"
        case 0xF70A: return "F7"
        case 0xF70B: return "F8"
        case 0xF70C: return "F9"
        case 0xF70D: return "F10"
        case 0xF70E: return "F11"
        case 0xF70F: return "F12"
        case 0xF728: return "⌫"
        case 0xF729: return "Home"
        case 0xF72B: return "End"
        case 0xF72C: return "Page Up"
        case 0xF72D: return "Page Down"
        default:
            if let scalar = UnicodeScalar(glyph) {
                return String(Character(scalar))
            }
            return "Key \(glyph)"
        }
    }

    private func title(of element: AXUIElement) -> String {
        (copyAttribute(element, kAXTitleAttribute) as String?)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func copyAttribute<T>(_ element: AXUIElement, _ attribute: String) -> T? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success, let value else {
            return nil
        }

        return value as? T
    }

    private func deduplicated(_ items: [ShortcutItem]) -> [ShortcutItem] {
        var seen = Set<String>()
        return items.filter { item in
            let key = "\(item.title)|\(item.combo.displaySegments.joined())"
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }
}

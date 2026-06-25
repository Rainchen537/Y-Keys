import AppKit
import Carbon
import Foundation

enum KeyModifier: String, CaseIterable, Hashable {
    case control
    case option
    case shift
    case command
    case function

    var symbol: String {
        switch self {
        case .control: return "⌃"
        case .option: return "⌥"
        case .shift: return "⇧"
        case .command: return "⌘"
        case .function: return "fn"
        }
    }

    var sortOrder: Int {
        switch self {
        case .control: return 0
        case .option: return 1
        case .shift: return 2
        case .command: return 3
        case .function: return 4
        }
    }
}

struct KeyCombo: Hashable {
    var modifiers: Set<KeyModifier>
    var key: String

    var displaySegments: [String] {
        modifiers
            .sorted { $0.sortOrder < $1.sortOrder }
            .map(\.symbol) + [key]
    }

    var matchSymbols: Set<String> {
        Set(displaySegments.map(Self.normalizedSymbol))
    }

    func containsPressedSymbols(_ symbols: Set<String>) -> Bool {
        guard !symbols.isEmpty else { return false }
        return symbols.isSubset(of: matchSymbols)
    }

    static func normalizedSymbol(_ symbol: String) -> String {
        symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
}

struct ShortcutItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let combo: KeyCombo
    let isEnabled: Bool
}

struct ShortcutSection: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let items: [ShortcutItem]
}

struct ShortcutCatalog {
    let appName: String
    let appIcon: NSImage?
    let appSections: [ShortcutSection]
    let systemSections: [ShortcutSection]
    let needsAccessibilityPermission: Bool
}

enum KeyCodeDisplay {
    static func displayName(for keyCode: Int) -> String? {
        keyNames[keyCode]
    }

    static func normalizedDisplayName(for keyCode: Int) -> String? {
        displayName(for: keyCode).map(KeyCombo.normalizedSymbol)
    }

    private static let keyNames: [Int: String] = [
        kVK_ANSI_A: "A",
        kVK_ANSI_S: "S",
        kVK_ANSI_D: "D",
        kVK_ANSI_F: "F",
        kVK_ANSI_H: "H",
        kVK_ANSI_G: "G",
        kVK_ANSI_Z: "Z",
        kVK_ANSI_X: "X",
        kVK_ANSI_C: "C",
        kVK_ANSI_V: "V",
        kVK_ANSI_B: "B",
        kVK_ANSI_Q: "Q",
        kVK_ANSI_W: "W",
        kVK_ANSI_E: "E",
        kVK_ANSI_R: "R",
        kVK_ANSI_Y: "Y",
        kVK_ANSI_T: "T",
        kVK_ANSI_1: "1",
        kVK_ANSI_2: "2",
        kVK_ANSI_3: "3",
        kVK_ANSI_4: "4",
        kVK_ANSI_6: "6",
        kVK_ANSI_5: "5",
        kVK_ANSI_Equal: "=",
        kVK_ANSI_9: "9",
        kVK_ANSI_7: "7",
        kVK_ANSI_Minus: "-",
        kVK_ANSI_8: "8",
        kVK_ANSI_0: "0",
        kVK_ANSI_RightBracket: "]",
        kVK_ANSI_O: "O",
        kVK_ANSI_U: "U",
        kVK_ANSI_LeftBracket: "[",
        kVK_ANSI_I: "I",
        kVK_ANSI_P: "P",
        kVK_ANSI_L: "L",
        kVK_ANSI_J: "J",
        kVK_ANSI_Quote: "'",
        kVK_ANSI_K: "K",
        kVK_ANSI_Semicolon: ";",
        kVK_ANSI_Backslash: "\\",
        kVK_ANSI_Comma: ",",
        kVK_ANSI_Slash: "/",
        kVK_ANSI_N: "N",
        kVK_ANSI_M: "M",
        kVK_ANSI_Period: ".",
        kVK_ANSI_Grave: "`",
        kVK_ANSI_KeypadDecimal: ".",
        kVK_ANSI_KeypadMultiply: "*",
        kVK_ANSI_KeypadPlus: "+",
        kVK_ANSI_KeypadClear: "Clear",
        kVK_ANSI_KeypadDivide: "/",
        kVK_ANSI_KeypadEnter: "↩",
        kVK_ANSI_KeypadMinus: "-",
        kVK_ANSI_KeypadEquals: "=",
        kVK_ANSI_Keypad0: "0",
        kVK_ANSI_Keypad1: "1",
        kVK_ANSI_Keypad2: "2",
        kVK_ANSI_Keypad3: "3",
        kVK_ANSI_Keypad4: "4",
        kVK_ANSI_Keypad5: "5",
        kVK_ANSI_Keypad6: "6",
        kVK_ANSI_Keypad7: "7",
        kVK_ANSI_Keypad8: "8",
        kVK_ANSI_Keypad9: "9",
        kVK_Return: "↩",
        kVK_Tab: "⇥",
        kVK_Space: "Space",
        kVK_Delete: "⌫",
        kVK_Escape: "Esc",
        kVK_Command: "⌘",
        kVK_Shift: "⇧",
        kVK_CapsLock: "Caps",
        kVK_Option: "⌥",
        kVK_Control: "⌃",
        kVK_RightCommand: "⌘",
        kVK_RightShift: "⇧",
        kVK_RightOption: "⌥",
        kVK_RightControl: "⌃",
        kVK_Function: "fn",
        kVK_F1: "F1",
        kVK_F2: "F2",
        kVK_F3: "F3",
        kVK_F4: "F4",
        kVK_F5: "F5",
        kVK_F6: "F6",
        kVK_F7: "F7",
        kVK_F8: "F8",
        kVK_F9: "F9",
        kVK_F10: "F10",
        kVK_F11: "F11",
        kVK_F12: "F12",
        kVK_F13: "F13",
        kVK_F14: "F14",
        kVK_F15: "F15",
        kVK_F16: "F16",
        kVK_F17: "F17",
        kVK_F18: "F18",
        kVK_F19: "F19",
        kVK_Home: "Home",
        kVK_End: "End",
        kVK_PageUp: "Page Up",
        kVK_PageDown: "Page Down",
        kVK_LeftArrow: "←",
        kVK_RightArrow: "→",
        kVK_DownArrow: "↓",
        kVK_UpArrow: "↑",
        kVK_ForwardDelete: "⌦",
        kVK_Help: "Help"
    ].reduce(into: [:]) { result, pair in
        result[Int(pair.key)] = pair.value
    }
}

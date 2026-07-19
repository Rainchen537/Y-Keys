import Foundation

@main
enum ShortcutModelTests {
    static func main() {
        let commandZ = KeyCombo(modifiers: [.command], key: "Z")
        let commandShiftZ = KeyCombo(modifiers: [.command, .shift], key: "Z")

        expect(commandZ.matchesPressedSymbols(["⌘"]), "Command should match Command-Z")
        expect(commandShiftZ.matchesPressedSymbols(["⌘"]), "Command should match Command-Shift-Z")
        expect(!commandZ.matchesPressedSymbols(["⌘", "⇧"]), "Extra Shift must exclude Command-Z")
        expect(commandShiftZ.matchesPressedSymbols(["⌘", "⇧"]), "Command-Shift should match Command-Shift-Z")
        expect(commandZ.matchesPressedSymbols(["⌘", "Z"]), "Complete Command-Z should match")
        expect(!commandShiftZ.matchesPressedSymbols(["⌘", "Z"]), "Missing Shift must exclude complete Command-Shift-Z")

        var escapeState = EscapeDismissalState(confirmationInterval: 1.2)
        expect(
            escapeState.registerPress(requiresConfirmation: true, at: 10) == .showHint,
            "First Escape should show a hint when Escape shortcuts exist"
        )
        expect(
            escapeState.registerPress(requiresConfirmation: true, at: 10.8) == .close,
            "Second Escape inside the confirmation interval should close"
        )
        expect(
            escapeState.registerPress(requiresConfirmation: true, at: 20) == .showHint,
            "A new Escape sequence should show the hint again"
        )
        expect(
            escapeState.registerPress(requiresConfirmation: true, at: 22) == .showHint,
            "An expired Escape sequence should restart confirmation"
        )
        expect(
            escapeState.registerPress(requiresConfirmation: false, at: 30) == .close,
            "Escape should close immediately when no Escape shortcut exists"
        )

        print("ShortcutModelTests passed")
    }

    private static func expect(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) {
        guard condition() else {
            fputs("ShortcutModelTests failed: \(message)\n", stderr)
            exit(1)
        }
    }
}

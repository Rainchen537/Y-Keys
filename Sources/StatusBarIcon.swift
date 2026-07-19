import AppKit

enum StatusBarIcon {
    static func makeImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()
        defer { image.unlockFocus() }

        func keycap(_ rect: NSRect, radius: CGFloat, width: CGFloat, alpha: CGFloat) {
            let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
            path.lineWidth = width
            path.lineJoinStyle = .round
            NSColor.black.withAlphaComponent(alpha).setStroke()
            path.stroke()
        }

        let rearKeycapRect = NSRect(x: 2.2, y: 5.0, width: 12.4, height: 9.4)
        let frontKeycapRect = NSRect(x: 3.8, y: 3.4, width: 12.0, height: 10.0)
        keycap(rearKeycapRect, radius: 2.4, width: 1.3, alpha: 0.45)
        keycap(frontKeycapRect, radius: 2.5, width: 1.45, alpha: 1)

        let command = "⌘" as NSString
        let commandAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 6.8, weight: .semibold),
            .foregroundColor: NSColor.black
        ]
        let commandSize = command.size(withAttributes: commandAttributes)
        command.draw(
            at: NSPoint(
                x: frontKeycapRect.midX - commandSize.width / 2,
                y: frontKeycapRect.midY - commandSize.height / 2 + 0.35
            ),
            withAttributes: commandAttributes
        )

        image.isTemplate = true
        image.accessibilityDescription = "Y-Keys 快捷键"
        return image
    }
}

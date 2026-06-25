import AppKit

enum StatusBarIcon {
    static func makeImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 20))
        image.lockFocus()

        NSColor.black.setFill()

        let key = NSBezierPath(roundedRect: NSRect(x: 2.4, y: 4.2, width: 15.2, height: 11.8), xRadius: 3.0, yRadius: 3.0)
        key.fill()

        NSColor.white.setFill()
        let smallKeys = [
            NSRect(x: 5.0, y: 11.4, width: 2.4, height: 1.9),
            NSRect(x: 8.7, y: 11.4, width: 2.4, height: 1.9),
            NSRect(x: 12.4, y: 11.4, width: 2.4, height: 1.9),
            NSRect(x: 5.0, y: 8.0, width: 2.4, height: 1.9),
            NSRect(x: 8.7, y: 8.0, width: 2.4, height: 1.9)
        ]
        smallKeys.forEach { NSBezierPath(roundedRect: $0, xRadius: 0.7, yRadius: 0.7).fill() }

        NSColor.black.setStroke()
        key.lineWidth = 0.4
        key.stroke()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}

import AppKit
import Foundation

let w = 640.0
let h = 400.0

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(w),
    pixelsHigh: Int(h),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .calibratedRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

let nsCtx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = nsCtx
guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("no ctx") }

let full = CGRect(x: 0, y: 0, width: w, height: h)
NSGradient(colors: [
    NSColor(calibratedRed: 0.16, green: 0.17, blue: 0.20, alpha: 1.0),
    NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.13, alpha: 1.0)
])!.draw(in: full, angle: -90)

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawCentered(_ text: String, font: NSFont, color: NSColor, centerX: CGFloat, y: CGFloat) {
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let attributed = NSAttributedString(string: text, attributes: attrs)
    let textSize = attributed.size()
    attributed.draw(at: CGPoint(x: centerX - textSize.width / 2, y: y))
}

drawCentered(
    "Y-Keys",
    font: NSFont.systemFont(ofSize: 30, weight: .semibold),
    color: NSColor(white: 0.97, alpha: 1.0),
    centerX: w / 2,
    y: h - 78
)
drawCentered(
    "将左侧应用拖入右侧「应用程序」文件夹即可安装",
    font: NSFont.systemFont(ofSize: 14, weight: .regular),
    color: NSColor(white: 0.66, alpha: 1.0),
    centerX: w / 2,
    y: h - 112
)

NSColor(white: 0.36, alpha: 1.0).setFill()
roundedRect(CGRect(x: 250, y: h - 132, width: 140, height: 3), 1.5).fill()

let arrowColor = NSColor(calibratedRed: 0.46, green: 0.72, blue: 1.0, alpha: 0.92)
arrowColor.setStroke()

let cy: CGFloat = 190
let shaft = NSBezierPath()
shaft.lineWidth = 8
shaft.lineCapStyle = .round
shaft.move(to: CGPoint(x: 270, y: cy))
shaft.line(to: CGPoint(x: 360, y: cy))
shaft.stroke()

let head = NSBezierPath()
head.move(to: CGPoint(x: 358, y: cy + 16))
head.line(to: CGPoint(x: 386, y: cy))
head.line(to: CGPoint(x: 358, y: cy - 16))
head.lineWidth = 8
head.lineJoinStyle = .round
head.lineCapStyle = .round
head.stroke()

let hintAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 12, weight: .medium),
    .foregroundColor: NSColor(white: 0.54, alpha: 1.0)
]
"Y-Keys.app".draw(at: CGPoint(x: 126, y: 86), withAttributes: hintAttrs)
"Applications".draw(at: CGPoint(x: 435, y: 86), withAttributes: hintAttrs)

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("encode failed")
}
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg_bg.png"
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")

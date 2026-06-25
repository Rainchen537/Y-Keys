import AppKit
import Foundation

let size: CGFloat = 1024
let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size),
    pixelsHigh: Int(size),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
bitmap.size = NSSize(width: size, height: size)

let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphicsContext
let ctx = graphicsContext.cgContext
ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawLinearGradient(colors: [NSColor], in rect: CGRect, start: CGPoint, end: CGPoint, clippedTo path: NSBezierPath? = nil) {
    ctx.saveGState()
    path?.addClip()
    let cgColors = colors.map { $0.cgColor } as CFArray
    let space = CGColorSpaceCreateDeviceRGB()
    guard let gradient = CGGradient(colorsSpace: space, colors: cgColors, locations: nil) else {
        ctx.restoreGState()
        return
    }
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: rect.minX + rect.width * start.x, y: rect.minY + rect.height * start.y),
        end: CGPoint(x: rect.minX + rect.width * end.x, y: rect.minY + rect.height * end.y),
        options: []
    )
    ctx.restoreGState()
}

func drawShadowedPath(_ path: NSBezierPath, fill: NSColor, shadowOffset: CGSize, shadowBlur: CGFloat, shadowColor: NSColor) {
    ctx.saveGState()
    ctx.setShadow(offset: shadowOffset, blur: shadowBlur, color: shadowColor.cgColor)
    fill.setFill()
    path.fill()
    ctx.restoreGState()
}

func strokeGradientBorder(rect: CGRect, radius: CGFloat, strokeWidth: CGFloat, colors: [NSColor]) {
    ctx.saveGState()
    let outer = roundedRect(rect, radius)
    outer.addClip()
    let inner = roundedRect(rect.insetBy(dx: strokeWidth, dy: strokeWidth), radius - strokeWidth)
    inner.append(NSBezierPath(rect: rect))
    inner.windingRule = .evenOdd
    inner.addClip()
    drawLinearGradient(
        colors: colors,
        in: rect,
        start: CGPoint(x: 0.08, y: 0.92),
        end: CGPoint(x: 0.96, y: 0.06)
    )
    ctx.restoreGState()
}

let iconRect = CGRect(x: 88, y: 88, width: 848, height: 848)
let iconRadius = iconRect.width * 0.225
let platePath = roundedRect(iconRect, iconRadius)

drawShadowedPath(
    platePath,
    fill: NSColor(calibratedRed: 0.965, green: 0.955, blue: 0.925, alpha: 1),
    shadowOffset: CGSize(width: 0, height: -18),
    shadowBlur: 44,
    shadowColor: NSColor(white: 0, alpha: 0.24)
)

drawLinearGradient(
    colors: [
        NSColor(calibratedRed: 1.000, green: 0.995, blue: 0.970, alpha: 1),
        NSColor(calibratedRed: 0.935, green: 0.955, blue: 0.925, alpha: 1)
    ],
    in: iconRect,
    start: CGPoint(x: 0.18, y: 0.96),
    end: CGPoint(x: 0.90, y: 0.05),
    clippedTo: platePath
)

ctx.saveGState()
platePath.addClip()
NSColor(white: 1.0, alpha: 0.46).setStroke()
let innerStroke = roundedRect(iconRect.insetBy(dx: 10, dy: 10), iconRadius - 10)
innerStroke.lineWidth = 5
innerStroke.stroke()
ctx.restoreGState()

let accentColors = [
    NSColor(calibratedRed: 0.61, green: 0.39, blue: 0.82, alpha: 1),
    NSColor(calibratedRed: 0.94, green: 0.42, blue: 0.53, alpha: 1),
    NSColor(calibratedRed: 0.98, green: 0.70, blue: 0.43, alpha: 1)
]

// Two soft trailing key outlines hint at "double tap" without adding text.
let ghostKeyRects = [
    CGRect(x: 228, y: 388, width: 548, height: 360),
    CGRect(x: 252, y: 354, width: 548, height: 360)
]

for (index, rect) in ghostKeyRects.enumerated() {
    let alpha: CGFloat = index == 0 ? 0.22 : 0.34
    strokeGradientBorder(
        rect: rect,
        radius: 92,
        strokeWidth: 28,
        colors: accentColors.map { $0.withAlphaComponent(alpha) }
    )
}

let keyBaseRect = CGRect(x: 224, y: 244, width: 576, height: 390)
let sideRect = CGRect(x: keyBaseRect.minX, y: keyBaseRect.minY, width: keyBaseRect.width, height: 116)

drawShadowedPath(
    roundedRect(CGRect(x: 184, y: 194, width: 656, height: 430), 120),
    fill: NSColor(white: 0, alpha: 0.0),
    shadowOffset: CGSize(width: 0, height: -30),
    shadowBlur: 58,
    shadowColor: NSColor(white: 0, alpha: 0.28)
)

drawLinearGradient(
    colors: [
        NSColor(calibratedRed: 0.56, green: 0.38, blue: 0.72, alpha: 1),
        NSColor(calibratedRed: 0.88, green: 0.36, blue: 0.55, alpha: 1),
        NSColor(calibratedRed: 0.98, green: 0.62, blue: 0.39, alpha: 1)
    ],
    in: sideRect,
    start: CGPoint(x: 0.08, y: 0.90),
    end: CGPoint(x: 0.96, y: 0.08),
    clippedTo: roundedRect(sideRect, 78)
)

let topKeyRect = CGRect(x: 224, y: 326, width: 576, height: 360)
let topKeyPath = roundedRect(topKeyRect, 92)

drawShadowedPath(
    topKeyPath,
    fill: NSColor(calibratedRed: 0.985, green: 0.990, blue: 1.000, alpha: 1),
    shadowOffset: CGSize(width: 0, height: -12),
    shadowBlur: 24,
    shadowColor: NSColor(white: 0, alpha: 0.18)
)

drawLinearGradient(
    colors: [
        NSColor(calibratedRed: 1.000, green: 1.000, blue: 0.995, alpha: 1),
        NSColor(calibratedRed: 0.925, green: 0.940, blue: 0.970, alpha: 1)
    ],
    in: topKeyRect,
    start: CGPoint(x: 0.24, y: 0.94),
    end: CGPoint(x: 0.86, y: 0.08),
    clippedTo: topKeyPath
)

ctx.saveGState()
topKeyPath.addClip()
NSColor(white: 1, alpha: 0.82).setStroke()
let highlight = roundedRect(topKeyRect.insetBy(dx: 18, dy: 18), 76)
highlight.lineWidth = 8
highlight.stroke()

NSColor(calibratedWhite: 0, alpha: 0.055).setStroke()
let lowerEdge = NSBezierPath()
lowerEdge.lineWidth = 8
lowerEdge.lineCapStyle = .round
lowerEdge.move(to: CGPoint(x: topKeyRect.minX + 86, y: topKeyRect.minY + 40))
lowerEdge.line(to: CGPoint(x: topKeyRect.maxX - 86, y: topKeyRect.minY + 40))
lowerEdge.stroke()
ctx.restoreGState()

let commandRect = CGRect(x: topKeyRect.minX, y: topKeyRect.minY + 42, width: topKeyRect.width, height: 260)
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let commandAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 214, weight: .heavy),
    .foregroundColor: NSColor(calibratedRed: 0.235, green: 0.270, blue: 0.410, alpha: 1),
    .paragraphStyle: paragraph
]
"⌘".draw(in: commandRect, withAttributes: commandAttributes)

let glowRect = CGRect(x: 318, y: 704, width: 388, height: 18)
drawLinearGradient(
    colors: accentColors.map { $0.withAlphaComponent(0.72) },
    in: glowRect,
    start: CGPoint(x: 0, y: 0.5),
    end: CGPoint(x: 1, y: 0.5),
    clippedTo: roundedRect(glowRect, 9)
)

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("encode failed")
}

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")

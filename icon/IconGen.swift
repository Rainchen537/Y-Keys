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

// A translucent offset deck keeps the double-tap idea visible at small sizes.
let echoRect = CGRect(x: 250, y: 382, width: 560, height: 314)
let echoPath = roundedRect(echoRect, 96)
drawLinearGradient(
    colors: accentColors.map { $0.withAlphaComponent(0.30) },
    in: echoRect,
    start: CGPoint(x: 0.06, y: 0.92),
    end: CGPoint(x: 0.95, y: 0.06),
    clippedTo: echoPath
)

let echoSurfaceRect = echoRect.insetBy(dx: 26, dy: 28)
NSColor(white: 1, alpha: 0.40).setFill()
roundedRect(echoSurfaceRect, 74).fill()

let chassisRect = CGRect(x: 210, y: 244, width: 604, height: 398)
let chassisPath = roundedRect(chassisRect, 108)
drawLinearGradient(
    colors: [
        NSColor(calibratedRed: 0.56, green: 0.38, blue: 0.72, alpha: 1),
        NSColor(calibratedRed: 0.90, green: 0.37, blue: 0.55, alpha: 1),
        NSColor(calibratedRed: 0.98, green: 0.64, blue: 0.40, alpha: 1)
    ],
    in: chassisRect,
    start: CGPoint(x: 0.06, y: 0.92),
    end: CGPoint(x: 0.96, y: 0.08),
    clippedTo: chassisPath
)

let keyboardRect = CGRect(x: 226, y: 326, width: 572, height: 344)
let keyboardPath = roundedRect(keyboardRect, 88)
drawShadowedPath(
    keyboardPath,
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
    in: keyboardRect,
    start: CGPoint(x: 0.24, y: 0.94),
    end: CGPoint(x: 0.86, y: 0.08),
    clippedTo: keyboardPath
)

ctx.saveGState()
keyboardPath.addClip()
NSColor(white: 1, alpha: 0.82).setStroke()
let keyboardHighlight = roundedRect(keyboardRect.insetBy(dx: 17, dy: 17), 72)
keyboardHighlight.lineWidth = 8
keyboardHighlight.stroke()
ctx.restoreGState()

let indigo = NSColor(calibratedRed: 0.235, green: 0.270, blue: 0.410, alpha: 1)

func drawKeycap(_ rect: CGRect, radius: CGFloat) {
    let path = roundedRect(rect, radius)
    drawShadowedPath(
        path,
        fill: NSColor(calibratedRed: 0.970, green: 0.978, blue: 0.995, alpha: 1),
        shadowOffset: CGSize(width: 0, height: -7),
        shadowBlur: 13,
        shadowColor: NSColor(white: 0, alpha: 0.16)
    )
    drawLinearGradient(
        colors: [
            NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 1),
            NSColor(calibratedRed: 0.920, green: 0.935, blue: 0.968, alpha: 1)
        ],
        in: rect,
        start: CGPoint(x: 0.22, y: 0.94),
        end: CGPoint(x: 0.84, y: 0.08),
        clippedTo: path
    )
    NSColor(white: 1, alpha: 0.78).setStroke()
    let inset = roundedRect(rect.insetBy(dx: 8, dy: 8), max(4, radius - 8))
    inset.lineWidth = 5
    inset.stroke()
}

func drawSymbol(_ symbol: String, in rect: CGRect, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat = 1) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: indigo.withAlphaComponent(alpha),
        .paragraphStyle: paragraph
    ]
    symbol.draw(in: rect, withAttributes: attributes)
}

let companionKeyRects = [
    CGRect(x: 288, y: 522, width: 128, height: 92),
    CGRect(x: 448, y: 522, width: 128, height: 92),
    CGRect(x: 608, y: 522, width: 128, height: 92)
]

for rect in companionKeyRects {
    drawKeycap(rect, radius: 28)
}

let companionSymbols: [(symbol: String, yOffset: CGFloat, height: CGFloat)] = [
    ("⌥", 15, 58),
    ("⇧", 13, 62),
    ("⌃", 12, 62)
]
for (rect, symbol) in zip(companionKeyRects, companionSymbols) {
    drawSymbol(
        symbol.symbol,
        in: CGRect(
            x: rect.minX,
            y: rect.minY + symbol.yOffset,
            width: rect.width,
            height: symbol.height
        ),
        size: 43,
        weight: .semibold,
        alpha: 0.76
    )
}

let commandKeyRect = CGRect(x: 288, y: 374, width: 448, height: 116)
drawKeycap(commandKeyRect, radius: 34)
drawSymbol("⌘", in: CGRect(x: commandKeyRect.minX, y: commandKeyRect.minY + 12, width: commandKeyRect.width, height: 88), size: 78, weight: .heavy)

NSColor(white: 1, alpha: 0.48).setFill()
roundedRect(CGRect(x: 444, y: 272, width: 136, height: 13), 6.5).fill()

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("encode failed")
}

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")

import AppKit

let output = CommandLine.arguments.dropFirst().first ?? "icon.png"
let size = 1024

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let canvas = CGRect(x: 0, y: 0, width: size, height: size)
let tile = canvas.insetBy(dx: 100, dy: 100)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
NSGradient(colors: [NSColor(white: 0.18, alpha: 1), NSColor(white: 0.06, alpha: 1)])!
    .draw(in: tilePath, angle: -90)
tilePath.addClip()

let screen = CGRect(x: 200, y: 230, width: 624, height: 564)
let screenPath = NSBezierPath(roundedRect: screen, xRadius: 36, yRadius: 36)
NSGradient(colors: [
    NSColor(srgbRed: 0.16, green: 0.08, blue: 0, alpha: 1),
    NSColor(srgbRed: 0.05, green: 0.02, blue: 0, alpha: 1),
])!.draw(in: screenPath, angle: -90)

let amber = NSColor(srgbRed: 1, green: 0.69, blue: 0, alpha: 1)
let lines: [(CGFloat, CGFloat)] = [(0.85, 1), (0.6, 0.8), (0.72, 0.55), (0.4, 0.9), (0.66, 0.4)]
for (i, (width, brightness)) in lines.enumerated() {
    let y = screen.maxY - 120 - CGFloat(i) * 82
    let bar = CGRect(x: screen.minX + 70, y: y, width: (screen.width - 140) * width, height: 36)
    amber.withAlphaComponent(brightness).setFill()
    NSBezierPath(roundedRect: bar, xRadius: 18, yRadius: 18).fill()
}

NSColor(white: 0.02, alpha: 0.9).setStroke()
screenPath.lineWidth = 22
screenPath.stroke()

NSGradient(colors: [NSColor(white: 1, alpha: 0.16), NSColor(white: 1, alpha: 0)])!
    .draw(in: CGRect(x: tile.minX, y: tile.midY, width: tile.width, height: tile.height / 2), angle: -90)

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))

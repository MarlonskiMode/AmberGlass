import AppKit

public extension NSWindow.Level {
    static let tintPane = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.overlayWindow)))
    static let drawingOverlay = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
}

/// The app-specific side of drawing mode: what a pane looks like and what to do with it.
@MainActor
public protocol DrawingHost: AnyObject {
    /// Bottom-to-top fills used to preview the rectangle being dragged.
    var previewFills: [NSColor] { get }
    var hintColor: NSColor { get }
    func addPane(frame: CGRect)
    func removePane(at screenPoint: CGPoint)
    func undo()
    func endDrawing()
}

/// Covers every screen with a transparent, mouse-capturing window while drawing mode is on.
@MainActor
public final class DrawingController {
    private unowned let host: DrawingHost
    private var windows: [DrawingWindow] = []

    public init(host: DrawingHost) {
        self.host = host
    }

    public func begin() {
        let mouse = NSEvent.mouseLocation
        windows = NSScreen.screens.map { DrawingWindow(screen: $0, host: host) }
        NSApp.activate(ignoringOtherApps: true)
        for window in windows {
            window.orderFrontRegardless()
        }
        let keyWindow = windows.first { $0.frame.contains(mouse) } ?? windows.first
        keyWindow?.makeKey()
    }

    public func end() {
        windows.forEach { $0.close() }
        windows.removeAll()
    }
}

final class DrawingWindow: NSWindow {
    init(screen: NSScreen, host: DrawingHost) {
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        level = .drawingOverlay
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        setFrame(screen.frame, display: false)
        contentView = DrawingView(host: host)
    }

    override var canBecomeKey: Bool { true }
}

final class DrawingView: NSView {
    private unowned let host: DrawingHost
    private var start: CGPoint?
    private var current: CGPoint?

    init(host: DrawingHost) {
        self.host = host
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    private var selection: CGRect? {
        guard let start, let current else { return nil }
        return CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
    }

    // MARK: Mouse & keyboard

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        if event.modifierFlags.contains(.option), let window {
            host.removePane(at: window.convertPoint(toScreen: event.locationInWindow))
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        start = point
        current = point
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start else { return }
        var point = convert(event.locationInWindow, from: nil)
        if event.modifierFlags.contains(.shift) {
            let side = max(abs(point.x - start.x), abs(point.y - start.y))
            point = CGPoint(
                x: start.x + (point.x >= start.x ? side : -side),
                y: start.y + (point.y >= start.y ? side : -side)
            )
        }
        current = point
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if let rect = selection, rect.width >= 4, rect.height >= 4, let window {
            host.addPane(frame: window.convertToScreen(rect))
        }
        start = nil
        current = nil
        needsDisplay = true
    }

    override func rightMouseDown(with event: NSEvent) {
        host.endDrawing()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 || event.keyCode == 36 {
            host.endDrawing()
        } else if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "z" {
            host.undo()
        } else {
            super.keyDown(with: event)
        }
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.12).setFill()
        bounds.fill()

        if let rect = selection {
            NSColor.clear.setFill()
            rect.fill(using: .copy)
            for fill in host.previewFills {
                fill.setFill()
                rect.fill(using: .sourceOver)
            }

            let outline = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
            outline.lineWidth = 1
            outline.setLineDash([6, 4], count: 2, phase: 0)
            NSColor.white.withAlphaComponent(0.9).setStroke()
            outline.stroke()

            drawLabel("\(Int(rect.width)) × \(Int(rect.height))", below: rect)
        }

        drawHint()
    }

    private func drawLabel(_ text: String, below rect: CGRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let size = string.size()
        var origin = CGPoint(x: rect.maxX - size.width - 8, y: rect.minY - size.height - 10)
        if origin.y < bounds.minY + 4 { origin.y = rect.minY + 6 }
        let pill = CGRect(x: origin.x - 6, y: origin.y - 3, width: size.width + 12, height: size.height + 6)
        NSColor.black.withAlphaComponent(0.65).setFill()
        NSBezierPath(roundedRect: pill, xRadius: pill.height / 2, yRadius: pill.height / 2).fill()
        string.draw(at: origin)
    }

    private func drawHint() {
        let text = "Drag to place glass   ·   ⇧ square   ·   ⌥-click removes a pane   ·   ⌘Z undo   ·   Esc to finish"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let size = string.size()
        let origin = CGPoint(x: bounds.midX - size.width / 2, y: bounds.maxY - 70)
        let pill = CGRect(x: origin.x - 18, y: origin.y - 9, width: size.width + 36, height: size.height + 18)
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: pill, xRadius: pill.height / 2, yRadius: pill.height / 2).fill()

        let swatch = CGRect(x: pill.minX + 8, y: pill.midY - 5, width: 10, height: 10)
        host.hintColor.setFill()
        NSBezierPath(ovalIn: swatch).fill()

        string.draw(at: CGPoint(x: origin.x + 6, y: origin.y))
    }
}

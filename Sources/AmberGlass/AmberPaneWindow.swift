import AppKit
import GlassKit
import ScreenCaptureKit

/// A click-through, always-on-top pane that shows the screen beneath it in shades of amber.
final class AmberPaneWindow: NSPanel {
    private let renderer: AmberRenderer

    init(frame: CGRect, settings: AmberSettings) {
        let view = NSView(frame: CGRect(origin: .zero, size: frame.size))
        view.wantsLayer = true
        let layer = view.layer!
        layer.backgroundColor = settings.color.withAlphaComponent(0.35).cgColor
        layer.contentsGravity = .resize
        renderer = AmberRenderer(layer: layer, settings: settings)

        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        level = .tintPane
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        contentView = view
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func update(_ settings: AmberSettings) {
        renderer.update(settings)
    }

    func startCapture() async throws {
        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(frame) }) ?? NSScreen.main,
              let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        else { return }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else { return }
        let ownApp = content.applications.filter { $0.processID == getpid() }
        let filter = SCContentFilter(display: display, excludingApplications: ownApp, exceptingWindows: [])

        let sourceRect = CGRect(
            x: frame.minX - screen.frame.minX,
            y: screen.frame.maxY - frame.maxY,
            width: frame.width,
            height: frame.height
        )
        try await renderer.start(filter: filter, sourceRect: sourceRect, scale: screen.backingScaleFactor)
    }

    override func close() {
        renderer.stop()
        super.close()
    }
}

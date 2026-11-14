import AppKit
import GlassKit
import QuartzCore

/// A click-through, always-on-top pane of colored glass.
final class TintWindow: NSPanel {
    private let glass = GlassView()

    init(pane: Pane, texture: Bool) {
        super.init(
            contentRect: pane.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        level = .tintPane
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        contentView = glass
        apply(pane, texture: texture)
    }

    func apply(_ pane: Pane, texture: Bool) {
        glass.update(pane, texture: texture)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class GlassView: NSView {
    private let sheen = CAGradientLayer()
    private var fillLayers: [CALayer] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        sheen.startPoint = CGPoint(x: 0, y: 1)
        sheen.endPoint = CGPoint(x: 1, y: 0)
        sheen.locations = [0, 0.45, 1]
        sheen.colors = [
            NSColor.white.withAlphaComponent(0.14).cgColor,
            NSColor.white.withAlphaComponent(0).cgColor,
            NSColor.white.withAlphaComponent(0.06).cgColor,
        ]
        layer?.addSublayer(sheen)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        sheen.frame = bounds
        fillLayers.forEach { $0.frame = bounds }
        CATransaction.commit()
    }

    func update(_ pane: Pane, texture: Bool) {
        guard let layer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        fillLayers.forEach { $0.removeFromSuperlayer() }
        fillLayers = pane.fills.map { fill in
            let fillLayer = CALayer()
            fillLayer.backgroundColor = fill.cgColor
            fillLayer.frame = bounds
            return fillLayer
        }
        fillLayers.forEach { layer.insertSublayer($0, below: sheen) }

        let color = pane.color
        sheen.isHidden = !texture
        layer.borderWidth = texture ? 2 : 0
        layer.borderColor = (color.blended(withFraction: 0.65, of: .black) ?? color)
            .withAlphaComponent(min(1, pane.opacity + 0.45)).cgColor
        CATransaction.commit()
    }
}

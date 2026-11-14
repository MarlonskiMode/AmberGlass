import AppKit
import GlassKit
import SwiftUI

struct Pane: Codable, Identifiable, Equatable {
    var id = UUID()
    var frame: CGRect
    var hex: String
    var opacity: Double
    /// -1 (black wash) ... 0 (unchanged) ... 1 (white wash).
    var brightness: Double = 0
    /// 1 is unchanged; lower values wash the content toward mid-gray.
    var contrast: Double = 1

    init(frame: CGRect, hex: String, opacity: Double, brightness: Double, contrast: Double) {
        self.frame = frame
        self.hex = hex
        self.opacity = opacity
        self.brightness = brightness
        self.contrast = contrast
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        frame = try c.decode(CGRect.self, forKey: .frame)
        hex = try c.decode(String.self, forKey: .hex)
        opacity = try c.decode(Double.self, forKey: .opacity)
        brightness = try c.decodeIfPresent(Double.self, forKey: .brightness) ?? 0
        contrast = try c.decodeIfPresent(Double.self, forKey: .contrast) ?? 1
    }

    var color: NSColor { NSColor(hex: hex) ?? .systemBlue }

    /// Bottom-to-top fills that approximate this pane's look over whatever is beneath it.
    var fills: [NSColor] {
        var fills: [NSColor] = []
        if contrast < 1 {
            fills.append(NSColor(white: 0.5, alpha: 1 - contrast))
        }
        fills.append(color.withAlphaComponent(opacity))
        if brightness != 0 {
            fills.append((brightness > 0 ? NSColor.white : NSColor.black).withAlphaComponent(abs(brightness) * 0.85))
        }
        return fills
    }
}

@MainActor
final class TintStore: ObservableObject, DrawingHost {
    static let shared = TintStore()

    private enum Keys {
        static let hex = "hex"
        static let opacity = "opacity"
        static let glassTexture = "glassTexture"
        static let brightness = "brightness"
        static let contrast = "contrast"
        static let panes = "panes"
    }

    private let defaults = UserDefaults.standard

    @Published var hex: String {
        didSet { defaults.set(hex, forKey: Keys.hex) }
    }
    @Published var opacity: Double {
        didSet { defaults.set(opacity, forKey: Keys.opacity) }
    }
    @Published var brightness: Double {
        didSet { defaults.set(brightness, forKey: Keys.brightness) }
    }
    @Published var contrast: Double {
        didSet { defaults.set(contrast, forKey: Keys.contrast) }
    }
    @Published var glassTexture: Bool {
        didSet {
            defaults.set(glassTexture, forKey: Keys.glassTexture)
            refreshWindows()
        }
    }
    @Published private(set) var panes: [Pane] = []
    @Published private(set) var isDrawing = false

    private var windows: [UUID: TintWindow] = [:]
    private lazy var drawing = DrawingController(host: self)

    var color: NSColor { NSColor(hex: hex) ?? .systemBlue }
    var previewFills: [NSColor] { makePane(frame: .zero).fills }
    var hintColor: NSColor { color }

    private init() {
        hex = defaults.string(forKey: Keys.hex) ?? "2D8CFF"
        opacity = defaults.object(forKey: Keys.opacity) as? Double ?? 0.35
        glassTexture = defaults.object(forKey: Keys.glassTexture) as? Bool ?? true
        brightness = defaults.object(forKey: Keys.brightness) as? Double ?? 0
        contrast = defaults.object(forKey: Keys.contrast) as? Double ?? 1
    }

    /// A pane carrying the current color and light settings.
    func makePane(frame: CGRect) -> Pane {
        Pane(frame: frame, hex: hex, opacity: opacity, brightness: brightness, contrast: contrast)
    }

    /// Applies user-entered hex text. Returns false when the text isn't a valid color.
    @discardableResult
    func applyHex(_ text: String) -> Bool {
        guard let parsed = HexColor.parse(text) else { return false }
        hex = parsed.rgb
        if let alpha = parsed.alpha { opacity = alpha }
        return true
    }

    // MARK: Panes

    func restore() {
        guard let data = defaults.data(forKey: Keys.panes),
              let saved = try? JSONDecoder().decode([Pane].self, from: data) else { return }
        panes = saved
        saved.forEach(show)
    }

    func addPane(frame: CGRect) {
        let pane = makePane(frame: frame.integral)
        panes.append(pane)
        show(pane)
        savePanes()
    }

    func applyCurrentSettingsToAll() {
        panes = panes.map { pane in
            var updated = makePane(frame: pane.frame)
            updated.id = pane.id
            return updated
        }
        refreshWindows()
        savePanes()
    }

    private func refreshWindows() {
        for pane in panes {
            windows[pane.id]?.apply(pane, texture: glassTexture)
        }
    }

    func remove(_ id: UUID) {
        panes.removeAll { $0.id == id }
        windows.removeValue(forKey: id)?.close()
        savePanes()
    }

    func undo() {
        if let last = panes.last { remove(last.id) }
    }

    func clearAll() {
        windows.values.forEach { $0.close() }
        windows.removeAll()
        panes.removeAll()
        savePanes()
    }

    func removePane(at screenPoint: CGPoint) {
        if let pane = panes.last(where: { $0.frame.contains(screenPoint) }) {
            remove(pane.id)
        }
    }

    private func show(_ pane: Pane) {
        let window = TintWindow(pane: pane, texture: glassTexture)
        windows[pane.id] = window
        window.orderFrontRegardless()
    }

    private func savePanes() {
        if let data = try? JSONEncoder().encode(panes) {
            defaults.set(data, forKey: Keys.panes)
        }
    }

    // MARK: Drawing mode

    func beginDrawing() {
        guard !isDrawing else { return }
        isDrawing = true
        drawing.begin()
    }

    func endDrawing() {
        guard isDrawing else { return }
        isDrawing = false
        drawing.end()
    }

    func toggleDrawing() {
        isDrawing ? endDrawing() : beginDrawing()
    }
}

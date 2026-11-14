import AppKit
import GlassKit
import ScreenCaptureKit
import SwiftUI

struct AmberPane: Codable, Identifiable, Equatable {
    var id = UUID()
    var frame: CGRect
}

@MainActor
final class AmberStore: ObservableObject, DrawingHost {
    static let shared = AmberStore()

    private enum Keys {
        static let brightness = "brightness"
        static let contrast = "contrast"
        static let tone = "tone"
        static let panes = "panes"
    }

    private let defaults = UserDefaults.standard

    @Published var brightness: Double {
        didSet {
            defaults.set(brightness, forKey: Keys.brightness)
            pushSettings()
        }
    }
    @Published var contrast: Double {
        didSet {
            defaults.set(contrast, forKey: Keys.contrast)
            pushSettings()
        }
    }
    @Published var tone: Double {
        didSet {
            defaults.set(tone, forKey: Keys.tone)
            pushSettings()
        }
    }
    @Published private(set) var panes: [AmberPane] = []
    @Published private(set) var isDrawing = false
    @Published private(set) var canCapture = false
    /// False until the first real capture attempt finishes, so the permission banner doesn't flash on launch.
    @Published private(set) var didCheckCapture = false

    private var windows: [UUID: AmberPaneWindow] = [:]
    private var probing = false
    private lazy var drawing = DrawingController(host: self)

    var settings: AmberSettings { AmberSettings(brightness: brightness, contrast: contrast, tone: tone) }
    var color: NSColor { settings.color }
    var previewFills: [NSColor] { [color.withAlphaComponent(0.45)] }
    var hintColor: NSColor { color }

    private init() {
        brightness = defaults.object(forKey: Keys.brightness) as? Double ?? 0
        contrast = defaults.object(forKey: Keys.contrast) as? Double ?? 1
        tone = defaults.object(forKey: Keys.tone) as? Double ?? 0
    }

    // MARK: Screen Recording permission

    /// Asks ScreenCaptureKit for the displays. That call is the real permission check:
    /// the preflight flag stays false when macOS approved an older, differently signed build.
    func probeCaptureAccess() {
        guard !probing else { return }
        probing = true
        Task {
            defer { probing = false }
            do {
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                didCheckCapture = true
                guard !canCapture else { return }
                canCapture = true
                for window in windows.values { startCapture(window) }
            } catch {
                canCapture = false
                didCheckCapture = true
                NSLog("Amber Glass screen capture is not allowed: \(error.localizedDescription)")
            }
        }
    }

    func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Clears the Screen Recording decision, which macOS keeps for the previous signature, then reopens.
    func resetPermissionAndRelaunch() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        task.arguments = ["reset", "ScreenCapture", Bundle.main.bundleIdentifier ?? "com.marlonski.amberglass"]
        try? task.run()
        task.waitUntilExit()
        relaunch()
    }

    func relaunch() {
        let path = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.5; open \"\(path)\""]
        try? task.run()
        NSApp.terminate(nil)
    }

    // MARK: Panes

    func restore() {
        guard let data = defaults.data(forKey: Keys.panes),
              let saved = try? JSONDecoder().decode([AmberPane].self, from: data) else { return }
        panes = saved
        saved.forEach(show)
    }

    func addPane(frame: CGRect) {
        if !canCapture { probeCaptureAccess() }
        var frame = frame.integral
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(CGPoint(x: frame.midX, y: frame.midY)) }) {
            frame = frame.intersection(screen.frame)
        }
        let pane = AmberPane(frame: frame)
        panes.append(pane)
        show(pane)
        savePanes()
    }

    func remove(_ id: UUID) {
        panes.removeAll { $0.id == id }
        windows.removeValue(forKey: id)?.close()
        savePanes()
    }

    func removePane(at screenPoint: CGPoint) {
        if let pane = panes.last(where: { $0.frame.contains(screenPoint) }) {
            remove(pane.id)
        }
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

    private func show(_ pane: AmberPane) {
        let window = AmberPaneWindow(frame: pane.frame, settings: settings)
        windows[pane.id] = window
        window.orderFrontRegardless()
        if canCapture { startCapture(window) }
    }

    private func startCapture(_ window: AmberPaneWindow) {
        Task {
            do {
                try await window.startCapture()
            } catch {
                NSLog("Amber Glass could not start capture: \(error.localizedDescription)")
                canCapture = false
                didCheckCapture = true
            }
        }
    }

    private func pushSettings() {
        let settings = settings
        windows.values.forEach { $0.update(settings) }
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

import AppKit
import Carbon.HIToolbox
import GlassKit
import SwiftUI

@main
struct BoxTintApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = TintStore.shared

    var body: some Scene {
        Window("Box Tint", id: "palette") {
            ControlPanel()
                .environmentObject(store)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra("Box Tint", systemImage: "square.on.square.intersection.dashed") {
            MenuContent()
                .environmentObject(store)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = TintStore.shared
        store.restore()
        HotKeys.register([
            HotKey(keyCode: kVK_ANSI_T, modifiers: HotKey.controlOptionCommand) { store.toggleDrawing() },
            HotKey(keyCode: kVK_ANSI_Z, modifiers: HotKey.controlOptionCommand) { store.undo() },
            HotKey(keyCode: kVK_Delete, modifiers: HotKey.controlOptionCommand) { store.clearAll() },
        ])
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

private struct MenuContent: View {
    @EnvironmentObject private var store: TintStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(store.isDrawing ? "Finish Drawing" : "Draw Glass") { store.toggleDrawing() }
        Button("Undo Last Pane") { store.undo() }
            .disabled(store.panes.isEmpty)
        Button("Clear All Panes") { store.clearAll() }
            .disabled(store.panes.isEmpty)
        Divider()
        Button("Show Palette…") {
            openWindow(id: "palette")
            NSApp.activate(ignoringOtherApps: true)
        }
        Divider()
        Button("Quit Box Tint") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

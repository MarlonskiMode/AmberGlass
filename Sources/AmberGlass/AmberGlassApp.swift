import AppKit
import Carbon.HIToolbox
import GlassKit
import SwiftUI

@main
struct AmberGlassApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = AmberStore.shared

    var body: some Scene {
        Window("Amber Glass", id: "palette") {
            ControlPanel()
                .environmentObject(store)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra("Amber Glass", systemImage: "rectangle.inset.filled") {
            MenuContent()
                .environmentObject(store)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = AmberStore.shared
        store.restore()
        store.probeCaptureAccess()
        HotKeys.register([
            HotKey(keyCode: kVK_ANSI_A, modifiers: HotKey.controlOptionCommand) { store.toggleDrawing() },
            HotKey(keyCode: kVK_ANSI_Z, modifiers: HotKey.controlOptionShiftCommand) { store.undo() },
            HotKey(keyCode: kVK_Delete, modifiers: HotKey.controlOptionShiftCommand) { store.clearAll() },
        ])
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

private struct MenuContent: View {
    @EnvironmentObject private var store: AmberStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(store.isDrawing ? "Finish Drawing" : "Draw Amber Pane") { store.toggleDrawing() }
        Button("Undo Last Pane") { store.undo() }
            .disabled(store.panes.isEmpty)
        Button("Clear All Panes") { store.clearAll() }
            .disabled(store.panes.isEmpty)
        Divider()
        Button("Show Controls…") {
            openWindow(id: "palette")
            NSApp.activate(ignoringOtherApps: true)
        }
        Divider()
        Button("Quit Amber Glass") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

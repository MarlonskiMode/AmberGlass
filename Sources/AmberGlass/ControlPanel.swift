import AppKit
import GlassKit
import SwiftUI

struct ControlPanel: View {
    @EnvironmentObject private var store: AmberStore

    private var amber: Color { Color(nsColor: store.color) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            AmberPreview(brightness: store.brightness, contrast: store.contrast, color: amber)
            if store.didCheckCapture && !store.canCapture {
                permissionBanner
            }
            dials
            actions
        }
        .padding(24)
        .frame(width: 360)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.probeCaptureAccess()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Amber Glass")
                .font(.system(size: 24, weight: .semibold, design: .serif))
            Text("Turn any part of your screen into an amber monitor.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Screen Recording permission needed", systemImage: "exclamationmark.triangle.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.orange)
            Text("If the switch in System Settings is already on, macOS is still remembering an older build. Remove Amber Glass from the list, relaunch, and allow it again. Panes stay a plain tint until then.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Open System Settings") { store.openScreenRecordingSettings() }
                Button("Reset and Relaunch") { store.resetPermissionAndRelaunch() }
            }
            .controlSize(.small)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(.orange.opacity(0.1)))
    }

    private var dials: some View {
        HStack(spacing: 28) {
            Spacer()
            Knob(
                title: "Tone",
                value: $store.tone,
                range: 0...1,
                defaultValue: 0,
                tint: amber
            ) { v in
                "#" + AmberFilter.color(tone: v).hexString
            }
            Knob(
                title: "Brightness",
                value: $store.brightness,
                range: -0.5...0.5,
                defaultValue: 0,
                bipolar: true,
                tint: amber
            ) { v in
                let n = Int((v * 200).rounded())
                return n > 0 ? "+\(n)" : n < 0 ? "−\(-n)" : "0"
            }
            Knob(
                title: "Contrast",
                value: $store.contrast,
                range: 0...2,
                defaultValue: 1,
                bipolar: true,
                tint: amber
            ) { v in
                "\(Int((v * 100).rounded()))%"
            }
            Spacer()
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                store.toggleDrawing()
            } label: {
                Label(store.isDrawing ? "Finish Drawing" : "Draw Amber Pane", systemImage: "rectangle.dashed")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(nsColor: store.color.blended(withFraction: 0.25, of: .black) ?? store.color))
            .controlSize(.large)

            HStack(spacing: 10) {
                Button {
                    store.undo()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward").frame(maxWidth: .infinity)
                }
                Button(role: .destructive) {
                    store.clearAll()
                } label: {
                    Label("Clear All", systemImage: "trash").frame(maxWidth: .infinity)
                }
            }
            .disabled(store.panes.isEmpty)

            HStack {
                Text("\(store.panes.count) pane\(store.panes.count == 1 ? "" : "s") on screen")
                Spacer()
                Text("⌃⌥⌘A draw  ·  ⌃⌥⇧⌘Z undo")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.top, 2)
        }
    }
}

/// Sample content run through an approximation of the amber filter.
private struct AmberPreview: View {
    let brightness: Double
    let contrast: Double
    let color: Color

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.blue, .green, .yellow, .red, .purple],
                startPoint: .leading,
                endPoint: .trailing
            )
            VStack(alignment: .leading, spacing: 4) {
                Text("Aa").font(.system(size: 30, weight: .bold, design: .serif))
                Text("The quick brown fox jumps over the lazy dog.")
                    .font(.caption)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
        }
        .grayscale(1)
        .brightness(brightness)
        .contrast(contrast)
        .colorMultiply(color)
        .frame(height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.1)))
    }
}

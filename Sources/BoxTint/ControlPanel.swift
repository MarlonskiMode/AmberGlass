import AppKit
import GlassKit
import SwiftUI

struct ControlPanel: View {
    @EnvironmentObject private var store: TintStore
    @State private var hexText = ""
    @FocusState private var hexFocused: Bool

    private let columns = Array(repeating: GridItem(.fixed(38), spacing: 12), count: 6)

    private var swiftColor: Color { Color(nsColor: store.color) }
    private var hexIsValid: Bool { HexColor.parse(hexText) != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            GlassPreview(fills: store.makePane(frame: .zero).fills, texture: store.glassTexture)
            palette
            hexRow
            opacityRow
            lightRow
            Toggle("Glass texture (sheen and leaded edge)", isOn: $store.glassTexture)
                .toggleStyle(.switch)
                .controlSize(.small)
            actions
        }
        .padding(24)
        .frame(width: 360)
        .onAppear { hexText = store.hex }
        .onChange(of: store.hex) { _, newValue in
            if !hexFocused { hexText = newValue }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Box Tint")
                .font(.system(size: 24, weight: .semibold, design: .serif))
            Text("Hold stained glass up to your screen.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var palette: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("Palette")
                Spacer()
                Text(Palette.name(for: store.hex) ?? "Custom")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(Palette.colors) { color in
                    Swatch(color: color, selected: color.hex == store.hex) {
                        store.hex = color.hex
                    }
                }
            }
        }
    }

    private var hexRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Hex")
            HStack(spacing: 10) {
                HStack(spacing: 2) {
                    Text("#").foregroundStyle(.secondary)
                    TextField("RRGGBB", text: $hexText)
                        .textFieldStyle(.plain)
                        .focused($hexFocused)
                        .onSubmit(commitHex)
                        .onChange(of: hexFocused) { _, focused in
                            if !focused { commitHex() }
                        }
                }
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.6)))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(hexIsValid ? Color.clear : Color.red.opacity(0.7), lineWidth: 1)
                )

                ColorPicker("Custom color", selection: Binding(
                    get: { swiftColor },
                    set: { store.hex = NSColor($0).hexString }
                ), supportsOpacity: false)
                .labelsHidden()
                .help("Choose any color")
            }
        }
    }

    private var opacityRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                SectionLabel("Density")
                Spacer()
                Text("\(Int((store.opacity * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $store.opacity, in: 0.05...0.95)
                .tint(swiftColor)
        }
    }

    private var lightRow: some View {
        HStack(alignment: .center, spacing: 22) {
            Knob(
                title: "Brightness",
                value: $store.brightness,
                range: -1...1,
                defaultValue: 0,
                bipolar: true,
                tint: swiftColor
            ) { v in
                let n = Int((v * 100).rounded())
                return n > 0 ? "+\(n)" : n < 0 ? "−\(-n)" : "0"
            }

            Knob(
                title: "Contrast",
                value: $store.contrast,
                range: 0.1...1,
                defaultValue: 1,
                tint: swiftColor
            ) { v in
                "\(Int((v * 100).rounded()))%"
            }

            Spacer()

            Button("Apply to All Panes") {
                store.applyCurrentSettingsToAll()
            }
            .controlSize(.small)
            .disabled(store.panes.isEmpty)
            .help("Give every pane on screen the current color, density, brightness and contrast")
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                store.toggleDrawing()
            } label: {
                Label(store.isDrawing ? "Finish Drawing" : "Draw Glass", systemImage: "rectangle.dashed")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
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
                Text("⌃⌥⌘T draw  ·  ⌃⌥⌘Z undo")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.top, 2)
        }
    }

    private func commitHex() {
        if store.applyHex(hexText) {
            hexText = store.hex
        }
    }
}

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1.2)
            .foregroundStyle(.secondary)
    }
}

private struct Swatch: View {
    let color: PaletteColor
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let base = color.nsColor
        let light = base.blended(withFraction: 0.35, of: .white) ?? base
        Button(action: action) {
            Circle()
                .fill(LinearGradient(
                    colors: [Color(nsColor: light), Color(nsColor: base)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                .shadow(color: Color(nsColor: base).opacity(hovering ? 0.6 : 0.3), radius: hovering ? 6 : 3)
                .padding(4)
                .overlay(Circle().strokeBorder(selected ? Color.primary.opacity(0.85) : .clear, lineWidth: 2))
                .frame(width: 38, height: 38)
                .scaleEffect(hovering ? 1.08 : 1)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(color.name)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .animation(.easeOut(duration: 0.15), value: selected)
    }
}

private struct GlassPreview: View {
    let fills: [NSColor]
    let texture: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.96), Color(white: 0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
            HStack(spacing: 0) {
                ForEach(0..<8) { i in
                    Rectangle().fill(i.isMultiple(of: 2) ? Color.black.opacity(0.06) : .clear)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Aa").font(.system(size: 30, weight: .bold, design: .serif))
                Text("The quick brown fox jumps over the lazy dog.")
                    .font(.caption)
            }
            .foregroundStyle(.black.opacity(0.8))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)

            ZStack {
                ForEach(fills.indices, id: \.self) { i in
                    Rectangle().fill(Color(nsColor: fills[i]))
                }
            }
            .overlay {
                if texture {
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.14), location: 0),
                            .init(color: .clear, location: 0.45),
                            .init(color: .white.opacity(0.06), location: 1),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .padding(.leading, 120)
            .padding(.vertical, 10)
        }
        .frame(height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.1)))
    }
}

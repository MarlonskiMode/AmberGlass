import SwiftUI

/// A rotary dial. Drag up/right to increase, down/left to decrease; double-click to reset.
public struct Knob: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let defaultValue: Double
    let bipolar: Bool
    let tint: Color
    let format: (Double) -> String

    @State private var dragStartValue: Double?

    public init(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        defaultValue: Double,
        bipolar: Bool = false,
        tint: Color = .accentColor,
        format: @escaping (Double) -> String
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.defaultValue = defaultValue
        self.bipolar = bipolar
        self.tint = tint
        self.format = format
    }

    private let sweep = 0.75
    private let dragDistanceForFullRange = 220.0
    private var span: Double { range.upperBound - range.lowerBound }
    private var fraction: Double { (value - range.lowerBound) / span }

    public var body: some View {
        VStack(spacing: 6) {
            dial
                .frame(width: 64, height: 64)
                .contentShape(Circle())
                .gesture(drag)
                .simultaneousGesture(TapGesture(count: 2).onEnded { value = defaultValue })
                .help("Drag to adjust · double-click to reset")
                .accessibilityElement()
                .accessibilityLabel(title)
                .accessibilityValue(format(value))
                .accessibilityAdjustableAction { direction in
                    let step = span / 20
                    switch direction {
                    case .increment: value = clamp(value + step)
                    case .decrement: value = clamp(value - step)
                    @unknown default: break
                    }
                }

            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(.secondary)
            Text(format(value))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.primary.opacity(0.8))
        }
    }

    private var dial: some View {
        let arcFrom = bipolar ? min(0.5, fraction) : 0
        let arcTo = bipolar ? max(0.5, fraction) : fraction

        return ZStack {
            Circle()
                .trim(from: 0, to: sweep)
                .stroke(.quaternary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(135))

            Circle()
                .trim(from: arcFrom * sweep, to: arcTo * sweep)
                .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(135))

            Circle()
                .fill(LinearGradient(
                    colors: [Color(white: 0.38), Color(white: 0.14)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
                .padding(10)

            Capsule()
                .fill(.white)
                .frame(width: 3, height: 11)
                .offset(y: -15)
                .rotationEffect(.degrees((fraction - 0.5) * sweep * 360))
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { gesture in
                let start = dragStartValue ?? value
                dragStartValue = start
                let distance = gesture.translation.width - gesture.translation.height
                value = clamp(start + distance / dragDistanceForFullRange * span)
            }
            .onEnded { _ in dragStartValue = nil }
    }

    private func clamp(_ v: Double) -> Double {
        min(max(v, range.lowerBound), range.upperBound)
    }
}

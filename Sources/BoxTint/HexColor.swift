import AppKit
import GlassKit
import SwiftUI

enum HexColor {
    /// Accepts `#RGB`, `#RRGGBB`, or `#RRGGBBAA` (with or without `#` / `0x`).
    /// Returns uppercase `RRGGBB` plus the alpha component when one was given.
    static func parse(_ input: String) -> (rgb: String, alpha: Double?)? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if text.hasPrefix("#") { text.removeFirst() }
        if text.hasPrefix("0X") { text.removeFirst(2) }
        guard !text.isEmpty, text.allSatisfy(\.isHexDigit) else { return nil }

        switch text.count {
        case 3:
            return (text.map { "\($0)\($0)" }.joined(), nil)
        case 6:
            return (text, nil)
        case 8:
            let alpha = Double(Int(text.suffix(2), radix: 16)!) / 255
            return (String(text.prefix(6)), alpha)
        default:
            return nil
        }
    }
}

extension NSColor {
    convenience init?(hex: String) {
        guard let parsed = HexColor.parse(hex), let value = UInt32(parsed.rgb, radix: 16) else { return nil }
        self.init(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}

struct PaletteColor: Identifiable {
    let name: String
    let hex: String
    var id: String { hex }
    var nsColor: NSColor { NSColor(hex: hex)! }
}

enum Palette {
    static let colors: [PaletteColor] = [
        .init(name: "Ruby", hex: "C0182B"),
        .init(name: "Vermilion", hex: "E4572E"),
        .init(name: "Amber", hex: "FFAA00"),
        .init(name: "Citrine", hex: "E8D21D"),
        .init(name: "Rose", hex: "E85D9C"),
        .init(name: "Garnet", hex: "7B1E3A"),

        .init(name: "Emerald", hex: "1F9D55"),
        .init(name: "Jade", hex: "00A88F"),
        .init(name: "Sea Glass", hex: "7FD1B9"),
        .init(name: "Azure", hex: "2D8CFF"),
        .init(name: "Cobalt", hex: "0047AB"),
        .init(name: "Sapphire", hex: "1B2F8F"),

        .init(name: "Amethyst", hex: "9B59B6"),
        .init(name: "Violet", hex: "5E2CA5"),
        .init(name: "Lavender", hex: "B9A3E3"),
        .init(name: "Smoke", hex: "5A5A66"),
        .init(name: "Sepia", hex: "8B6B3E"),
        .init(name: "Frost", hex: "DDE7F0"),
    ]

    static func name(for hex: String) -> String? {
        colors.first { $0.hex == hex }?.name
    }
}

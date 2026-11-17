import SwiftUI
import UIKit

/// ヒートマップの基準色。濃さはこの色の不透明度で表す（ライト／ダーク両方で段階が保たれる）。
struct ThemeColor: Codable, Equatable, Hashable {
    var red: Double
    var green: Double
    var blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    init(color: Color) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(red: min(max(Double(r), 0), 1),
                  green: min(max(Double(g), 0), 1),
                  blue: min(max(Double(b), 0), 1))
    }

    var color: Color { Color(red: red, green: green, blue: blue) }

    static let levelOpacities: [Double] = [0, 0.22, 0.45, 0.7, 1.0]

    /// level 0 は「記録が0の日」。データなしの日は別表示（枠線のみ）。
    func fill(level: Int) -> Color {
        guard level > 0 else { return Color.primary.opacity(0.09) }
        return color.opacity(Self.levelOpacities[min(level, 4)])
    }

    static let `default` = ThemePreset.all[0].theme  // オレンジ
}

struct ThemePreset: Identifiable {
    let name: String
    let theme: ThemeColor
    var id: String { name }

    static let all: [ThemePreset] = [
        ThemePreset(name: "オレンジ", theme: ThemeColor(hex: 0xF0883E)),
        ThemePreset(name: "緑", theme: ThemeColor(hex: 0x2EA043)),
        ThemePreset(name: "青", theme: ThemeColor(hex: 0x2F81F7)),
        ThemePreset(name: "紫", theme: ThemeColor(hex: 0x8957E5)),
        ThemePreset(name: "ピンク", theme: ThemeColor(hex: 0xDB61A2)),
        ThemePreset(name: "ティール", theme: ThemeColor(hex: 0x1A9E96)),
    ]
}

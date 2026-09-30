import SwiftUI
import UIKit

extension UIColor {
    nonisolated convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    /// Adaptive color that switches between a light and dark hex value.
    nonisolated init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    nonisolated init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }
}

/// revOWL palette: pearl and ivory by day, midnight by night, with teal and owl-eye gold accents.
enum Palette {
    static let canvas = Color(light: 0xF6F1E8, dark: 0x0A1224)
    static let canvasDeep = Color(light: 0xECE4D5, dark: 0x050B18)
    static let surface = Color(light: 0xFFFCF7, dark: 0x111B31)
    static let surfaceRaised = Color(light: 0xF2ECE1, dark: 0x192641)
    static let hairline = Color(light: 0xE3DACB, dark: 0x25324D)
    static let ink = Color(light: 0x0E1A33, dark: 0xF3EEE4)
    static let inkSecondary = Color(light: 0x4E5A72, dark: 0xA9B2C5)
    static let inkTertiary = Color(light: 0x7C8597, dark: 0x75809A)
    static let teal = Color(light: 0x0B7470, dark: 0x45C7BF)
    static let tealSoft = Color(light: 0xD8ECE8, dark: 0x113A3D)
    static let gold = Color(light: 0xAE6E14, dark: 0xF0B24A)
    static let goldSoft = Color(light: 0xF6E8CD, dark: 0x392B13)
    static let coral = Color(light: 0xAF4632, dark: 0xF08A72)
    static let coralSoft = Color(light: 0xF6DED7, dark: 0x3C1F1A)
    static let sage = Color(light: 0x2B7A4C, dark: 0x6FD19A)
    static let sageSoft = Color(light: 0xDCEEE2, dark: 0x15332A)
    static let onAccent = Color(light: 0xFFFFFF, dark: 0x052120)
    static let midnight = Color(hex: 0x0E1A33)
    static let owlAmber = Color(hex: 0xF2A332)
}

extension Font {
    /// Editorial serif (New York) that still scales with Dynamic Type.
    static func display(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .serif, weight: weight)
    }
}

enum Metrics {
    static let margin: CGFloat = 20
    static let cardRadius: CGFloat = 22
    static let smallRadius: CGFloat = 14
}

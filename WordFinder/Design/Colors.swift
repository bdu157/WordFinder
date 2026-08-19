import SwiftUI
import UIKit

/// Color tokens from the Claude Design system ("WordFinder 앱 디자인 방향안", section 1a
/// COLOR SYSTEM — still authoritative per the 2a note: "컬러·타입·컴포넌트 시스템은 그대로 유효").
///
/// `Color.accentColor` (Assets.xcassets/AccentColor) already carries the "Primary" role
/// (navy #1D3B63 light / #7FA6D9 dark) — used for selected tab, links, primary buttons.
/// Everything else lives here as dynamic (light/dark aware) colors.
extension Color {
    static let wfPrimaryFill = dynamic(light: 0x142946, dark: 0x2E4F7D)
    static let wfPrimaryTint = dynamic(light: 0xE6EBF2, dark: 0x1B2637)
    static let wfAccent = dynamic(light: 0xB26B2E, dark: 0xE0A567)
    static let wfBackground = dynamic(light: 0xF7F6F3, dark: 0x0E1420)
    static let wfSurface = dynamic(light: 0xFFFFFF, dark: 0x161E2C)
    static let wfTextPrimary = dynamic(light: 0x14171C, dark: 0xECEFF4)
    static let wfTextSecondary = dynamic(light: 0x5A6472, dark: 0x9BA6B6)
    static let wfSeparator = dynamic(light: 0xE2DED6, dark: 0x26303F)
    static let wfDestructive = dynamic(light: 0xA8402F, dark: 0xE4715C)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// Non-adaptive hex color, for one-off decorative use (e.g. mock camera backgrounds)
/// that isn't a semantic design token.
extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

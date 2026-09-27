import SwiftUI

enum ZuvanoColors {
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let tertiaryText = Color(.tertiaryLabel)
    static let contentBackground = Color(.systemGroupedBackground)
    static let rowBackground = Color(.secondarySystemGroupedBackground)

    /// Zuvano Indigo — primary application accent (#6366F1).
    static let indigo = Color(red: 99 / 255, green: 102 / 255, blue: 241 / 255)

    static let accent = indigo

    static let success = Color(.systemGreen)
    static let warning = Color(.systemOrange)
    static let error = Color(.systemRed)

    /// Logo gradient stops (Home mark only).
    enum LogoGradient {
        static let violet = Color(red: 166 / 255, green: 129 / 255, blue: 254 / 255)
        static let periwinkle = Color(red: 124 / 255, green: 124 / 255, blue: 252 / 255)
        static let blue = Color(red: 81 / 255, green: 95 / 255, blue: 253 / 255)
    }
}

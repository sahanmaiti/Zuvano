import SwiftUI

struct ZuvanoContentBackgroundModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    func body(content: Content) -> some View {
        content.background(backgroundColor)
    }

    private var backgroundColor: Color {
        if reduceTransparency || colorSchemeContrast == .increased {
            return Color(.systemBackground)
        }
        return ZuvanoColors.contentBackground
    }
}

extension View {
    func zuvanoContentBackground() -> some View {
        modifier(ZuvanoContentBackgroundModifier())
    }
}

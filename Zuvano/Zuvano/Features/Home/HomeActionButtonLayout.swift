import SwiftUI

extension View {
    /// Shared width and minimum touch height for Home capture actions.
    func homeActionButtonLayout() -> some View {
        frame(maxWidth: .infinity)
            .frame(minHeight: ZuvanoSpacing.minimumTouchTarget)
    }

    /// Secondary Home actions (Choose Photo, Enter Text).
    func homeSecondaryActionButtonStyle() -> some View {
        buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .controlSize(.large)
            .tint(ZuvanoColors.accent)
            .homeActionButtonLayout()
    }
}

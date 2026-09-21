import SwiftUI

extension View {
    /// Shared width and height for Home primary actions (Paste, Choose Photo, Enter Text).
    func homeActionButtonLayout() -> some View {
        frame(maxWidth: .infinity)
            .frame(minHeight: ZuvanoSpacing.homeActionButtonHeight)
    }

    /// Bordered capsule chrome used by SwiftUI home actions.
    func homeBorderedActionButtonStyle() -> some View {
        buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .homeActionButtonLayout()
    }
}

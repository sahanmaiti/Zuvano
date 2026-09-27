import SwiftUI

/// Original app logo for Home only. Do not use elsewhere in the app UI.
struct ZuvanoLogoMark: View {
    @ScaledMetric(relativeTo: .title) private var size: CGFloat = 72

    var body: some View {
        Image("ZuvanoLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

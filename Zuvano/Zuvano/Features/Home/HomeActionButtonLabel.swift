import SwiftUI

struct HomeActionButtonLabel: View {
    let title: String
    let systemImage: String
    var showsChevron = true

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer(minLength: 0)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

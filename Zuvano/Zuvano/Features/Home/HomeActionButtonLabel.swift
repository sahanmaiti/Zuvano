import SwiftUI

struct HomeActionButtonLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .frame(maxWidth: .infinity)
    }
}

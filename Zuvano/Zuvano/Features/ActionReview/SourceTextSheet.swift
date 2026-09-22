import SwiftUI

struct SourceTextSheet: View {
    let extractedText: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(extractedText)
                    .zuvanoMetaStyle()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(ZuvanoColors.contentBackground)
            .navigationTitle("Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

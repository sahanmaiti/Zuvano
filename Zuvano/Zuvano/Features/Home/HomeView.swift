import SwiftUI

struct HomeView: View {
    let onPaste: (String) -> Void
    let onChoosePhoto: () -> Void
    let onEnterText: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: ZuvanoSpacing.section) {
                VStack(spacing: ZuvanoSpacing.footnoteTop) {
                    Text("Turn a conversation into Calendar events and Reminders.")
                        .zuvanoScreenHeadlineStyle()
                        .accessibilityAddTraits(.isHeader)
                }
                .padding(.top, ZuvanoSpacing.emptyStateVertical)

                VStack(spacing: ZuvanoSpacing.actionStack) {
                    pasteButton
                    choosePhotoButton
                    enterTextButton
                }

                shareHint

                privacyLine
            }
            .padding(.horizontal)
            .padding(.bottom, ZuvanoSpacing.emptyStateVertical)
            .frame(maxWidth: .infinity)
        }
        .zuvanoContentBackground()
        .navigationTitle("Zuvano")
        .navigationBarTitleDisplayMode(.large)
    }

    /// Visible system `UIPasteControl` — required on iOS 16+ for authorized pasteboard access.
    private var pasteButton: some View {
        ZuvanoPasteControl { text in
            onPaste(text)
        }
        .frame(maxWidth: .infinity)
        .frame(height: ZuvanoSpacing.homeActionButtonHeight)
        .clipped()
        .accessibilityLabel("Paste")
        .accessibilityHint("Paste copied conversation text. iOS may ask to allow paste from the other app.")
    }

    private var choosePhotoButton: some View {
        Button(action: onChoosePhoto) {
            HomeActionButtonLabel(title: "Choose Photo", systemImage: "photo.on.rectangle")
        }
        .homeBorderedActionButtonStyle()
        .accessibilityLabel("Choose Photo")
        .accessibilityHint("Select a screenshot of a conversation.")
    }

    private var enterTextButton: some View {
        Button(action: onEnterText) {
            HomeActionButtonLabel(title: "Enter Text", systemImage: "text.alignleft")
        }
        .homeBorderedActionButtonStyle()
        .accessibilityLabel("Enter Text")
        .accessibilityHint("Type or paste conversation text manually.")
    }

    private var shareHint: some View {
        Label {
            Text("Or share text or a screenshot to Zuvano from another app.")
                .zuvanoMetaStyle()
        } icon: {
            Image(systemName: "square.and.arrow.up")
                .foregroundStyle(ZuvanoColors.secondaryText)
        }
        .labelStyle(.titleAndIcon)
        .symbolRenderingMode(.hierarchical)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Or share text or a screenshot to Zuvano from another app.")
    }

    private var privacyLine: some View {
        Text("On-device. Your conversation stays on this iPhone.")
            .zuvanoFootnoteStyle()
            .accessibilityLabel("On-device. Your conversation stays on this iPhone.")
    }
}

#Preview("Light") {
    NavigationStack {
        HomeView(
            onPaste: { _ in },
            onChoosePhoto: {},
            onEnterText: {}
        )
    }
}

#Preview("Dark") {
    NavigationStack {
        HomeView(
            onPaste: { _ in },
            onChoosePhoto: {},
            onEnterText: {}
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Large Dynamic Type") {
    NavigationStack {
        HomeView(
            onPaste: { _ in },
            onChoosePhoto: {},
            onEnterText: {}
        )
    }
    .dynamicTypeSize(.accessibility3)
}

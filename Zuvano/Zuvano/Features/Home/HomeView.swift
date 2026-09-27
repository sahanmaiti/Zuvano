import SwiftUI

struct HomeView: View {
    let onPaste: (String) -> Void
    let onChoosePhoto: () -> Void
    let onEnterText: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: ZuvanoSpacing.section) {
                brandingHeader
                    .padding(.top, ZuvanoSpacing.emptyStateVertical)

                VStack(spacing: ZuvanoSpacing.actionStack) {
                    pasteButton
                    choosePhotoButton
                    enterTextButton
                }

                shareHint

                privacyLine
            }
            .padding(.horizontal, 20)
            .padding(.bottom, ZuvanoSpacing.emptyStateVertical)
            .frame(maxWidth: .infinity)
        }
        .zuvanoContentBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var brandingHeader: some View {
        VStack(spacing: 16) {
            ZuvanoLogoMark()

            Text("Zuvano")
                .font(.largeTitle.bold())
                .foregroundStyle(ZuvanoColors.primaryText)
                .accessibilityAddTraits(.isHeader)

            Text("Turn a conversation into\nCalendar events and Reminders.")
                .font(.title3)
                .foregroundStyle(ZuvanoColors.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Zuvano. Turn a conversation into Calendar events and Reminders.")
    }

    /// Visible system `UIPasteControl` — required on iOS 16+ for authorized pasteboard access.
    private var pasteButton: some View {
        ZuvanoPasteControl { text in
            onPaste(text)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: ZuvanoSpacing.minimumTouchTarget)
        .clipped()
        .accessibilityLabel("Paste")
        .accessibilityHint("Paste copied conversation text. iOS may ask to allow paste from the other app.")
    }

    private var choosePhotoButton: some View {
        Button(action: onChoosePhoto) {
            HomeActionButtonLabel(title: "Choose Photo", systemImage: "photo.on.rectangle")
        }
        .homeSecondaryActionButtonStyle()
        .accessibilityLabel("Choose Photo")
        .accessibilityHint("Select a screenshot of a conversation.")
    }

    private var enterTextButton: some View {
        Button(action: onEnterText) {
            HomeActionButtonLabel(title: "Enter Text", systemImage: "text.alignleft")
        }
        .homeSecondaryActionButtonStyle()
        .accessibilityLabel("Enter Text")
        .accessibilityHint("Type or paste conversation text manually.")
    }

    private var shareHint: some View {
        Label {
            Text("Or share text or a screenshot to Zuvano from another app.")
                .font(.subheadline)
                .foregroundStyle(ZuvanoColors.secondaryText)
                .multilineTextAlignment(.center)
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
        Label {
            Text("On-device. Your conversation stays on this iPhone.")
                .zuvanoFootnoteStyle()
        } icon: {
            Image(systemName: "lock.fill")
                .font(.caption2)
        }
        .labelStyle(.titleAndIcon)
        .foregroundStyle(ZuvanoColors.tertiaryText)
        .accessibilityElement(children: .combine)
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
    .tint(ZuvanoColors.accent)
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
    .tint(ZuvanoColors.accent)
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
    .tint(ZuvanoColors.accent)
}

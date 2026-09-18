import PhotosUI
import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: HomeViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?
    @Environment(\.scenePhase) private var scenePhase

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
                }

                shareHint

                privacyLine
            }
            .padding(.horizontal)
            .padding(.bottom, ZuvanoSpacing.emptyStateVertical)
            .frame(maxWidth: .infinity)
        }
        .background(ZuvanoColors.contentBackground)
        .navigationTitle("Zuvano")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            viewModel.refreshClipboardState()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.refreshClipboardState()
            }
        }
        .onChange(of: selectedPhotoItem) { _, _ in
            // Day 1: selection is stored locally only; pipeline wiring arrives on Day 2.
        }
    }

    private var pasteButton: some View {
        Button {
            viewModel.pasteTapped()
        } label: {
            Label("Paste", systemImage: "doc.on.clipboard")
                .frame(maxWidth: .infinity)
                .frame(minHeight: ZuvanoSpacing.minimumTouchTarget)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.clipboardHasText)
        .accessibilityLabel("Paste")
        .accessibilityHint(pasteAccessibilityHint)
    }

    private var choosePhotoButton: some View {
        PhotosPicker(
            selection: $selectedPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            Label("Choose Photo", systemImage: "photo.on.rectangle")
                .frame(maxWidth: .infinity)
                .frame(minHeight: ZuvanoSpacing.minimumTouchTarget)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Choose Photo")
        .accessibilityHint("Select a screenshot of a conversation.")
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

    private var pasteAccessibilityHint: String {
        if viewModel.clipboardHasText {
            return "Paste copied text to start a new intake."
        }
        return "Unavailable. Copy text to your clipboard first."
    }
}

#Preview("Light") {
    NavigationStack {
        HomeView(viewModel: HomeViewModel())
    }
}

#Preview("Dark") {
    NavigationStack {
        HomeView(viewModel: HomeViewModel())
    }
    .preferredColorScheme(.dark)
}

#Preview("Large Dynamic Type") {
    NavigationStack {
        HomeView(viewModel: HomeViewModel())
    }
    .dynamicTypeSize(.accessibility3)
}

#Preview("Clipboard Available") {
    NavigationStack {
        HomeView(viewModel: HomeViewModel(clipboardChecker: StubClipboardChecker(hasPasteableText: true)))
    }
}

#Preview("Clipboard Empty") {
    NavigationStack {
        HomeView(viewModel: HomeViewModel(clipboardChecker: StubClipboardChecker(hasPasteableText: false)))
    }
}

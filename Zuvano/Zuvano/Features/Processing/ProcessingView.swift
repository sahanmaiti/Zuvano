import SwiftUI

struct ProcessingView: View {
    let intake: IntakeSnapshot
    let onCancel: () -> Void

    @State private var showDiscardConfirmation = false
    @State private var announcedPhase: ProcessingState?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: ZuvanoSpacing.section) {
            Spacer()

            ProgressView()
                .controlSize(.large)
                .accessibilityLabel(processingAccessibilityLabel)

            Text(statusCopy)
                .zuvanoScreenHeadlineStyle()
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.updatesFrequently)

            Spacer()
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ZuvanoColors.contentBackground)
        .navigationTitle("Processing")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    showDiscardConfirmation = true
                }
                .accessibilityHint("Stops processing and discards this conversation.")
            }
        }
        .confirmationDialog(
            "Discard this conversation?",
            isPresented: $showDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) {
                onCancel()
            }
            Button("Keep Processing", role: .cancel) {}
        }
        .animation(reduceMotion ? nil : .default, value: intake.processingState)
        .onChange(of: intake.processingState) { _, newPhase in
            announcePhaseIfNeeded(newPhase)
        }
        .onAppear {
            announcePhaseIfNeeded(intake.processingState)
        }
    }

    private func announcePhaseIfNeeded(_ phase: ProcessingState) {
        guard announcedPhase != phase else { return }
        announcedPhase = phase
        AccessibilityNotification.Announcement(statusCopy).post()
    }

    private var statusCopy: String {
        switch intake.processingState {
        case .importing, .extracting:
            switch intake.sourceType {
            case .image, .shareImage:
                return "Reading the screenshot…"
            case .text, .shareText:
                return "Reading text…"
            }
        case .understanding:
            return "Understanding the conversation…"
        case .generatingDrafts:
            return "Preparing actions…"
        default:
            return "Reading text…"
        }
    }

    private var processingAccessibilityLabel: String {
        "Processing. \(statusCopy)"
    }
}

#Preview("Text Extraction") {
    NavigationStack {
        ProcessingView(
            intake: IntakeSnapshot(
                id: UUID(),
                sourceType: .text,
                extractedText: nil,
                temporaryImageRef: nil,
                processingState: .extracting,
                failedStage: nil,
                failureReason: nil,
                createdAt: .now,
                updatedAt: .now
            ),
            onCancel: {}
        )
    }
}

#Preview("Screenshot Extraction") {
    NavigationStack {
        ProcessingView(
            intake: IntakeSnapshot(
                id: UUID(),
                sourceType: .image,
                extractedText: nil,
                temporaryImageRef: "sample.img",
                processingState: .extracting,
                failedStage: nil,
                failureReason: nil,
                createdAt: .now,
                updatedAt: .now
            ),
            onCancel: {}
        )
    }
}

#Preview("Dark") {
    NavigationStack {
        ProcessingView(
            intake: IntakeSnapshot(
                id: UUID(),
                sourceType: .text,
                extractedText: nil,
                temporaryImageRef: nil,
                processingState: .understanding,
                failedStage: nil,
                failureReason: nil,
                createdAt: .now,
                updatedAt: .now
            ),
            onCancel: {}
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Large Dynamic Type") {
    NavigationStack {
        ProcessingView(
            intake: IntakeSnapshot(
                id: UUID(),
                sourceType: .text,
                extractedText: nil,
                temporaryImageRef: nil,
                processingState: .extracting,
                failedStage: nil,
                failureReason: nil,
                createdAt: .now,
                updatedAt: .now
            ),
            onCancel: {}
        )
    }
    .dynamicTypeSize(.accessibility3)
}

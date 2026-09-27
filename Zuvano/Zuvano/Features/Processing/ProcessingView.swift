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
                .tint(ZuvanoColors.accent)
                .accessibilityLabel(processingAccessibilityLabel)

            Text(statusCopy)
                .font(.title2.weight(.semibold))
                .foregroundStyle(ZuvanoColors.primaryText)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.updatesFrequently)

            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .zuvanoContentBackground()
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
        .discardConversationConfirmation(
            isPresented: $showDiscardConfirmation,
            cancelTitle: "Keep Processing",
            onDiscard: onCancel
        )
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
    .tint(ZuvanoColors.accent)
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
    .tint(ZuvanoColors.accent)
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
    .tint(ZuvanoColors.accent)
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
    .tint(ZuvanoColors.accent)
}

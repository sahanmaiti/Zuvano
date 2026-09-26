import SwiftUI

struct PipelineFailureView: View {
    let intake: IntakeSnapshot
    let onRetry: () -> Void
    let onEnterText: () -> Void
    let onDiscard: () -> Void

    @State private var showDiscardConfirmation = false

    var body: some View {
        ContentUnavailableView {
            Label(failureTitle, systemImage: "exclamationmark.triangle")
        } description: {
            Text(failureDescription)
                .zuvanoMetaStyle()
        } actions: {
            VStack(spacing: ZuvanoSpacing.actionStack) {
                if showsRetry {
                    Button("Try Again", action: onRetry)
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: ZuvanoSpacing.minimumTouchTarget)
                        .accessibilityHint(retryAccessibilityHint)
                }

                if showsManualTextEntry {
                    Button("Enter Text", action: onEnterText)
                        .buttonStyle(.bordered)
                        .frame(minHeight: ZuvanoSpacing.minimumTouchTarget)
                        .accessibilityHint("Type the conversation text manually.")
                }

                Button("Discard", role: .destructive) {
                    showDiscardConfirmation = true
                }
                .frame(minHeight: ZuvanoSpacing.minimumTouchTarget)
            }
            .padding(.top, ZuvanoSpacing.footnoteTop)
        }
        .confirmationDialog(
            "Discard this conversation?",
            isPresented: $showDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive, action: onDiscard)
            Button("Keep", role: .cancel) {}
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .zuvanoContentBackground()
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    private var failureTitle: String {
        if intake.failureReason == .interrupted {
            return "Processing was interrupted"
        }

        switch intake.failedStage {
        case .extraction:
            return "Couldn't read the screenshot"
        case .understanding, .draftGeneration:
            return "Couldn't prepare actions"
        case .none:
            return "That content can't be used"
        }
    }

    private var failureDescription: String {
        if intake.failureReason == .interrupted {
            if showsManualTextEntry {
                return "Try again when you're ready, enter the text manually, or discard this conversation."
            }
            return "Try again when you're ready, or discard this conversation."
        }

        switch intake.failedStage {
        case .extraction:
            return "Try again, enter the text manually, or discard this conversation."
        case .understanding, .draftGeneration:
            return "Try again or discard this conversation."
        case .none:
            return "Try something else or discard this conversation."
        }
    }

    private var showsRetry: Bool {
        switch intake.failedStage {
        case .extraction, .understanding, .draftGeneration:
            true
        case .none:
            false
        }
    }

    private var showsManualTextEntry: Bool {
        intake.failedStage == .extraction
            && (intake.sourceType == .image || intake.sourceType == .shareImage)
    }

    private var retryAccessibilityHint: String {
        switch intake.failedStage {
        case .extraction:
            if intake.sourceType == .image || intake.sourceType == .shareImage {
                return "Retries reading the screenshot."
            }
            return "Retries reading the content."
        case .understanding, .draftGeneration:
            return "Retries preparing actions."
        case .none:
            return ""
        }
    }
}

#Preview("OCR Failure") {
    NavigationStack {
        PipelineFailureView(
            intake: IntakeSnapshot(
                id: UUID(),
                sourceType: .image,
                extractedText: nil,
                temporaryImageRef: "sample.img",
                processingState: .failed,
                failedStage: .extraction,
                failureReason: .ocrFailed,
                createdAt: .now,
                updatedAt: .now
            ),
            onRetry: {},
            onEnterText: {},
            onDiscard: {}
        )
    }
}

#Preview("Understanding Failure") {
    NavigationStack {
        PipelineFailureView(
            intake: IntakeSnapshot(
                id: UUID(),
                sourceType: .text,
                extractedText: "Sample conversation text.",
                temporaryImageRef: nil,
                processingState: .failed,
                failedStage: .understanding,
                failureReason: .interrupted,
                createdAt: .now,
                updatedAt: .now
            ),
            onRetry: {},
            onEnterText: {},
            onDiscard: {}
        )
    }
}

#Preview("Dark") {
    NavigationStack {
        PipelineFailureView(
            intake: IntakeSnapshot(
                id: UUID(),
                sourceType: .image,
                extractedText: nil,
                temporaryImageRef: "sample.img",
                processingState: .failed,
                failedStage: .extraction,
                failureReason: .ocrFailed,
                createdAt: .now,
                updatedAt: .now
            ),
            onRetry: {},
            onEnterText: {},
            onDiscard: {}
        )
    }
    .preferredColorScheme(.dark)
}

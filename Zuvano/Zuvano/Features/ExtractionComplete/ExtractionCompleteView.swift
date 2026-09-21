import SwiftUI

struct ExtractionCompleteView: View {
    let intake: IntakeSnapshot
    let onDone: () -> Void

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: ZuvanoSpacing.footnoteTop) {
                    Text("Text extracted")
                        .zuvanoContentHeadlineStyle()
                        .accessibilityAddTraits(.isHeader)

                    Text(extractionSourceLabel)
                        .zuvanoLeadingMetaStyle()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowBackground(Color.clear)
            }

            if let extractedText = intake.extractedText {
                Section {
                    Text(extractedText)
                        .font(.body)
                        .foregroundStyle(ZuvanoColors.primaryText)
                        .textSelection(.enabled)
                        .accessibilityLabel("Extracted conversation text")
                }
            }

            Section {
                Button("Done", action: onDone)
                    .frame(maxWidth: .infinity, minHeight: ZuvanoSpacing.minimumTouchTarget)
                    .accessibilityHint("Returns home and removes this conversation from Zuvano.")
            }
        }
        .navigationTitle("Extracted Text")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    private var extractionSourceLabel: String {
        switch intake.sourceType {
        case .image, .shareImage:
            return "From screenshot"
        case .text, .shareText:
            return "From pasted text"
        }
    }
}

#Preview {
    NavigationStack {
        ExtractionCompleteView(
            intake: IntakeSnapshot(
                id: UUID(),
                sourceType: .text,
                extractedText: "Yeah Friday works. Let's meet around 7 at the café near campus.",
                temporaryImageRef: nil,
                processingState: .understanding,
                failedStage: nil,
                failureReason: nil,
                createdAt: .now,
                updatedAt: .now
            ),
            onDone: {}
        )
    }
}

#Preview("Dark") {
    NavigationStack {
        ExtractionCompleteView(
            intake: IntakeSnapshot(
                id: UUID(),
                sourceType: .text,
                extractedText: "Yeah Friday works. Let's meet around 7 at the café near campus.",
                temporaryImageRef: nil,
                processingState: .understanding,
                failedStage: nil,
                failureReason: nil,
                createdAt: .now,
                updatedAt: .now
            ),
            onDone: {}
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Large Dynamic Type") {
    NavigationStack {
        ExtractionCompleteView(
            intake: IntakeSnapshot(
                id: UUID(),
                sourceType: .text,
                extractedText: "Yeah Friday works. Let's meet around 7 at the café near campus.",
                temporaryImageRef: nil,
                processingState: .understanding,
                failedStage: nil,
                failureReason: nil,
                createdAt: .now,
                updatedAt: .now
            ),
            onDone: {}
        )
    }
    .dynamicTypeSize(.accessibility3)
}

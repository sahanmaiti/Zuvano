import SwiftUI

struct UnderstandingResultsView: View {
    let intake: IntakeSnapshot
    let filteredIntents: [Intent]
    let onDone: () -> Void

    var body: some View {
        Group {
            if filteredIntents.isEmpty {
                emptyState
            } else {
                resultsList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ZuvanoColors.contentBackground)
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing to create", systemImage: "tray")
        } description: {
            Text("Zuvano didn't find anything for you to add to Calendar or Reminders.")
                .zuvanoMetaStyle()
        } actions: {
            Button("Done", action: onDone)
                .buttonStyle(.borderedProminent)
                .frame(minHeight: ZuvanoSpacing.minimumTouchTarget)
                .accessibilityHint("Returns home and removes this conversation from Zuvano.")
        }
        .padding(.horizontal)
    }

    private var resultsList: some View {
        List {
            Section {
                Text(headerCopy)
                    .zuvanoContentHeadlineStyle()
                    .accessibilityAddTraits(.isHeader)
                    .listRowBackground(Color.clear)
            }

            Section {
                ForEach(filteredIntents) { intent in
                    VStack(alignment: .leading, spacing: ZuvanoSpacing.footnoteTop) {
                        Label(actionKindLabel(for: intent), systemImage: actionSymbol(for: intent))
                            .font(.headline)
                            .foregroundStyle(ZuvanoColors.primaryText)

                        Text(intent.sourcePhrase)
                            .zuvanoLeadingMetaStyle()

                        if let entitySummary = entitySummary(for: intent) {
                            Text(entitySummary)
                                .zuvanoMetaStyle()
                        }

                        if intent.ambiguous {
                            Text(ambiguityFootnote(for: intent))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, ZuvanoSpacing.footnoteTop)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(accessibilityLabel(for: intent))
                }
            }

            Section {
                Button("Done", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, minHeight: ZuvanoSpacing.minimumTouchTarget)
                    .accessibilityHint("Returns home and removes this conversation from Zuvano.")
            }
        }
        .listStyle(.insetGrouped)
    }

    private var headerCopy: String {
        let count = filteredIntents.count
        if count == 1 {
            return "1 proposed action"
        }
        return "\(count) proposed actions"
    }

    private func actionKindLabel(for intent: Intent) -> String {
        switch intent.kind {
        case .meeting:
            "Calendar event"
        case .reminder, .task, .followUp, .commitment:
            "Reminder"
        }
    }

    private func actionSymbol(for intent: Intent) -> String {
        switch intent.kind {
        case .meeting:
            "calendar"
        case .reminder, .task, .followUp, .commitment:
            "checklist"
        }
    }

    private func entitySummary(for intent: Intent) -> String? {
        let parts = intent.entities.map { entity in
            if entity.ambiguous && entity.kind == .dateTime {
                return "About \(entity.rawExpression)"
            }
            return entity.rawExpression
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " · ")
    }

    private func ambiguityFootnote(for intent: Intent) -> String {
        if let timeEntity = intent.entities.first(where: { $0.kind == .dateTime && $0.ambiguous }) {
            return "About \(timeEntity.rawExpression), check before creating."
        }
        return "Check details before creating."
    }

    private func accessibilityLabel(for intent: Intent) -> String {
        var components = [actionKindLabel(for: intent), intent.sourcePhrase]
        if let summary = entitySummary(for: intent) {
            components.append(summary)
        }
        if intent.ambiguous {
            components.append(ambiguityFootnote(for: intent))
        }
        components.append("Proposal.")
        return components.joined(separator: ". ")
    }
}

#Preview("Multiple Actions") {
    NavigationStack {
        UnderstandingResultsView(
            intake: IntakeSnapshot(
                id: UUID(),
                sourceType: .text,
                extractedText: "Sample conversation.",
                temporaryImageRef: nil,
                processingState: .readyForReview,
                failedStage: nil,
                failureReason: nil,
                createdAt: .now,
                updatedAt: .now
            ),
            filteredIntents: [
                Intent(
                    kind: .meeting,
                    sourcePhrase: "Let's meet Friday around 7 at the café near campus.",
                    entities: [
                        IntentEntity(kind: .dateTime, rawExpression: "Friday"),
                        IntentEntity(kind: .dateTime, rawExpression: "around 7", ambiguous: true),
                        IntentEntity(kind: .location, rawExpression: "café near campus")
                    ],
                    confidence: .high,
                    ambiguous: true,
                    attribution: .userAction
                ),
                Intent(
                    kind: .reminder,
                    sourcePhrase: "Remind me Thursday to call Arjun.",
                    entities: [
                        IntentEntity(kind: .dateTime, rawExpression: "Thursday"),
                        IntentEntity(kind: .person, rawExpression: "Arjun")
                    ],
                    confidence: .high,
                    ambiguous: false,
                    attribution: .userAction
                )
            ],
            onDone: {}
        )
    }
}

#Preview("Nothing Actionable") {
    NavigationStack {
        UnderstandingResultsView(
            intake: IntakeSnapshot(
                id: UUID(),
                sourceType: .text,
                extractedText: "Did you send the file yesterday?",
                temporaryImageRef: nil,
                processingState: .readyForReview,
                failedStage: nil,
                failureReason: nil,
                createdAt: .now,
                updatedAt: .now
            ),
            filteredIntents: [],
            onDone: {}
        )
    }
}

#Preview("Dark") {
    NavigationStack {
        UnderstandingResultsView(
            intake: IntakeSnapshot(
                id: UUID(),
                sourceType: .text,
                extractedText: "Don't forget to bring the project files.",
                temporaryImageRef: nil,
                processingState: .readyForReview,
                failedStage: nil,
                failureReason: nil,
                createdAt: .now,
                updatedAt: .now
            ),
            filteredIntents: [
                Intent(
                    kind: .task,
                    sourcePhrase: "Don't forget to bring the project files.",
                    confidence: .medium,
                    attribution: .userAction
                )
            ],
            onDone: {}
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Large Dynamic Type") {
    NavigationStack {
        UnderstandingResultsView(
            intake: IntakeSnapshot(
                id: UUID(),
                sourceType: .text,
                extractedText: "Let's meet Friday around 7.",
                temporaryImageRef: nil,
                processingState: .readyForReview,
                failedStage: nil,
                failureReason: nil,
                createdAt: .now,
                updatedAt: .now
            ),
            filteredIntents: [
                Intent(
                    kind: .meeting,
                    sourcePhrase: "Let's meet Friday around 7 at the café near campus.",
                    entities: [
                        IntentEntity(kind: .dateTime, rawExpression: "around 7", ambiguous: true)
                    ],
                    confidence: .high,
                    ambiguous: true,
                    attribution: .userAction
                )
            ],
            onDone: {}
        )
    }
    .dynamicTypeSize(.accessibility3)
}

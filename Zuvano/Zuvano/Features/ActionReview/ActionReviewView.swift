import SwiftUI

struct ActionReviewView: View {
    let intake: IntakeSnapshot
    let drafts: [ActionDraftSnapshot]
    let onUpdateDraft: (ActionDraftSnapshot) -> Void
    let onSkip: (UUID) -> Void
    let onRestore: (UUID) -> Void
    let onCreate: (UUID) -> Void
    let onCreateAllReady: () -> Void
    let onCreateSelected: ([UUID]) -> Void
    let onDone: () -> Void

    @State private var editingDraft: ActionDraftSnapshot?
    @State private var showSourceText = false
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []

    private var pendingDrafts: [ActionDraftSnapshot] {
        drafts.filter { $0.confirmationState == .pending }
    }

    private var readyCount: Int {
        pendingDrafts.filter { DraftValidator.canCreate($0) }.count
    }

    private var invalidCount: Int {
        pendingDrafts.filter {
            switch DraftValidator.validationConcern(for: $0) {
            case .needsStartTime, .needsTitle: return true
            default: return false
            }
        }.count
    }

    private var allSkipped: Bool {
        !drafts.isEmpty && drafts.allSatisfy { $0.confirmationState == .rejected }
    }

    var body: some View {
        Group {
            if drafts.isEmpty {
                emptyState
            } else {
                reviewList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ZuvanoColors.contentBackground)
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar { toolbarContent }
        .sheet(item: $editingDraft) { draft in
            EditDraftSheet(draft: draft) { updated in
                onUpdateDraft(updated)
            }
        }
        .sheet(isPresented: $showSourceText) {
            if let text = intake.extractedText {
                SourceTextSheet(extractedText: text)
            }
        }
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

    private var reviewList: some View {
        List(selection: isSelecting ? $selectedIDs : .constant(Set<UUID>())) {
            Section {
                HStack {
                    Text(headerCopy)
                        .zuvanoContentHeadlineStyle()
                        .accessibilityAddTraits(.isHeader)

                    Spacer()

                    if intake.extractedText != nil {
                        Button("View source") {
                            showSourceText = true
                        }
                        .font(.subheadline)
                    }
                }
                .listRowBackground(Color.clear)

                if allSkipped {
                    Text("Every proposal was skipped.")
                        .zuvanoMetaStyle()
                        .listRowBackground(Color.clear)
                }

                if invalidCount > 0 && readyCount > 0 {
                    Text("\(invalidCount) need a start time.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
            }

            Section {
                ForEach(drafts) { draft in
                    DraftRowView(
                        draft: draft,
                        onEdit: { editingDraft = draft },
                        onCreate: { onCreate(draft.id) },
                        onSkip: { onSkip(draft.id) },
                        onRestore: { onRestore(draft.id) }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if draft.confirmationState == .rejected {
                            Button("Restore") { onRestore(draft.id) }
                                .tint(.blue)
                        } else if draft.confirmationState == .pending {
                            Button("Skip") { onSkip(draft.id) }
                                .tint(.orange)
                        }
                    }
                    .tag(draft.id)
                    .contextMenu {
                        if DraftValidator.canCreate(draft) {
                            Button("Create") { onCreate(draft.id) }
                        }
                        Button("Edit") { editingDraft = draft }
                        if draft.confirmationState == .rejected {
                            Button("Restore") { onRestore(draft.id) }
                        } else if draft.confirmationState == .pending {
                            Button("Skip") { onSkip(draft.id) }
                        }
                        if intake.extractedText != nil {
                            Button("View source") { showSourceText = true }
                        }
                    }
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
        .environment(\.editMode, isSelecting ? .constant(.active) : .constant(.inactive))
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if !drafts.isEmpty && readyCount > 0 {
            ToolbarItem(placement: .primaryAction) {
                if readyCount == 1, let draft = pendingDrafts.first(where: { DraftValidator.canCreate($0) }) {
                    Button("Create") { onCreate(draft.id) }
                        .disabled(!DraftValidator.canCreate(draft))
                } else if readyCount > 1 {
                    Button(createAllTitle) { onCreateAllReady() }
                }
            }
        }

        if drafts.count > 1 && readyCount > 1 {
            ToolbarItem(placement: .automatic) {
                Button(isSelecting ? "Cancel" : "Select") {
                    isSelecting.toggle()
                    if !isSelecting { selectedIDs.removeAll() }
                }
            }
        }

        if isSelecting && !selectedIDs.isEmpty {
            ToolbarItem(placement: .primaryAction) {
                Button("Create Selected (\(selectedIDs.count))") {
                    onCreateSelected(Array(selectedIDs))
                    isSelecting = false
                    selectedIDs.removeAll()
                }
            }
        }
    }

    private var headerCopy: String {
        let count = drafts.filter { $0.confirmationState != .rejected }.count
        if count == 1 {
            return "1 proposed action"
        }
        return "\(count) proposed actions"
    }

    private var createAllTitle: String {
        if invalidCount > 0 {
            return "Create \(readyCount) Ready"
        }
        return "Create All Ready"
    }
}

#Preview("Multiple Drafts") {
    NavigationStack {
        ActionReviewView(
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
            drafts: [
                ActionDraftSnapshot(
                    intakeID: UUID(),
                    intentKind: .meeting,
                    actionKind: .calendarEvent,
                    title: "Meeting",
                    sourcePhrase: "Let's meet Friday around 7 at the café near campus.",
                    when: ActionDateTime(rawExpression: "Friday, around 7", startDate: .now, ambiguous: true),
                    location: "café near campus",
                    confidence: .high,
                    ambiguous: true
                ),
                ActionDraftSnapshot(
                    intakeID: UUID(),
                    intentKind: .reminder,
                    actionKind: .reminder,
                    title: "Call Arjun",
                    sourcePhrase: "Remind me Thursday to call Arjun.",
                    when: ActionDateTime(rawExpression: "Thursday", startDate: .now),
                    person: "Arjun",
                    confidence: .high
                )
            ],
            onUpdateDraft: { _ in },
            onSkip: { _ in },
            onRestore: { _ in },
            onCreate: { _ in },
            onCreateAllReady: {},
            onCreateSelected: { _ in },
            onDone: {}
        )
    }
}

#Preview("Nothing Actionable") {
    NavigationStack {
        ActionReviewView(
            intake: IntakeSnapshot(
                id: UUID(),
                sourceType: .text,
                extractedText: "Did you send the file?",
                temporaryImageRef: nil,
                processingState: .readyForReview,
                failedStage: nil,
                failureReason: nil,
                createdAt: .now,
                updatedAt: .now
            ),
            drafts: [],
            onUpdateDraft: { _ in },
            onSkip: { _ in },
            onRestore: { _ in },
            onCreate: { _ in },
            onCreateAllReady: {},
            onCreateSelected: { _ in },
            onDone: {}
        )
    }
}

#Preview("Large Dynamic Type") {
    NavigationStack {
        ActionReviewView(
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
            drafts: [
                ActionDraftSnapshot(
                    intakeID: UUID(),
                    intentKind: .meeting,
                    actionKind: .calendarEvent,
                    title: "Meeting",
                    sourcePhrase: "Let's meet Friday around 7 at the café.",
                    when: ActionDateTime(rawExpression: "around 7", startDate: .now, ambiguous: true),
                    confidence: .high,
                    ambiguous: true
                )
            ],
            onUpdateDraft: { _ in },
            onSkip: { _ in },
            onRestore: { _ in },
            onCreate: { _ in },
            onCreateAllReady: {},
            onCreateSelected: { _ in },
            onDone: {}
        )
    }
    .dynamicTypeSize(.accessibility3)
}
